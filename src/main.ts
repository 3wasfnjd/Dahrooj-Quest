import './style.css';
import {AssetManager, World, SessionMode, ReferenceSpaceType} from '@iwsdk/core';
import {SaveStore} from './save/store';
import {createCompleteGame} from './reference/complete-game.js';
import {XR_MODE_CATALOG} from './reference/mode-catalog';
import {readDiagnosticOptions} from './rendering/diagnostic-options';
import {prepareXRQuality,readXRQualityOptions} from './rendering/diagnostic-quality';
import {automaticQualityEnabled} from './rendering/auto-quality-bridge';
import {attachAutomaticQuality} from './rendering/automatic-quality';
const status = document.getElementById('status')!, vr = document.getElementById('enter-vr') as HTMLButtonElement, ar = document.getElementById('enter-ar') as HTMLButtonElement;
async function boot() {
    if (import.meta.env.DEV && import.meta.env.VITE_XR_AUTOMATION === '1') {
        const { installEmulator } = await import('./platform/emulator');
        installEmulator();
    }
    if (!document.createElement('canvas').getContext('webgl2'))
        throw new Error('يلزم WebGL2 / WebGL2 required');
    const store = await new SaveStore().open();
    await Promise.allSettled([document.fonts.load('32px Dahrooj', 'دحروج'), document.fonts.load('32px Dahrooj', 'Dahrooj'), document.fonts.load('800 240px Dahrooj', '0123456789')]);
    const world = await World.create(document.getElementById('world')!, { xr: { sessionMode: SessionMode.ImmersiveVR, offer: 'none', launchOnSessionGranted: true, referenceSpace: { type: ReferenceSpaceType.LocalFloor, required: true }, features: { layers: true } }, render: { near: 0.03, far: 65 }, input: { canvasPointerEvents: false }, features: { physics: false, locomotion: false, grabbing: false, spatialUI: false } });
    // Controller models requested by xr-input are redirected to the application origin.
    AssetManager.loadingManager.setURLModifier(url => { const marker = '/@webxr-input-profiles/assets@1.0/dist/profiles/'; const index = url.indexOf(marker); if (index >= 0) {
        const path = url.slice(index + marker.length);
        const allowed = ['meta-quest-touch-plus', 'meta-quest-touch-plus-v2', 'meta-quest-touch-pro', 'oculus-touch-v2', 'oculus-touch-v3'];
        if (!allowed.includes(path.split('/')[0]))
            return `/vendor/profiles/oculus-touch-v3/${path.endsWith('right.glb') ? 'right.glb' : 'left.glb'}`;
        return '/vendor/profiles/' + path;
    } if (/^https?:/.test(url) && new URL(url).origin !== location.origin)
        throw new Error('External runtime asset blocked: ' + new URL(url).origin); return url; });
    world.renderer.setPixelRatio(1);
    world.renderer.shadowMap.enabled = false;
    world.renderer.xr.setFoveation(0.6);
    const game=createCompleteGame(world,store);
    const diagnosticOptions=readDiagnosticOptions(location.search);
    const qualityOptions=readXRQualityOptions(location.search);
    const automatic=automaticQualityEnabled(location.search)?attachAutomaticQuality(world,()=>game.inspectRendering().mode):null;
    if(automatic)world.addCleanup(()=>automatic.dispose());
    const diagnostics=diagnosticOptions.enabled?(await import('./rendering/render-diagnostics')).attachRenderDiagnostics(world,game,diagnosticOptions):null;
    // Runtime entry sets its legacy foveation; restore the fixed setting before drawing.
    if(!automatic&&!diagnostics)world.addCleanup(world.onXRFrame(()=>{
        if(world.renderer.xr.getFoveation()!==qualityOptions.foveation)world.renderer.xr.setFoveation(qualityOptions.foveation);
    }));
    const supports = await Promise.allSettled([navigator.xr?.isSessionSupported('immersive-vr'), navigator.xr?.isSessionSupported('immersive-ar')]);
    vr.disabled = !(supports[0].status === 'fulfilled' && supports[0].value);
    ar.disabled = !(supports[1].status === 'fulfilled' && supports[1].value);
    status.textContent = store.warning || (vr.disabled && ar.disabled ? 'افتح الرابط في Meta Quest Browser للعب. / Open in Meta Quest Browser.' : 'جاهز للرمي. اختر VR أو MR. / Ready. Choose VR or MR.');
    const enter = (mode: SessionMode) => { status.textContent = 'جارٍ فتح جلسة XR… / Starting XR…'; automatic?.prepare(mode); prepareXRQuality(world.renderer.xr,qualityOptions); game.start(mode); const started = performance.now(); const timer = setInterval(() => { if (world.renderer.xr.isPresenting) {
        clearInterval(timer);
        status.textContent = 'جاهز / Ready';
    }
    else if (!world.sessionRequestPending || performance.now() - started > 15000) {
        clearInterval(timer);
        status.textContent = 'لم تبدأ الجلسة. تحقق من أذونات المتصفح وأعد المحاولة. / Session did not start. Check permissions and retry.';
    } }, 500); };
    vr.onclick = () => enter(SessionMode.ImmersiveVR);
    ar.onclick = () => enter(SessionMode.ImmersiveAR);
    document.getElementById('export-performance')!.onclick = () => {
        if(diagnostics){diagnostics.download();return;}
        if(!automatic){game.export();return;}
        const href=URL.createObjectURL(new Blob([JSON.stringify({game:game.report(),automaticQuality:automatic.report()},null,2)],{type:'application/json'}));
        const a=document.createElement('a');a.href=href;a.download='dahrooj-auto-quality.json';a.click();setTimeout(()=>URL.revokeObjectURL(href),1000);
    };
    document.getElementById('reset-save')!.onclick = async () => { if (confirm('حذف التقدم والإعدادات المحلية؟ Delete local progress and settings?')) {
        await store.reset();
        location.reload();
    } };
    const localizeGate = () => { const en = store.data.language === 'en'; document.documentElement.lang = en ? 'en' : 'ar'; document.documentElement.dir = en ? 'ltr' : 'rtl'; document.querySelector('h1')!.textContent = en ? 'Hi, I’m Dahrooj.' : 'أهلًا، أنا دحروج.'; document.querySelector('.eyebrow')!.textContent = en ? 'Small world. Big throws.' : 'عالم صغير. رميات كبيرة.'; document.getElementById('intro')!.textContent = en ? `Hold me, throw me, and play ${XR_MODE_CATALOG.length} modes. Made for Meta Quest headsets.` : `امسكني، ارمني، والعب في ${XR_MODE_CATALOG.length.toLocaleString('ar')} نمطًا. تجربة مخصصة لنظارات Meta Quest.`; document.querySelector('.hint')!.textContent = en ? 'Trigger: hold and release to throw. Y: modes. B: settings. X: challenges. Open in Meta Quest Browser.' : 'استخدم الزناد للإمساك وأفلته للرمي. زر Y للأنماط وB للإعدادات وX للتحديات. افتح في Meta Quest Browser.'; vr.textContent = en ? 'Virtual Reality · VR' : 'الواقع الافتراضي · VR'; ar.textContent = en ? 'Mixed Reality · MR' : 'الواقع المختلط · MR'; document.getElementById('language')!.textContent = en ? 'العربية' : 'English'; document.getElementById('reset-save')!.textContent = en ? 'Delete local save' : 'حذف الحفظ المحلي'; document.getElementById('export-performance')!.textContent = en ? 'Export performance' : 'تصدير قياس الأداء'; };
    document.getElementById('language')!.onclick = () => { store.data.language = store.data.language === 'ar' ? 'en' : 'ar'; store.touch(); localizeGate(); };
    localizeGate();
    document.addEventListener('visibilitychange', () => { if (document.hidden)
        void store.flush(); });
    if (import.meta.env.DEV) {
        const { attachReferenceDevelopment } = await import('./platform/reference-development');
        attachReferenceDevelopment(game);
    }
    if (import.meta.env.PROD && 'serviceWorker' in navigator)
        void navigator.serviceWorker.register('/sw.js').catch(() => { status.textContent += ' · تعذّر تفعيل اللعب دون اتصال.'; });
}
void boot().catch(error => { console.error(error); status.textContent = 'تعذّر تحميل اللعبة. تحقق من الاتصال ثم أعد المحاولة. / Could not initialize. Check your connection and retry.'; const retry = document.createElement('button'); retry.textContent = 'إعادة المحاولة · Retry'; retry.onclick = () => location.reload(); status.after(retry); });
