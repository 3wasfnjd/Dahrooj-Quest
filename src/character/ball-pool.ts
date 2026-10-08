import { Group, Quaternion, Vector3, createSystem } from '@iwsdk/core';
import type { Entity } from '@iwsdk/core';
import { PHYSICS, LIMITS } from '../core/config';
import type { StyleId } from '../core/config';
import { Dahrooj } from '../core/components';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
import { CharacterFactory } from './visual';
import type { CharacterVisual } from './visual';
import { magnus } from '../input/pose-history';
export interface Ball {
    entity: Entity;
    root: Group;
    visual: CharacterVisual;
    active: boolean;
    held: boolean;
    age: number;
    radius: number;
    id: number;
    prev: Vector3;
    velocity: Vector3;
    spin: Vector3;
    scored: boolean;
    curved: boolean;
    water: boolean;
    pet: number;
}
export class BallPool {
    readonly factory: CharacterFactory;
    readonly slots: Ball[];
    private serial = 0;
    private q = new Quaternion();
    private look = new Vector3();
    constructor(readonly c: GameContext) {
        this.factory = new CharacterFactory(c.resources);
        this.slots = Array.from({ length: LIMITS.balls }, (_, slot) => { const root = new Group(), visual = this.factory.create(); root.name = `dahrooj-${slot}`; root.add(visual.root); root.visible = false; const entity = c.world.createTransformEntity(root).addComponent(Dahrooj, { slot }); return { entity, root, visual, active: false, held: false, age: 0, radius: PHYSICS.ballRadius, id: 0, prev: new Vector3(), velocity: new Vector3(), spin: new Vector3(), scored: false, curved: false, water: false, pet: 0 }; });
    }
    acquire(position: Vector3, style: StyleId, held = false) {
        const b = this.slots.find(b => !b.active);
        if (!b) {
            this.c.events.emit('notice', { ar: 'الميدان ممتلئ — A للاستدعاء', en: 'Field full — A to recall' });
            return undefined;
        }
        b.active = true;
        b.held = held;
        b.age = 0;
        b.id = ++this.serial;
        b.scored = false;
        b.curved = false;
        b.water = false;
        b.pet = 0;
        b.velocity.set(0, 0, 0);
        b.spin.set(0, 0, 0);
        b.radius = Math.max(0.045, PHYSICS.ballRadius * this.c.space.scale);
        b.root.visible = true;
        b.root.position.copy(position);
        b.root.quaternion.identity();
        b.prev.copy(position);
        b.visual.root.scale.setScalar(b.radius);
        b.visual.setStyle(style);
        b.visual.wear(this.c.store.data.accessory);
        b.visual.expression = 'open';
        this.c.store.noteStyle();
        if (!held)
            this.activatePhysics(b);
        return b;
    }
    activatePhysics(b: Ball) { this.c.bodies.add(b.root, { shape: 'Sphere', dimensions: [b.radius, 0, 0], dynamic: true, mass: PHYSICS.ballMass * (b.radius / PHYSICS.ballRadius) ** 3, restitution: PHYSICS.restitution, friction: PHYSICS.friction }, b.entity); }
    launch(b: Ball, v: Vector3, w: Vector3) { b.held = false; b.velocity.copy(v).clampLength(0, PHYSICS.maxThrowSpeed); b.spin.copy(w).clampLength(0, PHYSICS.maxSpin); b.curved = Math.abs(w.y) > 5; this.activatePhysics(b); this.c.bodies.manipulate(b.entity, b.velocity, b.spin); this.c.events.emit('throw', { id: b.id, curved: b.curved }); }
    release(b: Ball) { if (!b.active)
        return; this.c.bodies.detach(b.entity); b.active = false; b.held = false; b.root.visible = false; }
    clear() { for (const b of this.slots)
        this.release(b); }
    pop(b: Ball) { this.c.particles.burst(b.root.position, 0xe2603f, 14, this.c.space.scale); this.c.events.emit('impact', { position: b.root.position, power: 0.4, kind: 'pop' }); this.c.store.progress('pop20'); this.release(b); }
    get active() { let n = 0; for (const b of this.slots)
        if (b.active)
            n++; return n; }
    animate(dt: number) { this.factory.time.value = this.c.elapsed; for (const b of this.slots) {
        if (!b.active)
            continue;
        this.q.copy(b.root.quaternion).invert();
        this.look.subVectors(this.c.input.head, b.root.position).applyQuaternion(this.q);
        b.visual.update(dt, this.c.elapsed + b.id, this.look);
    } }
}
export class DahroojSystem extends createSystem({ balls: { required: [Dahrooj] } }) {
    private acceleration = new Vector3();
    private impulse = new Vector3();
    private last = new Vector3();
    update(dt: number) {
        const c = contextOf(this.world);
        if (!playing(c))
            return;
        for (const b of c.balls.slots) {
            if (!b.active || b.held)
                continue;
            b.age += dt;
            b.pet = Math.max(0, b.pet - dt);
            this.last.copy(b.velocity);
            c.bodies.velocity(b.entity, b.velocity);
            c.bodies.angular(b.entity, b.spin);
            if (b.velocity.length() > PHYSICS.maxThrowSpeed)
                c.bodies.manipulate(b.entity, b.velocity.clampLength(0, PHYSICS.maxThrowSpeed));
            if (b.curved && b.velocity.lengthSq() > 0.5) {
                magnus(b.velocity, b.spin, this.acceleration);
                const mass = PHYSICS.ballMass * (b.radius / PHYSICS.ballRadius) ** 3;
                this.impulse.copy(this.acceleration).multiplyScalar(mass * dt);
                c.bodies.manipulate(b.entity, undefined, undefined, this.impulse);
            }
            const impact = this.last.distanceTo(b.velocity);
            if (impact > 2 && b.age > 0.15) {
                b.visual.impact(Math.min(1, impact / 10));
                c.events.emit('impact', { position: b.root.position, power: Math.min(1, impact / 14), kind: 'impact' });
            }
            if (b.age > 24 || b.root.position.y < -5 || b.root.position.distanceToSquared(c.input.head) > 900)
                c.balls.release(b);
        }
        c.balls.animate(dt);
    }
}
