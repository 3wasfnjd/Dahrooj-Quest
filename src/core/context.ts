import type { Quality } from '../performance/quality';
import type { World } from '@iwsdk/core';
import type { SaveStore } from '../save/store';
import type { Bodies } from '../physics/bodies';
import type { Resources } from '../rendering/resources';
import type { Events } from './events';
import type { PlaySpace } from './space';
import type { ModeId } from './config';
import type { BallPool } from '../character/ball-pool';
import type { ModeLifecycle } from '../modes/lifecycle';
import type { InputState } from '../input/controller-system';
import type { ParticlePool } from '../rendering/particles';
import type { SpatialUI } from '../ui/spatial-ui';
import type { Environment } from '../world/environment';
import type { AudioBus } from '../audio/audio';
import type { MRPlacement } from '../mr/placement';
import type { Projectiles } from '../projectiles/projectiles';
import type { PerformanceMonitor } from '../performance/monitor';
export interface GameContext {
    world: World;
    store: SaveStore;
    bodies: Bodies;
    resources: Resources;
    events: Events;
    space: PlaySpace;
    balls: BallPool;
    modes: ModeLifecycle;
    input: InputState;
    particles: ParticlePool;
    ui: SpatialUI;
    environment: Environment;
    audio: AudioBus;
    mr: MRPlacement;
    projectiles: Projectiles;
    xr: 'immersive-vr' | 'immersive-ar' | null;
    focused: boolean;
    tracked: boolean;
    placing: boolean;
    mode: ModeId;
    elapsed: number;
    generation: number;
    performance: PerformanceMonitor;
    quality: Quality;
}
const contexts = new WeakMap<World, GameContext>();
export function attachContext(world: World, context: GameContext) { contexts.set(world, context); }
export function contextOf(world: World) { const c = contexts.get(world); if (!c)
    throw new Error('Game context not initialized'); return c; }
export const playing = (c: GameContext) => !!c.xr && c.focused && c.tracked && !c.placing && !c.ui.open;
