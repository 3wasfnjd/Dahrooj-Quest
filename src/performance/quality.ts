import { createSystem } from '@iwsdk/core';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
/** Hysteresis changes decorative density and foveation, never gameplay/physics frequency. */
export class Quality {
    level = 0;
    private elapsed = 0;
    private frames = 0;
    private healthy = 0;
    constructor(readonly c: GameContext) { }
    get decorFactor() { return this.level === 2 ? 0.5 : this.level === 1 ? 0.75 : 1; }
    update(dt: number) {
        if (!playing(this.c)) {
            this.elapsed = this.frames = 0;
            return;
        }
        this.elapsed += dt;
        this.frames++;
        if (this.elapsed < 4)
            return;
        const frameMs = this.elapsed * 1000 / this.frames;
        this.elapsed = this.frames = 0;
        if (frameMs > 17.5 && this.level < 2) {
            this.level++;
            this.healthy = 0;
        }
        else if (frameMs < 14.5 && this.level > 0) {
            if (++this.healthy >= 4) {
                this.level--;
                this.healthy = 0;
            }
        }
        else
            this.healthy = 0;
        this.c.world.renderer.xr.setFoveation(this.level === 2 ? 0.95 : this.level === 1 ? 0.8 : 0.6);
    }
}
export class QualitySystem extends createSystem({}) {
    update(dt: number) { contextOf(this.world).quality.update(dt); }
}
