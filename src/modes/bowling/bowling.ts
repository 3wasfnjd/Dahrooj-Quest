import { LatheGeometry, Vector2, Vector3 } from '@iwsdk/core';
import type { Mesh } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { ModeScope } from '../scope';
export class BowlingMode {
    readonly id = 'bowling' as const;
    scope: ModeScope;
    score = 0;
    private pins: {
        mesh: Mesh;
        down: boolean;
    }[] = [];
    private wait = 0;
    private throws = 0;
    private p = new Vector3();
    private up = new Vector3();
    constructor(readonly c: GameContext) { this.scope = new ModeScope(c); this.build(); }
    private build() {
        const s = this.scope, scale = this.c.space.scale;
        this.pins = [];
        this.throws = 0;
        s.box(0xb58b56, 0, 0.025, -3.1, 1.25, 0.05, 5.8);
        for (const x of [-0.77, 0.77]) {
            s.box(0x424549, x, -0.035, -3.1, 0.27, 0.07, 5.8);
            s.box(0x7d624d, x * 1.25, 0.08, -3.1, 0.09, 0.18, 5.8);
        }
        for (let i = -2; i <= 2; i++)
            s.line([i * 0.18 - 0.04, 0.056, -1.7, i * 0.18, 0.056, -1.78, i * 0.18, 0.056, -1.78, i * 0.18 + 0.04, 0.056, -1.7], 0x4a3828);
        // A compact lathed pin is newly authored. The audited legacy pin remains optional.
        const geo = new LatheGeometry([[0.065, -0.21], [0.095, -0.16], [0.095, -0.08], [0.06, 0.04], [0.035, 0.1], [0.055, 0.15], [0.05, 0.19], [0, 0.22]].map(([r, y]) => new Vector2(r, y)), 10);
        s.geometry.push(geo);
        for (let row = 0; row < 4; row++)
            for (let i = 0; i <= row; i++) {
                const mesh = s.shape(geo, 0xf5eada, (i - row / 2) * 0.255, 0.272, -4.4 - row * 0.25, 1);
                // The low-poly hull includes the broad foot and narrow neck, unlike a cylinder approximation.
                const entity = s.body(mesh, { shape: 'ConvexHull', dimensions: [0.19 * scale, 0.43 * scale, 0.19 * scale], dynamic: true, mass: 0.5 * scale ** 3, friction: 0.35, restitution: 0.15 });
                s.target(mesh, 0.19, () => this.c.events.emit('impact', { position: mesh.position, power: 0.7, kind: 'bowling' }), entity);
                this.pins.push({ mesh, down: false });
            }
    }
    onThrow() { this.throws++; this.wait = 6; }
    update(dt: number) {
        let down = 0;
        for (const pin of this.pins) {
            this.c.space.local(pin.mesh.position, this.p);
            this.up.set(0, 1, 0).applyQuaternion(pin.mesh.quaternion);
            if (!pin.down && (this.p.y < 0.17 || this.up.y < 0.55)) {
                pin.down = true;
                this.score++;
                this.c.events.emit('score', { mode: this.id, points: 1, curved: false });
            }
            if (pin.down)
                down++;
        }
        if (down === 10 && this.wait > 1.4) {
            this.wait = 1.4;
            if (this.throws === 1) {
                this.c.store.progress('strike1');
                this.c.events.emit('notice', { ar: 'ضربة كاملة!', en: 'Strike!' });
            }
        }
        if (this.wait > 0 && (this.wait -= dt) <= 0) {
            if (this.throws >= 2 || down === 10) {
                this.scope.dispose();
                this.scope = new ModeScope(this.c);
                this.build();
            }
            else
                for (const pin of this.pins)
                    if (pin.down) {
                        const e = this.scope.entity(pin.mesh);
                        if (e)
                            this.c.bodies.detach(e);
                        pin.mesh.visible = false;
                    }
        }
    }
    get detail() { return `${this.pins.filter(p => p.down).length}/10 · ${Math.min(2, this.throws)}/2`; }
    dispose() { this.scope.dispose(); }
}
