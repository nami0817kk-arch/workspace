"""節の頭に差し込む「紋章（国旗）の全面絵」を作り、取材メモに貼る行を出す（2026-10-15）。

ユーザー「全部！」。参考のシリーズ（クラックフットボール）は、話の節目に紋章・旗・トロフィーなどの
アップを差し込んで場面を切り替える。こちらのシリーズは写真1枚に板を重ねる形が多かった。

    python tools/cutaway.py アーセナル 日本代表
    python tools/cutaway.py アーセナル --back assets/images/20261016_xxx/01.jpg

やること
1. 手元のエンブレム・国旗（`assets/crests/`）から、クラブの色のグラデーションの中央にエンブレムを大きく置いた絵を作る。
   `tools/crestbg.py` の下地は右上に小さく置く別の用途（カードとテロップを避ける）なので流用しない。 `assets/backgrounds/cut_<名前>.png`（1920x1080。エンブレムを中央に大きく）を作る
2. 取材メモの行に貼る `image:` の2行を出す。**差し込みの行**と、**元の写真へ戻す次の行**の2つ。
   写真は次の行へ引き継がれるので、戻さないと紋章のまま最後まで残る

使いどころ（目安）
- 節が替わる所で、その節の主役のクラブ・国を1行だけ見せる（**1節に1回まで**。多いと「目的なく画面を変える」になる）
- 板（表・グラフ）が出る行には使わない（板の下地が替わるだけで見えない）
- 人の話の回で、その人の顔写真が出ている行には使わない

**クラブの紋章の権利は晴れていない**（引き受ける危険。CLAUDE.md「クラブのエンブレムを小さく添える」と同じ）。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, ".")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import crestbg  # noqa: E402
from PIL import Image, ImageFilter  # noqa: E402

from src import crest  # noqa: E402

W, H = 1920, 1080
CREST_H = 480                 # 中央に大きく（元の画像が小さいので、これ以上は伸ばさない。伸ばすとぼやける）
OUT = Path("assets/backgrounds")


def make(name: str) -> Path:
    """クラブの色のグラデーションの中央に、エンブレムを大きく置いた全面の絵。"""
    path = crest.find(name)
    if not path:
        raise SystemExit(f"エンブレムがありません: {name}")
    emblem = Image.open(path).convert("RGBA")
    canvas = crestbg.gradient(crestbg.club_color(emblem)).convert("RGBA")
    big_h = int(H * 1.3)
    big = emblem.resize((int(emblem.width * big_h / emblem.height), big_h), Image.LANCZOS)
    pad = 300                                   # ぼかす前に余白を足す（足さないと端が四角く切れて縁が出る）
    padded = Image.new("RGBA", (big.width + pad * 2, big.height + pad * 2), (0, 0, 0, 0))
    padded.paste(big, (pad, pad))
    big = padded.filter(ImageFilter.GaussianBlur(90))
    big.putalpha(big.getchannel("A").point(lambda v: int(v * 0.35)))
    canvas.alpha_composite(big, (W // 2 - big.width // 2, H // 2 - big.height // 2))
    height = CREST_H
    width = int(emblem.width * height / emblem.height)
    if width > 1100:                       # 横に広いエンブレム
        width, height = 1100, int(emblem.height * 1100 / emblem.width)
    sharp = emblem.resize((width, height), Image.LANCZOS)
    canvas.alpha_composite(sharp, (W // 2 - width // 2, int(H * 0.46) - height // 2))
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"cut_{name}.png"              # 名前を stadium で始めない（動画に差し替わる）
    canvas.convert("RGB").save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="+", help="クラブ名・国名（assets/crests/ にあるもの）")
    ap.add_argument("--back", default="", help="差し込みのあとに戻す写真（例: assets/images/…/01.jpg）")
    args = ap.parse_args()
    rc = 0
    for name in args.names:
        try:
            out = make(name)
        except Exception as exc:      # noqa: BLE001
            print(f"× {name}: 作れませんでした（{exc}）。`crest.find` で手元に紋章があるか確かめてください")
            rc = 1
            continue
        print(f"✓ {name}: {out}")
        print("   取材メモの行に（差し込みたい行と、その次の行）:")
        print(f"     - {{text: …, image: {out.as_posix()}}}")
        print(f"     - {{text: …, image: {args.back or '<元の写真>'}}}")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
