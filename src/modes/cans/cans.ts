import { Vector3 } from '@iwsdk/core';
import type { Entity, Mesh } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { ModeScope } from '../scope';
export class CansMode {
    readonly id = 'cans' as const;
    scope: ModeScope;
    score = 0;
    private cans: {
        mesh: Mesh;
        entity: Entity;
        down: boolean;
    }[] = [];
    private p = new Vector3();
    private reset = 0;
    private throws = 0;
    constructor(readonly c: GameContext) { this.scope = new ModeScope(c); this.build(); }
    private build() {
        const s = this.scope, scale = this.c.space.scale;
        this.throws = 0;
        this.cans = [];
        s.box(0x86604c, 0, 0.85, -2.6, 1.5, 0.12, 0.8);
        for (const x of [-0.58, 0.58])
            s.box(0x493d38, x, 0.4, -2.6, 0.09, 0.8, 0.6);
        for (let row = 0; row < 3; row++)
            for (let i = 0; i < 3 - row; i++) {
                const mesh = s.shape(this.c.resources.cylinder, [0xc66b51, 0xf2cb69, 0x70a6a0][row], (i - (2 - row) / 2) * 0.24, 1.035 + row * 0.252, -2.6, 0.105, 0.25, 0.105);
                const entity = s.body(mesh, { shape: 'Cylinder', dimensions: [0.105 * scale, 0.25 * scale, 0], dynamic: true, mass: 0.09 * scale ** 3, friction: 0.55, restitution: 0.12 });
                s.target(mesh, 0.17, () => this.c.events.emit('impact', { position: mesh.position, power: 0.5, kind: 'can' }), entity);
                this.cans.push({ mesh, entity, down: false });
            }
    }
    onThrow() { this.throws++; }
    update(dt: number) {
        let down = 0;
        for (const can of this.cans) {
            this.c.space.local(can.mesh.position, this.p);
            if (!can.down && (this.p.y < 0.72 || Math.abs(this.p.x) > 0.82 || Math.abs(this.p.z + 2.6) > 0.55)) {
                can.down = true;
                this.score++;
                this.c.events.emit('score', { mode: this.id, points: 1, curved: false });
            }
            if (can.down)
                down++;
        }
        if (down === 6 && !this.reset) {
            this.reset = 1.8;
            if (this.throws === 1)
                this.c.store.progress('cansOne');
        }
        if (this.reset > 0 && (this.reset -= dt) <= 0) {
            this.reset = 0;
            this.scope.dispose();
            this.scope = new ModeScope(this.c);
            this.build();
        }
    }
    get detail() { return `${this.cans.filter(c => c.down).length}/6`; }
    dispose() { this.scope.dispose(); }
}
