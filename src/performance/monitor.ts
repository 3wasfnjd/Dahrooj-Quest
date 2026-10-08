import { createSystem, Transform } from '@iwsdk/core';
import { contextOf } from '../core/context';
import type { GameContext } from '../core/context';
export class PerformanceMonitor {
    private times = new Float32Array(7200);
    private index = 0;
    private count = 0;
    private last = 0;
    private start = performance.now();
    private peakBodies = 0;
    private peakCalls = 0;
    private peakTriangles = 0;
    private longFrames = 0;
    private enabled = false;
    private entityQuery;
    constructor(readonly c: GameContext) { this.entityQuery = c.world.queryManager.registerQuery({ required: [Transform] }); }
    frame() { const now = performance.now(), active = !!this.c.xr && this.c.focused && this.c.tracked && !this.c.ui.open && !this.c.placing; if (!active) {
        this.last = 0;
        return;
    } if (this.last) {
        const dt = now - this.last;
        if (dt > 25)
            this.longFrames++;
        this.times[this.index] = dt;
        this.index = (this.index + 1) % this.times.length;
        this.count = Math.min(this.count + 1, this.times.length);
    } this.last = now; const info = this.c.world.renderer.info; this.peakBodies = Math.max(this.peakBodies, this.c.bodies.entities.size); this.peakCalls = Math.max(this.peakCalls, info.render.calls); this.peakTriangles = Math.max(this.peakTriangles, info.render.triangles); }
    report() { const sorted = Array.from(this.times.subarray(0, this.count)).sort((a, b) => a - b), sum = sorted.reduce((a, b) => a + b, 0), memory = (performance as Performance & {
        memory?: {
            usedJSHeapSize: number;
            totalJSHeapSize: number;
        };
    }).memory; const info = this.c.world.renderer.info; return { schema: 1, date: new Date().toISOString(), mode: this.c.mode, session: this.c.xr, samples: this.count, measuredSeconds: sum / 1000, meanFPS: sum ? this.count * 1000 / sum : null, frameMs: { mean: this.count ? sum / this.count : null, p50: sorted[Math.floor(this.count * 0.5)] ?? null, p95: sorted[Math.floor(this.count * 0.95)] ?? null, p99: sorted[Math.floor(this.count * 0.99)] ?? null }, peakDrawCalls: this.peakCalls, peakTriangles: this.peakTriangles, currentEntities: this.entityQuery.entities.size, peakPhysicsBodies: this.peakBodies, activeBalls: this.c.balls.active, activeProjectiles: this.c.projectiles.active, heapBytes: memory?.usedJSHeapSize ?? null, textureCount: info.memory.textures, geometryCount: info.memory.geometries, estimatedUITextureBytes: (1200 * 1000 + 1200 * 210) * 4 * 4 / 3, framesOver25ms: this.longFrames, gcPauses: null, timeSinceAppStartMs: performance.now() - this.start, renderer: 'WebGL2', physicsHz: 60, qualityLevel: this.c.quality.level, initialLoadMs: performance.getEntriesByType('navigation')[0]?.duration || null, evidence: import.meta.env.DEV ? 'Development or IWER. Not hardware proof.' : 'Exported by running build. Attach headset model, OS, browser, mode and test duration; environment is not inferred from user agent.' }; }
    export() { const blob = new Blob([JSON.stringify(this.report(), null, 2)], { type: 'application/json' }), a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = `dahrooj-performance-${Date.now()}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 1000); }
}
export class PerformanceMonitorSystem extends createSystem({}) {
    update() { contextOf(this.world).performance.frame(); }
}
