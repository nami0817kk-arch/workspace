"""縦の写真を、顔を残して 16:9 に切る（2026-09-28 指示「同じ選手を横並びにするのはやめよう」）。

    python tools/widecrop.py assets/images/20261001_haaland_face/01.jpg --dir assets/images/20261001_haaland_face_w --top 0.08

縦写真を2枚横に並べる `pairphoto.py` は、同じ人を2枚並べる形になると使えない。
元が大きい縦写真（3000px 以上）なら、上のほうを 16:9 に切っても顔は十分大きい。
`--top` は切り出しの上端（画像の高さに対する割合）。出典の控え（credits.json）は元の写真のものを引き継ぐ。
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image


def crop_wide(src: Path, out_dir: Path, top: float = 0.08, min_width: int = 1200) -> Path:
    image = Image.open(src).convert("RGB")
    w, h = image.size
    target_h = int(w * 9 / 16)
    if target_h > h:
        raise SystemExit(f"横長の写真です（{w}x{h}）。切る必要がありません")
    if w < min_width:
        print(f"注意: 幅が {w}px しかありません。1920 に伸ばすと粗くなります", file=sys.stderr)
    y0 = int(max(0, min(h - target_h, h * top)))
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "01.jpg"
    image.crop((0, y0, w, y0 + target_h)).save(out, quality=94)
    credits = src.parent / "credits.json"
    if credits.exists():
        data = json.loads(credits.read_text(encoding="utf-8"))
        note = f"{src.parent.name} の写真を 16:9 に切ったもの（上端 {top:.2f}）"
        if isinstance(data, dict):
            data["note"] = note
        (out_dir / "credits.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("photo")
    ap.add_argument("--dir", required=True)
    ap.add_argument("--top", type=float, default=0.08)
    args = ap.parse_args(argv)
    out = crop_wide(Path(args.photo), Path(args.dir), args.top)
    print(f"  {out}  → 台本に: image: {out.as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
