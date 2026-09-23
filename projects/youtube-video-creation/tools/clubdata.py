"""クラブの「基礎DATA」板をつくる（2026-09-19／2026-09-23 に作り直した）。

**2026-09-23 指摘「基礎データの画面があまりにもパクリなので、改変して」。**
はじめの板は、見本として提示されたサッカーキングのクラブ紹介動画と
**同じ形（クラブの色の地に、白いカードを3列×3段）**だった。形だけ借りた
つもりでも、並べれば同じ画面に見える。**こちらの形に作り直した。**

    旧: クラブの色の地 ＋ 白いカード9枚のタイル（3×3）＋ 上の帯に紋章と題
    新: 黒に近い地 ＋ 左の柱（紋章・クラブ名）＋ 右に9行の一覧（罫線1本ずつ）

一覧の形にしたのは、**読み上げが9項目を上から順に読むから**。タイルの格子だと
「いまどれを話しているか」が目で追えない（読む順と並びが一致しない）。
1行ずつ縦に並べれば、明るい行が上から下へ降りていく。

    python tools/clubdata.py assets/stats/pl_villa_data.png --spec data.json

spec の形（**変えていない**。20クラブの `<key>.json` はそのまま使える）:

    {"title": "アストン・ヴィラ 基礎DATA",
     "colors": ["#670E36", "#95BFE5"],     # 地の色, 差し色
     "crest": "assets/crests/アストンヴィラ.png",
     "tiles": [["クラブ創立", "1874年", "4人の青年が立ち上げた"], ...]}   # 見出し, 大きな字, 小さな字

行は9つまで。**大きな字は短く**（10字前後）。長い説明は小さな字へ。

**「いま見る理由」も、この板に入れる**（2026-09-23 指示「基礎データに今見る理由もいれよう」）。
`--reason` で渡した3つまでの一言が**左の柱**に並ぶ（柱の下が空いていた）。
理由を読み上げている行は `--focus reasons` で、柱だけを明るく残す。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.config import load_config  # noqa: E402

SIZE = (1280, 720)
RAIL = 340                 # 左の柱の幅
MARGIN = 40
ROWS_MAX = 9
NEAR_BLACK = (12, 12, 16)
VALUE = (246, 245, 250)
NOTE = (156, 152, 166)


def _rgb(code: str) -> tuple[int, int, int]:
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _lum(c: tuple[int, int, int]) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _readable(c: tuple[int, int, int]) -> tuple[int, int, int]:
    """暗い地に置くので、沈む差し色は白へ寄せる。

    差し色が黒のクラブ（ボーンマス・ニューカッスル…）がそのままだと、
    見出しも罫線も**地に溶けて消える**。
    """
    while _lum(c) < 150:
        c = _mix(c, (255, 255, 255), 0.25)
        if _lum(c) > 240:
            break
    return c


def _fit(draw: ImageDraw.ImageDraw, text: str, path: str, size: int, width: int,
         floor: int = 14) -> ImageFont.FreeTypeFont:
    """幅に収まるまで字を縮める。"""
    while size > floor:
        font = ImageFont.truetype(path, size)
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 2
    return ImageFont.truetype(path, size)


def _wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, cur = [], ""
    for ch in text:
        if draw.textlength(cur + ch, font=font) > width and cur:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def _name_and_eyebrow(title: str) -> tuple[str, str]:
    """「AFCボーンマス 基礎DATA」→（クラブ名, 上に小さく出す字）。"""
    for tail in ("基礎DATA", "基礎データ"):
        if title.endswith(tail):
            return title[: -len(tail)].strip(), tail
    return title, "基礎DATA"


def build(out: Path, spec: dict, focus: int | str | None = None) -> Path:
    """`focus` に番号（0始まり）を渡すとその行だけ、`"reasons"` を渡すと柱だけを明るく残す。

    **板を1枚のまま48秒出すと、画面が止まる**（2026-09-20）。読み上げは
    9つの項目を順に説明しているのに、絵は1枚も変わっていなかった。
    いま話している行だけを明るく残せば、**読み上げと画面が一致したまま
    1行ごとに絵が変わる**（テロップを重ねずに済む）。
    """
    font = str(load_config().video.font_path())
    base, accent = (_rgb(c) for c in spec["colors"])
    ground = _mix(base, NEAR_BLACK, 0.90)
    rail_bg = _mix(base, NEAR_BLACK, 0.74)
    if _lum(rail_bg) < 22:      # 地が黒のクラブ（フラム・ハル）だと柱が消える
        rail_bg = (26, 26, 32)
    tint = _readable(accent if _lum(accent) > 40 or _lum(base) < 40 else base)
    reasons = [str(r) for r in (spec.get("reasons") or []) if str(r).strip()][:3]
    # focus="reasons" で柱ぜんぶ、"reasons:2" なら2つめだけを明るく残す
    one = 0
    if isinstance(focus, str) and focus.startswith("reasons:"):
        one, focus = int(focus.split(":")[1]), "reasons"

    board = Image.new("RGB", SIZE, ground)
    draw = ImageDraw.Draw(board)

    # 左の柱。クラブの色を残すのはここだけで、一覧の地は黒に近いまま
    draw.rectangle([0, 0, RAIL, SIZE[1]], fill=rail_bg)
    draw.rectangle([RAIL - 3, 0, RAIL, SIZE[1]], fill=tint)

    name, eyebrow = _name_and_eyebrow(spec["title"])
    inner = RAIL - 2 * 28
    draw.text((28, 34), eyebrow, font=ImageFont.truetype(font, 22), fill=tint)

    crest = None
    if spec.get("crest") and Path(spec["crest"]).exists():
        crest = Image.open(spec["crest"]).convert("RGBA")
        crest.thumbnail((inner, 132 if reasons else 164))

    # **まず1行に収める。**折り返すと「AFCボーン／マス」のように語の途中で切れる
    nf = _fit(draw, name, font, 46 if not reasons else 40, inner, floor=26)
    lines = [name] if draw.textlength(name, font=nf) <= inner else None
    if lines is None:
        nf = ImageFont.truetype(font, 30)
        lines = _wrap(draw, name, nf, inner)
    step = round(nf.size * 1.28)

    block = (crest.height + 26 if crest else 0) + step * len(lines)
    # 理由を置く回は上から積む（柱の下に並べるため）。置かない回は縦の真ん中へ
    top = 74 if reasons else max(96, (SIZE[1] - block) // 2)
    if crest:
        board.paste(crest, (28, top), crest)
        top += crest.height + 26
    for i, line in enumerate(lines):
        draw.text((28, top + i * step), line, font=nf, fill=VALUE)
    top += step * len(lines)

    # **いま見る理由**（2026-09-23）。柱の下半分に、番号を振って並べる
    if reasons:
        lit = focus is None or focus == "reasons"
        rf = ImageFont.truetype(font, 20)
        nfont = ImageFont.truetype(font, 17)
        top += 26
        draw.line([(28, top), (RAIL - 28, top)], fill=tint if lit else _mix(rail_bg, tint, 0.4))
        top += 22
        draw.text((28, top), "いま見る理由", font=ImageFont.truetype(font, 21),
                  fill=tint if lit else _mix(rail_bg, tint, 0.34))
        top += 36
        for i, text in enumerate(reasons):
            # 1つだけ明るくするときは、その1つ以外を落とす
            here = lit and (not one or one == i + 1)
            draw.ellipse([28, top + 3, 28 + 20, top + 23],
                         fill=tint if here else _mix(rail_bg, tint, 0.3))
            draw.text((38, top + 13), str(i + 1), font=nfont, anchor="mm",
                      fill=rail_bg if here else _mix(rail_bg, VALUE, 0.2))
            for j, line in enumerate(_wrap(draw, text, rf, inner - 30)):
                draw.text((58, top + j * 27), line, font=rf,
                          fill=VALUE if here else _mix(rail_bg, VALUE, 0.34))
            top += 27 * len(_wrap(draw, text, rf, inner - 30)) + 16

    # 一覧。1行＝見出し・大きな字・小さな字
    tiles = spec["tiles"][:ROWS_MAX]
    x0, x1 = RAIL + MARGIN, SIZE[0] - MARGIN
    y0, y1 = 30, SIZE[1] - 30
    h = (y1 - y0) // max(len(tiles), 1)
    rule = _mix(ground, (255, 255, 255), 0.14)
    for i, (label, big, small) in enumerate(tiles):
        y = y0 + i * h
        lit = focus is None or i == focus
        if focus is not None and i == focus:
            draw.rectangle([RAIL + 3, y, SIZE[0], y + h], fill=_mix(ground, tint, 0.16))
            draw.rectangle([RAIL + 3, y, RAIL + 11, y + h], fill=tint)
        if i:
            draw.line([(x0, y), (x1, y)], fill=rule if lit else _mix(ground, rule, 0.45))

        def dim(c: tuple[int, int, int]) -> tuple[int, int, int]:
            return c if lit else _mix(ground, c, 0.34)

        draw.text((x0, y + 8), label, font=_fit(draw, label, font, 22, 300), fill=dim(tint))
        note_w = 0
        if small:
            nf = _fit(draw, small, font, 21, 420, floor=15)
            note_w = round(draw.textlength(small, font=nf)) + 24
            draw.text((x1 - note_w + 24, y + h - 34), small, font=nf, fill=dim(NOTE))
        bf = _fit(draw, big, font, 40, x1 - x0 - note_w)
        draw.text((x0, y + 26), big, font=bf, fill=dim(VALUE))

    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--spec", required=True, help="板の中身（JSON）")
    ap.add_argument("--focus", help="この行だけを明るく残す（0始まり。reasons で柱、reasons:2 で理由2つめ）")
    ap.add_argument("--reason", action="append", default=[], help="柱に並べる「いま見る理由」（3つまで）")
    args = ap.parse_args()
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    if args.reason:
        spec = dict(spec, reasons=args.reason)
    focus = args.focus
    if focus is not None and not str(focus).startswith("reasons"):
        focus = int(focus)
    if len(spec.get("tiles", [])) > ROWS_MAX:
        print(f"■ 行は{ROWS_MAX}つまで（それ以上は字が読めない）", file=sys.stderr)
        return 1
    print(f"基礎DATA板: {build(Path(args.out), spec, focus)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
