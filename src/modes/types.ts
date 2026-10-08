import type { Entity, Mesh, Object3D, Vector3 } from '@iwsdk/core';
import type { ModeId } from '../core/config';
export interface Hit {
    point: Vector3;
    direction: Vector3;
    power: number;
    curved: boolean;
    throwId: number;
    projectile: boolean;
}
export interface Target {
    object: Object3D;
    radius: number;
    body?: Entity;
    hit?: (hit: Hit) => void;
    cooldown: number;
}
export interface GameMode {
    readonly id: ModeId;
    update(dt: number): void;
    dispose(): void;
    onThrow?(id: number): void;
    jump?(): void;
    shoot?(): void;
    readonly score: number;
    readonly detail?: string;
}
export interface Solid {
    mesh: Mesh;
    entity: Entity;
}
