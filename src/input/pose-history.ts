import { Quaternion, Vector3 } from '@iwsdk/core';
import { clamp, PHYSICS } from '../core/config';
/** Fixed storage. Reject tracking jumps; estimate a recency-weighted short release window. */
export class PoseHistory {
    private samples = Array.from({ length: 24 }, () => ({ p: new Vector3(), q: new Quaternion(), t: -1 }));
    private index = 0;
    private count = 0;
    private dq = new Quaternion();
    private v = new Vector3();
    clear() { this.count = 0; this.index = 0; }
    push(p: Vector3, q: Quaternion, time: number) {
        if (!Number.isFinite(p.lengthSq()) || !Number.isFinite(time))
            return false;
        if (this.count) {
            const prev = this.samples[(this.index + 23) % 24];
            const dt = time - prev.t;
            if (dt <= 0)
                return false;
            if (dt > 0.12 || p.distanceTo(prev.p) > Math.max(0.15, dt * 22)) {
                this.clear();
                return false;
            }
        }
        const s = this.samples[this.index];
        s.p.copy(p);
        s.q.copy(q).normalize();
        s.t = time;
        this.index = (this.index + 1) % 24;
        this.count = Math.min(24, this.count + 1);
        return true;
    }
    release(velocity: Vector3, angular: Vector3, now: number) {
        velocity.set(0, 0, 0);
        angular.set(0, 0, 0);
        if (this.count < 3)
            return;
        const last = this.samples[(this.index + 23) % 24];
        if (now - last.t > 0.1)
            return;
        let weight = 0;
        for (let i = 2; i <= this.count; i++) {
            const a = this.samples[(this.index + 24 - i) % 24], dt = last.t - a.t;
            if (dt < 0.02 || dt > 0.11)
                continue;
            const w = Math.exp(-dt * 9);
            this.v.subVectors(last.p, a.p).divideScalar(dt);
            velocity.addScaledVector(this.v, w);
            weight += w;
        }
        if (weight)
            velocity.divideScalar(weight).clampLength(0, PHYSICS.maxThrowSpeed);
        const a = this.samples[(this.index + 24 - Math.min(this.count, 6)) % 24], dt = last.t - a.t;
        if (dt > 0.01) {
            this.dq.copy(a.q).invert().premultiply(last.q).normalize();
            if (this.dq.w < 0)
                this.dq.set(-this.dq.x, -this.dq.y, -this.dq.z, -this.dq.w);
            const angle = 2 * Math.acos(clamp(this.dq.w, -1, 1));
            angular.set(this.dq.x, this.dq.y, this.dq.z).normalize().multiplyScalar(angle / dt).clampLength(0, PHYSICS.maxSpin);
        }
    }
}
export function magnus(velocity: Vector3, spin: Vector3, out: Vector3) { return out.crossVectors(spin, velocity).multiplyScalar(0.008).clampLength(0, Math.min(PHYSICS.maxCurveAcceleration, velocity.length() * 0.22)); }
export function chargeSpeed(seconds: number) { const phase = Math.max(0, seconds) / 1.1 % 2; return 3 + 12 * (phase < 1 ? phase : 2 - phase); }
