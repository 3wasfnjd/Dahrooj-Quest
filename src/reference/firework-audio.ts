type FireworkCue = 'launch' | 'burst';
/** Two local, predecoded recordings; bounded one-shot voices use the existing spatial SFX bus. */
export function createFireworkAudio(context: AudioContext, output: () => AudioNode) {
    const buffers: Partial<Record<FireworkCue, AudioBuffer>> = {};
    const voices = new Set<{ stop(): void }>();
    let loading: Promise<void> | undefined;
    const load = () => loading ??= Promise.all((['launch', 'burst'] as const).map(async cue => {
        const response = await fetch(`/assets/audio/firework-${cue}.mp3`);
        if (!response.ok) throw new Error(`Firework audio ${response.status}`);
        buffers[cue] = await context.decodeAudioData(await response.arrayBuffer());
    })).then(() => {}).catch(() => { /* Existing reference cues remain the offline/load-failure fallback. */ });
    const clear = () => { for (const voice of voices) voice.stop(); };
    return {
        load, clear,
        play(cue: FireworkCue) {
            const buffer = buffers[cue];
            if (!buffer || context.state !== 'running') return false;
            // Five rockets/second can overlap their launch and burst tails without unbounded voices.
            while (voices.size >= 12) voices.values().next().value!.stop();
            const source = context.createBufferSource(), gain = context.createGain(), out = output();
            source.buffer = buffer;
            gain.gain.value = cue === 'launch' ? .28 : .52;
            source.connect(gain).connect(out);
            let ended = false;
            const finish = () => {
                if (ended) return;
                ended = true; voices.delete(voice); source.disconnect(); gain.disconnect();
                // sfxOut returns a private panner, or the shared bus when no position is supplied.
                if (out instanceof PannerNode) out.disconnect();
            };
            const voice = { stop() { source.stop(); finish(); } };
            source.onended = finish; voices.add(voice); source.start();
            return true;
        }
    };
}
