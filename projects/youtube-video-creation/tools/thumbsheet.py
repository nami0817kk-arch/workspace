"""台本と一緒にサムネを見せるための1枚（2026-09-25「サムネを作って見して」→ 09-28 に道具化）。

`python tools/thumbsheet.py <台本…> [--out <png>]`。台本ごとに `thumbnail` を作り直し、
出来た `output/<名前>/thumbnail.png` を縦に並べて1枚にする（3列まで。9枚なら3×3）。
9/28 までは scratchpad で毎回手で並べていたので、道具にした（品質100回の81）。
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TILE = (640, 360)


def sheet(thumbs: list[Path], out: Path, columns: int = 3) -> Path:
    """サムネの画像を並べて1枚にする。空のリストは作らない。"""
    if not thumbs:
        raise ValueError("サムネがありません")
    tiles = [Image.open(p).convert("RGB") for p in thumbs]
    for im in tiles:
        im.thumbnail(TILE)
    cols = min(columns, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * (TILE[0] + 10) + 10, rows * (TILE[1] + 34) + 10), (22, 22, 22))
    draw = ImageDraw.Draw(canvas)
    for i, (im, src) in enumerate(zip(tiles, thumbs)):
        x = 10 + (i % cols) * (TILE[0] + 10)
        y = 10 + (i // cols) * (TILE[1] + 34)
        canvas.paste(im, (x, y))
        draw.text((x, y + TILE[1] + 6), src.parent.name, fill=(230, 230, 230))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("scripts", nargs="+")
    ap.add_argument("--out", default="")
    ap.add_argument("--no-build", action="store_true", help="thumbnail を作り直さず、あるものを並べる")
    args = ap.parse_args(argv)
    thumbs: list[Path] = []
    for script in args.scripts:
        name = Path(script).stem
        if not args.no_build:
            subprocess.run([sys.executable, "-m", "src.cli", "thumbnail", script], cwd=ROOT, check=False)
        png = ROOT / "output" / name / "thumbnail.png"
        if png.exists():
            thumbs.append(png)
        else:
            print(f"サムネがありません: {png}", file=sys.stderr)
    if not thumbs:
        return 1
    out = Path(args.out) if args.out else ROOT / "output" / "pages" / f"thumbs_{Path(args.scripts[0]).stem[:8]}.png"
    print(sheet(thumbs, out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
