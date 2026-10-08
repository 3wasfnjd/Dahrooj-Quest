import { Quaternion, Vector3 } from '@iwsdk/core';
/** The only miniature transform. Camera and XR origin always remain at native scale. */
export class PlaySpace {
    origin = new Vector3();
    rotation = new Quaternion();
    scale = 1;
    point(x: number, y: number, z: number, out = new Vector3()) { return out.set(x, y, z).multiplyScalar(this.scale).applyQuaternion(this.rotation).add(this.origin); }
    local(point: Vector3, out: Vector3) { out.copy(point).sub(this.origin); const x = this.rotation.x, y = this.rotation.y, z = this.rotation.z, w = this.rotation.w; this.inverse.set(-x, -y, -z, w); return out.applyQuaternion(this.inverse).divideScalar(this.scale); }
    vector(x: number, y: number, z: number, out = new Vector3()) { return out.set(x, y, z).applyQuaternion(this.rotation); }
    private inverse = new Quaternion();
}
