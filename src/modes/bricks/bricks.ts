import { InstancedMesh, Matrix4, Object3D, Vector3, Quaternion } from '@iwsdk/core';
import type { Entity, Mesh } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { LIMITS } from '../../core/config';
import { ModeOwned } from '../../core/components';
import { ModeScope } from '../scope';
import type { Hit, Target } from '../types';
const MATERIALS = [{ color: 0xbf9c6b, strength: 1 }, { color: 0x85877e, strength: 2 }, { color: 0xa55039, strength: 1.3 }, { color: 0x484c50, strength: 2.5 }, { color: 0xdbceaa, strength: 1.8 }];
export class BricksMode {
    readonly id = 'bricks' as const;
    scope: ModeScope;
    score = 0;
    private level = 0;
    private count = 0;
    private reset = 0;
    private mesh!: InstancedMesh;
    private matrix = new Matrix4();
    private q = new Quaternion();
    private size = new Vector3();
    private impulse = new Vector3();
    private position = new Vector3();
    private fragments: {
        mesh: Mesh;
        entity?: Entity;
        life: number;
    }[] = [];
    constructor(readonly c: GameContext) { this.scope = new ModeScope(c); this.build(); }
    private build() {
        const s = this.scope, c = this.c, style = MATERIALS[this.level % 5], scale = c.space.scale;
        this.count = 0;
        const cells: [
            number,
            number,
            number
        ][] = [];
        for (let row = 0; row < 6; row++)
            for (let col = 0; col < 8; col++) {
                const castle = this.level % 2 === 1;
                if (castle && row > 2 && col >= 2 && col <= 5 && (row > 3 || col === 3 || col === 4))
                    continue;
                cells.push([(col - 3.5) * 0.43 + (row % 2 ? 0.06 : 0), 0.14 + row * 0.29, -3.5]);
            }
        this.mesh = s.add(new InstancedMesh(c.resources.box, c.resources.mat(style.color), cells.length));
        this.size.set(0.41, 0.27, 0.24).multiplyScalar(scale);
        this.q.copy(c.space.rotation);
        cells.forEach(([x, y, z], index) => {
            const o = new Object3D();
            s.at(o, x, y, z);
            this.matrix.compose(o.position, this.q, this.size);
            this.mesh.setMatrixAt(index, this.matrix);
            const entity = s.body(o, { shape: 'Box', dimensions: [0.41 * scale, 0.27 * scale, 0.24 * scale] });
            let health = style.strength;
            const target: Target = s.target(o, 0.25, hit => { health -= Math.max(0.45, hit.power); if (health <= 0 && target.radius > 0) {
                target.radius = 0;
                c.bodies.detach(entity);
                this.matrix.makeScale(0, 0, 0);
                this.mesh.setMatrixAt(index, this.matrix);
                this.mesh.instanceMatrix.needsUpdate = true;
                this.count++;
                this.score++;
                c.store.progress('bricks20');
                this.shatter(o.position, hit);
                c.events.emit('score', { mode: this.id, points: 1, curved: hit.curved });
            } });
        });
        this.mesh.computeBoundingSphere();
        this.fragments = Array.from({ length: LIMITS.debris }, () => { const mesh = s.box(style.color, 0, 0, 0, 0.17, 0.12, 0.14, false); mesh.visible = false; const entity = c.world.createTransformEntity(mesh).addComponent(ModeOwned, { generation: c.generation }); s.entities.push(entity); return { mesh, entity, life: 0 }; });
    }
    private shatter(p: Vector3, hit: Hit) { const s = this.c.space.scale; for (let i = 0; i < 3; i++) {
        const f = this.fragments.find(f => f.life <= 0);
        if (!f)
            break;
        f.life = 2.8;
        f.mesh.visible = true;
        f.mesh.position.copy(p);
        f.mesh.position.x += (i - 1) * 0.09 * s;
        this.c.bodies.add(f.mesh, { shape: 'Box', dimensions: [0.17 * s, 0.12 * s, 0.14 * s], dynamic: true, mass: 0.09 * s ** 3, friction: 0.7 }, f.entity);
        this.impulse.copy(hit.direction).multiplyScalar(Math.min(0.32, hit.power * 0.11) * s ** 3);
        this.impulse.y += 0.12 * s ** 3;
        this.c.bodies.manipulate(f.entity!, undefined, undefined, this.impulse);
    } this.c.particles.burst(p, MATERIALS[this.level % 5].color, 10, s); }
    update(dt: number) {
        for (const f of this.fragments)
            if (f.life > 0 && (f.life -= dt) <= 0) {
                if (f.entity)
                    this.c.bodies.detach(f.entity);
                f.mesh.visible = false;
            }
        if (this.count === this.mesh.count && this.reset === 0) {
            this.reset = 2;
            this.c.store.progress('wall1');
        }
        if (this.reset > 0 && (this.reset -= dt) <= 0) {
            this.reset = 0;
            this.level++;
            this.scope.dispose();
            this.scope = new ModeScope(this.c);
            this.build();
        }
    }
    get detail() { return `${this.level + 1} · ${this.count}/${this.mesh.count}`; }
    dispose() { this.scope.dispose(); }
}
