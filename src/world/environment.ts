import { AssetManager, Box3, Color, Fog, InstancedMesh, Matrix4, Mesh, Vector3, Quaternion, HemisphereLight, DirectionalLight, Points, BufferGeometry, Float32BufferAttribute, PointsMaterial, RepeatWrapping, SRGBColorSpace, createSystem } from '@iwsdk/core';
import type { Entity, Object3D } from '@iwsdk/core';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
import { ModeScope } from '../modes/scope';
import type { Target } from '../modes/types';
import { Vegetation } from '../nature/vegetation';
import { Water } from '../water/water';
import { Weather } from '../weather/weather';
import { seeded } from '../core/config';
export class Environment {
    scope?: ModeScope;
    water?: Water;
    private nature?: Vegetation;
    private weather?: Weather;
    readonly sun = new DirectionalLight(0xffe6c2, 2);
    readonly ambient = new HemisphereLight(0xcde3e6, 0x76644c, 2.4);
    readonly targets: Target[] = [];
    night = false;
    private sky = new Color();
    private dawn = new Color(0xb88d89);
    private day = new Color(0xaec5c2);
    private dark = new Color(0x121b31);
    private p = new Vector3();
    private velocity = new Vector3();
    private impulse = new Vector3();
    private version = 0;
    private fireflies?: Points;
    private stars?: Points;
    private lights: Object3D[] = [];
    private nightMaterial = new PointsMaterial({ color: 0xf6d78e, size: 0.045 });
    private crates: {
        mesh: Mesh;
        entity: Entity;
        home: Vector3;
        fuse: number;
        respawn: number;
        target: Target;
    }[] = [];
    constructor(readonly c: GameContext) { c.world.scene.add(this.sun, this.ambient); this.sun.position.set(-6, 10, 4); }
    rebuild() {
        this.dispose();
        const c = this.c, s = this.scope = new ModeScope(c), version = this.version;
        if (c.xr === 'immersive-ar') {
            c.world.scene.background = null;
            c.world.scene.fog = null;
            c.world.renderer.setClearColor(0x000000, 0);
            s.box(0x5e6662, 0, -0.025, -3, 4.2, 0.05, 6.5);
            return;
        }
        c.world.renderer.setClearColor(0xaec5c2, 1);
        c.world.scene.background = this.sky;
        c.world.scene.fog = new Fog(0xaec5c2, 20, 55);
        // Four ground colliders leave a genuine basin below the pond surface.
        s.box(0x64855c, -12.9, -0.14, -3, 34.1, 0.22, 60);
        s.box(0x64855c, 19, -0.14, -3, 22.3, 0.22, 60);
        s.box(0x64855c, 6, -0.14, 14.4, 3.7, 0.22, 31.2);
        s.box(0x64855c, 6, -0.14, -19.9, 3.7, 0.22, 30.2);
        s.box(0x4c6457, 6, -0.68, -3, 3.7, 0.12, 3.6);
        const court = s.box(0xb4ada0, 0, -0.018, -3, 8, 0.034, 13);
        void AssetManager.loadTexture('/assets/textures/slabs.png').then(t => { if (version !== this.version)
            return; t.wrapS = t.wrapT = RepeatWrapping; t.repeat.set(10, 16); t.colorSpace = SRGBColorSpace; const mat = this.c.resources.mat(0xb4ada0).clone(); mat.map = t; mat.needsUpdate = true; court.material = mat; s.materials.push(mat); }).catch(() => this.noticeAsset());
        for (const x of [-4.03, 4.03])
            s.box(0x777477, x, -0.015, -3, 0.12, 0.1, 13);
        this.nature = new Vegetation(c, s);
        this.water = new Water(c, s);
        this.weather = new Weather(c, s);
        for (let i = 0; i < 5; i++) {
            const x = -3 - (i % 2) * 0.37, y = 0.19 + (i === 4 ? 0.39 : 0), z = -1.9 - Math.floor(i / 2) * 0.42;
            const mesh = s.box(0xaa7951, x, y, z, 0.37, 0.37, 0.37, false);
            const entity = s.body(mesh, { shape: 'Box', dimensions: [0.37, 0.37, 0.37], dynamic: true, mass: 1.2, friction: 0.7 });
            const crate = { mesh, entity, home: mesh.position.clone(), fuse: 0, respawn: 0, target: undefined as unknown as Target };
            crate.target = s.target(mesh, 0.3, () => { if (!crate.fuse && !crate.respawn)
                crate.fuse = 0.65; }, entity);
            this.targets.push(crate.target);
            this.crates.push(crate);
        }
        void this.models(s, version);
        const random = seeded(801), stars = new Float32Array(180 * 3), flies = new Float32Array(36 * 3);
        for (let i = 0; i < stars.length; i += 3) {
            const theta = random() * Math.PI * 2, elevation = random() * 1.1 + 0.15;
            stars[i] = Math.cos(theta) * Math.cos(elevation) * 42;
            stars[i + 1] = Math.sin(elevation) * 42;
            stars[i + 2] = Math.sin(theta) * Math.cos(elevation) * 42;
        }
        for (let i = 0; i < flies.length; i += 3) {
            flies[i] = (random() - 0.5) * 17;
            flies[i + 1] = 0.3 + random() * 1.3;
            flies[i + 2] = -random() * 13;
        }
        const makePoints = (array: Float32Array, mat: PointsMaterial) => { const geo = new BufferGeometry(); geo.setAttribute('position', new Float32BufferAttribute(array, 3)); s.geometry.push(geo); return s.add(new Points(geo, mat)); };
        this.stars = makePoints(stars, c.resources.starMaterial);
        this.fireflies = makePoints(flies, this.nightMaterial);
    }
    private noticeAsset() { this.c.events.emit('notice', { ar: 'تعذر تحميل بعض الزينة؛ اللعب متاح ويمكن إعادة المحاولة.', en: 'Some scenery could not load. Gameplay remains available; reconnect to retry.' }); }
    private async models(scope: ModeScope, version: number) {
        const specs: [
            string,
            number,
            [
                number,
                number,
                number,
                number
            ][]
        ][] = [
            ['bench', 0.95, [[-5.2, 0, -2, 1.57], [5.2, 0, -8, -1.57]]], ['poleLight', 3.2, [[-4.6, 0, 2, 0], [4.6, 0, 2, 0], [-4.6, 0, -9, 0], [4.6, 0, -9, 0]]], ['lantern', 0.42, [[-5.2, 0, -3.2, 0], [5.2, 0, -7, 1]]],
        ];
        for (const [name, height, placements] of specs) {
            try {
                const gltf = await AssetManager.loadGLTF(`/assets/models/${name}.glb`);
                if (version !== this.version)
                    return;
                const scene = gltf.scene;
                scene.updateMatrixWorld(true);
                const box = new Box3().setFromObject(scene), size = box.getSize(new Vector3()), center = box.getCenter(new Vector3()), scale = height / Math.max(0.01, size.y), matrix = new Matrix4(), p = new Vector3(), q = new Quaternion(), uniform = new Vector3(1, 1, 1);
                scene.traverse(o => { if (!(o instanceof Mesh))
                    return; const geometry = o.geometry.clone().applyMatrix4(o.matrixWorld); geometry.translate(-center.x, -box.min.y, -center.z); geometry.scale(scale, scale, scale); scope.geometry.push(geometry); const mesh = scope.add(new InstancedMesh(geometry, o.material, placements.length)); placements.forEach(([x, y, z, rotation], i) => { p.set(x, y, z); q.setFromAxisAngle(this.p.set(0, 1, 0), rotation); matrix.compose(p, q, uniform); mesh.setMatrixAt(i, matrix); }); mesh.computeBoundingSphere(); });
                if (name === 'poleLight' || name === 'lantern')
                    for (const [x, y, z] of placements) {
                        const orb = scope.sphere(0xf5d992, x, y + height * 0.86, z, name === 'poleLight' ? 0.075 : 0.045);
                        orb.material = this.c.resources.mat(0xf5d992, true);
                        this.lights.push(orb);
                    }
                if (name === 'bench')
                    for (const [x, , z] of placements) {
                        const collider = scope.box(0x806450, x, 0.45, z, 0.7, 0.9, 2);
                        collider.visible = false;
                    }
            }
            catch {
                this.noticeAsset();
            }
        }
        try {
            const gltf = await AssetManager.loadGLTF('/assets/models/explosiveCrate.glb');
            if (version !== this.version)
                return;
            gltf.scene.updateMatrixWorld(true);
            const box = new Box3().setFromObject(gltf.scene), center = box.getCenter(new Vector3()), size = box.getSize(new Vector3());
            for (const crate of this.crates) {
                const model = gltf.scene.clone();
                model.scale.set(1 / size.x, 1 / size.y, 1 / size.z);
                model.position.copy(center).multiply(model.scale).negate();
                crate.mesh.add(model);
                crate.mesh.material = this.c.resources.hiddenMaterial;
            }
        }
        catch {
            this.noticeAsset();
        }
    }
    explosion(position: Vector3, power = 1) { const c = this.c; c.particles.burst(position, 0xeead62, 40, 1.2); c.events.emit('impact', { position, power, kind: 'explosion' }); for (const b of c.balls.slots)
        if (b.active && !b.held) {
            this.impulse.subVectors(b.root.position, position);
            const d = this.impulse.length();
            if (d < 2.5) {
                this.impulse.normalize().multiplyScalar(Math.min(1.7, (2.5 - d) * 0.7));
                this.impulse.y = Math.max(0.1, this.impulse.y);
                if(c.modes.current?.referencePhysics)b.velocity.addScaledVector(this.impulse,1/.38).clampLength(0,12);else c.bodies.manipulate(b.entity, undefined, undefined, this.impulse);
            }
        } for (const crate of this.crates)
        if (!crate.respawn && !crate.fuse && crate.mesh.position.distanceToSquared(position) < 1.7 ** 2)
            crate.fuse = 0.22 + Math.random() * 0.3; }
    update(dt: number) {
        if (!this.scope)
            return;
        const c = this.c;
        const setting = c.store.data.time, phase = setting === 'auto' ? (c.elapsed % 240) / 240 : ({ day: 0.25, dusk: 0.49, night: 0.7, dawn: 0.01 } as const)[setting];
        const daylight = Math.max(0, Math.sin(phase * Math.PI * 2));
        this.night = daylight < 0.08;
        this.sky.copy(this.dark).lerp(this.dawn, Math.min(1, daylight * 4)).lerp(this.day, Math.max(0, daylight - 0.15));
        if (c.world.scene.fog instanceof Fog)
            c.world.scene.fog.color.copy(this.sky);
        this.sun.intensity = 0.15 + daylight * 2;
        this.ambient.intensity = 0.75 + daylight * 1.65;
        if (c.xr === 'immersive-ar')
            return;
        this.nature?.update(c.elapsed);
        this.weather?.update(dt);
        this.water?.update(dt);
        for (const light of this.lights)
            light.visible = this.night;
        if (this.stars)
            this.stars.visible = this.night;
        if (this.fireflies) {
            this.fireflies.visible = this.night;
            this.fireflies.position.y = Math.sin(c.elapsed * 0.7) * 0.1;
        }
        for (const crate of this.crates) {
            crate.target.cooldown = Math.max(0, crate.target.cooldown - dt);
            if (crate.respawn > 0) {
                crate.respawn -= dt;
                if (crate.respawn <= 0) {
                    crate.mesh.visible = true;
                    c.bodies.add(crate.mesh, { shape: 'Box', dimensions: [0.37, 0.37, 0.37], dynamic: true, mass: 1.2, friction: 0.7 }, crate.entity);
                    c.bodies.pose(crate.entity, crate.home, undefined, true);
                    crate.target.radius = 0.3;
                }
                continue;
            }
            c.bodies.velocity(crate.entity, this.velocity);
            if (this.velocity.length() > 7)
                c.bodies.manipulate(crate.entity, this.velocity.clampLength(0, 7));
            if (crate.mesh.position.y < -3) {
                c.bodies.pose(crate.entity, crate.home, undefined, true);
            }
            if (crate.fuse > 0 && (crate.fuse -= dt) <= 0) {
                crate.fuse = 0;
                crate.respawn = 8;
                crate.mesh.visible = false;
                crate.target.radius = 0;
                c.bodies.detach(crate.entity);
                this.explosion(crate.mesh.position);
                c.store.progress('crates5');
            }
        }
    }
    dispose() { this.version++; this.scope?.dispose(); this.scope = undefined; this.water = undefined; this.nature = undefined; this.weather = undefined; this.crates.length = this.targets.length = this.lights.length = 0; this.stars = this.fireflies = undefined; }
}
export class EnvironmentSystem extends createSystem({}) {
    update(dt: number) { const c = contextOf(this.world); if (playing(c)) {
        c.elapsed += dt;
        c.environment.update(dt);
        c.particles.update(dt);
    } }
}
