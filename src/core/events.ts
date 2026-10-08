import type { Vector3 } from '@iwsdk/core';
import type { ModeId, ShotId } from './config';
export interface GameEvents {
    score: {
        mode: ModeId;
        points: number;
        curved: boolean;
    };
    notice: {
        ar: string;
        en: string;
    };
    impact: {
        position: Vector3;
        power: number;
        kind: 'impact' | 'can' | 'bowling' | 'pop' | 'bell' | 'explosion' | 'water' | 'shot';
    };
    throw: {
        id: number;
        curved: boolean;
    };
    mode: ModeId;
    projectile: ShotId;
}
export class Events {
    private listeners = new Map<keyof GameEvents, Set<(value: never) => void>>();
    on<K extends keyof GameEvents>(key: K, fn: (data: GameEvents[K]) => void) { let set = this.listeners.get(key); if (!set)
        this.listeners.set(key, set = new Set()); set.add(fn as (v: never) => void); return () => set!.delete(fn as (v: never) => void); }
    emit<K extends keyof GameEvents>(key: K, value: GameEvents[K]) { this.listeners.get(key)?.forEach(fn => fn(value as never)); }
}
