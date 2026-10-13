#!/usr/bin/env python3
"""Firework cues for the headset (the blaster's "firework" shot), richer than firework-audio.ts's
short whistle and thud. Writes assets/audio/firework_launch_{1,2,3}.wav and firework_burst_{1,2,3}.wav
(stereo, 44.1 kHz, 16-bit), the names and three-variant scheme game_audio.gd cycles through.

  python3 quest-native/tools/audio/render_fireworks.py

numpy only. Every variant is seeded, so a re-render gives the same files.

launch (0.62 s): a soft muzzle thump, a breathy rising whistle (a pitch-tracking band of noise round a
  sine with a touch of vibrato and its octave) over an air whoosh, then a sparse crackle tail that
  thins out, the crackles scattered left and right.
burst (1.9 s): a layered bang (a bright crack, a pitched-down sub boom and a low noise body), a shower
  of crackles and tiny glitter pings that peaks a moment after the bang and fades, and a baked-in
  decorrelated reverb tail (an exponentially decaying noise response per ear) for width and space.

Levels sit with the other SFX files (sounds.js's bus is baked into those): RMS over the first half
second a little above the web cues (launch 0.045 vs 0.036, burst 0.062 vs 0.043; the web boom is 0.040),
everything passes a soft limiter and peaks stay well under full scale.
"""
import os
import struct
import sys

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "audio"))


# --- building blocks ------------------------------------------------------------------------

def biquad(x, kind, f, q):
    """RBJ biquad over x; f (Hz) and q may be arrays (time-varying) or scalars."""
    n = len(x)
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    q = np.broadcast_to(np.asarray(q, dtype=float), (n,))
    w = 2 * np.pi * np.clip(f, 10, SR * 0.45) / SR
    cw, sw = np.cos(w), np.sin(w)
    a = sw / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:  # band-pass, 0 dB peak
        b0, b1, b2 = a, np.zeros(n), -a
    a0, a1, a2 = 1 + a, -2 * cw, 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        xi = x[i]
        yi = b0[i] * xi + b1[i] * x1 + b2[i] * x2 - a1[i] * y1 - a2[i] * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def env(t, attack, decay):
    """A quick rise then an exponential fall (decay: seconds to 1/e)."""
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(0.0, t - attack) / decay)


def pan(mono, p):
    """Equal-power pan, p in -1..1 -> (L, R)."""
    a = (p + 1) * np.pi / 4
    return mono * np.cos(a), mono * np.sin(a)


def crackles(rng, n, times, amp, width_ms=(0.6, 2.2), spread=0.55, bright=(2500, 7000)):
    """Sparse crackle clicks at the given times (s): short bursts of high-passed noise, each panned."""
    L = np.zeros(n)
    R = np.zeros(n)
    for t0, a in zip(times, amp):
        i0 = int(t0 * SR)
        m = int(rng.uniform(*width_ms) * SR / 1000) + 8
        if i0 + m >= n:
            continue
        k = np.arange(m) / m
        burst = rng.standard_normal(m) * np.exp(-k * 5.0) * a
        # A quick one-pole high-pass for the snap, then a rough tilt to the chosen brightness.
        hp = np.diff(np.concatenate([[0.0], burst]))
        c = rng.uniform(*bright) / SR
        burst = burst * (1 - c * 4) + hp * c * 9
        l, r = pan(burst, rng.uniform(-spread, spread))
        L[i0:i0 + m] += l
        R[i0:i0 + m] += r
    return L, R


def glitter(rng, n, times, amp, spread=0.7):
    """Tiny bright pings (the sparkle of a willow): short decaying sines at 3.5-8 kHz."""
    L = np.zeros(n)
    R = np.zeros(n)
    for t0, a in zip(times, amp):
        i0 = int(t0 * SR)
        m = int(rng.uniform(0.012, 0.035) * SR)
        if i0 + m >= n:
            continue
        k = np.arange(m) / SR
        f = rng.uniform(3500, 8000)
        ping = np.sin(2 * np.pi * f * k + rng.uniform(0, 6.28)) * np.exp(-k / rng.uniform(0.004, 0.01)) * a
        l, r = pan(ping, rng.uniform(-spread, spread))
        L[i0:i0 + m] += l
        R[i0:i0 + m] += r
    return L, R


def reverb(rng, L, R, seconds, rt, mix, lp=5200.0, pre_ms=12):
    """Convolve each ear with its own exponentially decaying noise response (decorrelated: width)."""
    m = int(seconds * SR)
    t = np.arange(m) / SR
    out = []
    for ch in (biquad(L, "hp", 180, 0.7), biquad(R, "hp", 180, 0.7)):  # no boomy sub in the tail
        ir = rng.standard_normal(m) * np.exp(-6.9 * t / rt)  # -60 dB at rt
        ir = biquad(ir, "lp", lp * np.exp(-t * 1.6), 0.6)  # darker as it dies away
        ir[: int(pre_ms * SR / 1000)] = 0.0
        ir /= np.sqrt((ir ** 2).sum())
        n = len(ch) + m
        size = 1 << (n - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(ch, size) * np.fft.rfft(ir, size), size)[: len(ch)]
        out.append(wet)
    return L + out[0] * mix, R + out[1] * mix


