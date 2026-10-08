import './style.css';
import { Quality, QualitySystem } from './performance/quality';
import { AssetManager, World, SessionMode, ReferenceSpaceType } from '@iwsdk/core';
import { Bodies } from './physics/bodies';
import { Resources } from './rendering/resources';
import { SaveStore } from './save/store';
import { Events } from './core/events';
import { PlaySpace } from './core/space';
import { attachContext } from './core/context';
import type { GameContext } from './core/context';
import { Dahrooj, ModeOwned, Projectile } from './core/components';
import { BallPool, DahroojSystem } from './character/ball-pool';
import { ModeLifecycle, GameModeLifecycleSystem } from './modes/lifecycle';
import { InputState, ControllerInputSystem } from './input/controller-system';
import { ThrowSystem } from './input/throw-system';
import { ParticlePool } from './rendering/particles';
import { SpatialUI, UISystem } from './ui/spatial-ui';
import { Environment, EnvironmentSystem } from './world/environment';
import { AudioBus, AudioSystem } from './audio/audio';
import { MRPlacement, MRPlacementSystem } from './mr/placement';
import { XRSessionSystem, PlayerRigSystem, requestSession } from './xr/session-system';
import { Projectiles, ProjectileSystem } from './projectiles/projectiles';
import { PerformanceMonitor, PerformanceMonitorSystem } from './performance/monitor';
const status = document.getElementById('status')!, vr = document.getElementById('enter-vr') as HTMLButtonElement, ar = document.getElementById('enter-ar') as HTMLButtonElement;
async function boot() {
    if (import.meta.env.DEV && import.meta.env.VITE_XR_AUTOMATION === '1') {
        const { installEmulator } = await import('./platform/emulator');
        installEmulator();
    }
    if (!document.createElement('canvas').getContext('webgl2'))
        throw new Error('يلزم WebGL2 / WebGL2 required');
    const store = await new SaveStore().open();
    await Promise.allSettled([document.fonts.load('32px Dahrooj', 'دحروج'), document.fonts.load('32px Dahrooj', 'Dahrooj')]);
    const world = await World.create(document.getElementById('world')!, { xr: { sessionMode: SessionMode.ImmersiveVR, offer: 'none', launchOnSessionGranted: true, referenceSpace: { type: ReferenceSpaceType.LocalFloor, required: true }, features: { layers: true } }, render: { near: 0.03, far: 65 }, input: { canvasPointerEvents: false }, features: { physics: { useWorker: true, updateFrequency: 60, interpolation: true }, locomotion: false, grabbing: false, spatialUI: false } });
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
    world.registerComponent(Dahrooj).registerComponent(ModeOwned).registerComponent(Projectile);
    const c = { world, store, bodies: new Bodies(world), resources: new Resources(), events: new Events(), space: new PlaySpace(), input: new InputState(), xr: null, focused: false, tracked: false, placing: false, mode: 'goal', elapsed: 0, generation: 0 } as GameContext;
    attachContext(world, c);
    c.particles = new ParticlePool(world.scene, c.resources);
    c.balls = new BallPool(c);
    c.modes = new ModeLifecycle(c);
    c.projectiles = new Projectiles(c);
    c.audio = new AudioBus(c);
    c.environment = new Environment(c);
    c.mr = new MRPlacement(c);
    c.ui = new SpatialUI(c);
    c.performance = new PerformanceMonitor(c);
    c.quality = new Quality(c);
    c.bodies.pause(true);
    world.registerSystem(ControllerInputSystem, { priority: -10 }).registerSystem(UISystem, { priority: -9 }).registerSystem(XRSessionSystem, { priority: -8 }).registerSystem(MRPlacementSystem, { priority: -7 }).registerSystem(PlayerRigSystem, { priority: -3.9 }).registerSystem(ThrowSystem, { priority: -3.1 }).registerSystem(DahroojSystem, { priority: -1.8 }).registerSystem(ProjectileSystem, { priority: -1.7 }).registerSystem(GameModeLifecycleSystem, { priority: -1.6 }).registerSystem(EnvironmentSystem, { priority: -1.5 }).registerSystem(AudioSystem, { priority: 2 }).registerSystem(PerformanceMonitorSystem, { priority: 3 }).registerSystem(QualitySystem, { priority: 4 });
    const supports = await Promise.allSettled([navigator.xr?.isSessionSupported('immersive-vr'), navigator.xr?.isSessionSupported('immersive-ar')]);
    vr.disabled = !(supports[0].status === 'fulfilled' && supports[0].value);
    ar.disabled = !(supports[1].status === 'fulfilled' && supports[1].value);
    status.textContent = store.warning || (vr.disabled && ar.disabled ? 'افتح الرابط في Meta Quest Browser للعب. / Open in Meta Quest Browser.' : 'جاهز للرمي. اختر VR أو MR. / Ready. Choose VR or MR.');
    const enter = (mode: SessionMode) => { status.textContent = 'جارٍ فتح جلسة XR… / Starting XR…'; requestSession(c, mode); const started = performance.now(); const timer = setInterval(() => { if (world.renderer.xr.isPresenting) {
        clearInterval(timer);
        status.textContent = 'جاهز / Ready';
    }
    else if (!world.sessionRequestPending || performance.now() - started > 15000) {
        clearInterval(timer);
        status.textContent = 'لم تبدأ الجلسة. تحقق من أذونات المتصفح وأعد المحاولة. / Session did not start. Check permissions and retry.';
    } }, 500); };
    vr.onclick = () => enter(SessionMode.ImmersiveVR);
    ar.onclick = () => enter(SessionMode.ImmersiveAR);
    document.getElementById('export-performance')!.onclick = () => c.performance.export();
    document.getElementById('reset-save')!.onclick = async () => { if (confirm('حذف التقدم والإعدادات المحلية؟ Delete local progress and settings?')) {
        await store.reset();
        location.reload();
    } };
    const localizeGate = () => { const en = store.data.language === 'en'; document.documentElement.lang = en ? 'en' : 'ar'; document.documentElement.dir = en ? 'ltr' : 'rtl'; document.querySelector('h1')!.textContent = en ? 'Hi, I’m Dahrooj.' : 'أهلًا، أنا دحروج.'; document.querySelector('.eyebrow')!.textContent = en ? 'Small world. Big throws.' : 'عالم صغير. رميات كبيرة.'; document.getElementById('intro')!.textContent = en ? 'Hold me, throw me, and play nine modes. Made for Meta Quest headsets.' : 'امسكني، ارمني، والعب في تسعة أنماط. تجربة مخصصة لنظارات Meta Quest.'; document.querySelector('.hint')!.textContent = en ? 'Grip: hold and release to throw. B: modes. Open in Meta Quest Browser.' : 'استخدم Grip للإمساك، وأفلته للرمي. زر B يفتح الأنماط. افتح في Meta Quest Browser.'; vr.textContent = en ? 'Virtual Reality · VR' : 'الواقع الافتراضي · VR'; ar.textContent = en ? 'Mixed Reality · MR' : 'الواقع المختلط · MR'; document.getElementById('language')!.textContent = en ? 'العربية' : 'English'; document.getElementById('reset-save')!.textContent = en ? 'Delete local save' : 'حذف الحفظ المحلي'; document.getElementById('export-performance')!.textContent = en ? 'Export performance' : 'تصدير قياس الأداء'; };
    document.getElementById('language')!.onclick = () => { store.data.language = store.data.language === 'ar' ? 'en' : 'ar'; store.touch(); localizeGate(); };
    localizeGate();
    document.addEventListener('visibilitychange', () => { if (document.hidden)
        void store.flush(); });
    if (import.meta.env.DEV) {
        const { attachDevelopment } = await import('./platform/development');
        attachDevelopment(c);
    }
    if (import.meta.env.PROD && 'serviceWorker' in navigator)
        void navigator.serviceWorker.register('/sw.js').catch(() => { status.textContent += ' · تعذّر تفعيل اللعب دون اتصال.'; });
}
void boot().catch(error => { console.error(error); status.textContent = 'تعذّر تحميل اللعبة. تحقق من الاتصال ثم أعد المحاولة. / Could not initialize. Check your connection and retry.'; const retry = document.createElement('button'); retry.textContent = 'إعادة المحاولة · Retry'; retry.onclick = () => location.reload(); status.after(retry); });
