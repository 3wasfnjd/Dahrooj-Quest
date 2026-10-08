import { Quaternion, Vector3, createSystem } from '@iwsdk/core';
import { contextOf } from '../core/context';
import { PoseHistory } from './pose-history';
export class HandState {
    readonly position = new Vector3();
    readonly orientation = new Quaternion();
    readonly ray = new Vector3();
    readonly direction = new Vector3(0, 0, -1);
    readonly history = new PoseHistory();
    tracked = false;
    grip = false;
    trigger = false;
    primary = false;
    secondary = false;
    gripDown = false;
    gripUp = false;
    triggerDown = false;
    triggerUp = false;
    primaryDown = false;
    secondaryDown = false;
    axisX = 0;
    axisY = 0;
    source?: XRInputSource;
    clear() { this.tracked = this.grip = this.trigger = this.primary = this.secondary = this.gripDown = this.gripUp = this.triggerDown = this.triggerUp = this.primaryDown = this.secondaryDown = false; this.axisX = this.axisY = 0; this.history.clear(); }
}
export class InputState {
    readonly left = new HandState();
    readonly right = new HandState();
    readonly head = new Vector3();
    readonly orientation = new Quaternion();
    time = 0;
    clear() { this.left.clear(); this.right.clear(); }
    sample(frame: XRFrame, reference: XRReferenceSpace, focused: boolean, time: number) {
        this.time = time;
        const viewer = frame.getViewerPose(reference);
        if (!viewer || !focused) {
            this.clear();
            return false;
        }
        this.head.copy(viewer.transform.position);
        this.orientation.copy(viewer.transform.orientation);
        const left = this.left, right = this.right;
        let sawLeft = false, sawRight = false;
        for (const source of frame.session.inputSources) {
            if (source.handedness !== 'left' && source.handedness !== 'right')
                continue;
            const h = source.handedness === 'left' ? left : right;
            if (h === left)
                sawLeft = true;
            else
                sawRight = true;
            const grip = source.gripSpace && frame.getPose(source.gripSpace, reference), ray = frame.getPose(source.targetRaySpace, reference);
            if (!grip || !ray || !source.gamepad) {
                h.clear();
                continue;
            }
            const previouslyTracked = h.tracked;
            h.tracked = true;
            h.source = source;
            h.position.copy(grip.transform.position);
            h.orientation.copy(grip.transform.orientation);
            h.ray.copy(ray.transform.position);
            h.direction.set(0, 0, -1).applyQuaternion(this.rayQuaternion.copy(ray.transform.orientation));
            h.history.push(h.position, h.orientation, time);
            const b = source.gamepad.buttons, g = (b[1]?.value || 0) > 0.55, t = (b[0]?.value || 0) > 0.55, a = !!b[4]?.pressed, menu = !!b[5]?.pressed;
            h.gripDown = previouslyTracked && g && !h.grip;
            h.gripUp = previouslyTracked && !g && h.grip;
            h.triggerDown = previouslyTracked && t && !h.trigger;
            h.triggerUp = previouslyTracked && !t && h.trigger;
            h.primaryDown = previouslyTracked && a && !h.primary;
            h.secondaryDown = previouslyTracked && menu && !h.secondary;
            h.grip = g;
            h.trigger = t;
            h.primary = a;
            h.secondary = menu;
            const axis = source.gamepad.axes;
            h.axisX = Math.abs(axis[2] || axis[0] || 0) < 0.15 ? 0 : axis[2] || axis[0] || 0;
            h.axisY = axis[3] || axis[1] || 0;
        }
        if (!sawLeft)
            left.clear();
        if (!sawRight)
            right.clear();
        return true;
    }
    private rayQuaternion = new Quaternion();
}
export class ControllerInputSystem extends createSystem({}) {
    private registered = false;
    update() { if (this.registered)
        return; this.registered = true; const c = contextOf(this.world); this.world.onXRFrame(frame => { if (!frame || !this.world.xrReferenceSpace)
        return; const focused = frame.session.visibilityState === 'visible'; c.focused = focused; c.tracked = c.input.sample(frame, this.world.xrReferenceSpace, focused, performance.now() / 1000); c.mr.frame(frame, this.world.xrReferenceSpace); }); }
}
