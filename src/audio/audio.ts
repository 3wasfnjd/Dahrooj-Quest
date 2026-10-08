import { createSystem, Vector3 } from '@iwsdk/core';
import { contextOf } from '../core/context';
import type { GameContext } from '../core/context';
import type { GameEvents } from '../core/events';
type Sound = GameEvents['impact']['kind'] | 'bird' | 'cricket' | 'frog' | 'ui';
export class AudioBus {
    private context?: AudioContext;
    private groups = new Map<string, GainNode>();
    private buffers = new Map<Sound, AudioBuffer>();
    private voices = 0;
    private ambienceAt = 0;
    private lastSound = 0;
    private music?: AudioBufferSourceNode;
    private ambience?: AudioBufferSourceNode;
    private forward = new Vector3();
    private up = new Vector3();
    private active = false;
    constructor(readonly c: GameContext) { c.events.on('impact', e => this.play(e.kind, e.power, e.position)); }
    unlock() { if (!this.context) {
        this.context = new AudioContext({ latencyHint: 'interactive' });
        const master = this.context.createGain();
        master.connect(this.context.destination);
        this.groups.set('master', master);
        for (const key of ['music', 'sfx', 'ambience', 'ui']) {
            const gain = this.context.createGain();
            gain.connect(master);
            this.groups.set(key, gain);
        }
        this.makeSounds();
        this.levels();
        void this.loadMusic();
    } void this.context.resume(); }
    levels() { if (!this.context)
        return; for (const key of ['master', 'music', 'sfx', 'ambience', 'ui'] as const)
        this.groups.get(key)!.gain.setTargetAtTime(this.c.store.data[key], this.context.currentTime, 0.03); }
    focus(on: boolean) { this.active = on; if (!this.context)
        return; if (on)
        void this.context.resume().catch(() => { });
    else
        void this.context.suspend().catch(() => { }); }
    private makeSounds() {
        const ctx = this.context!, specs: [
            Sound,
            number,
            number,
            number
        ][] = [['impact', 170, 0.16, 0.35], ['can', 630, 0.22, 0.5], ['bowling', 270, 0.35, 0.75], ['pop', 560, 0.12, 0.25], ['bell', 1320, 1, 0.02], ['explosion', 85, 0.65, 0.9], ['water', 360, 0.4, 0.85], ['shot', 950, 0.09, 0.2], ['bird', 2300, 0.32, 0], ['cricket', 4200, 0.28, 0], ['frog', 220, 0.25, 0.15], ['ui', 780, 0.075, 0]];
        for (const [id, frequency, seconds, noise] of specs) {
            const buffer = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * seconds), ctx.sampleRate), data = buffer.getChannelData(0);
            let phase = 0;
            for (let i = 0; i < data.length; i++) {
                const t = i / ctx.sampleRate, decay = Math.exp(-t * (id === 'bell' ? 5 : 15) / Math.max(0.4, seconds * 3));
                const f = frequency * (id === 'bird' ? 1 + Math.sin(t * 32) * 0.18 : id === 'shot' ? Math.exp(-t * 12) : 1);
                phase += f * Math.PI * 2 / ctx.sampleRate;
                data[i] = ((Math.sin(phase) + Math.sin(phase * 2.76) * (id === 'bell' ? 0.3 : 0.05)) * (1 - noise) + (Math.random() * 2 - 1) * noise) * decay * Math.min(1, t * 250) * 0.45;
            }
            this.buffers.set(id, buffer);
        }
        const rain = ctx.createBuffer(1, ctx.sampleRate * 3, ctx.sampleRate), data = rain.getChannelData(0);
        let previous = 0;
        for (let i = 0; i < data.length; i++) {
            previous = (previous + (Math.random() * 2 - 1) * 0.035) / 1.04;
            data[i] = previous;
        }
        const source = ctx.createBufferSource();
        source.buffer = rain;
        source.loop = true;
        const gain = ctx.createGain();
        gain.gain.value = 0;
        source.connect(gain).connect(this.groups.get('ambience')!);
        this.groups.set('rain', gain);
        source.start();
        this.ambience = source;
    }
    private async loadMusic() { try {
        const response = await fetch('/assets/audio/dahrooj-theme.ogg');
        if (!response.ok)
            throw new Error('music response');
        const buffer = await this.context!.decodeAudioData(await response.arrayBuffer());
        const source = this.context!.createBufferSource();
        source.buffer = buffer;
        source.loop = true;
        source.connect(this.groups.get('music')!);
        source.start();
        this.music = source;
    }
    catch {
        this.c.events.emit('notice', { ar: 'الموسيقى غير متاحة حاليًا؛ المؤثرات مستمرة.', en: 'Music unavailable; sound effects remain active.' });
    } }
    private play(kind: Sound, power: number, position?: Vector3) {
        const ctx = this.context;
        if (!ctx || !this.active || this.voices >= 16 || power <= 0)
            return;
        const now = performance.now();
        if (kind === 'impact' && now - this.lastSound < 65)
            return;
        this.lastSound = now;
        const buffer = this.buffers.get(kind);
        if (!buffer)
            return;
        const source = ctx.createBufferSource(), gain = ctx.createGain();
        source.buffer = buffer;
        gain.gain.value = Math.max(0.02, Math.min(1, power));
        const group = this.groups.get(kind === 'ui' ? 'ui' : ['bird', 'cricket', 'frog'].includes(kind) ? 'ambience' : 'sfx')!;
        let panner: PannerNode | undefined;
        source.connect(gain);
        if (position) {
            panner = ctx.createPanner();
            panner.panningModel = 'equalpower';
            panner.distanceModel = 'inverse';
            panner.refDistance = 1;
            panner.maxDistance = 25;
            panner.positionX.value = position.x;
            panner.positionY.value = position.y;
            panner.positionZ.value = position.z;
            gain.connect(panner).connect(group);
        }
        else
            gain.connect(group);
        this.voices++;
        source.onended = () => { this.voices--; source.disconnect(); gain.disconnect(); panner?.disconnect(); };
        source.start();
    }
    uiSound() { this.play('ui', 0.35); }
    update(dt: number) {
        const ctx = this.context;
        if (!ctx || !this.active)
            return;
        const c = this.c, l = ctx.listener;
        l.positionX.value = c.input.head.x;
        l.positionY.value = c.input.head.y;
        l.positionZ.value = c.input.head.z;
        this.forward.set(0, 0, -1).applyQuaternion(c.input.orientation);
        this.up.set(0, 1, 0).applyQuaternion(c.input.orientation);
        l.forwardX.value = this.forward.x;
        l.forwardY.value = this.forward.y;
        l.forwardZ.value = this.forward.z;
        l.upX.value = this.up.x;
        l.upY.value = this.up.y;
        l.upZ.value = this.up.z;
        this.ambienceAt -= dt;
        if (this.ambienceAt <= 0 && c.xr === 'immersive-vr') {
            this.ambienceAt = 2.3 + Math.random() * 3;
            this.up.set(c.input.head.x + (Math.random() - 0.5) * 10, 1.5, c.input.head.z - 4);
            this.play(c.environment.night ? Math.random() > 0.3 ? 'cricket' : 'frog' : 'bird', 0.4, this.up);
        }
        const rain = this.groups.get('rain');
        if (rain)
            rain.gain.setTargetAtTime(c.store.data.weather === 'rain' && c.xr === 'immersive-vr' ? 1 : 0, ctx.currentTime, 0.5);
    }
}
export class AudioSystem extends createSystem({}) {
    update(dt: number) { contextOf(this.world).audio.update(dt); }
}
