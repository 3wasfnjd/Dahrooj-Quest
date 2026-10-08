import { createRequire } from 'node:module';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { config, fingerprint } from './deployment-config.mjs';
const require = createRequire(process.env.BUBBLEWRAP_PACKAGE_JSON || import.meta.url);
const { TwaManifest, TwaGenerator, ConsoleLog } = require('@meta-quest/bubblewrap-core');
const app = await config({ signing: true }), baseline = JSON.parse(await readFile('quest-package/meta-baseline.json', 'utf8'));
const code = Number(process.env.APK_VERSION_CODE || app.versionCode);
if (!Number.isSafeInteger(code) || code < 1)
    throw new Error('APK_VERSION_CODE must be a positive integer greater than all released versions.');
const twa = new TwaManifest({ packageId: app.packageId, applicationId: app.metaApplicationId, host: new URL(app.origin).host, name: 'Dahrooj — دحروج', launcherName: 'Dahrooj', display: 'fullscreen', themeColor: '#262932', navigationColor: '#262932', backgroundColor: '#262932', enableNotifications: false, enableMicrophone: false, enableXRScene: true, enableSiteSettingsShortcut: true, startUrl: '/', iconUrl: app.origin + '/icons/icon-512.png', maskableIconUrl: app.origin + '/icons/maskable-512.png', splashScreenFadeOutDuration: 150, signingKey: { path: process.env.SIGNING_KEY_PATH, alias: process.env.ANDROID_KEY_ALIAS }, appVersion: app.version, appVersionCode: code, webManifestUrl: app.origin + '/manifest.webmanifest', fallbackType: 'customtabs', features: {}, isMetaQuest: true, horizonOSAppMode: 'immersive', fullScopeUrl: app.origin + '/', minSdkVersion: baseline.minSdk, orientation: 'landscape', fingerprints: [{ name: 'permanent-release', value: fingerprint(process.env.ANDROID_CERT_SHA256) }] });
const dir = 'quest-package/generated';
await mkdir(dir, { recursive: true });
await twa.saveToFile(dir + '/twa-manifest.json');
await new TwaGenerator().createTwaProject(dir, twa, new ConsoleLog('Dahrooj Quest'));
// Bubblewrap 1.24.1 still emits Quest SDK 32 and optional head tracking.
// Apply the reviewed current Meta baseline; assertions fail if its template changes.
let gradle = await readFile(dir + '/app/build.gradle', 'utf8');
if (!gradle.includes('compileSdkVersion 32') || !gradle.includes('targetSdkVersion 32'))
    throw new Error('Bubblewrap Gradle template changed: review baseline patch');
gradle = gradle.replace('compileSdkVersion 32', `compileSdkVersion ${baseline.compileSdk}`).replace('targetSdkVersion 32', `targetSdkVersion ${baseline.targetSdk}`);
await writeFile(dir + '/app/build.gradle', gradle);
let manifest = await readFile(dir + '/app/src/main/AndroidManifest.xml', 'utf8');
if (!manifest.includes('android.hardware.vr.headtracking'))
    throw new Error('Quest headtracking missing');
manifest = manifest.replace(/(<manifest\b[^>]*)(>)/, '$1 android:installLocation="auto"$2').replace(/(android:name="android.hardware.vr.headtracking"\s+android:required=")false"/, '$1true"').replace('<application', '<application android:debuggable="false" android:usesCleartextTraffic="false"').replace('<activity android:name="LauncherActivity"', '<activity android:name="LauncherActivity" android:excludeFromRecents="true"').replace(/\s*<uses-permission android:name="com.oculus.permission.HAND_TRACKING"\s*\/>/g, '').replace(/\s*<uses-feature\s+android:name="oculus.software.handtracking"\s+android:required="false"\s*\/>/g, '').replace('</application>', '<meta-data android:name="com.oculus.supportedDevices" android:value="quest2|quest3|quest3s" /></application>');
await writeFile(dir + '/app/src/main/AndroidManifest.xml', manifest);
await writeFile(dir + '/local.properties', `sdk.dir=${process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT}\n`);
console.log('Generated immersive Quest project; production signing happens outside Gradle using secret environment inputs.');
