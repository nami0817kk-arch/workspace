"""自クラブ用のエンブレム画像(25枚)をアプリの素材と色の表にする。

    python tool/art/build_own_crests.py --cut <切り抜き済みPNGのフォルダ>

- 材料: <cut>/00.png〜24.png(透明の地・正方形)。並びと色は下の OWN の表。
- 出力: assets/crests/own_NN.webp(既定 160px・品質80。白いふちの外し方と
  縮め方は build_crests.py と同じ)と lib/data/own_crest_hues.dart。

Pillow と numpy が要る。プロジェクト直下(projects/soccer-manager)で実行する。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_crests import ROOT, convert  # noqa: E402

# (中身, 地の色相, 差し色の色相)。-1 は白・黒・灰・銀。
# 両方とも -1 の絵(15 の狼: 黒と銀)は、地を夜の紺に寄せる
# (ClubPalette は色相1つで色を作るので、どちらかは色が要る)。
OWN: list[tuple[str, int, int]] = [
    ("sunrise-waves", 225, 200),  # navy / sky blue
    ("phoenix", 350, 45),  # crimson / gold
    ("mountain-pine", 150, -1),  # emerald / white
    ("fox", -1, 30),  # black / orange
    ("lightning", 220, 55),  # royal blue / yellow
    ("crown", 275, 45),  # purple / gold
    ("koi", 180, 10),  # teal / coral
    ("crane", -1, 0),  # white / red
    ("tiger", 30, 225),  # orange / navy
    ("swallow", 200, 225),  # sky blue / navy
    ("kabuto", 350, -1),  # maroon / silver
    ("hawk", 55, -1),  # yellow / black
    ("oak-leaf", 120, 45),  # green / gold
    ("anchor-star", 225, 45),  # navy / gold
    ("horse", 0, -1),  # red / white
    ("wolf-moon", 230, -1),  # black / silver
    ("sakura", 245, 340),  # indigo / pink
    ("castle-tower", 70, 45),  # olive / cream
    ("dolphin", 190, -1),  # cyan / white
    ("lion", 45, 25),  # gold / brown
    ("dragon", 315, 45),  # magenta / gold
    ("stag", 130, 55),  # forest green / yellow
    ("flame", -1, 0),  # charcoal / red
    ("compass", -1, 225),  # white / navy
    ("eagle", 215, 30),  # blue / orange
]


def write_dart(out: Path) -> None:
    lines = [
        "// 生成物。手で直さない(tool/art/build_own_crests.py が作る)。",
        "",
        "/// 自クラブ用のエンブレム画像(assets/crests/own_NN.webp)の2色の色相。",
        "/// 番号 i の色は [i * 2](地)と [i * 2 + 1](差し色)。-1 は白・黒・灰。",
        "const List<int> kOwnCrestHues = [",
    ]
    for i, (name, a, b) in enumerate(OWN):
        lines.append(f"  {a}, {b}, // {i:02d} {name}")
    lines += ["];", "", f"const int kOwnCrestCount = {len(OWN)};", ""]
    out.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cut", required=True, type=Path)
    ap.add_argument("--size", type=int, default=160)
    ap.add_argument("--quality", type=int, default=80)
    ap.add_argument("--defringe", type=int, default=5)
    ap.add_argument("--assets-out", type=Path, default=ROOT / "assets" / "crests")
    ap.add_argument("--dart-out", type=Path,
                    default=ROOT / "lib" / "data" / "own_crest_hues.dart")
    args = ap.parse_args()

    for i, (_, a, b) in enumerate(OWN):
        if a == -1 and b == -1:
            sys.exit(f"{i:02d} の色相が両方とも白黒灰")
    missing = [i for i in range(len(OWN)) if not (args.cut / f"{i:02d}.png").exists()]
    if missing:
        sys.exit(f"画像が無い: {missing}")

    args.assets_out.mkdir(parents=True, exist_ok=True)
    total = 0
    for i in range(len(OWN)):
        total += convert(args.cut / f"{i:02d}.png", args.assets_out / f"own_{i:02d}.webp",
                         args.size, args.quality, args.defringe)
    write_dart(args.dart_out)
    print(f"{len(OWN)} 枚 / 合計 {total / 1024:.1f} KiB -> {args.assets_out}")
    print(f"色の表 -> {args.dart_out}")


if __name__ == "__main__":
    main()
