"""本編(横 16:9・15 分前後)を、章ごとの回をつないで作る。

episodes/<題材>/long.py に LONG = dict(title="…", parts=[dict(title="章の題", ep="章のフォルダ名"), …]) を置く。
章のフォルダはそれぞれ普通の回(ep.py に aspect="landscape")。地形の章と計算の章を混ぜてよい。

python -m naze long episodes/<題材> [--skip-build]
  1. 章ごとに `python -m naze all` を回す(--skip-build ならできている mp4 を使う。地形の章は途中から再開できる)
  2. 章の頭に 2 秒の章の札を入れる(最初の章は札なし。冒頭はすぐ本題に入る)
  3. 全部をつないで out/<題材>/<題材>.mp4 と、概要欄に貼る目次 chapters.txt(0:00 から)を書く
"""
from __future__ import annotations

import importlib.util
import os
import re
import subprocess
import sys
from pathlib import Path

CARD_SEC = 2.0


def _load(folder: Path) -> dict:
    sp = importlib.util.spec_from_file_location("long_" + folder.name, folder / "long.py")
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    return mod.LONG


def _duration(ff: str, video: Path) -> float:
    r = subprocess.run([ff, "-i", str(video)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def _card(ff: str, n: int, title: str, out: Path) -> Path:
    """章の札(紺の地に「第n章」と章の題)。音は無音。"""
    from PIL import Image, ImageDraw
    from . import overlay as ov
    from .config import FPS, H, W
    img = Image.new("RGB", (W, H), (8, 16, 36))
    dr = ImageDraw.Draw(img)
    ov.rows(dr, f"第{n}章", H * 0.40, 60, color=ov.OCHRE, stroke=0)
    ov.rows(dr, title, H * 0.53, 96, stroke=0)
    dr.line([(W * 0.3, H * 0.62), (W * 0.7, H * 0.62)], fill=ov.OCHRE, width=3)
    png = out.with_suffix(".png")
    img.save(png)
    subprocess.run([ff, "-y", "-loglevel", "error", "-loop", "1", "-i", str(png), "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
                    "-t", str(CARD_SEC), "-r", str(FPS), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
                    "-ar", "48000", str(out)], check=True)
    return out


def _stamp(sec: float) -> str:
    sec = int(sec)
    return f"{sec // 3600}:{sec % 3600 // 60:02d}:{sec % 60:02d}" if sec >= 3600 else f"{sec // 60}:{sec % 60:02d}"


def main(folder: Path, args) -> int:
    os.environ["NAZE_ASPECT"] = "landscape"
    from .config import OUT, ffmpeg
    ff = ffmpeg()
    L = _load(folder)
    out = OUT / folder.name
    out.mkdir(parents=True, exist_ok=True)
    pieces, toc, t = [], [], 0.0
    for i, part in enumerate(L["parts"], 1):
        pf = folder / part["ep"]
        video = OUT / f"{folder.name}_{pf.name}" / f"{folder.name}_{pf.name}.mp4"
        if "--skip-build" not in args or not video.exists():
            r = subprocess.run([sys.executable, "-m", "naze", "all", str(pf)])
            if r.returncode != 0:
                raise SystemExit(f"章 {i}({part['title']})の書き出しが失敗した")
        if i > 1:
            pieces.append(_card(ff, i, part["title"], out / f"card_{i:02d}.mp4"))
        toc.append(f"{_stamp(t)} {part['title']}")
        t += (CARD_SEC if i > 1 else 0.0) + _duration(ff, video)
        pieces.append(video)
    lst = out / "concat.txt"
    lst.write_text("".join(f"file '{p.resolve().as_posix()}'\n" for p in pieces), encoding="utf-8")
    final = out / f"{folder.name}.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c:v", "libx264", "-preset", "medium", "-crf", "20",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-movflags", "+faststart", str(final)], check=True)
    (out / "chapters.txt").write_text("\n".join(toc) + "\n", encoding="utf-8")
    print(final)
    print("\n".join(toc))
    print(f"長さ {_stamp(_duration(ff, final))}")
    return 0
