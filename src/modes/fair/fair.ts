import { Vector3 } from '@iwsdk/core';
import type { Entity, Mesh } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { ModeOwned } from '../../core/components';
import { ModeScope } from '../scope';
import type { Target } from '../types';
interface Prop {
    mesh: Mesh;
    entity?: Entity;
    target: Target;
    x: number;
    y: number;
    type: 'duck' | 'balloon' | 'bell';
    cooldown: number;
    phase: number;
}
export class FairMode {
    readonly id = 'fair' as const;
    readonly scope: ModeScope;
    score = 0;
    remaining = 60;
    private elapsed = 0;
    private finished = false;
    private impulse = new Vector3();
    private props: Prop[] = [];
    constructor(readonly c: GameContext) {
        const s = this.scope = new ModeScope(c);
        s.box(0x5c3c36, 0, 0.7, -3.8, 3.4, 0.16, 0.8);
        for (const x of [-1.6, 1.6])
            s.box(0xe8d7ad, x, 1.2, -3.9, 0.08, 2.4, 0.08);
        for (let i = 0; i < 12; i++)
            s.box(i % 2 ? 0xefcfab : 0xb24340, (i - 5.5) * 0.28, 2.35, -3.9, 0.28, 0.27, 0.9, false);
        for (let i = 0; i < 12; i++) {
            const type = i < 6 ? 'duck' : i < 11 ? 'balloon' : 'bell', x = type === 'duck' ? (i - 2.5) * 0.44 : type === 'balloon' ? (i - 8) * 0.52 : 0, y = type === 'duck' ? 1 : type === 'balloon' ? 1.72 : 2.02;
            const mesh = s.sphere(type === 'duck' ? 0xf1bb41 : type === 'bell' ? 0xf0d787 : [0xd57b8d, 0x73b8bd, 0x997bbc][i % 3], x, y, -3.6, type === 'bell' ? 0.11 : 0.12);
            mesh.scale.y *= type === 'balloon' ? 1.25 : type === 'duck' ? 0.7 : 1;
            const prop: Prop = { mesh, x, y, type, cooldown: 0, phase: i, target: undefined as unknown as Target };
            if (type === 'duck') {
                // Allocate the entity once; Havok components exist only during the hit reaction.
                prop.entity = c.world.createTransformEntity(mesh).addComponent(ModeOwned, { generation: c.generation });
                s.entities.push(prop.entity);
                const head = s.sphere(0xf1bb41, x + 0.055, y + 0.08, -3.6, 0.06);
                mesh.attach(head);
                const beak = s.box(0xdb743d, x + 0.11, y + 0.07, -3.6, 0.07, 0.035, 0.05, false);
                mesh.attach(beak);
                const eye = s.sphere(0x22242d, x + 0.07, y + 0.1, -3.545, 0.013);
                mesh.attach(eye);
            }
            prop.target = s.target(mesh, 0.17, hit => {
                if (this.finished || prop.cooldown > 0)
                    return;
                const points = (type === 'duck' ? 1 : type === 'bell' ? 5 : 2) * (hit.curved ? 2 : 1);
                this.score += points;
                c.events.emit('score', { mode: this.id, points, curved: hit.curved });
                if (type === 'bell')
                    c.store.progress('bell3');
                else
                    c.store.progress('pop20');
                c.events.emit('impact', { position: mesh.position, power: 0.5, kind: type === 'bell' ? 'bell' : 'pop' });
                c.particles.burst(mesh.position, type === 'duck' ? 0xf1bb41 : 0xd57b8d, 12, c.space.scale);
                prop.cooldown = type === 'bell' ? 0.65 : 1.4;
                prop.target.radius = 0;
                if (prop.entity) {
                    const scale = c.space.scale;
                    c.bodies.add(mesh, { shape: 'Sphere', dimensions: [0.12 * scale, 0, 0], dynamic: true, mass: 0.06 * scale ** 3, restitution: 0.2 }, prop.entity);
                    this.impulse.copy(hit.direction).multiplyScalar(Math.min(0.1, hit.power * 0.035) * scale ** 3);
                    this.impulse.y += 0.015 * scale ** 3;
                    c.bodies.manipulate(prop.entity, undefined, undefined, this.impulse);
                }
                else
                    mesh.visible = false;
            });
            this.props.push(prop);
        }
    }
    update(dt: number) {
        if (this.finished)
            return;
        this.elapsed += dt;
        this.remaining = Math.max(0, this.remaining - dt);
        for (const p of this.props) {
            if (p.cooldown > 0) {
                p.cooldown = Math.max(0, p.cooldown - dt);
                if (p.cooldown > 0)
                    continue;
                if (p.entity)
                    this.c.bodies.detach(p.entity);
                p.mesh.quaternion.copy(this.c.space.rotation);
            }
            p.mesh.visible = true;
            p.target.radius = 0.17 * this.c.space.scale;
            this.c.space.point(p.x + (p.type === 'duck' ? Math.sin(this.elapsed * 0.7 + p.phase) * 0.16 : 0), p.y + (p.type === 'balloon' ? Math.sin(this.elapsed + p.phase) * 0.06 : 0), -3.6, p.mesh.position);
        }
        if (this.remaining === 0) {
            this.finished = true;
            for (const p of this.props)
                if (p.entity)
                    this.c.bodies.detach(p.entity);
            this.c.store.progress('fair25', this.score, true);
            this.c.store.data.best.fair = Math.max(this.score, this.c.store.data.best.fair || 0);
            this.c.store.touch();
            this.c.events.emit('notice', { ar: `انتهى المهرجان: ${this.score} — أعد النمط للعب مجددًا`, en: `Time! ${this.score} — reset mode to play again` });
        }
    }
    get detail() { return `${Math.ceil(this.remaining)}s · ★ ${this.c.store.data.best.fair || 0}`; }
    dispose() { this.scope.dispose(); }
}