def finish(L, R, rms, peak_max=0.8):
    """Soft-limit, fade the ends, scale to the loudness asked (RMS over the first half second, like
    the other SFX files), never past peak_max."""
    x = np.stack([L, R])
    x /= np.abs(x).max() + 1e-12
    x = np.tanh(x * 1.2) / np.tanh(1.2)  # gentle limiter: transients round off instead of clipping
    n = x.shape[1]
    fade_in = np.minimum(1.0, np.arange(n) / (0.002 * SR))
    fade_out = np.minimum(1.0, (n - 1 - np.arange(n)) / (0.04 * SR))
    x *= fade_in * fade_out
    now = np.sqrt((x[:, : int(0.5 * SR)] ** 2).mean())
    x *= min(rms / now, peak_max / (np.abs(x).max() + 1e-12))
    return x


# --- the cues -------------------------------------------------------------------------------

def launch(seed):
    """A soft, round launch (the owner found the whistle and crackle tail harsh): a low "pfoomp" at
    the muzzle, a short airy whoosh that rises a little as the rocket leaves, and a light room tail.
    No whistle, no crackles."""
    rng = np.random.default_rng(seed)
    dur = 0.42
    n = int(dur * SR)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (70 + 70 * np.exp(-t * 30)) * t) * env(t, 0.003, 0.06) * 0.7
    puff = biquad(rng.standard_normal(n), "lp", 700, 0.7) * env(t, 0.002, 0.05) * 0.45
    p = np.clip(t / 0.3, 0, 1)
    w_env = np.minimum(1, t / 0.04) * np.clip((0.34 - t) / 0.16, 0, 1)
    whoosh = biquad(rng.standard_normal(n), "bp", 380 + 520 * p, 0.9) * w_env * 0.32
    L = thump + puff + whoosh
    R = L.copy()
    L, R = reverb(rng, L, R, 0.35, 0.25, 0.12, lp=3000.0)
    return finish(L, R, 0.03)


def burst(seed):
    rng = np.random.default_rng(seed)
    dur = 1.9
    n = int(dur * SR)
    t = np.arange(n) / SR
    # The bang: a bright crack on top...
    crack = biquad(rng.standard_normal(n), "bp", 2400, 0.9) * env(t, 0.0008, 0.018) * 1.1
    click = biquad(rng.standard_normal(n), "hp", 3500, 0.7) * env(t, 0.0003, 0.004) * 0.9
    # ...a deep boom gliding down (with its second harmonic, so small speakers still carry it)...
    fb = rng.uniform(80, 95) * np.exp(-t * 3.0) + 42
    ph = 2 * np.cumsum(np.pi * fb / SR)
    boom = (np.sin(ph) + 0.35 * np.sin(2 * ph)) * env(t, 0.004, 0.17) * 0.8
    # ...and a noise body (the thud of the shell) that closes down.
    body = biquad(rng.standard_normal(n), "lp", 250 + 1600 * np.exp(-t * 12), 0.8) * env(t, 0.002, 0.12) * 1.3
    mid = crack + click + boom + body
    L = mid.copy()
    R = mid.copy()
    # The shower: crackles peaking ~0.3 s after the bang, fading by ~1.4 s; glitter over it.
    k = 240 + rng.integers(-20, 20)
    times = np.sort(0.06 + rng.gamma(2.2, 0.17, k))
    times = times[times < dur - 0.25]
    amp = rng.uniform(0.08, 0.42, len(times)) * np.exp(-np.maximum(0, times - 0.3) * 1.9)
    cl, cr = crackles(rng, n, times, amp, spread=0.8)
    L += cl * 2.4
    R += cr * 2.4
    gt = np.sort(0.1 + rng.gamma(2.0, 0.22, 70))
    gt = gt[gt < dur - 0.2]
    ga = rng.uniform(0.04, 0.12, len(gt)) * np.exp(-np.maximum(0, gt - 0.35) * 1.6)
    gl, gr = glitter(rng, n, gt, ga)
    L += gl * 1.8
    R += gr * 1.8
    # Space: a wide, decorrelated tail (an open sky with some park round it).
    L, R = reverb(rng, L, R, 1.4, 1.15, 0.38, lp=4200)
    return finish(L, R, 0.062)


def write_wav(path, x):
    pcm = np.clip(np.round(x.T * 32767), -32768, 32767).astype("<i2").tobytes()
    ch = x.shape[0]
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, ch, SR, SR * ch * 2, ch * 2, 16))
        f.write(b"data" + struct.pack("<I", len(pcm)) + pcm)


def main():
    for i in range(3):
        # The burst stays the web original (render_audio.mjs); only the launch is ours.
        for name, fn, seed in (("firework_launch", launch, 101 + i * 7919),):
            x = fn(seed)
            path = os.path.join(OUT, "%s_%d.wav" % (name, i + 1))
            write_wav(path, x)
            rms = np.sqrt((x[:, : int(0.5 * SR)] ** 2).mean())
            print("%s  %.2f s  peak %.3f  rms(0.5 s) %.4f" % (os.path.relpath(path), x.shape[1] / SR, np.abs(x).max(), rms))
    return 0


if __name__ == "__main__":
    sys.exit(main())
