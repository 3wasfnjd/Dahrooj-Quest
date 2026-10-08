import { describe, expect, it } from 'vitest';
import { Vector3, Quaternion } from '@iwsdk/core';
import { PoseHistory, magnus, chargeSpeed } from '../../src/input/pose-history';
describe('Physical release estimation', () => {
    for (const hz of [60, 72, 90, 120])
        for (const speed of [0.6, 4, 12])
            it(`estimates ${speed} m/s at ${hz} Hz`, () => { const h = new PoseHistory(), v = new Vector3(), w = new Vector3(), p = new Vector3(), q = new Quaternion(), axis = new Vector3(0, 1, 0); for (let i = 0; i < 20; i++)
                h.push(p.set(0, 1.3, -i / hz * speed), q.setFromAxisAngle(axis, i / hz * 6), i / hz); h.release(v, w, 19 / hz); expect(v.z).toBeCloseTo(-speed, 4); expect(w.y).toBeCloseTo(6, 4); });
    it('rejects tracking jumps and stale releases', () => { const h = new PoseHistory(), p = new Vector3(), q = new Quaternion(), v = new Vector3(), w = new Vector3(); for (let i = 0; i < 8; i++)
        h.push(p.set(i / 90, 1, 0), q, i / 90); h.release(v, w, 1); expect(v.length()).toBe(0); expect(h.push(p.set(3, 1, 0), q, 8 / 90)).toBe(false); h.release(v, w, 8 / 90); expect(v.length()).toBe(0); });
    it('bounds the curve and decays it with speed', () => { const out = new Vector3(), spin = new Vector3(0, 45, 0); magnus(new Vector3(0, 0, -18), spin, out); expect(out.length()).toBeLessThanOrEqual(3.2); expect(out.x).toBeLessThan(0); magnus(new Vector3(0, 0, -0.1), spin, out); expect(out.length()).toBeLessThanOrEqual(0.022000001); });
    it('retains the 3–15 m/s 1.1 second charge rhythm', () => { expect(chargeSpeed(0)).toBe(3); expect(chargeSpeed(1.1)).toBe(15); expect(chargeSpeed(2.2)).toBe(3); });
});
