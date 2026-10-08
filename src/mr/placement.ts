import { Matrix4, Mesh, RingGeometry, MeshBasicMaterial, Quaternion, Vector3, createSystem } from '@iwsdk/core';
import type { Entity } from '@iwsdk/core';
import type { GameContext } from '../core/context';
import { contextOf } from '../core/context';
import { LIMITS } from '../core/config';
type Plane = {
    planeSpace: XRSpace;
    polygon: readonly DOMPointReadOnly[];
    lastChangedTime: number;
    orientation?: string;
    semanticLabel?: string;
};
type RoomFrame = XRFrame & {
    detectedPlanes?: Set<Plane>;
    createAnchor?: (pose: XRRigidTransform, space: XRSpace) => Promise<XRAnchor>;
};
export class MRPlacement {
    readonly preview: Mesh;
    kind: 'floor' | 'table' | 'wall' = 'floor';
    manual = false;
    readonly support = { hitTest: false, planes: false, anchors: false, hands: false, environmentRaycast: false };
    private hitSource?: XRHitTestSource;
    private session?: XRSession;
    private previewPoint = new Vector3();
    private up = new Vector3(0, 1, 0);
    private q = new Quaternion();
    private matrix = new Matrix4();
    private normal = new Vector3();
    private ready = false;
    private anchor?: XRAnchor;
    private room = new Map<Plane, {
        entity: Entity;
        mesh: Mesh;
        changed: number;
    }>();
    private lastHit?: XRHitTestResult;
    private pending = false;
    constructor(readonly c: GameContext) { this.preview = new Mesh(new RingGeometry(0.11, 0.14, 40), new MeshBasicMaterial({ color: 0xf1c47b, side: 2, depthTest: false })); this.preview.visible = false; this.preview.renderOrder = 5; c.world.scene.add(this.preview); }
    async begin() {
        const c = this.c;
        this.clearRoom();
        c.placing = true;
        c.modes.suspend();
        c.environment.dispose();
        c.balls.clear();
        c.projectiles.clear();
        c.world.scene.background = null;
        c.world.scene.fog = null;
        c.world.renderer.setClearColor(0, 0);
        this.ready = false;
        this.pending = false;
        this.anchor?.delete();
        this.anchor = undefined;
        c.ui.close();
        const session = this.session = c.world.renderer.xr.getSession()!;
        this.hitSource?.cancel();
        this.hitSource = undefined;
        this.support.hands = Array.from(session.inputSources).some(s => !!s.hand);
        this.support.hitTest = typeof session.requestHitTestSource === 'function';
        this.support.anchors = 'createAnchor' in XRFrame.prototype;
        this.support.environmentRaycast = false;
        this.manual = !this.support.hitTest;
        if (this.support.hitTest)
            try {
                const viewer = await session.requestReferenceSpace('viewer');
                this.hitSource = await session.requestHitTestSource!({ space: viewer }) || undefined;
                this.support.environmentRaycast = !!this.hitSource;
                this.manual = !this.hitSource;
            }
            catch {
                this.manual = true;
            }
        c.events.emit('notice', { ar: 'وجّه المؤشر إلى أرض أو طاولة أو جدار، ثم اضغط الزناد الأيمن للتثبيت. A يبدّل الحجم، B للتعيين اليدوي.', en: 'Aim at a floor, table or wall; right trigger confirms. A changes size; B toggles manual placement.' });
    }
    frame(raw: XRFrame, reference: XRReferenceSpace) {
        if (this.c.xr !== 'immersive-ar')
            return;
        const frame = raw as RoomFrame;
        if (this.c.placing) {
            this.lastHit = undefined;
            if (this.hitSource && !this.manual) {
                const hit = frame.getHitTestResults(this.hitSource)[0], pose = hit?.getPose(reference);
                if (pose) {
                    this.previewPoint.copy(pose.transform.position);
                    this.q.copy(pose.transform.orientation);
                    this.normal.copy(this.up).applyQuaternion(this.q);
                    this.kind = Math.abs(this.normal.y) < 0.55 ? 'wall' : this.kind === 'wall' ? 'floor' : this.kind;
                    this.lastHit = hit;
                    this.ready = true;
                }
                else
                    this.ready = false;
            }
            if (this.manual && this.c.input.right.tracked) {
                this.previewPoint.copy(this.c.input.right.ray).addScaledVector(this.c.input.right.direction, this.kind === 'table' ? 0.8 : 1.6);
                if (this.kind === 'floor')
                    this.previewPoint.y = 0;
                this.q.identity();
                this.ready = true;
            }
            this.preview.visible = this.ready && this.c.focused;
            this.preview.position.copy(this.previewPoint);
            this.preview.quaternion.copy(this.q).multiply(this.rotation);
            if (this.pending && this.ready) {
                this.pending = false;
                this.commit(frame, reference);
            }
        }
        else {
            this.preview.visible = false;
            if (this.anchor && frame.trackedAnchors?.has(this.anchor)) {
                const pose = frame.getPose(this.anchor.anchorSpace, reference);
                if (pose) {
                    this.normal.copy(pose.transform.position);
                    if (this.normal.distanceToSquared(this.c.space.origin) > 0.0025) {
                        this.c.space.origin.copy(this.normal);
                        this.c.environment.rebuild();
                        this.c.modes.activate(this.c.mode);
                    }
                }
            }
            if (frame.detectedPlanes) {
                this.support.planes = true;
                this.syncPlanes(frame, reference);
            }
        }
    }
    private rotation = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    confirm() { if (this.ready)
        this.pending = true; }
    private commit(frame: RoomFrame, reference: XRReferenceSpace) {
        const c = this.c;
        c.space.origin.copy(this.previewPoint);
        c.space.scale = this.kind === 'table' ? 0.22 : this.kind === 'wall' ? 0.55 : 1;
        this.normal.set(0, 0, -1).applyQuaternion(c.input.orientation);
        c.space.rotation.setFromAxisAngle(this.up, Math.atan2(-this.normal.x, -this.normal.z));
        // Hit location is the centre of the game surface; the local player is not rescaled or translated.
        this.normal.set(0, 0, 3 * c.space.scale).applyQuaternion(c.space.rotation);
        c.space.origin.add(this.normal);
        c.placing = false;
        this.preview.visible = false;
        c.environment.rebuild();
        c.modes.activate(c.mode);
        if (frame.createAnchor) {
            const pose = new XRRigidTransform({ x: c.space.origin.x, y: c.space.origin.y, z: c.space.origin.z });
            const active = this.session;
            void frame.createAnchor(pose, reference).then(anchor => { if (this.session !== active || c.placing)
                anchor.delete();
            else
                this.anchor = anchor; }).catch(() => { this.support.anchors = false; });
        }
    }
    private syncPlanes(frame: RoomFrame, reference: XRReferenceSpace) {
        const planes = frame.detectedPlanes!;
        for (const [plane, item] of this.room)
            if (!planes.has(plane)) {
                this.c.bodies.remove(item.entity);
                this.room.delete(plane);
            }
        for (const plane of planes) {
            if (plane.polygon.length < 3)
                continue;
            const old = this.room.get(plane);
            if (old?.changed === plane.lastChangedTime)
                continue;
            if (!old && this.room.size >= LIMITS.roomPlanes)
                break;
            const pose = frame.getPose(plane.planeSpace, reference);
            if (!pose)
                continue;
            let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
            for (const p of plane.polygon) {
                minX = Math.min(minX, p.x);
                maxX = Math.max(maxX, p.x);
                minZ = Math.min(minZ, p.z);
                maxZ = Math.max(maxZ, p.z);
            }
            const width = Math.min(12, maxX - minX), depth = Math.min(12, maxZ - minZ);
            if (width < 0.08 || depth < 0.08)
                continue;
            if (old)
                this.c.bodies.remove(old.entity);
            const mesh = new Mesh(this.c.resources.box, this.c.resources.hiddenMaterial);
            this.matrix.fromArray(pose.transform.matrix);
            mesh.position.set((minX + maxX) / 2, -0.012, (minZ + maxZ) / 2).applyMatrix4(this.matrix);
            mesh.quaternion.copy(pose.transform.orientation);
            mesh.scale.set(width, 0.024, depth);
            const entity = this.c.bodies.add(mesh, { shape: 'Box', dimensions: [width, 0.024, depth], friction: 0.65 });
            this.room.set(plane, { mesh, entity, changed: plane.lastChangedTime });
        }
    }
    private clearRoom() { for (const r of this.room.values())
        this.c.bodies.remove(r.entity); this.room.clear(); }
    end() { this.session = undefined; this.hitSource?.cancel(); this.hitSource = undefined; this.anchor?.delete(); this.anchor = undefined; this.clearRoom(); this.preview.visible = false; this.c.placing = false; }
    update() { const c = this.c; if (!c.focused || !c.tracked || !c.placing)
        return; if (c.input.right.primaryDown) {
        this.kind = this.kind === 'table' ? 'floor' : 'table';
        c.events.emit('notice', { ar: this.kind === 'table' ? 'مجسّم فوق الطاولة' : 'حجم أرضي', en: this.kind === 'table' ? 'Tabletop scale' : 'Floor scale' });
    } if (c.input.right.secondaryDown)
        this.manual = !this.manual; if (c.input.right.triggerDown)
        this.confirm(); }
}
export class MRPlacementSystem extends createSystem({}) {
    update() { contextOf(this.world).mr.update(); }
}
