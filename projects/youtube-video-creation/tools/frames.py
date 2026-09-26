# -*- coding: utf-8 -*-
"""書き出した動画から、見せる前に見るべきコマを並べる（2026-09-25）。

    python tools/frames.py output/20260924_zidane            # 1本
    python tools/frames.py output/20260924_*                 # まとめて
    python tools/frames.py output/20260924_zidane --open     # 作ったら開く

**なぜ要るか。**9/25 に「直しました」と言ってから「反映されてない」と
スクショで返されたのが2回。どちらも**台本の文字で確かめて、絵を見ていなかった**。
本文の絵は直っていて、**冒頭の10秒だけ**別の仕組み（サムネの1枚目）で敷かれていた。
相手がスマホで最初に見るのは冒頭の1コマなので、そこを見ずに「直した」と言ってはいけない。

並べるのは4コマ。**0:03（冒頭）／山場の節の頭／60秒／最後の5秒前**。
出力は `output/<名前>/frames.png`。見せる前に、これを開いて自分の目で見る。
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.ffmpeg import ffmpeg_exe  # noqa: E402


def _duration(video: Path) -> float:
    """尺。ffprobe は同梱されていないので、ffmpeg の stderr の Duration を読む。"""
    import re

    done = subprocess.run([ffmpeg_exe(), "-i", str(video)], capture_output=True,
                          encoding="utf-8", errors="replace")
    m = re.search(r"Duration: (\d+):(\d+):(\d+)\.(\d+)", done.stderr or "")
    if not m:
        return 0.0
    h, mi, s, frac = m.groups()
    return int(h) * 3600 + int(mi) * 60 + int(s) + int(frac) / 100


def _main_start(build_dir: Path) -> float | None:
    """山場（@main）の節が始まる秒。script.json の scenes から拾う。"""
    meta = build_dir / "script.json"
    if not meta.exists():
        return None
    try:
        data = json.loads(meta.read_text(encoding="utf-8"))
    except Exception:
        return None
    t = 0.0
    for scene in data.get("scenes", []):
        if scene.get("main") or scene.get("is_main"):
            return t
        for line in scene.get("lines", []):
            t += float(line.get("duration") or 0.0)
    return None


def _grab(video: Path, at: float, out: Path) -> bool:
    done = subprocess.run([ffmpeg_exe(), "-y", "-ss", f"{max(0.0, at):.2f}", "-i", str(video),
                           "-frames:v", "1", str(out)], capture_output=True)
    return out.exists()


def sheet(build_dir: Path) -> Path | None:
    video = build_dir / "video.mp4"
    if not video.exists():
        print(f"× 動画がありません: {video}")
        return None
    total = _duration(video)
    marks = [("冒頭 0:03", 3.0)]
    main = _main_start(build_dir)
    if main is not None:
        marks.append(("山場の頭", main + 1.0))
    if total > 70:
        marks.append(("60秒", 60.0))
    if total > 10:
        marks.append(("最後の5秒前", total - 5.0))

    tmp = build_dir / "_frames"
    tmp.mkdir(exist_ok=True)
    tiles: list[tuple[str, Image.Image]] = []
    for label, at in marks:
        f = tmp / f"{int(at)}.png"
        if _grab(video, at, f):
            im = Image.open(f).convert("RGB")
            im.thumbnail((640, 640))
            tiles.append((label, im))
    if not tiles:
        return None

    w = max(im.width for _, im in tiles)
    h = max(im.height for _, im in tiles) + 28
    cols = 2
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (w * cols + 8 * (cols + 1), h * rows + 8 * (rows + 1)), (12, 12, 12))
    draw = ImageDraw.Draw(out)
    try:
        from src.config import load_config

        font = ImageFont.truetype(str(load_config().video.font_path()), 18)
    except Exception:
        font = ImageFont.load_default()
    for i, (label, im) in enumerate(tiles):
        x = 8 + (i % cols) * (w + 8)
        y = 8 + (i // cols) * (h + 8)
        draw.text((x + 4, y + 2), f"{build_dir.name}  {label}", fill=(240, 240, 240), font=font)
        out.paste(im, (x, y + 24))
    path = build_dir / "frames.png"
    out.save(path)
    return path


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("dirs", nargs="+", help="build の出力先")
    ap.add_argument("--open", action="store_true", help="作ったら開く")
    args = ap.parse_args(argv)
    made = []
    for d in args.dirs:
        path = sheet(Path(d))
        if path:
            made.append(path)
            print(f"  {path}")
    if args.open:
        for path in made:
            subprocess.run(["cmd", "/c", "start", "", str(path)], capture_output=True)
    return 0 if made else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
