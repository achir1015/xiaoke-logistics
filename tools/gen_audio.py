"""產生小柯機器人物流大亨的背景音樂與音效（原創程序合成）。

用法：python -I tools/gen_audio.py
輸出：assets/music/*.ogg、assets/sfx/*.wav（需要 numpy、scipy、ffmpeg）
"""
import os
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "music")
SFX = os.path.join(ROOT, "assets", "sfx")
rng = np.random.default_rng(20261106)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def lp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), "high")
    return lfilter(b, a, x)


def epiano(f, dur, vel=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 2.2) * (1 - np.exp(-t * 400))
    tine = np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 9))
    body = 0.5 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 4)
    trem = 1 + 0.15 * np.sin(2 * np.pi * 4.5 * t)
    return (tine + body) * env * trem * vel


def bass(f, dur, vel=0.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 1.5) * (1 - np.exp(-t * 200))
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t)
    return x * env * vel


def pluck(f, dur, vel=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 6) * (1 - np.exp(-t * 600))
    x = np.sign(np.sin(2 * np.pi * f * t)) * 0.3 + np.sin(2 * np.pi * f * t)
    return lp(x * env * vel, 2500)


def kick():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.8


def hat(open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    x = hp(rng.standard_normal(n), 7000)
    return x * np.exp(-t * (12 if open_ else 60)) * 0.12


def snare():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    x = lp(rng.standard_normal(n), 5000) * np.exp(-t * 18) * 0.25
    x += np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.2
    return x


def add(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i]


def vinyl(n):
    x = lp(rng.standard_normal(n), 1800) * 0.008
    pops = (rng.random(n) > 0.99993) * rng.standard_normal(n) * 0.15
    return x + lp(pops, 3000)


def track(name, key, bpm, prog, bars, swing=0.58, melody_scale=None):
    beat = 60.0 / bpm
    total = bars * 4 * beat + 2.0
    n = int(total * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    scale = melody_scale or [0, 2, 4, 7, 9, 12, 14, 16]
    for bar in range(bars):
        root, quality = prog[bar % len(prog)]
        t0 = bar * 4 * beat
        chord = [0, 4, 7, 11, 14] if quality == "maj" else [0, 3, 7, 10, 14]
        notes = [key + root + c for c in chord]
        # 和弦：前拍與切分
        for hit, vel in ((0.0, 0.42), (2.5, 0.3)):
            for k, nn in enumerate(notes[1:]):
                x = epiano(midi(nn + 12), beat * 3, vel * 0.5)
                pan = 0.35 + 0.3 * (k / 3)
                add(L, x * (1 - pan), t0 + hit * beat + k * 0.012)
                add(R, x * pan, t0 + hit * beat + k * 0.012)
        # 低音
        for b_at, off in ((0, 0), (1.5, 7), (2.5, 0), (3.5, 12 if bar % 2 else 7)):
            x = bass(midi(key + root - 12 + off), beat * 1.2, 0.5)
            add(L, x, t0 + b_at * beat)
            add(R, x, t0 + b_at * beat)
        # 鼓
        if bar >= 2:
            for b in range(4):
                tt = t0 + b * beat
                if b in (0, 2):
                    add(L, kick(), tt); add(R, kick(), tt)
                if b in (1, 3):
                    s = snare(); add(L, s * 0.9, tt); add(R, s, tt)
                for h in range(2):
                    off = h * beat * (swing if h else 0)
                    hh = hat(open_=(b == 3 and h == 1))
                    add(L, hh * 0.8, tt + off); add(R, hh, tt + off)
        # 旋律（溫和、偶爾休息）
        if bar >= 4 and bar % 8 < 6:
            for s in range(8):
                if rng.random() < 0.45:
                    deg = scale[int(rng.integers(0, len(scale)))]
                    x = pluck(midi(key + 24 + root % 12 // 12 + deg), beat * 0.9, 0.18)
                    tt = t0 + s * beat / 2 + (beat / 2 * (swing - 0.5) if s % 2 else 0)
                    add(L, x * 0.6, tt); add(R, x * 0.9, tt)
    st = np.stack([L, R], axis=1)
    st[:, 0] += vinyl(n)
    st[:, 1] += vinyl(n)
    st = lp(st.T, 9000).T
    # 淡入淡出
    fade = int(1.5 * SR)
    st[:fade] *= np.linspace(0, 1, fade)[:, None]
    st[-fade:] *= np.linspace(1, 0, fade)[:, None]
    st /= np.max(np.abs(st)) + 1e-9
    st *= 0.8
    wav = os.path.join(MUSIC, name + ".wav")
    wavfile.write(wav, SR, (st * 32767).astype(np.int16))
    ogg = os.path.join(MUSIC, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)
    print("music", name, round(total, 1), "s")


def write_sfx(name, x):
    x = np.asarray(x, dtype=float)
    x /= np.max(np.abs(x)) + 1e-9
    x *= 0.7
    wavfile.write(os.path.join(SFX, name + ".wav"), SR, (x * 32767).astype(np.int16))


def tone(f, dur, decay=8.0, wave="sine"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if wave == "square":
        x = np.sign(np.sin(2 * np.pi * f * t))
    else:
        x = np.sin(2 * np.pi * f * t)
    return x * np.exp(-t * decay) * (1 - np.exp(-t * 800))


def cat(*parts):
    return np.concatenate(parts)


def sfx():
    write_sfx("click", tone(1400, 0.05, 60))
    write_sfx("ding", tone(1318, 0.5, 6) + 0.5 * tone(1975, 0.5, 8))
    write_sfx("sign", cat(tone(784, 0.09, 20), tone(1046, 0.25, 9)))
    write_sfx("error", cat(tone(220, 0.12, 10, "square") * 0.4, tone(185, 0.18, 10, "square") * 0.4))
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (90 + 120 * np.exp(-t * 40)) * t) * np.exp(-t * 14)
    clank = hp(rng.standard_normal(n), 2500) * np.exp(-t * 35) * 0.4
    write_sfx("build", thump + clank)
    bell = sum(tone(f, 0.7, 5) * a for f, a in ((2093, 0.6), (2637, 0.4), (3136, 0.3)))
    drawer = lp(rng.standard_normal(int(0.12 * SR)), 1500) * 0.5
    write_sfx("cash", cat(drawer, bell))
    ring = []
    for _ in range(2):
        seg = int(0.4 * SR)
        tt = np.arange(seg) / SR
        r = np.sin(2 * np.pi * 900 * tt) * (np.sin(2 * np.pi * 20 * tt) > 0) + 0.5 * np.sin(2 * np.pi * 1100 * tt)
        ring.append(r * 0.6)
        ring.append(np.zeros(int(0.2 * SR)))
    write_sfx("phone", np.concatenate(ring))
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    f = 650 + 350 * np.sin(2 * np.pi * 1.2 * t)
    write_sfx("siren", np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.7)
    write_sfx("beep", cat(tone(1700, 0.12, 2, "square") * 0.3, np.zeros(int(0.1 * SR)), tone(1700, 0.12, 2, "square") * 0.3))
    write_sfx("fanfare", cat(tone(523, 0.12, 6), tone(659, 0.12, 6), tone(784, 0.12, 6), tone(1046, 0.5, 3)))
    hn = int(0.6 * SR)
    t = np.arange(hn) / SR
    horn = (np.sign(np.sin(2 * np.pi * 220 * t)) + np.sign(np.sin(2 * np.pi * 277 * t))) * (1 - np.exp(-t * 60)) * np.exp(-t * 1.5)
    write_sfx("horn", lp(horn, 1800) * 0.5)
    print("sfx done")


if __name__ == "__main__":
    os.makedirs(MUSIC, exist_ok=True)
    os.makedirs(SFX, exist_ok=True)
    sfx()
    # 調性、速度、和弦進行（級數, 大/小）
    track("morning_dock", 60, 84, [(0, "maj"), (9, "min"), (5, "maj"), (7, "maj")], 40)
    track("forklift_waltz", 57, 76, [(0, "min"), (5, "min"), (10, "maj"), (3, "maj")], 36)
    track("night_shift", 62, 70, [(5, "maj"), (4, "min"), (2, "min"), (0, "maj")], 32,
          melody_scale=[0, 3, 5, 7, 10, 12])
