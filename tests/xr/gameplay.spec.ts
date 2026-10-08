import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import type { GameContext } from '../../src/core/context';
import type { ModeId } from '../../src/core/config';
import type { XRDevice } from 'iwer';
declare global {
    interface Window {
        __DAHROOJ_TEST__: {
            context: GameContext;
            ready: boolean;
            releaseSpeeds?: number[];
            fired?: {
                type: string;
                speed: number;
                dynamic: boolean;
            }[];
        };
        IWER_DEVICE: XRDevice;
    }
}
test('Quest VR session, nine modes, Havok, bounded pools, focus and controller input', async ({ page }, info) => {
    const errors: string[] = [], external: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error')
        errors.push(m.text().slice(0, 600)); });
    page.on('request', r => { if (/^https?:/.test(r.url()) && !r.url().startsWith('http://127.0.0.1:5173'))
        external.push(r.url()); });
    await page.goto('/');
    await page.waitForFunction(() => !!window.__DAHROOJ_TEST__?.ready);
    await expect(page.locator('#enter-vr')).toBeEnabled();
    await page.screenshot({ path: info.outputPath('gate.png') });
    await page.locator('#enter-vr').click();
    await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.xr === 'immersive-vr' && window.__DAHROOJ_TEST__.context.tracked);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: info.outputPath('goal-vr.png') });
    const samples: unknown[] = [];
    for (const mode of ['goal', 'hoop', 'window', 'cans', 'bowling', 'bricks', 'fair', 'summit', 'rain'] as ModeId[]) {
        await page.evaluate(id => window.__DAHROOJ_TEST__.context.modes.activate(id), mode);
        await page.waitForTimeout(400);
        const sample = await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; return { mode: c.modes.current?.id, bodies: c.bodies.entities.size, entities: c.performance.report().currentEntities, score: c.modes.current?.score }; });
        expect(sample.mode).toBe(mode);
        expect(sample.bodies).toBeLessThan(100);
        samples.push(sample);
    }
    await page.evaluate(() => window.__DAHROOJ_TEST__.context.modes.activate('cans'));
    await page.waitForTimeout(1800);
    const gravity = await page.evaluate(async () => { const c = window.__DAHROOJ_TEST__.context; const p = c.input.head.clone().set(0.6, 2, -1); const b = c.balls.acquire(p, 'fabric')!; const before = b.root.position.y; await new Promise(r => setTimeout(r, 700)); return { before, after: b.root.position.y, velocity: b.velocity.y }; });
    expect(gravity.after).toBeLessThan(gravity.before - 0.2);
    const limits = await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.balls.clear(); for (let i = 0; i < 60; i++)
        c.balls.acquire(c.input.head, 'fabric', true); const balls = c.balls.active; for (let i = 0; i < 70; i++)
        c.projectiles.fire('bolt', c.input.left.position, c.input.left.direction); const shots = c.projectiles.active; c.balls.clear(); c.projectiles.clear(); return { balls, shots }; });
    expect(limits).toEqual({ balls: 16, shots: 32 });
    await page.evaluate(() => { window.IWER_DEVICE.updateVisibilityState('visible-blurred'); });
    await page.waitForFunction(() => !window.__DAHROOJ_TEST__.context.focused);
    const paused = await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; return { paused: c.bodies.system.isPaused, controllerVisible: c.world.input.xr.visualAdapters.controller.right.visual?.model.visible ?? false }; });
    expect(paused).toEqual({ paused: true, controllerVisible: false });
    await page.evaluate(() => window.IWER_DEVICE.updateVisibilityState('visible'));
    await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.focused);
    await page.evaluate(() => { const d = window.IWER_DEVICE; d.controllers.right!.updateButtonValue('squeeze', 1); });
    await page.waitForTimeout(200);
    const held = await page.evaluate(() => window.__DAHROOJ_TEST__.context.balls.slots.some(b => b.active && b.held));
    expect(held).toBe(true);
    await page.evaluate(() => window.IWER_DEVICE.controllers.right!.updateButtonValue('squeeze', 0));
    await page.waitForTimeout(250);
    expect(await page.evaluate(() => window.__DAHROOJ_TEST__.context.balls.slots.some(b => b.active && !b.held))).toBe(true);
    for (const style of ['jelly', 'fabric', 'clay', 'fur', 'bubble'] as const) {
        await page.evaluate(style => { const c = window.__DAHROOJ_TEST__.context; c.balls.clear(); c.balls.acquire(c.input.head.clone().add(c.input.right.direction.clone().multiplyScalar(1)), style, true); }, style);
        await page.waitForTimeout(150);
    }
    await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.store.data.language = 'ar'; c.ui.show('challenges'); });
    await page.screenshot({ path: info.outputPath('arabic-challenges.png') });
    await mkdir('reports', { recursive: true });
    await writeFile('reports/mode-resources.json', JSON.stringify(samples, null, 2));
    await writeFile('reports/simulator-performance.json', await page.evaluate(() => JSON.stringify(window.__DAHROOJ_TEST__.context.performance.report(), null, 2)));
    await info.attach('mode-resources', { body: JSON.stringify(samples, null, 2), contentType: 'application/json' });
    await info.attach('simulator-performance-NOT-hardware', { body: await page.evaluate(() => JSON.stringify(window.__DAHROOJ_TEST__.context.performance.report(), null, 2)), contentType: 'application/json' });
    await info.attach('console-errors', { body: JSON.stringify(errors), contentType: 'application/json' });
    expect(external).toEqual([]);
    expect(errors).toEqual([]);
});
test('immersive-ar preserves passthrough and requires confirmed placement', async ({ page }, info) => { await page.goto('/'); await page.waitForFunction(() => !!window.__DAHROOJ_TEST__?.ready); await page.locator('#enter-ar').click(); await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.xr === 'immersive-ar'); expect(await page.evaluate(() => window.__DAHROOJ_TEST__.context.placing)).toBe(true); expect(await page.evaluate(() => window.__DAHROOJ_TEST__.context.world.scene.background)).toBeNull(); await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.mr.manual = true; c.mr.kind = 'table'; }); await page.waitForTimeout(200); await page.evaluate(() => window.__DAHROOJ_TEST__.context.mr.confirm()); await page.waitForFunction(() => !window.__DAHROOJ_TEST__.context.placing); expect(await page.evaluate(() => window.__DAHROOJ_TEST__.context.space.scale)).toBe(0.22); await page.screenshot({ path: info.outputPath('mr-tabletop.png') }); await page.evaluate(() => window.__DAHROOJ_TEST__.context.mr.begin()); await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.placing); expect(await page.evaluate(() => window.__DAHROOJ_TEST__.context.modes.current)).toBeUndefined(); });
test('charged and slingshot release, blaster variants and Rain pop interaction', async ({ page }) => {
    await page.goto('/');
    await page.waitForFunction(() => !!window.__DAHROOJ_TEST__?.ready);
    await page.locator('#enter-vr').click();
    await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.tracked && window.__DAHROOJ_TEST__.context.xr === 'immersive-vr');
    await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.store.data.throwType = 'charged'; window.__DAHROOJ_TEST__.releaseSpeeds = []; c.events.on('throw', e => { const b = c.balls.slots.find(b => b.id === e.id); if (b)
        window.__DAHROOJ_TEST__.releaseSpeeds!.push(b.velocity.length()); }); window.IWER_DEVICE.controllers.right!.position.set(0.3, 1.4, -0.3); window.IWER_DEVICE.controllers.right!.updateButtonValue('squeeze', 1); });
    await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.balls.slots.some(b => b.held));
    await page.evaluate(() => window.IWER_DEVICE.controllers.right!.updateButtonValue('trigger', 1));
    await page.waitForTimeout(500);
    await page.evaluate(() => window.IWER_DEVICE.controllers.right!.updateButtonValue('trigger', 0));
    await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.balls.slots.some(b => b.active && !b.held));
    expect(await page.evaluate(() => window.__DAHROOJ_TEST__.releaseSpeeds![0])).toBeGreaterThan(3);
    await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.balls.clear(); window.IWER_DEVICE.controllers.right!.updateButtonValue('squeeze', 0); c.store.data.throwType = 'slingshot'; });
    await page.waitForTimeout(120);
    await page.evaluate(() => { const d = window.IWER_DEVICE; d.controllers.left!.position.set(0.3, 1.4, -0.8); d.controllers.right!.position.set(0.3, 1.4, -0.3); d.controllers.left!.updateButtonValue('squeeze', 1); d.controllers.right!.updateButtonValue('squeeze', 1); });
    await page.waitForTimeout(200);
    await page.evaluate(() => window.IWER_DEVICE.controllers.right!.updateButtonValue('squeeze', 0));
    await page.waitForFunction(() => window.__DAHROOJ_TEST__.context.balls.slots.some(b => b.active && !b.held));
    expect(await page.evaluate(() => window.__DAHROOJ_TEST__.releaseSpeeds![1])).toBeGreaterThan(8);
    await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.balls.clear(); window.IWER_DEVICE.controllers.left!.updateButtonValue('squeeze', 0); window.__DAHROOJ_TEST__.fired = []; c.events.on('projectile', type => { const s = c.projectiles.slots.find(s => s.active && s.type === type)!; window.__DAHROOJ_TEST__.fired!.push({ type, speed: s.v.length(), dynamic: c.bodies.entities.has(s.entity) }); }); });
    for (const shot of ['bolt', 'mini', 'bubble', 'firework'] as const) {
        await page.evaluate(shot => { const c = window.__DAHROOJ_TEST__.context; c.projectiles.clear(); c.store.data.shot = shot; window.IWER_DEVICE.controllers.left!.updateButtonValue('trigger', 1); }, shot);
        await page.waitForFunction(shot => window.__DAHROOJ_TEST__.fired!.some(s => s.type === shot), shot);
        const launched = await page.evaluate(shot => window.__DAHROOJ_TEST__.fired!.find(s => s.type === shot)!, shot);
        expect(launched.speed).toBeGreaterThan(0);
        expect(launched.dynamic).toBe(shot === 'mini');
        await page.evaluate(() => window.IWER_DEVICE.controllers.left!.updateButtonValue('trigger', 0));
    }
    const pop = await page.evaluate(() => { const c = window.__DAHROOJ_TEST__.context; c.projectiles.clear(); c.modes.activate('rain'); const p = c.input.head.clone().set(0, 1.5, -1); const b = c.balls.acquire(p, 'fabric')!; const before = c.store.data.challenges.pop20 || 0; c.modes.popCharacters(p.clone().set(0, 1.5, 0), p.clone().set(0, 1.5, -2), 0.02); return { active: b.active, before, after: c.store.data.challenges.pop20 }; });
    expect(pop.active).toBe(false);
    expect(pop.after).toBe(pop.before + 1);
});
