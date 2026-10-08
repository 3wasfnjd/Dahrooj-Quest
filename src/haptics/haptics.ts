import type { HandState } from '../input/controller-system';
const last = new WeakMap<HandState, number>();
export function pulse(hand: HandState, strength = 0.35, duration = 35) { const now = performance.now(); if (now - (last.get(hand) || 0) < 45)
    return; last.set(hand, now); const actuator = hand.source?.gamepad?.hapticActuators?.[0]; if (actuator)
    void actuator.pulse(Math.max(0, Math.min(1, strength)), Math.min(120, duration)).catch(() => { }); }
