#!/usr/bin/env python3
"""Build a test-signed local Quest launcher with Android SDK tools, without Gradle/Unity."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk', default=os.environ.get('ANDROID_SDK_ROOT'))
parser.add_argument('--jdk', default=os.environ.get('JAVA_HOME'))
parser.add_argument('--dist', type=Path, default=REPO / 'dist')
parser.add_argument('--work-dir', type=Path, help='Optional isolated staging directory for this build')
args = parser.parse_args()
if not args.sdk or not args.jdk:
    parser.error('Specify --sdk and --jdk (or ANDROID_SDK_ROOT and JAVA_HOME).')
sdk, jdk, dist = Path(args.sdk).resolve(), Path(args.jdk).resolve(), args.dist.resolve()
out = REPO / 'quest-package/generated/local'
work = args.work_dir.resolve() if args.work_dir else out / 'work'
if out not in work.parents:
    raise SystemExit('--work-dir must be a subdirectory of quest-package/generated/local')
key = out / 'local-test.keystore'
release = REPO / 'release'
tools = sdk / 'build-tools/36.0.0'
android = sdk / 'platforms/android-34/android.jar'
env = dict(os.environ, JAVA_HOME=str(jdk), PATH=str(jdk / 'bin') + os.pathsep + os.environ.get('PATH',''))
manifest_settings = ET.parse(HERE/'AndroidManifest.xml').getroot()
android_namespace = '{http://schemas.android.com/apk/res/android}'
package_id = manifest_settings.attrib['package']
version_code = int(manifest_settings.attrib[android_namespace + 'versionCode'])
version_name = manifest_settings.attrib[android_namespace + 'versionName']
release_name = f'Dahrooj-local-test-v{version_code}'
# An update must remain installable over the delivered v1 without deleting player data.
v1_certificate = '4c8cebcce50fff6b2fddafe9d44b9de9882491d8a8fac98fa9c22fb790829967'
if version_code > 1 and not key.is_file():
    raise SystemExit(f'Restore the original local test signing key before building an update: {key}')

def run(*command, capture=False):
    result = subprocess.run([str(c) for c in command], env=env, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None, stderr=subprocess.STDOUT if capture else None)
    return result.stdout if capture else None

def digest(data):
    return hashlib.sha256(data).hexdigest()

for required in [android, tools/'aapt2', tools/'d8', tools/'zipalign', tools/'apksigner', jdk/'bin/javac', dist/'build.json', dist/'index.html']:
    if not required.is_file():
        raise SystemExit(f'Missing build input: {required}')
if work.exists(): shutil.rmtree(work)
for folder in [work/'assets',work/'classes',work/'java',work/'dex',work/'tests',release]: folder.mkdir(parents=True,exist_ok=True)
game = work/'assets/game'
shutil.copytree(dist,game)
shutil.copy2(HERE/'local-sw.js',game/'sw.js')
inventory = []
for file in sorted(game.rglob('*')):
    if file.is_file():
        path = file.relative_to(game).as_posix()
        if any(c in path for c in '\t\r\n') or file.is_symlink(): raise SystemExit('Invalid asset path')
        data = file.read_bytes()
        inventory.append((path,len(data),digest(data)))
(work/'assets/game-index.tsv').write_text(''.join(f'{p}\t{n}\t{h}\n' for p,n,h in inventory),encoding='utf-8')
game_build = json.loads((dist/'build.json').read_text())
(work/'assets/package-info.json').write_text(json.dumps({
    'package':package_id,'versionCode':version_code,'versionName':version_name,
    'gameBuild':game_build,'assetCount':len(inventory),'browser':'com.oculus.browser',
    'origin':'http://127.0.0.1:48189/','signing':'local test certificate',
    'questHardwareTested':False,'modifiedGameFiles':['sw.js'],
},ensure_ascii=False,indent=2),encoding='utf-8')

# Run transport regressions against real loopback sockets before packaging.
core = HERE/'src/com/abodengames/dahrooj/localtest/LocalAssetServer.java'
run(jdk/'bin/javac','-encoding','UTF-8','-d',work/'tests',core,*sorted((HERE/'test').rglob('*.java')))
test_result = run(jdk/'bin/java','-cp',work/'tests','com.abodengames.dahrooj.localtest.LocalAssetServerTest',capture=True)
print(test_result.strip(),flush=True)
(out/'server-tests.txt').write_text(test_result)

shutil.copytree(HERE/'res',work/'res')
shutil.copy2(dist/'icons/icon-192.png',work/'res/drawable/game_icon.png')
run(tools/'aapt2','compile','--dir',work/'res','-o',work/'resources.zip')
run(tools/'aapt2','link','-o',work/'base.apk','-I',android,'--manifest',HERE/'AndroidManifest.xml',
    '--java',work/'java','-A',work/'assets','-R',work/'resources.zip','--auto-add-overlay')
run(jdk/'bin/javac','-encoding','UTF-8','-source','8','-target','8','-Xlint:-options',
    '-bootclasspath',str(android)+os.pathsep+str(tools/'core-lambda-stubs.jar'),
    '-d',work/'classes',*sorted((HERE/'src').rglob('*.java')),*sorted((work/'java').rglob('*.java')))
run(jdk/'bin/jar','cf',work/'classes.jar','-C',work/'classes','.')
run(tools/'d8','--release','--lib',android,'--min-api','32','--output',work/'dex',work/'classes.jar')
with zipfile.ZipFile(work/'base.apk','a',compression=zipfile.ZIP_DEFLATED) as apk:
    for dex in sorted((work/'dex').glob('*.dex')): apk.write(dex,dex.name)
run(tools/'zipalign','-f','-p','4',work/'base.apk',work/'aligned.apk')
if not key.exists():
    run(jdk/'bin/keytool','-genkeypair','-keystore',key,'-storepass','android','-keypass','android',
        '-alias','androiddebugkey','-keyalg','RSA','-keysize','2048','-validity','10000',
        '-dname','CN=Dahrooj Local Test,O=Aboden Games,C=SA')
apk_path = release/(release_name + '.apk')
run(tools/'apksigner','sign','--ks',key,'--ks-key-alias','androiddebugkey','--ks-pass','pass:android',
    '--key-pass','pass:android','--v1-signing-enabled','false','--v2-signing-enabled','true',
    '--v3-signing-enabled','true','--out',apk_path,work/'aligned.apk')
verification = run(tools/'apksigner','verify','--verbose','--print-certs','--min-sdk-version','24',apk_path,capture=True)
if 'Verified using v2 scheme (APK Signature Scheme v2): true' not in verification:
    raise SystemExit('APK v2 signature verification failed')
if 'Verified using v3 scheme (APK Signature Scheme v3): true' not in verification:
    raise SystemExit('APK v3 signature verification failed')
certificate = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)',verification).group(1)
if version_code > 1 and certificate != v1_certificate:
    raise SystemExit('Signing certificate differs from v1; do not distribute this as an update')
run(tools/'zipalign','-c','-p','4',apk_path)
manifest = run(tools/'aapt2','dump','badging',apk_path,capture=True)
if "package: name='com.abodengames.dahrooj.localtest'" not in manifest: raise SystemExit('Wrong package')
if f"versionCode='{version_code}'" not in manifest or f"versionName='{version_name}'" not in manifest:
    raise SystemExit('APK version does not match package-info.json')
with zipfile.ZipFile(apk_path) as apk:
    names = apk.namelist()
    if len(set(names)) != len(names): raise SystemExit('Duplicate APK entries')
    if apk.testzip() is not None: raise SystemExit('Corrupt APK ZIP')
    for path,size,sha in inventory:
        data = apk.read('assets/game/' + path)
        if len(data) != size or digest(data) != sha: raise SystemExit('Asset mismatch: ' + path)
        if path != 'sw.js' and data != (dist/path).read_bytes(): raise SystemExit('Game changed: ' + path)
    if 'classes.dex' not in names: raise SystemExit('Missing application code')
sha = digest(apk_path.read_bytes())
(release/(apk_path.name + '.sha256')).write_text(f'{sha}  {apk_path.name}\n')
report = {'status':'built-and-verified','apk':apk_path.name,'bytes':apk_path.stat().st_size,'sha256':sha,
    'package':package_id,'versionCode':version_code,'versionName':version_name,
    'signingCertificateSha256':certificate,'sameCertificateAsV1':certificate==v1_certificate,
    'gameBuild':game_build,'assetCount':len(inventory),'assetBytes':sum(n for _,n,_ in inventory),
    'unmodifiedGameFiles':len(inventory)-1,'modifiedGameFiles':['sw.js'],
    'serverTests':test_result.strip(),'v2SignatureVerified':True,'v3SignatureVerified':True,'zipAlignmentVerified':True,
    'questHardwareTested':False,'nativeUnityPort':False,'requiresQuestBrowser':True,
    'firstLaunchWithoutInternetOnQuest':'NOT TESTED','vrAndArOnQuest':'NOT TESTED'}
(release/(release_name + '-build-report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2))
(out/'signature.txt').write_text(verification)
(out/'manifest.txt').write_text(manifest)
print(json.dumps(report,ensure_ascii=False,indent=2))
