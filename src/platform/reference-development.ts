import type {CompleteGame} from '../reference/complete-game.js';
export function attachReferenceDevelopment(game:CompleteGame){(window as unknown as {__DAHROOJ_REFERENCE__:unknown}).__DAHROOJ_REFERENCE__={game,ready:true};}
