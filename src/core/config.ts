export const MODES = ['goal', 'hoop', 'window', 'cans', 'bowling', 'bricks', 'fair', 'summit', 'rain'] as const;
export type ModeId = typeof MODES[number];
export const STYLES = ['jelly', 'fabric', 'clay', 'fur', 'bubble'] as const;
export type StyleId = typeof STYLES[number];
export const THROWS = ['physical', 'charged', 'slingshot'] as const;
export type ThrowId = typeof THROWS[number];
export const SHOTS = ['bolt', 'mini', 'bubble', 'firework'] as const;
export type ShotId = typeof SHOTS[number];
export const ACCESSORIES = ['', 'party', 'glasses', 'cap', 'flower', 'crown'] as const;
export type AccessoryId = typeof ACCESSORIES[number];
export type Language = 'ar' | 'en';
export type TimeOfDay = 'day' | 'dusk' | 'night' | 'dawn' | 'auto';
export type Weather = 'clear' | 'rain' | 'snow' | 'auto';
export const LIMITS = Object.freeze({ balls: 16, projectiles: 32, rain: 120, rainBodies: 8, debris: 24, sparks: 256, roomPlanes: 24 });
export const PHYSICS = Object.freeze({ hz: 60, gravity: 9.81, ballRadius: 0.13, ballMass: 0.38, maxThrowSpeed: 18, maxSpin: 45, maxCurveAcceleration: 3.2, restitution: 0.48, friction: 0.55 });
export const clamp = (n: number, a: number, b: number) => Math.max(a, Math.min(b, n));
export function seeded(seed = 42) { return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }; }
