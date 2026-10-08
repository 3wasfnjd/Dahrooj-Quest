import { Group, Mesh, Vector3, createSystem } from '@iwsdk/core';
import type { Entity } from '@iwsdk/core';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
import { LIMITS } from '../core/config';
import type { ShotId } from '../core/config';
import { Projectile } from '../core/components';
import { pulse } from '../haptics/haptics';
export const SHOT_SPEC = { bolt: { speed: 45, gravity: 0, life: 1.2, radius: 0.018, cooldown: 0.12 }, mini: { speed: 11, gravity: 1, life: 3.2, radius: 0.042, cooldown: 0.12 }, bubble: { speed: 4.2, gravity: -0.06, life: 3.6, radius: 0.06, cooldown: 0.16 }, firework: { speed: 20, gravity: 0.35, life: 0.85, radius: 0.025, cooldown: 0.2 } } as const;
interface Shot {
    entity: Entity;
    mesh: Mesh;
    active: boolean;
    type: ShotId;
    v: Vector3;
    previous: Vector3;
    life: number;
    age: number;
    skips: number;
    radius: number;
}
export class Projectiles {
    readonly slots: Shot[];
    readonly blaster = new Group();
    private cooldown = 0;
    private phase = 0;
    private p = new Vector3();
    private normal = new Vector3();
    private zero = new Vector3();
    private trail = 0;
    constructor(readonly c: GameContext) {
        this.slots = Array.from({ length: LIMITS.projectiles }, (_, slot) => { const mesh = new Mesh(c.resources.lowSphere, c.resources.mat(0xf6d283, true)); mesh.visible = false; const entity = c.world.createTransformEntity(mesh).addComponent(Projectile, { slot }); return { entity, mesh, active: false, type: 'bolt', v: new Vector3(), previous: new Vector3(), life: 0, age: 0, skips: 0, radius: 0.02 }; });
        c.resources.mesh(c.resources.box, 0x594253, 0, 0.025, -0.08, 0.08, 0.065, 0.14, this.blaster);
        c.resources.mesh(c.resources.cylinder, 0xf0bb69, 0, 0.025, -0.16, 0.029, 0.06, 0.029, this.blaster).rotation.x = Math.PI / 2;
        c.world.scene.add(this.blaster);
    }
    fire(type: ShotId, origin: Vector3, direction: Vector3) {
        const slot = this.slots.find(s => !s.active);
        if (!slot)
            return false;
        const spec = SHOT_SPEC[type], c = this.c, scale = Math.max(0.4, c.space.scale);
        slot.active = true;
        slot.type = type;
        slot.life = spec.life;
        slot.age = slot.skips = 0;
        slot.radius = spec.radius * scale;
        slot.mesh.visible = true;
        slot.mesh.position.copy(origin).addScaledVector(direction, 0.17);
        slot.previous.copy(slot.mesh.position);
        slot.mesh.scale.setScalar(slot.radius);
        slot.mesh.material = type === 'mini' ? c.balls.factory.mats[c.store.data.style] : type === 'bubble' ? c.balls.factory.mats.bubble : c.resources.mat(type === 'bolt' ? 0xf6d283 : 0xef7159, true);
        slot.v.copy(direction).multiplyScalar(spec.speed * Math.sqrt(c.space.scale));
        if (type === 'mini') {
            c.bodies.add(slot.mesh, { shape: 'Sphere', dimensions: [slot.radius, 0, 0], dynamic: true, mass: 0.045 * scale ** 3, friction: 0.4, restitution: 0.62 }, slot.entity);
            c.bodies.manipulate(slot.entity, slot.v);
        }
        c.particles.burst(slot.mesh.position, 0xf6cb74, 4, 0.3);
        c.events.emit('impact', { position: origin, power: 0.3, kind: 'shot' });
        c.events.emit('projectile', type);
        pulse(c.input.left, 0.18, 20);
        return true;
    }
    private end(s: Shot, explosion = false) {
        if (!s.active)
            return;
        if (explosion) {
            this.c.particles.burst(s.mesh.position, 0xf3b365, 36, this.c.space.scale);
            this.c.events.emit('impact', { position: s.mesh.position, power: 0.6, kind: 'pop' });
            for (const t of this.c.modes.current?.scope.targets || [])
                if (t.radius > 0 && t.object.position.distanceToSquared(s.mesh.position) < (0.6 * this.c.space.scale) ** 2) {
                    this.normal.subVectors(t.object.position, s.mesh.position).normalize();
                    this.p.copy(t.object.position).addScaledVector(this.normal, 0.01);
                    this.c.modes.sweep(s.mesh.position, this.p, 0, 0.9);
                }
        }
        if (s.type === 'mini')
            this.c.bodies.detach(s.entity);
        s.active = false;
        s.mesh.visible = false;
    }
    clear() { for (const s of this.slots)
        this.end(s); this.cooldown = 0; }
    get active() { let n = 0; for (const s of this.slots)
        if (s.active)
            n++; return n; }
    update(dt: number) {
        const c = this.c, left = c.input.left;
        this.blaster.visible = playing(c) && left.tracked && c.mode !== 'summit';
        this.blaster.position.copy(left.position);
        this.blaster.quaternion.copy(left.orientation);
        if (!playing(c))
            return;
        this.cooldown = Math.max(0, this.cooldown - dt);
        if (left.tracked && left.trigger && this.cooldown === 0) {
            this.cooldown = SHOT_SPEC[c.store.data.shot].cooldown;
            if (c.mode === 'summit')
                c.modes.current?.shoot?.();
            else
                this.fire(c.store.data.shot, left.ray, left.direction);
        }
        if (c.mode === 'summit' && c.input.right.primaryDown)
            c.modes.current?.jump?.();
        this.phase += dt;
        this.trail += dt;
        for (const s of this.slots) {
            if (!s.active)
                continue;
            s.life -= dt;
            s.age += dt;
            if (s.life <= 0) {
                this.end(s, s.type === 'firework');
                continue;
            }
            if (s.type === 'mini')
                c.bodies.velocity(s.entity, s.v);
            else {
                s.v.y -= 9.81 * SHOT_SPEC[s.type].gravity * dt;
                s.mesh.position.addScaledVector(s.v, dt);
                if (s.type === 'bubble')
                    s.mesh.position.x += Math.sin(this.phase * 5 + s.entity.index) * dt * 0.1;
            }
            if (s.type === 'firework' && this.trail > 0.055)
                c.particles.burst(s.mesh.position, 0xe7995c, 2, 0.15);
            if (c.environment.water?.contains(s.mesh.position) && s.mesh.position.y - s.radius < c.environment.water.surface) {
                const w = c.environment.water;
                w.splash(s.mesh.position, 0.35);
                if (s.type === 'mini' && s.skips < 4 && Math.hypot(s.v.x, s.v.z) > 2.2 && -s.v.y < Math.hypot(s.v.x, s.v.z) * 0.7) {
                    s.skips++;
                    s.v.y = Math.max(1, -s.v.y * 0.6);
                    s.v.multiplyScalar(0.82);
                    s.mesh.position.y = w.surface + s.radius;
                    c.bodies.pose(s.entity, s.mesh.position);
                    c.bodies.manipulate(s.entity, s.v);
                }
                else if (s.type === 'bubble') {
                    s.mesh.position.y = w.surface + s.radius;
                    s.v.multiplyScalar(0.9);
                    s.life = Math.min(s.life, 0.5);
                }
                else
                    this.end(s);
            }
            if (!s.active)
                continue;
            const blocked = s.type !== 'mini' && c.modes.block(s.previous, s.mesh.position, s.radius, s.mesh.position);
            const target = c.modes.sweep(s.previous, s.mesh.position, s.radius, s.type === 'firework' ? 2 : s.type === 'mini' ? 1.2 : 0.8);
            const popped = s.type !== 'mini' && c.modes.popCharacters(s.previous, s.mesh.position, s.radius);
            if ((target || blocked || popped) && s.type !== 'mini') {
                c.particles.burst(s.mesh.position, 0xf5d497, 8, 0.3);
                this.end(s, s.type === 'firework');
                continue;
            }
            if (s.mesh.position.y < c.space.origin.y - 0.08 && s.type !== 'mini')
                this.end(s, s.type === 'firework');
            if (s.mesh.position.y < -4 || s.mesh.position.distanceToSquared(c.input.head) > 45 ** 2)
                this.end(s);
            s.previous.copy(s.mesh.position);
        }
        if (this.trail > 0.055)
            this.trail = 0;
    }
}
export class ProjectileSystem extends createSystem({ projectiles: { required: [Projectile] } }) {
    update(dt: number) { contextOf(this.world).projectiles.update(dt); }
}
