import type { GameContext } from '../core/context';
import type { ModeId } from '../core/config';
export function attachDevelopment(c: GameContext) { (window as unknown as {
    __DAHROOJ_TEST__: unknown;
}).__DAHROOJ_TEST__ = { context: c, mode: (id: ModeId) => c.modes.activate(id), metrics: () => c.performance.report(), ready: true }; }
