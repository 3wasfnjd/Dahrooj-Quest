import { SessionMode, Vector3, createSystem } from '@iwsdk/core';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
export function requestSession(c: GameContext, mode: SessionMode) { c.audio.unlock(); c.world.launchXR({ sessionMode: mode, features: { hitTest: mode === SessionMode.ImmersiveAR, planeDetection: mode === SessionMode.ImmersiveAR, anchors: mode === SessionMode.ImmersiveAR, layers: true, handTracking: false } }); }
export class XRSessionSystem extends createSystem({}) {
    private session: XRSession | null = null;
    private lastFocus = false;
    private forward = new Vector3();
    private up = new Vector3(0, 1, 0);
    update() {
        const c = contextOf(this.world), session = c.world.renderer.xr.getSession();
        if (session && session !== this.session) {
            this.session = session;
            c.xr = session.environmentBlendMode === 'opaque' ? 'immersive-vr' : 'immersive-ar';
            c.focused = session.visibilityState === 'visible';
            c.ui.close();
            document.getElementById('gate')!.hidden = true;
            c.space.scale = 1;
            c.space.origin.set(c.input.head.x, 0, c.input.head.z);
            this.forward.set(0, 0, -1).applyQuaternion(c.input.orientation);
            c.space.rotation.setFromAxisAngle(this.up, Math.atan2(-this.forward.x, -this.forward.z));
            if (c.xr === 'immersive-ar')
                void c.mr.begin();
            else {
                c.environment.rebuild();
                c.modes.activate(c.mode);
            }
            // A supported frame-rate request is a preference, never measured performance evidence.
            const rates = session.supportedFrameRates;
            if (rates && Array.from(rates).includes(72))
                void session.updateTargetFrameRate(72).catch(() => { });
            session.addEventListener('visibilitychange', () => { c.focused = session.visibilityState === 'visible'; if (!c.focused) {
                c.input.clear();
                c.bodies.pause(true);
                void c.store.flush();
            } });
        }
        else if (!session && this.session) {
            this.session = null;
            c.xr = null;
            c.tracked = false;
            c.input.clear();
            c.mr.end();
            c.ui.close();
            c.modes.suspend();
            c.environment.dispose();
            c.bodies.pause(true);
            document.getElementById('gate')!.hidden = false;
            void c.store.flush();
        }
        if (this.session)
            c.focused = this.session.visibilityState === 'visible';
        c.bodies.pause(!playing(c));
        const focus = !!c.xr && c.focused && c.tracked;
        if (focus !== this.lastFocus) {
            this.lastFocus = focus;
            c.audio.focus(focus);
            if (!focus)
                c.input.clear();
        }
    }
}
// Run after IWSDK input updates so a controller adapter cannot reveal its model while blurred.
export class PlayerRigSystem extends createSystem({}) {
    update() {
        const c = contextOf(this.world), focused = !!c.xr && c.focused && c.tracked;
        const adapters = c.world.input.xr.visualAdapters;
        const left = adapters.controller.left, right = adapters.controller.right;
        if (left.visual)
            left.visual.model.visible = focused && c.input.left.tracked && left.isPrimary;
        if (right.visual)
            right.visual.model.visible = focused && c.input.right.tracked && right.isPrimary;
    }
}
export function recenterWorld(c: GameContext) {
    if (c.xr !== 'immersive-vr')
        return;
    // Rebuild content around the current heading. Never move the XR camera or origin rig.
    const forward = new Vector3(0, 0, -1).applyQuaternion(c.input.orientation);
    c.space.origin.set(c.input.head.x, 0, c.input.head.z);
    c.space.rotation.setFromAxisAngle(new Vector3(0, 1, 0), Math.atan2(-forward.x, -forward.z));
    c.environment.rebuild();
    c.modes.activate(c.mode);
    c.ui.close();
}
