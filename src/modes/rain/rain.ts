import { InstancedMesh, Matrix4, Quaternion, Vector3 } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { LIMITS, seeded } from '../../core/config';
import { ModeScope } from '../scope';
import { segmentSphere } from '../../physics/sweep';
export class RainMode {
    readonly id = 'rain' as const;
    readonly scope: ModeScope;
    score = 0;
    private mesh: InstancedMesh;
    private eyes: InstancedMesh;
    private matrix = new Matrix4();
    private q = new Quaternion();
    private p = new Vector3();
    private size = new Vector3();
    private random = seeded(231);
    private drops = Array.from({ length: LIMITS.rain }, () => ({ p: new Vector3(), v: new Vector3(), radius: 0.09, cooldown: 0 }));
    constructor(readonly c: GameContext) { this.scope = new ModeScope(c); this.mesh = this.scope.add(new InstancedMesh(c.resources.lowSphere, c.resources.mat(0x80334c), LIMITS.rain)); this.eyes = this.scope.add(new InstancedMesh(c.resources.lowSphere, c.resources.mat(0xf4e5da), LIMITS.rain * 2)); for (const d of this.drops)
        this.reset(d); }
    private reset(d: typeof this.drops[number]) { d.p.set((this.random() - 0.5) * 5, 1.5 + this.random() * 5, -0.7 - this.random() * 5); d.v.set((this.random() - 0.5) * 0.2, -0.1, 0); d.radius = 0.065 + this.random() * 0.07; d.cooldown = 0; }
    update(dt: number) {
        const c = this.c;
        const count = c.quality.level === 2 ? 80 : c.quality.level === 1 ? 100 : LIMITS.rain;
        this.mesh.count = count;
        this.eyes.count = count * 2;
        let promoted = c.balls.active;
        for (let i = 0; i < count; i++) {
            const d = this.drops[i];
            d.cooldown = Math.max(0, d.cooldown - dt);
            d.v.y -= 9.81 * dt;
            d.p.addScaledVector(d.v, dt);
            if (d.p.y < d.radius) {
                d.p.y = d.radius;
                d.v.y = Math.max(0.8, -d.v.y * 0.5);
                d.v.x *= 0.85;
                if (d.v.y < 1.1)
                    this.reset(d);
            }
            c.space.point(d.p.x, d.p.y, d.p.z, this.p);
            if (d.cooldown === 0 && promoted < LIMITS.rainBodies && (this.p.distanceToSquared(c.input.right.position) < 0.45 ** 2 || this.p.distanceToSquared(c.input.left.position) < 0.45 ** 2)) {
                const b = c.balls.acquire(this.p, c.store.data.style, true);
                if (b) {
                    this.size.copy(d.v).applyQuaternion(c.space.rotation).multiplyScalar(Math.sqrt(c.space.scale));
                    c.balls.launch(b, this.size, this.p.set(0, 0, 0));
                    promoted++;
                    this.score++;
                    this.reset(d);
                    d.cooldown = 1;
                }
            }
            c.space.point(d.p.x, d.p.y, d.p.z, this.p);
            this.size.setScalar(d.radius * c.space.scale);
            this.matrix.compose(this.p, c.space.rotation, this.size);
            this.mesh.setMatrixAt(i, this.matrix);
            for (let eye = 0; eye < 2; eye++) {
                c.space.point(d.p.x + (eye ? 1 : -1) * d.radius * 0.3, d.p.y + d.radius * 0.2, d.p.z + d.radius * 0.87, this.p);
                this.size.setScalar(d.radius * 0.18 * c.space.scale);
                this.matrix.compose(this.p, c.space.rotation, this.size);
                this.eyes.setMatrixAt(i * 2 + eye, this.matrix);
            }
        }
        this.mesh.instanceMatrix.needsUpdate = this.eyes.instanceMatrix.needsUpdate = true;
        this.mesh.computeBoundingSphere();
        this.eyes.computeBoundingSphere();
    }
    hitProjectile(from: Vector3, to: Vector3, radius: number) { for (let i = 0; i < this.mesh.count; i++) {
        const d = this.drops[i];
        this.c.space.point(d.p.x, d.p.y, d.p.z, this.p);
        if (segmentSphere(from, to, this.p, radius + d.radius * this.c.space.scale)) {
            this.c.particles.burst(this.p, 0xe2603f, 12, this.c.space.scale);
            this.c.events.emit('impact', { position: this.p, power: 0.4, kind: 'pop' });
            this.c.store.progress('pop20');
            this.score++;
            this.reset(d);
            return true;
        }
    } return false; }
    get detail() { return `${this.mesh.count} · Havok ≤ ${LIMITS.rainBodies}`; }
    dispose() { this.scope.dispose(); }
}
