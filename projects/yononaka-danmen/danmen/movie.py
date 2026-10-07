# -*- coding: utf-8 -*-
"""台本と画面をつないで動画にする。

台本（YAML）の行を上から読み、

  ・`screen:` の行  … ここから出す画面を切り替える（画像の名前）
  ・話者の行        … 読み上げて、その長さだけ画面を出す。字幕も焼く

行ごとに声を作って**長さを測る**ので、画面の切り替えは語りに合う。
最後に ffmpeg で連番の画像と音声をつないで mp4 にする。

    python -m danmen.movie 台本.yaml --screens out/screens --out out/試作.mp4

字幕の縁は**縁を全部描いてから本体を描く**（1文字ずつ重ねると、次の字の縁が
前の字を潰す）。数字だけ金の細縁を足す。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import wave
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

from danmen import tts

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
GOLD = (231, 185, 63)
EDGE = (6, 10, 18)
NUM = re.compile(r"(\d+(?:[.,]\d+)*)")
FPS = 30


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def ffmpeg() -> str:
    """ffmpeg の場所。imageio 同梱のものを使う（別に入れなくてよい）。"""
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


# ---- 台本 -------------------------------------------------------------------

def read_script(path: Path) -> list[dict]:
    """台本を、頭から順の指示の列にする。

    返すのは {"screen": 名前} か {"who": 話者, "tone": 強さ, "text": 本文} の並び。
    """
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    out: list[dict] = []
    for sec in data.get("sections", []):
        for line in sec.get("lines", []):
            if not isinstance(line, dict) or len(line) != 1:
                raise SystemExit("読めない行です（節 {}）: {}".format(sec.get("id"), line))
            key, val = next(iter(line.items()))
            if key == "screen":
                out.append({"screen": str(val)})
                continue
            m = re.match(r"^(?P<who>[^\s(（]+)\s*(?:[（(](?P<tone>[^）)]+)[）)])?$", key)
            if not m:
                raise SystemExit("話者の書き方が読めません: {}".format(key))
            out.append({"who": m["who"], "tone": m["tone"] or "ふつう", "text": str(val)})
    return out


# ---- 字幕 -------------------------------------------------------------------

def _wrap(d, text: str, font, width: float) -> list[str]:
    """折り返す。切れるなら**読点・句点のあと**で切る（字幕が読みやすくなる）。"""
    lines, cur = [], ""
    for ch in text:
        cur += ch
        if d.textlength(cur, font=font) > width:
            cut = max(cur.rfind("、"), cur.rfind("。"))
            if cut >= len(cur) * 0.45:
                lines.append(cur[:cut + 1]); cur = cur[cut + 1:]
            else:
                lines.append(cur); cur = ""
    if cur:
        lines.append(cur)
    return lines


def caption(im: Image.Image, text: str, size: int = 74) -> Image.Image:
    """字幕を焼く。縁を全部描いてから本体を描く（潰れを避けるため）。"""
    out = im.convert("RGB").copy()
    d = ImageDraw.Draw(out)
    f = F(size)
    lines = _wrap(d, text, f, W - 220)[:2]
    y0 = H - 60 - len(lines) * int(size * 1.34)
    # 置き場所を先に決めておく（文字ごとの x）
    place: list[tuple[str, float, float, bool]] = []
    for n, ln in enumerate(lines):
        x = (W - d.textlength(ln, font=f)) / 2
        y = y0 + n * int(size * 1.34)
        for part in NUM.split(ln):
            if not part:
                continue
            place.append((part, x, y, bool(NUM.fullmatch(part))))
            x += d.textlength(part, font=f)
    # ① 黒い太い縁を全部
    for part, x, y, _ in place:
        d.text((x, y), part, font=f, fill=EDGE, stroke_width=16, stroke_fill=EDGE)
    # ② 数字だけ金の細い縁
    for part, x, y, is_num in place:
        if is_num:
            d.text((x, y), part, font=f, fill=EDGE, stroke_width=6, stroke_fill=GOLD)
    # ③ 本体
    for part, x, y, is_num in place:
        d.text((x, y), part, font=f, fill=GOLD if is_num else (255, 255, 255))
    return out


# ---- 組み立て ---------------------------------------------------------------

def wav_seconds(p: Path) -> float:
    with wave.open(str(p), "rb") as w:
        return w.getnframes() / w.getframerate()


def build(script: Path, screens_dir: Path, out: Path, config: Path,
          gap: float = 0.28) -> Path:
    cfg = tts.load_config(config)
    steps = read_script(script)
    work = out.parent / "_movie"
    work.mkdir(parents=True, exist_ok=True)
    for old in work.glob("*"):
        old.unlink()

    current: Image.Image | None = None
    current_name = ""
    wavs: list[Path] = []
    shots: list[tuple[Path, float]] = []      # (画像, 出す秒数)
    n = 0
    for step in steps:
        if "screen" in step:
            current_name = step["screen"]
            p = screens_dir / (current_name + ".png")
            if not p.exists():
                raise SystemExit("画面が見つかりません: {}".format(p))
            current = Image.open(p).convert("RGB")
            if current.size != (W, H):
                current = current.resize((W, H), Image.LANCZOS)
            continue
        if current is None:
            raise SystemExit("最初の話者の行より前に screen: がありません")
        style_id, params = tts.params_for(cfg, step["who"], step["tone"])
        wav = work / "{:03d}.wav".format(n)
        wav.write_bytes(tts.synth(cfg["engine_url"], step["text"], style_id, **params))
        wavs.append(wav)
        sec = wav_seconds(wav) + gap
        shot = work / "{:03d}.png".format(n)
        caption(current, step["text"]).save(shot)
        shots.append((shot, sec))
        print("  {:>3}  {:>5.2f}秒  [{}]  {}".format(
            n + 1, sec, current_name, step["text"][:30]))
        n += 1

    if not shots:
        raise SystemExit("話者の行が1つもありません")

    # 音声をつなぐ
    voice = work / "voice.wav"
    tts.join_wavs(wavs, voice, gap_sec=gap)

    # 画像の並びを ffmpeg の concat で渡す
    lst = work / "list.txt"
    with lst.open("w", encoding="utf-8") as fh:
        for p, sec in shots:
            fh.write("file '{}'\n".format(p.as_posix()))
            fh.write("duration {:.3f}\n".format(sec))
        fh.write("file '{}'\n".format(shots[-1][0].as_posix()))   # 最後は1回多く要る

    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [ffmpeg(), "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
           "-i", str(voice), "-c:v", "libx264", "-pix_fmt", "yuv420p",
           "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-shortest", str(out)]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(r.stderr[-2500:], file=sys.stderr)
        raise SystemExit("ffmpeg が失敗しました")
    total = sum(s for _, s in shots)
    print("書き出しました: {}（{:.1f}秒 / 画面 {}枚）".format(out, total, len(shots)))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="台本と画面をつないで動画にする")
    ap.add_argument("script", help="台本（YAML）")
    ap.add_argument("--screens", required=True, help="画面の画像を置いた場所")
    ap.add_argument("--out", default="out/movie.mp4")
    ap.add_argument("--config", default="config.yaml")
    ap.add_argument("--gap", type=float, default=0.28, help="行と行のあいだ（秒）")
    a = ap.parse_args()
    build(Path(a.script), Path(a.screens), Path(a.out), Path(a.config), a.gap)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
