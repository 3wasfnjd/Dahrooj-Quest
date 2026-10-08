import { Group, Mesh, Vector3, CylinderGeometry, SphereGeometry, MeshBasicMaterial, Raycaster, createSystem } from '@iwsdk/core';
import type { Entity } from '@iwsdk/core';
import { contextOf, playing } from '../core/context';
import type { GameContext } from '../core/context';
import { LIMITS } from '../core/config';
import type { ShotId } from '../core/config';
import { Projectile } from '../core/components';
import { SHOT_STYLE, FIRE_COLS, advanceShot, groundMini } from '../reference/projectile-spec.js';
import type { ReferenceShot } from '../reference/projectile-spec.js';
import type { ReferenceCrowd } from '../reference/character.js';
import { ReferenceMode } from '../modes/reference-mode';
import { STYLES } from '../core/config';
import { pulse } from '../haptics/haptics';
export const SHOT_SPEC = Object.fromEntries(Object.entries(SHOT_STYLE).map(([id,s])=>[id,{speed:s.speed,gravity:s.grav,life:s.life,radius:s.r,cooldown:s.cool}])) as Record<ShotId,{speed:number;gravity:number;life:number;radius:number;cooldown:number}>;
interface Shot {
    entity: Entity;
    original:ReferenceShot; visual:Group; look:typeof STYLES[number];
    mesh: Mesh;
    active: boolean;
    type: ShotId;
    v: Vector3;
    previous: Vector3;
    life: number;
    age: number;
    skips: number;
    radius: number;
}
export class Projectiles {
    readonly slots: Shot[];
    readonly blaster = new Group();
    private cooldown = 0;
    private phase = 0;
    private crowd:ReferenceCrowd;
    private ray=new Raycaster();
    private squash=[1,1];
    private fired=0;
    private p = new Vector3();
    private normal = new Vector3();
    private zero = new Vector3();
    private trail = 0;
    constructor(readonly c: GameContext) {
        this.crowd=c.balls.factory.reference.crowd(LIMITS.projectiles);c.world.scene.add(this.crowd.group);
        const trailGeo=new CylinderGeometry(.006,.006,1,6,1,true).rotateX(Math.PI/2),trailMat=new MeshBasicMaterial({color:0xffd27a,transparent:true,opacity:.95,depthWrite:false}),headGeo=new SphereGeometry(.012,10,8),headMat=new MeshBasicMaterial({color:0xfff4d6});
        this.slots = Array.from({ length: LIMITS.projectiles }, (_, slot) => {
            const mesh=new Mesh(c.resources.lowSphere,c.resources.hiddenMaterial),visual=new Group(),trail=new Mesh(trailGeo,trailMat),head=new Mesh(headGeo,headMat);
            trail.scale.z=.35;trail.position.z=-.175;visual.add(trail,head);c.world.scene.add(visual);visual.visible=false;mesh.visible=false;
            const entity=c.world.createTransformEntity(mesh).addComponent(Projectile,{slot}),v=new Vector3();
            return {entity,mesh,visual,look:'fabric',original:{kind:'bolt',p:mesh.position,v,wob:0,r:.02},active:false,type:'bolt',v,previous:new Vector3(),life:0,age:0,skips:0,radius:.02};
        });
        c.resources.mesh(c.resources.box, 0x594253, 0, 0.025, -0.08, 0.08, 0.065, 0.14, this.blaster);
        c.resources.mesh(c.resources.cylinder, 0xf0bb69, 0, 0.025, -0.16, 0.029, 0.06, 0.029, this.blaster).rotation.x = Math.PI / 2;
        c.world.scene.add(this.blaster);
    }
    fire(type: ShotId, origin: Vector3, direction: Vector3) {
        const slot = this.slots.find(s => !s.active);
        if (!slot)
            return false;
        const spec = SHOT_SPEC[type], c = this.c, scale = Math.max(0.4, c.space.scale);
        slot.active = true;
        slot.type = type;
        slot.life = spec.life;
        slot.age = slot.skips = 0;
        slot.radius = spec.radius * scale;
        slot.mesh.visible = true;
        slot.mesh.position.copy(origin).addScaledVector(direction, 0.17);
        slot.previous.copy(slot.mesh.position);
        slot.mesh.scale.setScalar(slot.radius);
        slot.original.kind=type;slot.original.r=slot.radius;slot.original.wob=Math.random()*6;
        slot.look=STYLES[(++this.fired)%STYLES.length];slot.visual.visible=type==='bolt'||type==='firework';slot.visual.children[0].visible=type==='bolt';slot.visual.scale.setScalar(scale*(type==='firework'?1.4:1));
        slot.visual.position.copy(slot.mesh.position);this.p.copy(slot.mesh.position).add(direction);slot.visual.lookAt(this.p);
        slot.v.copy(direction).multiplyScalar(spec.speed*scale);
        c.particles.burst(slot.mesh.position, 0xf6cb74, 4, 0.3);
        c.events.emit('impact', { position: origin, power: 0.3, kind: 'shot' });
        c.events.emit('projectile', type);
        pulse(c.input.left, 0.18, 20);
        return true;
    }
    private end(s: Shot, explosion = false) {
        if (!s.active)
            return;
        if (explosion) {
            for(const color of FIRE_COLS)this.c.particles.burst(s.mesh.position,color,5,this.c.space.scale);
            for(const b of this.c.balls.slots)if(b.active&&!b.held&&b.root.position.distanceTo(s.mesh.position)<.55*this.c.space.scale+b.radius)this.c.balls.pop(b);
            for(let i=0;i<LIMITS.rain+LIMITS.balls;i++){if(!this.c.modes.popCharacters(s.mesh.position,s.mesh.position,.55*this.c.space.scale))break;}
            this.c.events.emit('impact', { position: s.mesh.position, power: 0.6, kind: 'pop' });
            for (const t of this.c.modes.current?.scope.targets || [])
                if (t.radius > 0 && t.object.position.distanceToSquared(s.mesh.position) < (0.6 * this.c.space.scale) ** 2) {
                    this.normal.subVectors(t.object.position, s.mesh.position).normalize();
                    this.p.copy(t.object.position).addScaledVector(this.normal, 0.01);
                    this.c.modes.sweep(s.mesh.position, this.p, 0, 0.9);
                }
        }

        s.active = false;
        s.mesh.visible = false;
        s.visual.visible = false;
    }
    clear() { for (const s of this.slots)
        this.end(s); this.crowd.begin();this.crowd.end();this.cooldown = 0; }
    get active() { let n = 0; for (const s of this.slots)
        if (s.active)
            n++; return n; }
    update(dt: number) {
        const c = this.c, left = c.input.left;
        this.blaster.visible = playing(c) && left.tracked && c.mode !== 'summit';
        this.blaster.position.copy(left.position);
        this.blaster.quaternion.copy(left.orientation);
        if (!playing(c))
            return;
        this.cooldown = Math.max(0, this.cooldown - dt);
        if (left.tracked && left.trigger && this.cooldown === 0) {
            this.cooldown = SHOT_SPEC[c.store.data.shot].cooldown;
            if (c.mode === 'summit')
                c.modes.current?.shoot?.();
            else
                this.fire(c.store.data.shot, left.ray, left.direction);
        }
        if (c.mode === 'summit' && c.input.right.primaryDown)
            c.modes.current?.jump?.();
        this.phase += dt;
        this.trail += dt;
        this.crowd.begin();
        for (const s of this.slots) {
            if (!s.active)
                continue;
            s.life -= dt;
            s.age += dt;
            if (s.life <= 0) {
                this.end(s, s.type === 'firework');
                continue;
            }
            advanceShot(s.original,dt,Math.max(.4,c.space.scale));
            if (s.type === 'firework' && this.trail > 0.055)
                c.particles.burst(s.mesh.position, 0xe7995c, 2, 0.15);
            if (c.environment.water?.contains(s.mesh.position) && s.mesh.position.y - s.radius < c.environment.water.surface) {
                const w = c.environment.water;
                w.splash(s.mesh.position, 0.35);
                if (s.type === 'mini' && s.skips < 4 && Math.hypot(s.v.x, s.v.z) > 2.2 && -s.v.y < Math.hypot(s.v.x, s.v.z) * 0.7) {
                    s.skips++;
                    s.v.y = Math.max(1, -s.v.y * 0.6);
                    s.v.multiplyScalar(0.82);
                    s.mesh.position.y = w.surface + s.radius;

                }
                else if (s.type === 'bubble') {
                    s.mesh.position.y = w.surface + s.radius;
                    s.v.multiplyScalar(0.9);
                    s.v.set(0,0,0);s.life = Math.min(s.life, 0.9);
                }
                else
                    this.end(s);
            }
            if (!s.active)
                continue;
            const mode=c.modes.current;
            if(mode instanceof ReferenceMode){
                this.normal.subVectors(s.mesh.position,s.previous);const distance=this.normal.length();
                if(distance>0){this.ray.set(s.previous,this.normal.divideScalar(distance));this.ray.far=distance+s.radius;
                    const contact=this.ray.intersectObject(mode.stage.grp,true).find(h=>h.object instanceof Mesh&&h.object.visible&&h.object.parent?.visible);
                    if(contact){const normal=contact.face?.normal.clone().transformDirection(contact.object.matrixWorld)??this.normal.clone().negate();
                        mode.root.worldToLocal(this.p.copy(contact.point));const direction=this.normal.clone().applyQuaternion(mode.root.quaternion.clone().invert());
                        if(mode.id==='fair')mode.stage.onThrow?.();const took=mode.stage.shoot?.(contact.object,this.p,direction);
                        if(s.type==='mini'&&!took){s.mesh.position.copy(contact.point).addScaledVector(normal,s.radius);const vn=s.v.dot(normal);if(vn<0)s.v.addScaledVector(normal,-1.5*vn);}else{this.end(s,s.type==='firework');continue;}
                    }
                }
            }
            const blocked = s.type !== 'mini' && c.modes.block(s.previous, s.mesh.position, s.radius, s.mesh.position);
            const target = c.modes.sweep(s.previous, s.mesh.position, s.radius, s.type === 'firework' ? 2 : s.type === 'mini' ? 1.2 : 0.8);
            const popped = c.modes.popCharacters(s.previous, s.mesh.position, s.radius);
            if(popped&&s.type==='mini')s.v.multiplyScalar(.6);
            if ((target || blocked || popped) && s.type !== 'mini') {
                c.particles.burst(s.mesh.position, 0xf5d497, 8, 0.3);
                this.end(s, s.type === 'firework');
                continue;
            }
            if(s.type==='mini'&&s.mesh.position.y<c.space.origin.y+s.radius)groundMini(s.original,dt,c.space.origin.y,Math.max(.4,c.space.scale));
            if (s.mesh.position.y < c.space.origin.y - 0.08 && s.type !== 'mini')
                this.end(s, s.type === 'firework');
            if (s.mesh.position.y < -4 || s.mesh.position.distanceToSquared(c.input.head) > 45 ** 2)
                this.end(s);
            s.visual.position.copy(s.mesh.position);
            if(s.active&&(s.type==='mini'||s.type==='bubble'))this.crowd.add(s.type==='bubble'?'bubble':s.look,s.mesh.position,s.radius,null,this.squash,null);
            s.previous.copy(s.mesh.position);
        }
        this.crowd.end();
        if (this.trail > 0.055)
            this.trail = 0;
    }
}
export class ProjectileSystem extends createSystem({ projectiles: { required: [Projectile] } }) {
    update(dt: number) { contextOf(this.world).projectiles.update(dt); }
}
