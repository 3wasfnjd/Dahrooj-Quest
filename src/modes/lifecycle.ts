import { Raycaster, Vector3, createSystem, PhysicsBody, PhysicsState } from '@iwsdk/core';
import type { Intersection } from '@iwsdk/core';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
import type { ModeId } from '../core/config';
import { GoalMode } from './goal/goal';
import { HoopMode } from './hoop/hoop';
import { WindowMode } from './window/window';
import { CansMode } from './cans/cans';
import { BowlingMode } from './bowling/bowling';
import { BricksMode } from './bricks/bricks';
import { FairMode } from './fair/fair';
import { SummitMode } from './summit/summit';
import { RainMode } from './rain/rain';
import type { GameMode, Hit, Target } from './types';
import type { ModeScope } from './scope';
import { segmentSphere } from '../physics/sweep';
const FACTORIES = { goal: GoalMode, hoop: HoopMode, window: WindowMode, cans: CansMode, bowling: BowlingMode, bricks: BricksMode, fair: FairMode, summit: SummitMode, rain: RainMode };
export class ModeLifecycle {
    current?: GameMode & {
        scope: ModeScope;
    };
    private direction = new Vector3();
    private hitPoint = new Vector3();
    private impulse = new Vector3();
    private ray = new Raycaster();
    private intersections: Intersection[] = [];
    private normal = new Vector3();
    private hit: Hit = { point: this.hitPoint, direction: this.direction, power: 1, curved: false, throwId: 0, projectile: false };
    constructor(readonly c: GameContext) { c.events.on('throw', e => this.current?.onThrow?.(e.id)); }
    activate(id: ModeId) { this.current?.dispose(); this.current = undefined; this.c.balls.clear(); this.c.projectiles?.clear(); this.c.mode = id; this.c.generation++; if (!this.c.xr || this.c.placing)
        return; this.current = new FACTORIES[id](this.c); this.c.events.emit('mode', id); }
    suspend() { this.current?.dispose(); this.current = undefined; this.c.balls.clear(); this.c.projectiles?.clear(); }
    sweep(from: Vector3, to: Vector3, radius: number, power: number, curved = false, throwId = 0, projectile = true) {
        this.direction.subVectors(to, from).normalize();
        this.hitPoint.copy(to);
        this.hit.power = power;
        this.hit.curved = curved;
        this.hit.throwId = throwId;
        this.hit.projectile = projectile;
        let result: Target | undefined;
        for (let group = 0; group < 2; group++) {
            const targets = group === 0 ? this.current?.scope.targets : this.c.environment?.targets;
            if (targets)
                for (const target of targets) {
                    if (target.radius <= 0 || target.cooldown > 0 || !target.object.visible)
                        continue;
                    if (segmentSphere(from, to, target.object.position, radius + target.radius)) {
                        target.cooldown = 0.16;
                        target.hit?.(this.hit);
                        if (projectile && target.body?.hasComponent(PhysicsBody) && target.body.getValue(PhysicsBody, 'state') === PhysicsState.Dynamic) {
                            this.impulse.copy(this.direction).multiplyScalar(Math.min(1.8, power * 0.6) * this.c.space.scale ** 3);
                            this.c.bodies.manipulate(target.body, undefined, undefined, this.impulse);
                        }
                        result = target;
                        if (projectile)
                            return result;
                    }
                }
        }
        return result;
    }
    popCharacters(from: Vector3, to: Vector3, radius: number) {
        for (const b of this.c.balls.slots)
            if (b.active && !b.held && segmentSphere(from, to, b.root.position, b.radius + radius)) {
                this.c.balls.pop(b);
                return true;
            }
        return this.current instanceof RainMode && this.current.hitProjectile(from, to, radius);
    }
    block(from: Vector3, to: Vector3, radius: number, out: Vector3) {
        this.direction.subVectors(to, from);
        const distance = this.direction.length();
        if (distance < 1e-6)
            return false;
        this.ray.set(from, this.direction.divideScalar(distance));
        this.ray.near = 0;
        this.ray.far = distance + radius;
        let nearest: Intersection | undefined;
        for (let group = 0; group < 2; group++) {
            const solids = group === 0 ? this.current?.scope.solids : this.c.environment.scope?.solids;
            if (!solids)
                continue;
            for (const solid of solids) {
                if (!solid.entity.hasComponent(PhysicsBody))
                    continue;
                this.intersections.length = 0;
                this.ray.intersectObject(solid.mesh, false, this.intersections);
                const hit = this.intersections[0];
                if (hit && (!nearest || hit.distance < nearest.distance))
                    nearest = hit;
            }
        }
        if (!nearest)
            return false;
        out.copy(nearest.point).addScaledVector(this.direction, -radius);
        return true;
    }
    update(dt: number) {
        if (!this.current)
            return;
        for (const t of this.current.scope.targets)
            t.cooldown = Math.max(0, t.cooldown - dt);
        this.current.update(dt);
        for (const b of this.c.balls.slots) {
            if (!b.active || b.held)
                continue;
            this.sweep(b.prev, b.root.position, b.radius, Math.min(2.5, b.velocity.length() / 5), b.curved, b.id, false);
            // Complement Havok with a swept static-surface guard for exceptional fast/low-rate frames.
            this.direction.subVectors(b.root.position, b.prev);
            const distance = this.direction.length();
            if (!this.current.referencePhysics && distance > b.radius * 1.2 && b.age > 0.04) {
                this.ray.set(b.prev, this.direction.divideScalar(distance));
                this.ray.near = 0;
                this.ray.far = distance + b.radius;
                let nearest: Intersection | undefined;
                for (const solid of this.current.scope.solids) {
                    if (!solid.entity.hasComponent(PhysicsBody) || solid.entity.getValue(PhysicsBody, 'state') !== PhysicsState.Static)
                        continue;
                    this.intersections.length = 0;
                    this.ray.intersectObject(solid.mesh, false, this.intersections);
                    if (this.intersections[0] && (!nearest || this.intersections[0].distance < nearest.distance))
                        nearest = this.intersections[0];
                }
                if (nearest?.face && nearest.distance <= distance) {
                    this.normal.copy(nearest.face.normal).transformDirection(nearest.object.matrixWorld);
                    if (this.normal.dot(b.velocity) > 0)
                        this.normal.negate();
                    this.hitPoint.copy(nearest.point).addScaledVector(this.normal, b.radius + 0.003);
                    this.c.bodies.pose(b.entity, this.hitPoint, b.root.quaternion);
                    b.velocity.reflect(this.normal).multiplyScalar(0.65);
                    this.c.bodies.manipulate(b.entity, b.velocity);
                }
            }
            b.prev.copy(b.root.position);
        }
    }
}
export class GameModeLifecycleSystem extends createSystem({}) {
    update(dt: number) { const c = contextOf(this.world); if (playing(c))
        c.modes.update(dt); }
}
