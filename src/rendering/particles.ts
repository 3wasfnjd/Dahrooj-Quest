import { InstancedMesh, Matrix4, Quaternion, Vector3, Color } from '@iwsdk/core';
import type { Scene } from '@iwsdk/core';
import { LIMITS, seeded } from '../core/config';
import type { Resources } from './resources';
export class ParticlePool {
    private parts = Array.from({ length: LIMITS.sparks }, () => ({ p: new Vector3(), v: new Vector3(), life: 0, max: 1, size: 0.01, color: new Color() }));
    private mesh: InstancedMesh;
    private matrix = new Matrix4();
    private q = new Quaternion();
    private scale = new Vector3();
    private random = seeded(76);
    private next = 0;
    constructor(scene: Scene, r: Resources) { this.mesh = new InstancedMesh(r.lowSphere, r.mat(0xffffff, true), LIMITS.sparks); this.mesh.count = 0; this.mesh.name = 'pooled-sparks'; scene.add(this.mesh); }
    burst(at: Vector3, color = 0xf2c14e, count = 12, power = 1) { for (let i = 0; i < Math.min(count, LIMITS.sparks); i++) {
        const p = this.parts[this.next++ % this.parts.length];
        p.p.copy(at);
        p.v.set(this.random() - 0.5, this.random(), this.random() - 0.5).multiplyScalar(power * 2);
        p.life = p.max = 0.3 + this.random() * 0.4;
        p.size = 0.012 * power;
        p.color.setHex(i % 3 ? color : 0xfffaf2);
    } }
    update(dt: number) { let n = 0; for (const p of this.parts) {
        if (p.life <= 0)
            continue;
        p.life -= dt;
        p.v.y -= 4 * dt;
        p.p.addScaledVector(p.v, dt);
        this.scale.setScalar(Math.max(0, p.size * p.life / p.max));
        this.matrix.compose(p.p, this.q, this.scale);
        this.mesh.setMatrixAt(n, this.matrix);
        this.mesh.setColorAt(n++, p.color);
    } this.mesh.count = n; this.mesh.instanceMatrix.needsUpdate = true; if (this.mesh.instanceColor)
        this.mesh.instanceColor.needsUpdate = true; if (n)
        this.mesh.computeBoundingSphere(); }
    clear() { for (const p of this.parts)
        p.life = 0; this.mesh.count = 0; }
}
