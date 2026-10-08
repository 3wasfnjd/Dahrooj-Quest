import { InstancedMesh, Matrix4, Vector3, Quaternion } from '@iwsdk/core';
import type { Mesh } from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { ModeScope } from '../scope';
import { SummitSimulation, SUMMIT } from './simulation';
import type { CharacterVisual } from '../../character/visual';
const COLORS = [0x779869, 0x9a826b, 0x645977, 0xc3dae5];
export class SummitMode {
    readonly id = 'summit' as const;
    readonly scope: ModeScope;
    readonly simulation = new SummitSimulation();
    score = 0;
    private avatar: CharacterVisual;
    private platformMesh: InstancedMesh;
    private enemies: Mesh[];
    private shots: Mesh[];
    private ice: Mesh[];
    private matrix = new Matrix4();
    private p = new Vector3();
    private size = new Vector3();
    private q = new Quaternion();
    private scroll = 0;
    private won = false;
    private kills = 0;
    private hearts = 3;
    constructor(readonly c: GameContext) {
        const s = this.scope = new ModeScope(c);
        this.avatar = c.balls.factory.create();
        this.avatar.setStyle(c.store.data.style);
        this.avatar.wear(c.store.data.accessory);
        s.add(this.avatar.root);
        this.avatar.root.scale.setScalar(SUMMIT.radius * c.space.scale);
        s.box(0x383d49, 0, 1.6, -3.5, 2.3, 3.3, 0.18, false);
        this.platformMesh = s.add(new InstancedMesh(c.resources.box, c.resources.mat(0xffffff), this.simulation.platforms.length));
        this.platformMesh.frustumCulled = false; // Bounded 38-instance diorama; matrices are clipped to the visible window below.
        this.simulation.platforms.forEach((p, i) => this.platformMesh.setColorAt(i, c.resources.mat(p.kind === 'ice' ? 0xa3dbea : p.kind === 'crumble' ? 0xc59764 : COLORS[Math.min(3, Math.floor(p.y / 2.88))]).color));
        this.enemies = this.simulation.enemies.map(e => s.sphere(e.type === 'crawler' ? 0xe16f55 : e.type === 'bat' ? 0x9980bd : 0x93b756, 0, 0, 0, 0.07));
        this.shots = this.simulation.shots.map(() => s.sphere(0xf4dd94, 0, 0, 0, 0.025));
        this.ice = this.simulation.icicles.map(() => s.shape(c.resources.cone, 0xc9ecf8, 0, 0, 0, 0.035, 0.2, 0.035));
        // Spikes have the same positions as the deterministic side-hazard rule.
        for (let side = -1; side <= 1; side += 2)
            for (let i = 0; i < 9; i++)
                s.shape(c.resources.cone, 0xae877f, side * 1.06, 0.2 + i * 0.35, -3.08, 0.065, 0.12, 0.065);
        c.events.emit('notice', { ar: 'القمة: العصا اليسرى للحركة، A للقفز، الزناد الأيسر للرمي، B للخروج', en: 'Summit: left stick move · A jump · left trigger shoot · B menu' });
    }
    jump() { this.simulation.jump(); }
    shoot() { this.simulation.shoot(); }
    update(dt: number) {
        const c = this.c, sim = this.simulation;
        sim.update(dt, c.input.left.axisX);
        this.scroll += (Math.max(0, sim.y - 1.2) - this.scroll) * Math.min(1, dt * 4);
        this.place(this.avatar.root, sim.x, sim.y);
        this.avatar.root.visible = sim.respawn <= 0 && (sim.invincible <= 0 || Math.sin(sim.time * 25) > 0);
        this.avatar.expression = sim.hearts < this.hearts ? 'hurt' : sim.won ? 'joy' : 'focus';
        this.hearts = sim.hearts;
        this.p.set(0, 0, 1);
        this.avatar.update(dt, c.elapsed, this.p);
        for (let i = 0; i < sim.platforms.length; i++) {
            const p = sim.platforms[i], y = p.y - this.scroll;
            c.space.point(p.x, y + 0.24, -3.05, this.p);
            this.size.set(p.width, 0.075, 0.25).multiplyScalar(c.space.scale);
            if (p.broken > 0 || y < -0.2 || y > 3)
                this.size.setScalar(0);
            this.matrix.compose(this.p, c.space.rotation, this.size);
            this.platformMesh.setMatrixAt(i, this.matrix);
        }
        this.platformMesh.instanceMatrix.needsUpdate = true;
        sim.enemies.forEach((e, i) => { this.place(this.enemies[i], e.x, e.y); this.enemies[i].visible &&= e.alive; });
        sim.shots.forEach((s, i) => { this.place(this.shots[i], s.x, s.y); this.shots[i].visible &&= s.life > 0; });
        sim.icicles.forEach((s, i) => { this.place(this.ice[i], s.x + (s.state === 1 ? Math.sin(sim.time * 50) * 0.012 : 0), s.y); this.ice[i].visible &&= s.state !== 3; this.ice[i].quaternion.copy(c.space.rotation).multiply(this.q.setFromAxisAngle(this.p.set(1, 0, 0), Math.PI)); });
        if (sim.kills > this.kills) {
            c.store.progress('monsters15', sim.kills - this.kills);
            this.kills = sim.kills;
        }
        this.score = Math.floor(sim.y * 10);
        if (sim.won && !this.won) {
            this.won = true;
            c.store.progress('summit1');
            c.events.emit('notice', { ar: 'وصلت إلى القمة!', en: 'Summit reached!' });
            c.events.emit('score', { mode: this.id, points: 100, curved: false });
        }
    }
    private place(mesh: {
        position: Vector3;
        visible: boolean;
    }, x: number, y: number) { const local = y - this.scroll; this.c.space.point(x, local + 0.24, -2.99, mesh.position); mesh.visible = local > -0.2 && local < 3; }
    get detail() { return `${'♥'.repeat(Math.max(0, this.simulation.hearts))} · ${this.c.store.data.language === 'ar' ? ({ meadow: 'المرج', cliffs: 'المنحدرات', caves: 'الكهوف', snow: 'الثلج' })[this.simulation.region] : this.simulation.region} · ${this.simulation.checkpoint}/37`; }
    dispose() { this.scope.dispose(); }
}
