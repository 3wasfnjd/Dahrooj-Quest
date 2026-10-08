import type { GameContext } from '../../core/context';
import { ReferenceMode } from '../reference-mode';
export class GoalMode extends ReferenceMode { constructor(c: GameContext) { super(c, 'goal'); } }
