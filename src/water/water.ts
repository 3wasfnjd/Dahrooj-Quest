import { Mesh, PlaneGeometry, ShaderMaterial, Vector3, RingGeometry, MeshBasicMaterial } from '@iwsdk/core';
import type { GameContext } from '../core/context';
import type { ModeScope } from '../modes/scope';
import { PHYSICS } from '../core/config';
export class Water {
    readonly surface = -0.08;
    private impulse = new Vector3();
    private ripples: {
        mesh: Mesh;
        life: number;
    }[] = [];
    private time = { value: 0 };
    constructor(readonly c: GameContext, scope: ModeScope) {
        const geometry = new PlaneGeometry(3.7, 3.6, 1, 1), material = new ShaderMaterial({ uniforms: { time: this.time }, vertexShader: 'varying vec2 uvv;void main(){uvv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}', fragmentShader: 'uniform float time;varying vec2 uvv;void main(){float a=sin(uvv.x*42.+time*.8)*sin(uvv.y*34.-time*.65);vec3 c=mix(vec3(.12,.28,.32),vec3(.32,.51,.53),.5+a*.16);gl_FragColor=vec4(c,1.);}' });
        scope.geometry.push(geometry);
        scope.materials.push(material);
        const mesh = scope.add(new Mesh(geometry, material));
        mesh.rotation.x = -Math.PI / 2;
        mesh.position.set(6, this.surface, -3);
        const ring = new RingGeometry(0.9, 1, 28);
        scope.geometry.push(ring);
        const mat = new MeshBasicMaterial({ color: 0xa8cdca, depthWrite: false });
        scope.materials.push(mat);
        for (let i = 0; i < 12; i++) {
            const mesh = scope.add(new Mesh(ring, mat));
            mesh.rotation.x = -Math.PI / 2;
            mesh.visible = false;
            this.ripples.push({ mesh, life: 0 });
        }
    }
    contains(p: Vector3) { return this.c.xr === 'immersive-vr' && p.x > 4.15 && p.x < 7.85 && p.z > -4.8 && p.z < -1.2; }
    splash(p: Vector3, strength = 0.5) { const r = this.ripples.find(r => r.life <= 0); if (r) {
        r.life = 1;
        r.mesh.position.set(p.x, this.surface + 0.004, p.z);
        r.mesh.visible = true;
        r.mesh.scale.setScalar(0.06);
    } this.c.particles.burst(p, 0x8ebdbd, 10, Math.min(1.2, strength)); this.c.events.emit('impact', { position: p, power: strength, kind: 'water' }); }
    update(dt: number) {
        this.time.value = this.c.elapsed;
        for (const r of this.ripples)
            if (r.life > 0) {
                r.life -= dt;
                r.mesh.visible = r.life > 0;
                r.mesh.scale.setScalar(0.08 + (1 - r.life) * 0.75);
            }
        for (const b of this.c.balls.slots) {
            if (!b.active || b.held)
                continue;
            const p = b.root.position;
            if (!this.contains(p) || p.y - b.radius > this.surface) {
                b.water = false;
                continue;
            }
            const depth = Math.min(2 * b.radius, Math.max(0, this.surface - p.y + b.radius)), fraction = depth * depth * (3 * b.radius - depth) / (4 * b.radius ** 3), mass = PHYSICS.ballMass * (b.radius / PHYSICS.ballRadius) ** 3;
            if (!b.water) {
                b.water = true;
                this.splash(p, Math.min(1, b.velocity.length() / 8));
            }
            this.impulse.copy(b.velocity).multiplyScalar(-mass * Math.min(0.25, fraction * dt * 3.2));
            this.impulse.y += mass * 9.81 * fraction * 1.3 * dt;
            this.c.bodies.manipulate(b.entity, undefined, undefined, this.impulse);
        }
    }
}
