import { BufferGeometry, Float32BufferAttribute, Line, LineBasicMaterial, Vector3, createSystem } from '@iwsdk/core';
import type { Ball } from '../character/ball-pool';
import { contextOf, playing } from '../core/context';
import { chargeSpeed } from './pose-history';
import { pulse } from '../haptics/haptics';
export class ThrowSystem extends createSystem({}) {
    private held?: Ball;
    private charge = -1;
    private sling = false;
    private velocity = new Vector3();
    private spin = new Vector3();
    private p = new Vector3();
    private line?: Line;
    private points = new Float32Array(24 * 3);
    private preview() { if (!this.line) {
        const geometry = new BufferGeometry();
        geometry.setAttribute('position', new Float32BufferAttribute(this.points, 3));
        this.line = new Line(geometry, new LineBasicMaterial({ color: 0xf0c579 }));
        this.world.scene.add(this.line);
    } return this.line; }
    update(dt: number) {
        const c = contextOf(this.world), r = c.input.right, l = c.input.left, type = c.store.data.throwType;
        if (!playing(c) || !r.tracked || c.mode === 'summit') {
            if (this.held) {
                c.balls.release(this.held);
                this.held = undefined;
            }
            this.charge = -1;
            this.sling = false;
            if (this.line)
                this.line.visible = false;
            return;
        }
        if (this.held && !this.held.active)
            this.held = undefined;
        if (r.primaryDown) {
            for (const b of c.balls.slots)
                if (b.active && !b.held)
                    c.balls.release(b);
            pulse(r, 0.25);
        }
        if (r.gripDown && !this.held) {
            const nearby = c.balls.slots.find(b => b.active && !b.held && b.root.position.distanceToSquared(r.position) < (b.radius + 0.14) ** 2);
            if (nearby) {
                c.bodies.detach(nearby.entity);
                nearby.held = true;
                nearby.age = 0;
                this.held = nearby;
            }
            else
                this.held = c.balls.acquire(r.position, c.store.data.style, true);
            this.charge = -1;
            pulse(r, 0.2);
        }
        if (!this.held) {
            if (this.line)
                this.line.visible = false;
            return;
        }
        const b = this.held;
        b.root.position.copy(r.position);
        b.root.quaternion.copy(r.orientation);
        b.prev.copy(b.root.position);
        b.visual.expression = 'open';
        // Stroking the held character with the other controller is the pet interaction.
        if (l.tracked && l.position.distanceToSquared(r.position) < 0.2 ** 2 && b.pet <= 0) {
            b.pet = 1.5;
            b.visual.expression = 'joy';
            pulse(l, 0.12, 20);
        }
        b.pet = Math.max(0, b.pet - dt);
        r.history.release(this.velocity, this.spin, c.input.time);
        this.velocity.multiplyScalar(2);
        if (type === 'charged') {
            if (r.triggerDown)
                this.charge = 0;
            if (r.trigger && this.charge >= 0)
                this.charge += dt;
            if (this.charge >= 0) {
                this.velocity.copy(r.direction).multiplyScalar(chargeSpeed(this.charge) * Math.sqrt(c.space.scale));
                b.visual.expression = 'focus';
            }
        }
        if (type === 'slingshot' && l.tracked && l.grip) {
            this.sling = true;
            this.velocity.subVectors(l.position, r.position);
            const pull = Math.min(0.65, this.velocity.length());
            this.velocity.normalize().multiplyScalar(pull * 23 * Math.sqrt(c.space.scale));
            b.visual.expression = 'focus';
        }
        const release = r.gripUp || (type === 'charged' && r.triggerUp && this.charge >= 0);
        if (release) {
            if (type === 'slingshot' && !this.sling)
                this.velocity.copy(r.direction).multiplyScalar(3 * Math.sqrt(c.space.scale));
            c.balls.launch(b, this.velocity, this.spin);
            this.held = undefined;
            this.charge = -1;
            this.sling = false;
            if (this.line)
                this.line.visible = false;
            pulse(r, 0.5, 45);
            return;
        }
        if ((type === 'charged' && this.charge >= 0) || (type === 'slingshot' && this.sling)) {
            const line = this.preview(), arr = line.geometry.getAttribute('position');
            for (let i = 0; i < 24; i++) {
                const t = i * 0.035;
                this.p.copy(b.root.position).addScaledVector(this.velocity, t);
                this.p.y -= 4.905 * t * t;
                arr.setXYZ(i, this.p.x, this.p.y, this.p.z);
            }
            arr.needsUpdate = true;
            line.geometry.computeBoundingSphere();
            line.visible = true;
        }
        else if (this.line)
            this.line.visible = false;
    }
}
