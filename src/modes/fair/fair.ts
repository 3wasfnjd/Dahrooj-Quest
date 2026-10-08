import type { GameContext } from '../../core/context';
import { ReferenceMode } from '../reference-mode';
export class FairMode extends ReferenceMode { constructor(c: GameContext) { super(c, 'fair'); } }
