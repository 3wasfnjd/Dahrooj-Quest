import { describe, expect, it } from 'vitest';
import { SummitSimulation, SUMMIT } from '../../src/modes/summit/simulation';
describe('Summit fixed-step rules', () => {
    it('has all regions, 37 ascents, checkpoints, platform and enemy variants', () => { const s = new SummitSimulation(); expect(s.platforms).toHaveLength(38); expect(s.platforms.at(-1)!.y).toBeCloseTo(SUMMIT.top); expect(new Set(s.platforms.map(p => p.kind)).size).toBe(4); expect(new Set(s.enemies.map(e => e.type)).size).toBe(3); expect(s.icicles.length).toBeGreaterThan(0); for (let i = 1; i < s.platforms.length; i++)
        expect(s.platforms[i].y - s.platforms[i - 1].y).toBeLessThan(SUMMIT.jump ** 2 / (2 * SUMMIT.gravity)); });
    it('does not depend on rendering frequency', () => { const run = (hz: number) => { const s = new SummitSimulation(); s.jump(); for (let i = 0; i < hz; i++)
        s.update(1 / hz, 0.3); return [s.x, s.y, s.vx, s.vy]; }; const a = run(60), b = run(90); a.forEach((n, i) => expect(n).toBeCloseTo(b[i], 7)); });
    it('bounds projectiles and enforces invulnerability and checkpoint recovery', () => { const s = new SummitSimulation(); s.damage(); s.damage(); expect(s.hearts).toBe(2); for (let i = 0; i < 30; i++)
        s.shoot(); expect(s.shots.filter(p => p.life > 0)).toHaveLength(1); s.checkpoint = 18; s.recover(); expect(s.hearts).toBe(3); expect(s.y).toBeGreaterThan(s.platforms[18].y); expect(s.invincible).toBe(1.6); });
    it('rebuilds crumbling platforms after the cooldown', () => { const s = new SummitSimulation(), p = s.platforms.find(p => p.kind === 'crumble')!; p.timer = 0.59; s.update(0.05, 0); expect(p.broken).toBeGreaterThan(2.9); for (let i = 0; i < 200; i++)
        s.update(1 / 60, 0); expect(p.broken).toBeLessThanOrEqual(0); });
});
it('can traverse all four regions and reach the summit using movement, jump and shooting only', () => {
    const s = new SummitSimulation(), regions = new Set<string>();
    let target = 1;
    for (let frame = 0; frame < 60 * 180 && !s.won; frame++) {
        regions.add(s.region);
        if (s.grounded) {
            const floor = s.platforms.findIndex(p => Math.abs(s.y - SUMMIT.radius - p.y) < 0.025);
            if (floor >= 0)
                target = Math.min(37, floor + 1);
        }
        const p = s.platforms[target], error = p.x - s.x;
        if (s.grounded && Math.abs(error) < 0.46)
            s.jump();
        s.shoot();
        s.update(1 / 60, Math.max(-1, Math.min(1, error * 7 - s.vx * 1.6)));
    }
    expect([...regions].sort()).toEqual(['caves', 'cliffs', 'meadow', 'snow']);
    expect(s.won).toBe(true);
    expect(s.checkpoint).toBe(37);
});
