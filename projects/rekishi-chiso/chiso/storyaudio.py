"""物語完結型ショートの音：映画のような厚みの BGM（弦＝チェロ風の低音とヴァイオリン風の高音の持続音＋静かなピアノの分散和音）と、
転換点の前に上がる音（ライザー）・低い響き・頂点の一拍の無音（BGM だけ消える）。

すべてこのモジュールの中で numpy の数式だけで合成する（外部の音源・サンプル・学習済みモデルは使わない）。
音は和音の構成音（イ短調の Am → F → C → G）を、倍音を足した正弦波に指数の減衰をかけて鳴らしただけで、既存の曲の旋律・音源とは無関係。
したがって著作権・ライセンスの問題は無い（クレジットも不要）。ショート用のオプション（台本の bgm: true）。本編は BGM なしのまま。

声が主役：BGM の大きさは声（loudnorm 前）の積分ラウドネスより約9 LU 小さく合わせる（仕上げの loudnorm 後は
声 -14 LUFS 前後・BGM -23 LUFS 前後）。最初に1.5秒でフェードインし、最後の約3秒でフェードアウトする。
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 24000                 # VOICEVOX の出力に合わせる
BPM = 76
VIBRATO_DEPTH = 0.0018        # 弦のビブラート：±0.18%（約±3セント）。第7版の0.45%は揺れが目立った（第8版で弱めた）
FADE_IN = 2.5                # 立ち上がりをなだらかに（第7版は1.5秒。冒頭の強い音が出ないように）
CHORDS = [                  # (低い持続音, 分散和音の音)  Hz
    ((110.00, 164.81), (220.00, 261.63, 329.63, 440.00)),      # Am
    ((87.31, 130.81), (174.61, 220.00, 261.63, 349.23)),       # F
    ((130.81, 196.00), (261.63, 329.63, 392.00, 523.25)),      # C
    ((98.00, 146.83), (196.00, 246.94, 293.66, 392.00)),       # G
]
ARP = (0, 1, 2, 3, 2, 1, 2, 1)       # 8分音符ごとの分散和音の並び


def _piano(freq: float, dur: float, sr: int, vel: float) -> np.ndarray:
    t = np.arange(int(dur * sr)) / sr
    tau = 1.7 / (1.0 + freq / 700.0)
    env = np.exp(-t / tau) * np.minimum(1.0, t / 0.006)
    y = np.zeros_like(t)
    for k, a in enumerate((1.0, 0.42, 0.2, 0.1, 0.05), start=1):
        if freq * k < sr / 2.4:
            y += a * np.sin(2 * np.pi * freq * k * t * (1 + 0.00005 * k * k))
    return (vel * env * y).astype(np.float32)


def _string(freq: float, dur: float, sr: int, vel: float, vib: float = 5.0, depth: float = VIBRATO_DEPTH) -> np.ndarray:
    """弦（チェロ・ヴァイオリン風）の持続音：ゆっくり立ち上がり、ビブラートをかけた鋸波に近い音を低域で丸める。"""
    t = np.arange(int(dur * sr)) / sr
    f = freq * (1.0 + depth * np.sin(2 * np.pi * vib * t) * np.minimum(1.0, t / 0.9))
    ph = 2 * np.pi * np.cumsum(f) / sr
    y = np.zeros_like(t)
    for k in range(1, 8):
        if freq * k < sr / 2.4:
            y += np.sin(k * ph) / k ** 1.15
    env = np.minimum(1.0, t / 0.7) * np.minimum(1.0, np.maximum(0.0, dur - t) / 0.9)
    return (vel * env * y).astype(np.float32)


def synth_riser(sr: int = SR, dur: float = 1.4) -> np.ndarray:
    """転換点の直前に上がっていく音：音程が上がる正弦波＋次第に強くなる帯域ノイズ。最後は急に止める。最大振幅 0.8。"""
    t = np.arange(int(dur * sr)) / sr
    u = t / dur
    f = 130.0 * (2 ** (3.2 * u ** 1.6))
    ph = 2 * np.pi * np.cumsum(f) / sr
    tone = np.sin(ph) + 0.4 * np.sin(2 * ph)
    rng = np.random.default_rng(11)
    nz = rng.standard_normal(len(t)).astype(np.float32)
    nz = nz - np.convolve(nz, np.ones(40) / 40, mode="same")        # 高域寄りのノイズ
    y = (tone * 0.7 + nz * 0.9 * u ** 2) * (u ** 1.8)
    y *= np.minimum(1.0, (dur - t) / 0.02)
    return (y / (np.abs(y).max() + 1e-9) * 0.8).astype(np.float32)


def _pad(freq: float, dur: float, sr: int, vel: float) -> np.ndarray:
    t = np.arange(int(dur * sr)) / sr
    env = np.minimum(1.0, t / 1.2) * np.minimum(1.0, (dur - t) / 1.2)
    y = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
    return (vel * env * y).astype(np.float32)


def _reverb(x: np.ndarray, sr: int) -> np.ndarray:
    out = x.copy()
    for delay, gain in ((0.113, 0.30), (0.177, 0.24), (0.241, 0.18)):
        d = int(delay * sr)
        y = np.zeros_like(x)
        y[d:] = x[:-d]
        out += gain * y
    return out


def synth_bgm(seconds: float, sr: int = SR, seed: int = 7) -> np.ndarray:
    """seconds 秒の BGM（-1〜1 の float32、最大振幅 0.5）。同じ seed なら毎回同じ音。"""
    rng = np.random.default_rng(seed)
    beat = 60.0 / BPM
    n = int((seconds + 1.0) * sr)
    out = np.zeros(n, dtype=np.float32)
    bar, t0 = 0, 0.0
    while t0 < seconds + 0.5:
        pad_notes, arp_notes = CHORDS[bar % len(CHORDS)]
        for f in pad_notes:
            s = _pad(f, 4 * beat + 0.8, sr, 0.24)
            i = int(t0 * sr)
            out[i:i + len(s)] += s[:max(0, n - i)]
        for f, v in ((pad_notes[0], 0.30), (pad_notes[1], 0.16)):          # チェロ風の低音と、ヴァイオリン風の高い持続音
            s = _string(f, 4 * beat + 1.0, sr, v)
            i = int(t0 * sr)
            out[i:i + len(s)] += s[:max(0, n - i)]
        for j, idx in enumerate(ARP):
            f = arp_notes[idx]
            vel = (0.40 if j % 4 == 0 else 0.28) * (0.92 + 0.16 * rng.random())
            s = _piano(f, 2.6, sr, vel)
            i = int((t0 + j * beat / 2) * sr)
            out[i:i + len(s)] += s[:max(0, n - i)]
        bar += 1
        t0 += 4 * beat
    out = _reverb(out, sr)[: int(seconds * sr)]
    out = out / (np.abs(out).max() + 1e-9) * 0.5
    fi, fo = int(FADE_IN * sr), int(3.0 * sr)
    out[:fi] *= np.linspace(0, 1, fi) ** 2.0
    out[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    return out.astype(np.float32)


def synth_boom(sr: int = SR, dur: float = 1.8) -> np.ndarray:
    """転換点（「だが」）の小さな低い響き：下がっていく低音の正弦波＋ごく短い低域のノイズ。最大振幅 0.9。"""
    t = np.arange(int(dur * sr)) / sr
    f = 46.0 + 30.0 * np.exp(-t / 0.35)
    ph = 2 * np.pi * np.cumsum(f) / sr
    y = np.sin(ph) * np.exp(-t / 0.62) * np.minimum(1.0, t / 0.02)
    rng = np.random.default_rng(3)
    nz = rng.standard_normal(len(t)).astype(np.float32)
    k = np.ones(48) / 48                                         # 簡単な低域通過
    nz = np.convolve(nz, k, mode="same") * np.exp(-t / 0.12) * 1.5
    y = y + 0.4 * nz
    return (y / (np.abs(y).max() + 1e-9) * 0.9).astype(np.float32)


def bgm_stats(x: np.ndarray, sr: int = SR) -> dict:
    """BGM の帯域・音の確認用の数字：スペクトルの重心（Hz）・95%の音量が収まる上限（Hz）・立ち上がりの最大振幅（最初の0.3秒）。"""
    seg = x[len(x) // 4: len(x) // 4 + 10 * sr] if len(x) > 12 * sr else x
    sp = np.abs(np.fft.rfft(seg.astype(np.float64) * np.hanning(len(seg)))) ** 2
    fr = np.fft.rfftfreq(len(seg), 1 / sr)
    cum = np.cumsum(sp) / sp.sum()
    return {"centroid_hz": float((fr * sp).sum() / sp.sum()), "rolloff95_hz": float(fr[np.searchsorted(cum, 0.95)]),
            "head_peak": float(np.abs(x[: int(0.3 * sr)]).max()), "vibrato_cents": float(1200 * np.log2(1 + VIBRATO_DEPTH))}


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path)) as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
    return data, sr


def write_wav(path: Path, x: np.ndarray, sr: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def lufs(ffmpeg_exe: str, path: Path) -> float:
    """積分ラウドネス（LUFS）。ffmpeg の loudnorm の測定を使う。"""
    import json
    import re
    import subprocess
    r = subprocess.run([ffmpeg_exe, "-hide_banner", "-nostats", "-i", str(path), "-af",
                        "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    m = None
    for m in re.finditer(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr):
        pass
    return float(json.loads(m.group(0))["input_i"])


def mix_voice_bgm(voice_wav: Path, target: Path, total: float, booms: list[float], ffmpeg_exe: str,
                  diff_lu: float = 9.0, risers: list[float] | None = None, hushes: list[tuple[float, float]] | None = None) -> dict:
    """声（voice_wav）に BGM・上がる音・低い響きを重ねて target に書く。BGM は声より diff_lu だけ小さく。
    risers＝上がる音が終わる時刻、hushes＝BGM だけを消す区間（頂点の一拍の無音）。
    返り値は確認用の数字（声・BGM の LUFS、BGM の倍率、最大振幅）。"""
    import tempfile
    voice, sr = read_wav(voice_wav)
    n = int(total * sr)
    voice = np.pad(voice, (0, max(0, n - len(voice))))[:n]
    bgm = synth_bgm(total, sr)
    with tempfile.TemporaryDirectory() as td:
        write_wav(Path(td) / "bgm.wav", bgm, sr)
        lv, lb = lufs(ffmpeg_exe, voice_wav), lufs(ffmpeg_exe, Path(td) / "bgm.wav")
    gain = 10 ** ((lv - diff_lu - lb) / 20)
    env = np.ones(n, dtype=np.float32)
    ramp = int(0.06 * sr)
    for t0, t1 in hushes or []:                                    # 頂点の一拍の無音：BGM だけ消す（声は消さない）
        a, b = max(0, int(t0 * sr)), min(n, int(t1 * sr))
        if b > a:
            env[a:b] = 0.0
            env[max(0, a - ramp):a] = np.minimum(env[max(0, a - ramp):a], np.linspace(1, 0, a - max(0, a - ramp)))
            env[b:b + ramp] = np.minimum(env[b:b + ramp], np.linspace(0, 1, len(env[b:b + ramp])))
    mix = voice + bgm * env * gain
    for t in risers or []:
        r = synth_riser(sr)
        i = int(t * sr) - len(r)
        if i < 0:
            r = r[-i:]
            i = 0
        mix[i:i + len(r)] += r[: max(0, n - i)] * gain * 1.6
    boom = synth_boom(sr)
    for t in booms:
        i = int(t * sr)
        seg = boom[: max(0, n - i)]
        mix[i:i + len(seg)] += seg * gain * 2.2                  # 短い響きは BGM の2倍ほどの振幅
    peak = float(np.abs(mix).max())
    if peak > 0.97:
        mix = mix * (0.97 / peak)
    write_wav(target, mix, sr)
    st = bgm_stats(bgm * gain, sr)
    return {**st, "voice_lufs": lv, "bgm_lufs_before": lb, "bgm_gain": gain, "bgm_lufs_after": lb + 20 * np.log10(gain),
            "peak": float(np.abs(mix).max()), "booms": booms, "risers": risers or [], "hushes": hushes or []}
