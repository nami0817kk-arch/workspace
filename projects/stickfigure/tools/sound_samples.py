"""戦闘アニメ風の効果音(stickfig/sfx_anime.py)の見本を書き出す。1 つずつの見本と、3 対 1 の流れに並べた通しの見本(約 15 秒)。
絵コンテのページで聴いて合わせるため(2026-10-24「音とかはドラゴンボールのアニメに寄せて」)。

使い方: python tools/sound_samples.py → out/storyboard3/snd/*.mp3 と sounds.json(名前・説明・長さ・ピーク)
"""
from __future__ import annotations

import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import cli, sfx_anime as sa  # noqa: E402
from stickfig.sfx import SR, _add  # noqa: E402

OUT = Path("out/storyboard3/snd")
LABEL = dict(hit="打撃(拳・蹴り)", heavy_hit="重い一撃(吹き飛ばす)", guard="受け止め", flurry="連打(ドドドド)", teleport="瞬間移動(シュン)",
             charge="気を溜める(2.5 秒)", aura="覚醒のオーラ", beam="光線の発射", ki_shot="気弾(ピシュン)", explosion="大爆発", clash="拳と拳の激突",
             dash="高速の移動(ビュンッ)", land="重い着地(ズンッ)", sting="山場の合図(ジャーン)")


def write(x: np.ndarray, name: str) -> Path:
    x = np.concatenate([np.zeros(int(SR * 0.15)), x, np.zeros(int(SR * 0.25))])
    x = np.tanh(1.2 * x) / np.tanh(1.2)
    x = 0.72 * x / max(1e-9, float(np.max(np.abs(x))))          # 圧縮(AAC)で山が 2 割ほど持ち上がるので、余裕を取る
    wav = OUT / f"{name}.wav"
    pcm = (np.stack([x, x], axis=1) * 32767).astype(np.int16)
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    mp3 = OUT / f"{name}.mp3"                                       # ページで鳴らすので、artifact が配信できる mp3 にする(m4a は配信されない)
    subprocess.run([cli.find_ffmpeg(), "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "160k", str(mp3)], check=True)
    wav.unlink()
    return mp3


def demo(rng) -> np.ndarray:
    """3 対 1 の流れの抜粋: にらみ合い → 3 人が消える → 四方の受け流し → 連携技 → 溜め → 合体光線 → 覚醒 → 瞬間移動 → 連打 → 激突 → とどめの光線。"""
    buf = np.zeros(int(SR * 16.0))
    t = 0.3
    _add(buf, sa.sting(rng, 1.4), t, 0.6)
    t = 1.6
    for k in range(3):
        _add(buf, sa.zip_(rng), t + k * 0.12, 0.8)
    t = 2.3
    for k in range(3):
        _add(buf, sa.guard(rng), t + k * 0.18, 0.9)
    t = 3.2
    _add(buf, sa.hit(rng, 1.0), t, 1.0)
    _add(buf, sa.flurry(rng, 6, 0.07), t + 0.4, 0.8)
    _add(buf, sa.hit(rng, 1.8), t + 1.0, 1.0)
    _add(buf, sa.land_heavy(rng), t + 1.25, 0.9)
    t = 5.0
    _add(buf, sa.charge(rng, 2.2), t, 0.8)
    _add(buf, sa.beam(rng, 1.4), t + 2.2, 1.0)
    _add(buf, sa.explosion(rng, 1.8), t + 3.3, 0.9)
    t = 9.0
    _add(buf, sa.aura(rng, 1.8), t, 0.9)
    _add(buf, sa.zip_(rng), t + 2.0, 0.9)
    _add(buf, sa.hit(rng, 1.4), t + 2.15, 1.0)
    _add(buf, sa.flurry(rng, 10, 0.05), t + 2.7, 0.85)
    _add(buf, sa.clash(rng), t + 3.6, 1.0)
    t = 13.4
    _add(buf, sa.beam(rng, 1.5), t, 1.0)
    _add(buf, sa.explosion(rng, 2.0), t + 1.3, 1.0)
    return buf


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(11)
    info = []
    for name, fn in sa.SOUNDS.items():
        x = fn(rng)
        write(x, name)
        info.append(dict(name=name, label=LABEL[name], sec=round(len(x) / SR, 2), src=f"snd/{name}.mp3"))
    d = demo(rng)
    write(d, "demo")
    info.insert(0, dict(name="demo", label="通しの見本(3 対 1 の流れの抜粋)", sec=round(len(d) / SR, 1), src="snd/demo.mp3"))
    (OUT.parent / "sounds.json").write_text(json.dumps(info, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(info), "本", [i["name"] for i in info])


if __name__ == "__main__":
    main()
