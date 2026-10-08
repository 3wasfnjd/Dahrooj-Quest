"""Validate the actual signed APK using Android SDK tools, never source XML alone."""
import hashlib, json, os, re, subprocess, sys, zipfile
from pathlib import Path
apk=Path(sys.argv[1]); baseline=json.loads(Path('quest-package/meta-baseline.json').read_text()); app=json.loads(Path('quest-package/app-config.json').read_text()); sdk=Path(os.environ.get('ANDROID_HOME',os.environ.get('ANDROID_SDK_ROOT',''))); bt=sdk/'build-tools'/baseline['buildTools']
def run(*args):return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT)
signature=run(str(bt/'apksigner'),'verify','--verbose','--print-certs',str(apk))
badging=run(str(bt/'aapt'),'dump','badging',str(apk)); xml=run(str(bt/'aapt'),'dump','xmltree',str(apk),'AndroidManifest.xml'); resources=run(str(bt/'aapt'),'dump','resources',str(apk))
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature,'Missing v2 signature'
actual=re.search(r'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]+)',signature).group(1).upper();expected=os.environ['ANDROID_CERT_SHA256'].replace(':','').upper();assert actual==expected,'Release certificate mismatch'
assert f"package: name='{app['packageId']}'" in badging,'Package mismatch'
assert f"sdkVersion:'{baseline['minSdk']}'" in badging and f"targetSdkVersion:'{baseline['targetSdk']}'" in badging,'SDK baseline mismatch'
assert 'application-debuggable' not in badging,'Debuggable release'
assert 'android.hardware.vr.headtracking' in badging and "uses-feature-not-required: name='android.hardware.vr.headtracking'" not in badging,'Required headtracking missing'
assert 'quest2|quest3|quest3s' in xml,'Supported devices missing'
assert re.search(r'installLocation[^\n]*0x0\b',xml),'installLocation must be auto'
assert re.search(r'excludeFromRecents[^\n]*0xffffffff',xml),'Launcher must be excluded from recents'
assert 'horizonOSAppMode' in resources and '"immersive"' in resources,'Missing immersive mode resource'
permissions=re.findall(r"uses-permission: name='([^']+)'",badging);allowed={'android.permission.INTERNET','android.permission.ACCESS_NETWORK_STATE','com.oculus.permission.USE_SCENE','android.permission.WAKE_LOCK','com.abodengames.dahrooj.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
assert not(set(permissions)-allowed),f'Unexpected permissions: {set(permissions)-allowed}'
with zipfile.ZipFile(apk) as z:
 libs=[n for n in z.namelist() if n.startswith('lib/') and n.endswith('.so')]
 assert all(n.startswith(('lib/arm64-v8a/','lib/x86_64/')) for n in libs),'32-bit native library'
size=apk.stat().st_size;assert size<min(baseline['maximumApkBytes'],baseline['internalApkBudgetBytes']),'APK over budget'
digest=hashlib.sha256(apk.read_bytes()).hexdigest();Path('reports').mkdir(exist_ok=True);Path('reports/apk-signature.txt').write_text(signature);Path('reports/apk-manifest.txt').write_text(xml);Path('reports/apk-validation.json').write_text(json.dumps(dict(status='PASS',packageId=app['packageId'],bytes=size,sha256=digest,certificateSHA256=actual,permissions=permissions,nativeLibraries=libs,hardwareTest=False),indent=2));Path(str(apk)+'.sha256').write_text(f'{digest}  {apk.name}\n');print('تم التحقق من توقيع APK وبيانات الحزمة. لا يعني ذلك اجتياز اختبارات النظارة أو المتجر.')
