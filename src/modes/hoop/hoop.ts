import { TorusGeometry, Mesh, Vector3 } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import type { GameMode } from '../types';
import { ModeScope } from '../scope';
import { crossY } from '../../physics/sweep';
export class HoopMode implements GameMode {
    readonly id = 'hoop';
    readonly scope: ModeScope;
    score = 0;
    streak = 0;
    private a = new Vector3();
    private b = new Vector3();
    private hit = new Vector3();
    private net;
    private wave = 0;
    private netBase: Float32Array;
    constructor(readonly c: GameContext) {
        const s = this.scope = new ModeScope(c);
        s.box(0xf3ead9, 0, 2.45, -3.6, 1.35, 0.85, 0.09);
        s.box(0x5b5d68, 0, 1.35, -3.8, 0.1, 2.7, 0.12);
        const geo = new TorusGeometry(0.37, 0.028, 6, 32), rim = new Mesh(geo, c.resources.mat(0xd66543));
        s.geometry.push(geo);
        s.at(rim, 0, 2.18, -3.12);
        rim.scale.setScalar(c.space.scale);
        rim.rotateX(Math.PI / 2);
        for (let i = 0; i < 16; i++) {
            const a = i / 16 * Math.PI * 2;
            s.sphere(0xd66543, Math.cos(a) * 0.37, 2.18, -3.12 + Math.sin(a) * 0.37, 0.05, true).visible = false;
        }
        const lines: number[] = [];
        for (let i = 0; i < 12; i++) {
            const a = i * Math.PI / 6, b = a + Math.PI / 12;
            lines.push(Math.cos(a) * 0.36, 2.18, -3.12 + Math.sin(a) * 0.36, Math.cos(b) * 0.21, 1.78, -3.12 + Math.sin(b) * 0.21);
        }
        this.net = s.line(lines);
        this.netBase = new Float32Array(this.net.geometry.attributes.position.array);
        s.line([-1.4, 0.008, -3.8, -1.4, 0.008, 0.1, 1.4, 0.008, -3.8, 1.4, 0.008, 0.1, -1.4, 0.008, 0.1, 1.4, 0.008, 0.1]);
    }
    update(dt: number) {
        const c = this.c;
        for (const ball of c.balls.slots) {
            if (!ball.active || ball.held || ball.scored)
                continue;
            c.space.local(ball.prev, this.a);
            c.space.local(ball.root.position, this.b);
            if (crossY(this.a, this.b, 2.18, this.hit) && Math.hypot(this.hit.x, this.hit.z + 3.12) < 0.37 - ball.radius / c.space.scale) {
                ball.scored = true;
                this.score++;
                this.streak++;
                this.wave = 1;
                c.events.emit('score', { mode: this.id, points: 1, curved: ball.curved });
                c.store.progress('hoop3', this.streak, true);
            }
            else if (ball.age > 3 && this.b.y < 0.3) {
                ball.scored = true;
                this.streak = 0;
            }
        }
        if (this.wave > 0.001) {
            this.wave *= Math.exp(-dt * 5);
            const a = this.net.geometry.attributes.position;
            for (let i = 1; i < a.count; i += 2)
                a.setY(i, this.netBase[i * 3 + 1] - Math.sin(c.elapsed * 18) * this.wave * 0.08 * c.space.scale);
            a.needsUpdate = true;
        }
    }
    get detail() { return `${this.streak}`; }
    dispose() { this.scope.dispose(); }
}
