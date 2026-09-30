"""Synthesises every Cut & Run sound effect and music loop from scratch (no samples),
so all audio is original and free to ship. Requires numpy; ffmpeg converts to OGG.

Run from repo root: python tool/gen_audio.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, attack=0.005, curve=4.0):
    t = np.linspace(0, 1, n)
    a = max(1, int(attack * SR))
    e = np.exp(-curve * t)
    e[:a] *= np.linspace(0, 1, a)
    return e


def tone(freq, dur, shape="sine"):
    t = t_axis(dur)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(t)) / SR
    else:
        phase = 2 * np.pi * freq * t
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    raise ValueError(shape)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def highpass(x, k=0.95):
    y = np.zeros_like(x)
    for i in range(1, len(x)):
        y[i] = k * (y[i - 1] + x[i] - x[i - 1])
    return y


def lowpass(x, k=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc)
        y[i] = acc
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts):
    return np.concatenate(parts)


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def write(name, x, peak=0.85):
    x = normalize(x, peak)
    # short fade-out avoids clicks at the end of every sample
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    pcm = (x * 32767).astype(np.int16)
    wav_path = os.path.join(OUT, name + ".wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    ogg_path = os.path.join(OUT, name + ".ogg")
    subprocess.run([os.environ.get("FFMPEG", "ffmpeg"), "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3", ogg_path], check=True)
    os.remove(wav_path)


def n_of(d):
    return int(SR * d)


def sfx():
    d = 0.16
    swish = highpass(noise(d), 0.9) * env(n_of(d), 0.01, curve=6)
    write("cut", swish * 0.9 + tone(lambda t: 1800 - 6000 * t, d) * env(n_of(d), curve=10) * 0.2)

    d = 0.22
    snap = highpass(noise(0.03), 0.7) * env(n_of(0.03), curve=8)
    thud = tone(lambda t: 180 - 300 * t, d) * env(n_of(d), curve=9)
    write("split", mix(snap, thud * 0.8))

    write("collect", seq(tone(988, 0.05, "tri") * env(n_of(0.05), curve=3),
                         tone(1318, 0.08, "tri") * env(n_of(0.08), curve=5)), 0.6)

    d = 0.3
    write("coin", (tone(1568, d) + 0.5 * tone(2350, d) + 0.25 * tone(3136, d)) * env(n_of(d), curve=7), 0.6)

    d = 0.35
    rise = tone(lambda t: 440 + 1400 * t, d, "tri") * env(n_of(d), 0.02, curve=3)
    write("combine", mix(rise, tone(lambda t: 660 + 2100 * t, d) * env(n_of(d), 0.02, curve=4) * 0.5))

    d = 0.35
    write("hit", mix(lowpass(noise(d), 0.3) * env(n_of(d), curve=7),
                     tone(lambda t: 110 - 120 * t, d, "square") * env(n_of(d), curve=6) * 0.7))

    d = 0.3
    write("shield", mix(highpass(noise(d), 0.8) * env(n_of(d), curve=9) * 0.6,
                        tone(lambda t: 900 - 1500 * t, d, "tri") * env(n_of(d), curve=5)))

    write("perfect", seq(*[tone(f, 0.06, "tri") * env(n_of(0.06), curve=3) for f in (1046, 1318, 1568, 2093)]), 0.6)

    write("chain", seq(*[tone(lambda t, b=b: b + 3000 * t, 0.07, "saw") * env(n_of(0.07), curve=5)
                         for b in (500, 700, 900)]), 0.55)

    d = 0.25
    write("gate", mix(tone(660, d) * env(n_of(d), curve=6), tone(990, d) * env(n_of(d), curve=6) * 0.6), 0.6)

    write("gate_fail", seq(tone(330, 0.12, "square") * env(n_of(0.12), curve=3),
                           tone(247, 0.18, "square") * env(n_of(0.18), curve=3)), 0.5)

    d = 0.4
    write("powerup", tone(lambda t: 300 + 9600 * t * t, d, "square") * env(n_of(d), 0.01, curve=3) * 0.7, 0.55)

    d = 0.06
    write("tap", tone(740, d) * env(n_of(d), 0.002, curve=12), 0.5)

    write("reward", seq(*[tone(f, 0.09, "tri") * env(n_of(0.09), curve=2.5) for f in (784, 988, 1175, 1568)]), 0.6)

    parts = []
    for f, d in ((523, 0.12), (659, 0.12), (784, 0.12), (1046, 0.45)):
        parts.append(mix(tone(f, d, "tri"), tone(f * 1.5, d) * 0.3) * env(n_of(d), 0.01, curve=2.5))
    write("complete", seq(*parts), 0.7)

    parts = []
    for f, d in ((392, 0.18), (330, 0.18), (262, 0.5)):
        parts.append(tone(f, d, "tri") * env(n_of(d), 0.01, curve=2))
    write("fail", seq(*parts), 0.6)

    d = 0.2
    write("clang", (tone(1200, d) + tone(1790, d) * 0.7 + highpass(noise(d), 0.9) * 0.3) * env(n_of(d), curve=10), 0.55)


def midi(n):
    return 440 * 2 ** ((n - 69) / 12)


def music(name, bpm, root, progression, lead_pattern, bars=8):
    beat = 60 / bpm
    step = beat / 2
    total = n_of(beat * 4 * bars)
    out = np.zeros(total)

    def place(sig, start):
        i = int(start * SR)
        end = min(total, i + len(sig))
        out[i:end] += sig[: end - i]

    kick = tone(lambda t: 120 - 300 * t, 0.18) * env(n_of(0.18), curve=10) * 0.9
    hat = highpass(noise(0.04), 0.6) * env(n_of(0.04), curve=12) * 0.18
    snare = lowpass(noise(0.12), 0.5) * env(n_of(0.12), curve=9) * 0.35
    for bar in range(bars):
        chord = progression[bar % len(progression)]
        base_t = bar * beat * 4
        for b in range(4):
            t0 = base_t + b * beat
            place(kick, t0)
            place(hat, t0 + beat / 2)
            if b in (1, 3):
                place(snare, t0)
        bd = step * 0.9
        bass = tone(midi(root + chord[0] - 12), bd, "tri") * env(n_of(bd), 0.005, curve=3) * 0.45
        for s in range(8):
            place(bass, base_t + s * step)
        pd = beat * 4
        pad = sum(tone(midi(root + c), pd) for c in chord) / len(chord)
        ramp = np.linspace(0, 6, n_of(pd))
        pe = np.minimum(1, ramp) * np.minimum(1, ramp[::-1])
        place(pad * pe * 0.18, base_t)
        ld = step * 0.8
        for s, deg in enumerate(lead_pattern):
            if deg is None:
                continue
            n = root + 12 + chord[deg % len(chord)] + (12 if deg >= len(chord) else 0)
            place(tone(midi(n), ld, "square") * env(n_of(ld), 0.005, curve=5) * 0.12, base_t + s * step)
    write(name, lowpass(out, 0.55), 0.7)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    minor = [[0, 3, 7], [-4, 0, 3], [-2, 2, 5], [-5, -1, 2]]
    major = [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]]
    music("music_menu", 100, 57, major, [0, None, 1, 2, None, 1, 3, None])
    music("music_game", 128, 55, minor, [0, 1, 2, 1, 3, 2, 1, 2])
    print("audio generated")
