import { Mesh, Group, Quaternion, Vector3, LineSegments, BufferGeometry, Float32BufferAttribute, LineBasicMaterial } from '@iwsdk/core';
import type { Entity, Object3D, Material } from '@iwsdk/core';
import type { GameContext } from '../core/context';
import { ModeOwned } from '../core/components';
import type { BodyOptions } from '../physics/bodies';
import type { Target, Solid } from './types';
export class ModeScope {
    readonly objects: Object3D[] = [];
    readonly entities: Entity[] = [];
    readonly targets: Target[] = [];
    readonly solids: Solid[] = [];
    readonly geometry: BufferGeometry[] = [];
    readonly materials: Material[] = [];
    private q = new Quaternion();
    private zAxis = new Vector3(0, 0, 1);
    constructor(readonly c: GameContext) { }
    add<T extends Object3D>(o: T) { this.c.world.scene.add(o); this.objects.push(o); return o; }
    at<T extends Object3D>(o: T, x: number, y: number, z: number) { this.c.space.point(x, y, z, o.position); o.quaternion.copy(this.c.space.rotation); return this.add(o); }
    shape(geo: BufferGeometry, color: number, x: number, y: number, z: number, sx: number, sy = sx, sz = sx, opt?: Partial<BodyOptions>) {
        const m = new Mesh(geo, this.c.resources.mat(color));
        this.c.space.point(x, y, z, m.position);
        m.quaternion.copy(this.c.space.rotation);
        m.scale.set(sx, sy, sz).multiplyScalar(this.c.space.scale);
        this.add(m);
        if (opt) {
            const s = this.c.space.scale;
            const dimensions: [
                number,
                number,
                number
            ] = opt.dimensions ? opt.dimensions.map(v => v * s) as [
                number,
                number,
                number
            ] : [sx * s, sy * s, sz * s];
            this.body(m, { shape: 'Box', ...opt, dimensions });
        }
        return m;
    }
    box(color: number, x: number, y: number, z: number, w: number, h: number, d: number, physics = true) { return this.shape(this.c.resources.box, color, x, y, z, w, h, d, physics ? { shape: 'Box' } : undefined); }
    sphere(color: number, x: number, y: number, z: number, radius: number, physics = false) { return this.shape(this.c.resources.lowSphere, color, x, y, z, radius, radius, radius, physics ? { shape: 'Sphere', dimensions: [radius, 0, 0] } : undefined); }
    body(o: Object3D, opt: BodyOptions) { const e = this.c.bodies.add(o, opt).addComponent(ModeOwned, { generation: this.c.generation }); this.entities.push(e); if (o instanceof Mesh)
        this.solids.push({ mesh: o, entity: e }); return e; }
    entity(o: Object3D) { return this.entities.find(e => e.object3D === o); }
    target(o: Object3D, radius: number, hit?: Target['hit'], body?: Entity) { const t = { object: o, radius: radius * this.c.space.scale, hit, body, cooldown: 0 }; this.targets.push(t); return t; }
    line(points: number[], color = 0xfffaf2) { const geo = new BufferGeometry(), arr: number[] = [], p = new Vector3(); for (let i = 0; i < points.length; i += 3) {
        this.c.space.point(points[i], points[i + 1], points[i + 2], p);
        arr.push(p.x, p.y, p.z);
    } geo.setAttribute('position', new Float32BufferAttribute(arr, 3)); const mat = new LineBasicMaterial({ color }); this.geometry.push(geo); this.materials.push(mat); return this.add(new LineSegments(geo, mat)); }
    move(o: Object3D, x: number, y: number, z: number, angle = 0) { this.c.space.point(x, y, z, o.position); this.q.setFromAxisAngle(this.zAxis, angle).premultiply(this.c.space.rotation); o.quaternion.copy(this.q); const e = this.entity(o); if (e)
        this.c.bodies.pose(e, o.position, o.quaternion); }
    group() { return this.add(new Group()); }
    dispose() { for (const e of this.entities)
        this.c.bodies.remove(e); for (const o of this.objects)
        o.removeFromParent(); for (const g of this.geometry)
        g.dispose(); for (const m of this.materials)
        m.dispose(); this.targets.length = this.solids.length = this.entities.length = this.objects.length = 0; }
}
