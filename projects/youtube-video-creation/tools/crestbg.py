"""クラブのエンブレムから、その回ぜんぶで使う下地を作る（2026-09-16）。

**プレミアリーグ20クラブ紹介のための下地**（ユーザー決定「エンブレムにしましょう」）。
それまでの指定はヴォルフスブルクのスタジアムの実写で、**LEDの看板に
VFL WOLFSBURG と読める**ものだった。プレミアの紹介を20本続けてドイツの
スタジアムの前で喋ることになるので、下地そのものをクラブのエンブレムにする。

    python tools/crestbg.py ボーンマス アーセナル …
    python tools/crestbg.py --all-premier          # 台本の crest_main から拾う

できるもの: ``assets/backgrounds/crest_<クラブ名>.png``（1920x1080）

**作りは3枚重ね。**
  1. クラブの色から作った、明るい斜めのグラデーション
  2. うんと大きくぼかしたエンブレム（薄く）… 画面の隅まで色を行き渡らせる
  3. くっきりしたエンブレム（上半分の真ん中）… ここが主役

**上半分に置く。**テロップは画面の下 58〜88% に出る（`Layout.headline_box`）ので、
そこへ重ねると字が読めなくなる。カードは上半分に出るが、カードの地は不透明なので
その行だけエンブレムが隠れる形になる。

**名前を `stadium` などにしてはいけない。**render は書き出しのたびに
`moving_background()` を通し、「同じ名前で始まる .mp4 があれば差し替える」ので、
静止画にしたつもりが実写クリップに戻る（2026-09-15 に踏んでいる）。
"""
from __future__ import annotations

import argparse
import glob
import re
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, ".")

from src import crest  # noqa: E402

OUT = Path("assets/backgrounds")
WIDTH, HEIGHT = 1920, 1080
# エンブレムの置き場所。**カードとテロップを避けた右上**。
#   ・テロップは画面の下 58〜88%（`Layout.headline_box`）… y 626 より下は使えない
#   ・カードは幅の64%を真ん中に取る（x 345〜1574）… 真ん中も使えない
# 最初は真ん中に大きく置いたが、**カードの地が半透明なので、エンブレムが
# 表の文字に透けた**（アーセナルの大砲が「The Gunners」に重なっていた。
# 書き出して1枚見るまで気づかなかった）。右の余白（x 1574〜1920）に寄せる
CREST_HEIGHT = 300
CREST_MAX_WIDTH = 320
CREST_CENTER_X = 1738
CREST_CENTER_Y = 360
# ぼかした1枚の濃さ。**濃くすると字が読みにくくなる**ので薄く
BLUR_ALPHA = 0.30
BLUR_SCALE = 2.4


