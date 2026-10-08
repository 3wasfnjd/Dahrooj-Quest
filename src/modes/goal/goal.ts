import { Vector3 } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { ModeScope } from '../scope';
import type { GameMode } from '../types';
import { crossZ } from '../../physics/sweep';
import { clamp, seeded } from '../../core/config';
export class GoalMode implements GameMode {
    readonly id = 'goal';
    readonly scope: ModeScope;
    score = 0;
    detail = '';
    private a = new Vector3();
    private b = new Vector3();
    private hit = new Vector3();
    private random = seeded(97);
    private wrongGuess = false;
    private keeper;
    private keeperFace;
    private net;
    private netBase: Float32Array;
    private netWave = 0;
    private targetX = 0;
    private targetY = 0.45;
    private x = 0;
    private y = 0.45;
    private vy = 0;
    private wait = 0;
    private trackedId = -1;
    private saves = 0;
    private misses = 0;
    constructor(readonly c: GameContext) {
        const s = this.scope = new ModeScope(c);
        s.box(0xf3ead9, -2.3, 1.1, -5.2, 0.1, 2.2, 0.1);
        s.box(0xf3ead9, 2.3, 1.1, -5.2, 0.1, 2.2, 0.1);
        s.box(0xf3ead9, 0, 2.2, -5.2, 4.7, 0.1, 0.1);
        s.line([-3.4, 0.006, -5.2, 3.4, 0.006, -5.2, -3.4, 0.006, -5.2, -3.4, 0.006, -1.2, 3.4, 0.006, -5.2, 3.4, 0.006, -1.2, -3.4, 0.006, -1.2, 3.4, 0.006, -1.2]);
        const lines: number[] = [];
        for (let x = -2.3; x <= 2.31; x += 0.23)
            lines.push(x, 0, -6.25, x, 2.2, -6.25);
        for (let y = 0; y <= 2.21; y += 0.22)
            lines.push(-2.3, y, -6.25, 2.3, y, -6.25);
        this.net = s.line(lines, 0xc6bfae);
        this.netBase = new Float32Array(this.net.geometry.attributes.position.array);
        s.box(0xd7ceb9, 0, 0.9, -6.32, 4.6, 1.8, 0.14).visible = false;
        this.keeperFace = c.balls.factory.create();
        this.keeperFace.setStyle('clay');
        this.keeper = s.at(this.keeperFace.root, 0, 0.45, -4.95);
        this.keeper.scale.setScalar(0.4 * c.space.scale);
        const e = s.body(this.keeper, { shape: 'Sphere', dimensions: [0.42 * c.space.scale, 0, 0], kinematic: true });
        s.target(this.keeper, 0.42, () => { this.saves++; c.events.emit('impact', { position: this.keeper.position, kind: 'impact', power: 0.6 }); }, e);
    }
    update(dt: number) {
        const c = this.c;
        let soonest = 5, next = -1;
        for (const ball of c.balls.slots) {
            if (!ball.active || ball.held)
                continue;
            c.space.local(ball.prev, this.a);
            c.space.local(ball.root.position, this.b);
            if (!ball.scored && crossZ(this.a, this.b, -5.2, this.hit)) {
                ball.scored = true;
                if (Math.abs(this.hit.x) < 2.3 - ball.radius / c.space.scale && this.hit.y > 0 && this.hit.y < 2.2) {
                    this.score++;
                    this.netWave = 1;
                    c.events.emit('score', { mode: this.id, points: 1, curved: ball.curved });
                    c.store.progress('keeper3');
                    if (ball.curved)
                        c.store.progress('curve3');
                }
                else
                    this.misses++;
            }
            const velocity = c.space.vector(0, 0, -1, this.hit).dot(ball.velocity);
            if (velocity <= 0.1 || this.b.z < -4.95)
                continue;
            const t = (-4.95 - this.b.z) / (-velocity / c.space.scale);
            if (t > 0 && t < soonest) {
                soonest = t;
                next = ball.id;
                const sideV = c.space.vector(1, 0, 0, this.hit).dot(ball.velocity) / c.space.scale;
                this.targetX = clamp(this.b.x + sideV * t, -1.9, 1.9);
                this.targetY = clamp(this.b.y + ball.velocity.y / c.space.scale * t - 4.905 / c.space.scale * t * t, 0.45, 1.8);
            }
        }
        if (next !== -1 && next !== this.trackedId) {
            this.trackedId = next;
            this.wait = 0.1 + this.random() * 0.08;
            this.wrongGuess = this.random() < 0.07;
        }
        if (next !== -1 && this.wrongGuess)
            this.targetX *= -0.7;
        if (next === -1) {
            this.targetX = Math.sin(c.elapsed) * 0.3;
            this.trackedId = -1;
        }
        this.wait -= dt;
        if (this.wait <= 0) {
            this.x += clamp(this.targetX - this.x, -3.2 * dt, 3.2 * dt);
            if (next !== -1 && this.targetY > 1 && this.y <= 0.451)
                this.vy = 3.8;
        }
        this.vy -= 9.81 * dt;
        this.y = Math.max(0.45, this.y + this.vy * dt);
        if (this.y === 0.45)
            this.vy = 0;
        this.scope.move(this.keeper, this.x, this.y, -4.95, clamp((this.x - this.targetX) * 0.35, -0.65, 0.65));
        this.keeperFace.expression = next === -1 ? 'open' : 'focus';
        this.a.subVectors(c.input.head, this.keeper.position);
        this.keeperFace.update(dt, c.elapsed, this.a);
        this.keeper.scale.y = 0.4 * c.space.scale * (1 + Math.min(0.4, Math.abs(this.targetX - this.x) * 0.15));
        if (this.netWave > 0.002) {
            this.netWave *= Math.exp(-dt * 4);
            const attr = this.net.geometry.attributes.position;
            for (let i = 0; i < attr.count; i++) {
                const wave = this.netWave * Math.sin(c.elapsed * 14 + i) * 0.06 * c.space.scale;
                c.space.vector(0, 0, -wave, this.a);
                attr.setXYZ(i, this.netBase[i * 3] + this.a.x, this.netBase[i * 3 + 1], this.netBase[i * 3 + 2] + this.a.z);
            }
            attr.needsUpdate = true;
        }
        this.detail = `${this.saves} / ${this.misses}`;
    }
    dispose() { this.scope.dispose(); }
}
