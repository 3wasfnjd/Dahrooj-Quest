import type { GameContext } from '../../core/context';
import { ReferenceMode } from '../reference-mode';
export class BowlingMode extends ReferenceMode { constructor(c: GameContext) { super(c, 'bowling'); } }
