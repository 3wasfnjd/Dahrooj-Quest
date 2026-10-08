import { clamp, seeded } from '../../core/config';
export type Region = 'meadow' | 'cliffs' | 'caves' | 'snow';
export interface Platform {
    x: number;
    y: number;
    width: number;
    kind: 'solid' | 'moving' | 'crumble' | 'ice';
    origin: number;
    phase: number;
    timer: number;
    broken: number;
    checkpoint: boolean;
}
export interface Enemy {
    x: number;
    y: number;
    home: number;
    type: 'crawler' | 'bat' | 'spitter';
    direction: number;
    alive: boolean;
    cooldown: number;
    platform: number;
}
export interface Seed {
    x: number;
    y: number;
    vx: number;
    vy: number;
    life: number;
    enemy: boolean;
}
export interface Icicle {
    x: number;
    y: number;
    home: number;
    state: number;
    time: number;
    vy: number;
}
export const SUMMIT = Object.freeze({ gravity: 4.8, speed: 0.83, jump: 2.22, acceleration: 5.6, airAcceleration: 2.7, iceAcceleration: 1.1, radius: 0.074, coyote: 0.1, jumpBuffer: 0.13, top: 11.84 });
/** Fixed-step, metre-scale platform controller. All terrain moves; the XR origin never does. */
export class SummitSimulation {
    readonly platforms: Platform[] = [];
    readonly enemies: Enemy[] = [];
    readonly shots: Seed[] = Array.from({ length: 16 }, () => ({ x: 0, y: 0, vx: 0, vy: 0, life: 0, enemy: false }));
    readonly icicles: Icicle[] = [];
    x = 0;
    y = 0.09;
    vx = 0;
    vy = 0;
    hearts = 3;
    invincible = 0;
    checkpoint = 0;
    kills = 0;
    won = false;
    grounded = true;
    facing = 1;
    time = 0;
    respawn = 0;
    private coyote = 0;
    private buffer = 0;
    private accumulator = 0;
    private cooldown = 0;
    private floor = 0;
    constructor() {
        const random = seeded(74019);
        this.platforms.push({ x: 0, y: 0, width: 1.8, kind: 'solid', origin: 0, phase: 0, timer: 0, broken: 0, checkpoint: true });
        for (let i = 1; i <= 37; i++) {
            const checkpoint = i % 9 === 0 || i === 37, x = checkpoint ? 0 : Math.sin(i * 1.65) * 0.38, y = i * 0.32;
            const kind = checkpoint ? 'solid' : i >= 28 && i % 3 === 0 ? 'ice' : i % 7 === 0 ? 'crumble' : i % 5 === 0 ? 'moving' : 'solid';
            this.platforms.push({ x, y, width: checkpoint ? 1.2 : 0.55, origin: x, kind, phase: random() * 6.28, timer: 0, broken: 0, checkpoint });
            if (i > 2 && i % 3 === 0 && !checkpoint)
                this.enemies.push({ x, y: y + 0.12, home: x, type: i >= 18 ? 'spitter' : i >= 10 ? 'bat' : 'crawler', direction: 1, alive: true, cooldown: 1 + random(), platform: i });
            if (i >= 29 && i % 2)
                this.icicles.push({ x: x + 0.2, y: y + 0.9, home: y + 0.9, state: 0, time: 0, vy: 0 });
        }
    }
    jump() { this.buffer = SUMMIT.jumpBuffer; }
    shoot() {
        if (this.cooldown > 0 || this.respawn > 0 || this.won)
            return;
        const own = this.shots.filter(s => s.life > 0 && !s.enemy).length;
        if (own >= 3)
            return;
        const s = this.shots.find(s => s.life <= 0);
        if (!s)
            return;
        this.cooldown = 0.32;
        s.x = this.x;
        s.y = this.y;
        s.vx = this.facing * 1.6;
        s.vy = 0;
        s.enemy = false;
        s.life = 1.1;
        let best = 1.5;
        for (const e of this.enemies)
            if (e.alive && (e.x - this.x) * this.facing > 0 && Math.abs(e.y - this.y) < 0.4) {
                const d = Math.hypot(e.x - this.x, e.y - this.y);
                if (d < best) {
                    best = d;
                    s.vx = (e.x - this.x) / d * 1.6;
                    s.vy = (e.y - this.y) / d * 1.6;
                }
            }
    }
    damage() { if (this.invincible > 0 || this.respawn > 0 || this.won)
        return; this.hearts--; this.invincible = 1.6; this.vy = 1; this.vx = -this.facing * 0.45; if (this.hearts <= 0)
        this.respawn = 1.1; }
    recover() { const p = this.platforms[this.checkpoint]; this.x = p.x; this.y = p.y + SUMMIT.radius + 0.005; this.vx = this.vy = 0; this.hearts = 3; this.invincible = 1.6; this.respawn = 0; this.grounded = true; this.floor = this.checkpoint; }
    update(dt: number, axis: number) { this.accumulator = Math.min(0.1, this.accumulator + dt); while (this.accumulator >= 1 / 60) {
        this.step(1 / 60, clamp(axis, -1, 1));
        this.accumulator -= 1 / 60;
    } }
    private step(dt: number, axis: number) {
        if (this.won)
            return;
        this.time += dt;
        this.invincible = Math.max(0, this.invincible - dt);
        this.cooldown = Math.max(0, this.cooldown - dt);
        if (this.respawn > 0) {
            this.respawn -= dt;
            if (this.respawn <= 0)
                this.recover();
            return;
        }
        for (const p of this.platforms) {
            const old = p.x;
            if (p.kind === 'moving')
                p.x = p.origin + Math.sin(this.time * 0.85 + p.phase) * 0.17;
            if (this.grounded && p === this.platforms[this.floor])
                this.x += p.x - old;
            if (p.broken > 0) {
                p.broken -= dt;
                if (p.broken <= 0)
                    p.timer = 0;
            }
            else if (p.timer > 0 && (p.timer += dt) >= 0.6) {
                p.broken = 3;
                p.timer = 0;
            }
        }
        this.buffer = Math.max(0, this.buffer - dt);
        this.coyote = this.grounded ? SUMMIT.coyote : Math.max(0, this.coyote - dt);
        if (this.buffer > 0 && this.coyote > 0) {
            this.vy = SUMMIT.jump;
            this.grounded = false;
            this.coyote = this.buffer = 0;
        }
        const ice = this.grounded && this.platforms[this.floor].kind === 'ice', acceleration = ice ? SUMMIT.iceAcceleration : this.grounded ? SUMMIT.acceleration : SUMMIT.airAcceleration, target = axis * SUMMIT.speed;
        this.vx += clamp(target - this.vx, -acceleration * dt, acceleration * dt);
        if (Math.abs(axis) > 0.15)
            this.facing = Math.sign(axis);
        const oldY = this.y;
        this.x = clamp(this.x + this.vx * dt, -0.95, 0.95);
        this.vy -= SUMMIT.gravity * dt;
        this.y += this.vy * dt;
        this.grounded = false;
        if (this.vy <= 0)
            for (let i = 0; i < this.platforms.length; i++) {
                const p = this.platforms[i];
                if (p.broken > 0 || Math.abs(this.x - p.x) > p.width / 2 + SUMMIT.radius * 0.55)
                    continue;
                if (oldY - SUMMIT.radius >= p.y - 0.012 && this.y - SUMMIT.radius <= p.y) {
                    this.y = p.y + SUMMIT.radius;
                    this.vy = 0;
                    this.grounded = true;
                    this.floor = i;
                    if (p.kind === 'crumble' && p.timer === 0)
                        p.timer = dt;
                    if (p.checkpoint && i > this.checkpoint)
                        this.checkpoint = i;
                    if (i === 37)
                        this.won = true;
                    break;
                }
            }
        if (this.y < this.platforms[this.checkpoint].y - 1 || this.y < -0.6) {
            this.hearts--;
            if (this.hearts <= 0)
                this.respawn = 1.1;
            else {
                const health = this.hearts;
                this.recover();
                this.hearts = health;
            }
        }
        // Side spikes stay off the required landing centres.
        if (this.y > 3 && Math.abs(this.x) > 0.88 && Math.floor(this.y * 3) % 3 === 0)
            this.damage();
        for (const e of this.enemies) {
            if (!e.alive)
                continue;
            const p = this.platforms[e.platform];
            if (e.type === 'crawler') {
                e.x += e.direction * 0.14 * dt;
                if (Math.abs(e.x - p.x) > p.width * 0.35)
                    e.direction *= -1;
                e.y = p.y + 0.075;
            }
            else if (e.type === 'bat') {
                e.x = e.home + Math.sin(this.time * 1.4 + e.platform) * 0.3;
                e.y = p.y + 0.22 + Math.sin(this.time * 2) * 0.08;
            }
            else {
                e.cooldown -= dt;
                if (e.cooldown <= 0 && Math.abs(e.y - this.y) < 1) {
                    e.cooldown = 2.4;
                    const s = this.shots.find(s => s.life <= 0);
                    if (s) {
                        const d = Math.max(0.1, Math.hypot(this.x - e.x, this.y - e.y));
                        Object.assign(s, { x: e.x, y: e.y, vx: (this.x - e.x) / d * 0.56, vy: (this.y - e.y) / d * 0.56, life: 2.4, enemy: true });
                    }
                }
            }
            if (Math.hypot(e.x - this.x, e.y - this.y) < 0.13) {
                if (this.vy < -0.5 && oldY > e.y + 0.08) {
                    e.alive = false;
                    this.kills++;
                    this.vy = 1.7;
                }
                else
                    this.damage();
            }
        }
        for (const s of this.shots)
            if (s.life > 0) {
                s.life -= dt;
                s.x += s.vx * dt;
                s.y += s.vy * dt;
                if (s.enemy) {
                    if (Math.hypot(s.x - this.x, s.y - this.y) < 0.1) {
                        s.life = 0;
                        this.damage();
                    }
                }
                else
                    for (const e of this.enemies)
                        if (e.alive && Math.hypot(s.x - e.x, s.y - e.y) < 0.12) {
                            e.alive = false;
                            s.life = 0;
                            this.kills++;
                            break;
                        }
            }
        for (const i of this.icicles) {
            if (i.state === 0 && Math.abs(i.x - this.x) < 0.18 && i.y - this.y > 0 && i.y - this.y < 1) {
                i.state = 1;
                i.time = 0.45;
            }
            else if (i.state === 1 && (i.time -= dt) <= 0)
                i.state = 2;
            else if (i.state === 2) {
                i.vy -= SUMMIT.gravity * dt;
                i.y += i.vy * dt;
                if (Math.hypot(i.x - this.x, i.y - this.y) < 0.13)
                    this.damage();
                if (i.y < i.home - 2) {
                    i.state = 3;
                    i.time = 4;
                }
            }
            else if (i.state === 3 && (i.time -= dt) <= 0) {
                i.y = i.home;
                i.vy = 0;
                i.state = 0;
            }
        }
    }
    get region(): Region { return this.y < 2.88 ? 'meadow' : this.y < 5.76 ? 'cliffs' : this.y < 8.64 ? 'caves' : 'snow'; }
}
