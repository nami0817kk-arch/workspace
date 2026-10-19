"""エピソード: 複数の場面(戦い)と、場面カード(タイトル・「一か月後」など)を、1本の動画にまとめる。

episode.yaml:
    name: ep1
    mood_cards: sad              # カードの BGM(none で無音)
    items:
    - card: {text: "第1話 敗北", sub: "最強の剣士ミドリ", dur: 2.2}
    - scene: scenes/fight_default.yaml          # 台本ファイル
    - scene: {name: s2, fight: {...}}           # その場に書いた台本(fight: の指定でもよい)
    - card: {text: "一か月後", dur: 1.6, style: time}

各場面は build_scene でそれぞれ点検・書き出しし、同じ設定の mp4(H.264 + AAC 44.1kHz ステレオ)に揃えて、ffmpeg で連結する。
"""
from __future__ import annotations

import subprocess
import wave
from pathlib import Path
from typing import Optional

import numpy as np
import yaml
from PIL import Image, ImageDraw

from . import anime, camera, fight, plan as planmod, sfx

W, H = camera.W, camera.H


def load_episode(path) -> dict:
    ep = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    if "story" in ep:                         # 物語の型(story.py)から組む。ほかのキーで上書き
        from . import story
        base = story.build_story(ep["story"])
        base.update({k: v for k, v in ep.items() if k != "story"})
        ep = base
    return ep


def _card_frame(text: str, sub: str, style: str, color, alpha: float, size=(W, H)) -> Image.Image:
    W, H = size
    k = 0.6 if W < H else 1.0                 # 縦画面は文字を小さめに
    bg = Image.new("RGB", (W, H), tuple(color))
    img = bg.copy()
    d = ImageDraw.Draw(img)
    if style == "time":          # 場面の転換: 右下に小さく
        f = anime._font(int(64 * k))
        tw = d.textlength(text, font=f)
        d.text((W - tw - 60, H - 140), text, font=f, fill=(235, 235, 235))
    else:
        f = anime._font(int(110 * k))
        tw = d.textlength(text, font=f)
        d.text(((W - tw) / 2, H * 0.36), text, font=f, fill=(255, 255, 255), stroke_width=6, stroke_fill=(10, 10, 16))
        if sub:
            f2 = anime._font(int(46 * k))
            tw2 = d.textlength(sub, font=f2)
            d.text(((W - tw2) / 2, H * 0.36 + 150 * k), sub, font=f2, fill=(220, 220, 230))
    return Image.blend(bg, img, max(0.0, min(1.0, alpha)))


def _write_wav(path: Path, snd: np.ndarray) -> None:
    pcm = (np.stack([snd, snd], axis=1) * 32767 * 0.8).clip(-32767, 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sfx.SR)
        w.writeframes(pcm.tobytes())


def card_segment(c: dict, out: Path, ff: str, mood: Optional[str], fps: int = 30, size=(W, H)) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    dur = float(c.get("dur", 2.0))
    n = int(dur * fps)
    color = c.get("color", (10, 10, 18))
    for p in out.glob("*.png"):
        p.unlink()
    for i in range(n):
        t = i / fps
        a = min(1.0, t / 0.3, (dur - t) / 0.3)
        _card_frame(c["text"], c.get("sub", ""), c.get("style", "title"), color, a, size).save(out / f"{i + 1:04d}.png")
    silent = out / "card_silent.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(out / "%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(silent)], check=True)
    snd = sfx.bgm(dur, mood, 5) * 0.5 if mood and mood != "none" else np.zeros(int(sfx.SR * dur))
    fade = int(sfx.SR * 0.3)
    snd[:fade] *= np.linspace(0, 1, fade)
    snd[-fade:] *= np.linspace(1, 0, fade)
    wav = out / "card.wav"
    _write_wav(wav, snd)
    mp4 = out / "card.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(silent), "-i", str(wav), "-c:v", "copy", "-c:a", "aac",
                    "-b:a", "192k", "-ar", "44100", "-ac", "2", "-shortest", str(mp4)], check=True)
    return mp4


def build_episode(ep: dict, out: Path, reuse_figs: bool = False, force: bool = False, vertical: bool = False) -> Optional[Path]:
    from . import cli
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    from . import review
    r = review.review_episode(ep)                       # 書き出す前の自動点検(字幕の読みやすさ・話の筋)。直すところがあれば止める
    for n in r["notes"]:
        print("  " + n)
    if not r["ok"] and not force:
        print("自動点検で直すところがあるので、書き出さずに止める(--force で続ける)")
        return None
    ff = cli.find_ffmpeg()
    segs = []
    for i, it in enumerate(ep["items"]):
        seg_dir = out / f"seg{i + 1:02d}"
        if "card" in it:
            segs.append(card_segment(it["card"], seg_dir, ff, ep.get("mood_cards", "sad"), size=((720, 1280) if vertical else (W, H))))
            continue
        sc = it["scene"]
        if isinstance(sc, str):
            scene = planmod.load_scene(sc)
        else:
            scene = fight.expand(dict(sc), verify=True)
            planmod.validate_scene(scene)
        if vertical:
            scene["output"] = {"aspect": "vertical"}
        mp4 = cli.build_scene(scene, seg_dir, reuse_figs, force, quiet=True)
        if mp4 is None:
            print(f"場面 {i + 1} が点検で止まった")
            return None
        segs.append(mp4)
    lst = out / "concat.txt"
    lst.write_text("".join(f"file '{Path(s).resolve().as_posix()}'\n" for s in segs), encoding="utf-8")
    final = out / f"{ep.get('name', 'episode')}.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "18", "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2", str(final)], check=True)
    print(f"\n【エピソード】{final}({len(segs)} 区間)")
    return final
