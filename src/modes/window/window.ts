import type { GameContext } from '../../core/context';
import { ReferenceMode } from '../reference-mode';
export class WindowMode extends ReferenceMode { constructor(c: GameContext) { super(c, 'window'); } }