def club_color(image: Image.Image) -> tuple[int, int, int]:
    """エンブレムの中で、いちばん面積の大きい「濃い色」を返す。

    透明なところと、白に近いところは数えない。白を数えると、どのクラブも
    同じ薄い灰色の下地になる（実測でアーセナルとリヴァプールが同じになった）。
    """
    small = image.convert("RGBA").resize((80, 80), Image.LANCZOS)
    counts: dict[tuple[int, int, int], int] = {}
    for r, g, b, a in small.getdata():
        if a < 140:
            continue
        if r > 225 and g > 225 and b > 225:
            continue
        key = (r // 32 * 32, g // 32 * 32, b // 32 * 32)
        counts[key] = counts.get(key, 0) + 1
    if not counts:
        return (40, 70, 110)
    return max(counts, key=lambda k: counts[k])


def _tint(color: tuple[int, int, int], toward: int, amount: float) -> tuple[int, int, int]:
    return tuple(int(c + (toward - c) * amount) for c in color)


def gradient(color: tuple[int, int, int]) -> Image.Image:
    """クラブの色を、**明るいほうへ寄せた**斜めのグラデーション。

    そのままの色だと暗すぎて、白いテロップ以外が沈む。上を薄く、下を少し濃くして、
    画面の下（テロップの出るところ）が落ち着くようにする。
    """
    top = _tint(color, 255, 0.80)
    bottom = _tint(color, 255, 0.55)
    base = Image.new("RGB", (2, 2))
    base.putpixel((0, 0), top)
    base.putpixel((1, 0), _tint(color, 255, 0.72))
    base.putpixel((0, 1), _tint(color, 255, 0.66))
    base.putpixel((1, 1), bottom)
    return base.resize((WIDTH, HEIGHT), Image.BICUBIC)


def make(name: str) -> Path:
    path = crest.find(name)
    if not path:
        raise SystemExit(f"エンブレムがありません: {name}")
    emblem = Image.open(path).convert("RGBA")
    canvas = gradient(club_color(emblem)).convert("RGBA")

    # ② 大きくぼかした1枚
    big_h = int(HEIGHT * BLUR_SCALE)
    big = emblem.resize((int(emblem.width * big_h / emblem.height), big_h), Image.LANCZOS)
    big = big.filter(ImageFilter.GaussianBlur(90))
    faded = big.copy()
    faded.putalpha(faded.getchannel("A").point(lambda v: int(v * BLUR_ALPHA)))
    canvas.alpha_composite(faded, (WIDTH // 2 - faded.width // 2, HEIGHT // 2 - faded.height // 2))

    # ③ くっきりした1枚（右上。カードとテロップを避ける）
    height = CREST_HEIGHT
    width = int(emblem.width * height / emblem.height)
    if width > CREST_MAX_WIDTH:      # 横に広いエンブレム（ハルシティなど）
        width, height = CREST_MAX_WIDTH, int(emblem.height * CREST_MAX_WIDTH / emblem.width)
    sharp = emblem.resize((width, height), Image.LANCZOS)
    canvas.alpha_composite(
        sharp, (CREST_CENTER_X - sharp.width // 2, CREST_CENTER_Y - sharp.height // 2))

    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"crest_{name}.png"
    canvas.convert("RGB").save(out)
    return out


def premier_clubs() -> list[str]:
    names = []
    for script in sorted(glob.glob("scripts/*_pl[0-9]*.md")):
        text = Path(script).read_text(encoding="utf-8")
        got = re.search(r"thumbnail_crest_main:\n- (.+)", text)
        if got:
            names.append(got.group(1).strip())
    return names


def apply_to_scripts() -> int:
    """プレミアの台本20本の `bg:` と `@bg:` を、そのクラブの下地に差し替える。

    **下地は1本のあいだ変えない**（2026-09-14 指示）ので、節ごとの `@bg:` も
    ぜんぶ同じにする。①ボーンマスだけ実写の動画を指していたが、
    ②〜⑳と揃えて止まった下地にする。
    """
    changed = 0
    for script in sorted(glob.glob("scripts/*_pl[0-9]*.md")):
        path = Path(script)
        text = path.read_text(encoding="utf-8")
        got = re.search(r"thumbnail_crest_main:\n- (.+)", text)
        if not got:
            continue
        bg = f"assets/backgrounds/crest_{got.group(1).strip()}.png"
        new = re.sub(r"^bg: .+$", f"bg: {bg}", text, flags=re.M)
        new = re.sub(r"^@bg: .+$", f"@bg: {bg}", new, flags=re.M)
        if new != text:
            path.write_text(new, encoding="utf-8")
            changed += 1
            print(f"  {path.name}　→　{bg}")
    return changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--all-premier", action="store_true")
    ap.add_argument("--apply", action="store_true", help="台本の bg も差し替える")
    args = ap.parse_args()
    names = args.names + (premier_clubs() if args.all_premier else [])
    if not names and not args.apply:
        print("クラブ名を渡してください", file=sys.stderr)
        return 1
    for name in names:
        out = make(name)
        print(f"  {out}　{out.stat().st_size // 1024}KB")
    if args.apply:
        print(f"■ 台本を {apply_to_scripts()}本 差し替えました")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
