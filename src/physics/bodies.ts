import { PhysicsBody, PhysicsShape, PhysicsManipulation, PhysicsState, PhysicsShapeType, PhysicsSystem, Quaternion, Vector3 } from '@iwsdk/core';
import type { Entity, Object3D, World } from '@iwsdk/core';
export interface BodyOptions {
    shape: 'Sphere' | 'Box' | 'Cylinder' | 'Capsules' | 'ConvexHull';
    dimensions: [
        number,
        number,
        number
    ];
    dynamic?: boolean;
    kinematic?: boolean;
    mass?: number;
    restitution?: number;
    friction?: number;
}
export class Bodies {
    readonly system: PhysicsSystem;
    readonly entities = new Set<Entity>();
    private q = new Quaternion();
    constructor(readonly world: World) { this.system = world.getSystem(PhysicsSystem)!; }
    add(object: Object3D, opt: BodyOptions, existing?: Entity) {
        const e = existing || this.world.createTransformEntity(object);
        const d = opt.dimensions;
        const volume = opt.shape === 'Sphere' ? 4 / 3 * Math.PI * d[0] ** 3 : opt.shape === 'Cylinder' || opt.shape === 'Capsules' ? Math.PI * d[0] ** 2 * d[1] : Math.max(1e-5, d[0] * d[1] * d[2]);
        e.addComponent(PhysicsShape, { shape: PhysicsShapeType[opt.shape], dimensions: d, density: (opt.mass ?? 1) / Math.max(1e-6, volume), restitution: opt.restitution ?? 0.25, friction: opt.friction ?? 0.6 });
        e.addComponent(PhysicsBody, { state: opt.kinematic ? PhysicsState.Kinematic : opt.dynamic ? PhysicsState.Dynamic : PhysicsState.Static, linearDamping: opt.dynamic ? 0.06 : 0, angularDamping: opt.dynamic ? 0.14 : 0 });
        this.entities.add(e);
        return e;
    }
    detach(e: Entity) { if (e.hasComponent(PhysicsManipulation))
        e.removeComponent(PhysicsManipulation); if (e.hasComponent(PhysicsBody))
        e.removeComponent(PhysicsBody); if (e.hasComponent(PhysicsShape))
        e.removeComponent(PhysicsShape); this.entities.delete(e); }
    remove(e: Entity) { this.detach(e); e.dispose({ disposeResources: false }); }
    pose(e: Entity, p: Vector3, q: Quaternion = this.q, resetVelocity = false) { this.system.setBodyTransform(e, { position: p, quaternion: q }, { resetVelocity }); }
    velocity(e: Entity, out: Vector3) { if (!e.hasComponent(PhysicsBody))
        return out.set(0, 0, 0); const v = e.getVectorView(PhysicsBody, '_linearVelocity'); return out.set(v[0], v[1], v[2]); }
    angular(e: Entity, out: Vector3) { const v = e.getVectorView(PhysicsBody, '_angularVelocity'); return out.set(v[0], v[1], v[2]); }
    manipulate(e: Entity, velocity?: Vector3, angular?: Vector3, impulse?: Vector3) {
        if (!e.hasComponent(PhysicsManipulation))
            e.addComponent(PhysicsManipulation);
        if (velocity) {
            const v = e.getVectorView(PhysicsManipulation, 'linearVelocity');
            v[0] = velocity.x;
            v[1] = velocity.y;
            v[2] = velocity.z;
        }
        if (angular) {
            const v = e.getVectorView(PhysicsManipulation, 'angularVelocity');
            v[0] = angular.x;
            v[1] = angular.y;
            v[2] = angular.z;
        }
        if (impulse) {
            const v = e.getVectorView(PhysicsManipulation, 'force');
            v[0] += impulse.x;
            v[1] += impulse.y;
            v[2] += impulse.z;
        }
    }
    pause(on: boolean) { this.system.isPaused = on; }
}
