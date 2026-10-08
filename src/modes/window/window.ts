import { Vector3 } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import type { GameMode } from '../types';
import { ModeScope } from '../scope';
import { crossZ } from '../../physics/sweep';
import { seeded } from '../../core/config';
export class WindowMode implements GameMode {
    readonly id = 'window';
    scope: ModeScope;
    score = 0;
    size = 1.15;
    x = 0.6;
    y = 1.4;
    private timer = 0;
    private rand = seeded(37);
    private a = new Vector3();
    private b = new Vector3();
    private hit = new Vector3();
    constructor(readonly c: GameContext) { this.scope = new ModeScope(c); this.build(); }
    private build() { const s = this.scope, h = this.size / 2 + 0.035; s.box(0xe9c981, this.x - h, this.y, -4, 0.07, this.size + 0.14, 0.12); s.box(0xe9c981, this.x + h, this.y, -4, 0.07, this.size + 0.14, 0.12); s.box(0xe9c981, this.x, this.y + h, -4, this.size, 0.07, 0.12); s.box(0xe9c981, this.x, this.y - h, -4, this.size, 0.07, 0.12); }
    update(dt: number) {
        if (this.timer > 0) {
            this.timer -= dt;
            if (this.timer <= 0) {
                this.scope.dispose();
                this.scope = new ModeScope(this.c);
                const min = Math.max(0.34, 2.4 * Math.max(0.045, 0.13 * this.c.space.scale) / this.c.space.scale);
                this.size = Math.max(min, this.size * 0.85);
                const prev = this.x;
                this.x = (this.rand() - 0.5) * 2.8;
                if (Math.abs(this.x - prev) < 0.75)
                    this.x = prev > 0 ? -1 : 1;
                this.y = 0.95 + this.rand() * 0.9;
                if (this.size <= min + 0.001)
                    this.c.store.progress('windowMin');
                this.build();
            }
        }
        for (const ball of this.c.balls.slots) {
            if (!ball.active || ball.held || ball.scored)
                continue;
            this.c.space.local(ball.prev, this.a);
            this.c.space.local(ball.root.position, this.b);
            if (crossZ(this.a, this.b, -4, this.hit)) {
                ball.scored = true;
                const r = ball.radius / this.c.space.scale;
                if (!this.timer && Math.abs(this.hit.x - this.x) < this.size / 2 - r && Math.abs(this.hit.y - this.y) < this.size / 2 - r) {
                    this.score++;
                    this.timer = 0.8;
                    this.c.events.emit('score', { mode: this.id, points: 1, curved: ball.curved });
                }
            }
        }
    }
    dispose() { this.scope.dispose(); }
}
