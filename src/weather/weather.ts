import { BufferGeometry, Float32BufferAttribute, Points, PointsMaterial } from '@iwsdk/core';
import type { GameContext } from '../core/context';
import type { ModeScope } from '../modes/scope';
import { seeded } from '../core/config';
export class Weather {
    readonly points: Points;
    private array = new Float32Array(480 * 3);
    private random = seeded(726);
    kind = 'clear';
    private last = '';
    constructor(readonly c: GameContext, scope: ModeScope) { const geometry = new BufferGeometry(); geometry.setAttribute('position', new Float32BufferAttribute(this.array, 3)); const mat = new PointsMaterial({ color: 0xd4e1e4, size: 0.025, sizeAttenuation: true, transparent: false }); this.points = scope.add(new Points(geometry, mat)); scope.geometry.push(geometry); scope.materials.push(mat); for (let i = 0; i < this.array.length; i += 3) {
        this.array[i] = (this.random() - 0.5) * 10;
        this.array[i + 1] = this.random() * 6;
        this.array[i + 2] = (this.random() - 0.5) * 10;
    } }
    update(dt: number) {
        const c = this.c;
        this.kind = c.store.data.weather === 'auto' ? ['clear', 'rain', 'clear', 'snow'][Math.floor(c.elapsed / 90) % 4] : c.store.data.weather;
        this.points.visible = this.kind !== 'clear' && c.xr === 'immersive-vr';
        if (!this.points.visible)
            return;
        if (this.kind !== this.last) {
            this.last = this.kind;
            (this.points.material as PointsMaterial).size = this.kind === 'snow' ? 0.045 : 0.014;
        }
        this.points.position.set(c.input.head.x, c.input.head.y - 1.5, c.input.head.z);
        const count = Math.floor(480 * c.quality.decorFactor);
        this.points.geometry.setDrawRange(0, count);
        const attr = this.points.geometry.getAttribute('position');
        for (let i = 0; i < count * 3; i += 3) {
            this.array[i + 1] -= dt * (this.kind === 'snow' ? 0.65 : 7);
            this.array[i] += dt * (this.kind === 'snow' ? Math.sin(c.elapsed + i) * 0.2 : -0.12);
            if (this.array[i + 1] < 0) {
                this.array[i + 1] = 6;
                this.array[i] = (this.random() - 0.5) * 10;
            }
        }
        (attr.array as Float32Array).set(this.array);
        attr.needsUpdate = true;
        this.points.geometry.computeBoundingSphere();
    }
}
