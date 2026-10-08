import { Vector3 } from '@iwsdk/core';
const d = new Vector3();
export function segmentSphere(a: Vector3, b: Vector3, center: Vector3, radius: number) { d.subVectors(b, a); const denom = d.lengthSq(); const t = denom ? Math.max(0, Math.min(1, ((center.x - a.x) * d.x + (center.y - a.y) * d.y + (center.z - a.z) * d.z) / denom)) : 0; const x = a.x + d.x * t - center.x, y = a.y + d.y * t - center.y, z = a.z + d.z * t - center.z; return x * x + y * y + z * z <= radius * radius; }
/** Crossing detection interpolates the point; does not score a behind-target spawn. */
export function crossZ(a: Vector3, b: Vector3, z: number, out: Vector3) { if (a.z <= z || b.z > z)
    return false; return out.copy(a).lerp(b, (z - a.z) / (b.z - a.z)), true; }
export function crossY(a: Vector3, b: Vector3, y: number, out: Vector3) { if (a.y <= y || b.y > y)
    return false; return out.copy(a).lerp(b, (y - a.y) / (b.y - a.y)), true; }
