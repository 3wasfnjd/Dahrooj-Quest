import { expect, it } from 'vitest';
import { Vector3 } from '@iwsdk/core';
import { crossY, crossZ, segmentSphere } from '../../src/physics/sweep';
it('detects a fast projectile crossing a small target between frames', () => { expect(segmentSphere(new Vector3(0, 1, 0), new Vector3(0, 1, -10), new Vector3(0, 1, -5), 0.1)).toBe(true); expect(segmentSphere(new Vector3(0, 1, 0), new Vector3(0, 1, -10), new Vector3(1, 1, -5), 0.1)).toBe(false); });
it('scores downward hoop crossing and forward goal crossing only', () => { const p = new Vector3(); expect(crossY(new Vector3(0, 3, 0), new Vector3(0, 2, 0), 2.5, p)).toBe(true); expect(p.y).toBe(2.5); expect(crossY(new Vector3(0, 2, 0), new Vector3(0, 3, 0), 2.5, p)).toBe(false); expect(crossZ(new Vector3(1, 2, -2), new Vector3(1, 1, -4), -3, p)).toBe(true); expect(p.y).toBe(1.5); });
