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
PORTRAIT = (1080, 1920)   # ショート用の縦版
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


def _rows(draw: ImageDraw.ImageDraw, tiles: list, focus, font: str, ground, tint,
          x0: int, x1: int, y0: int, y1: int, sizes: tuple[int, int, int], left_edge: int) -> None:
    """一覧（1行＝見出し・大きな字・小さな字）。横版でも縦版でも同じ形。"""
    label_size, big_size, note_size = sizes
    h = (y1 - y0) // max(len(tiles), 1)
    rule = _mix(ground, (255, 255, 255), 0.14)
    for i, (label, big, small) in enumerate(tiles):
        y = y0 + i * h
        lit = focus is None or i == focus
        if focus is not None and i == focus:
            draw.rectangle([left_edge, y, x1 + MARGIN, y + h], fill=_mix(ground, tint, 0.16))
            draw.rectangle([left_edge, y, left_edge + 8, y + h], fill=tint)
        if i:
            draw.line([(x0, y), (x1, y)], fill=rule if lit else _mix(ground, rule, 0.45))

        def dim(c):
            return c if lit else _mix(ground, c, 0.34)

        draw.text((x0, y + h * 0.10), label,
                  font=_fit(draw, label, font, label_size, (x1 - x0) // 3), fill=dim(tint))
        note_w = 0
        if small:
            nf = _fit(draw, small, font, note_size, (x1 - x0) // 2, floor=15)
            note_w = round(draw.textlength(small, font=nf)) + 24
            draw.text((x1 - note_w + 24, y + h - note_size * 1.7), small, font=nf, fill=dim(NOTE))
        bf = _fit(draw, big, font, big_size, x1 - x0 - note_w)
        draw.text((x0, y + h * 0.10 + label_size * 1.2), big, font=bf, fill=dim(VALUE))


def _reasons_block(draw: ImageDraw.ImageDraw, reasons: list, font: str, ground, tint,
                   x: int, top: int, width: int, lit: bool, one: int, size: int) -> int:
    """「いま見る理由」を並べる。`one`（1始まり）を渡すと、その1つだけ明るい。"""
    rf = ImageFont.truetype(font, size)
    nfont = ImageFont.truetype(font, round(size * 0.85))
    draw.line([(x, top), (x + width, top)], fill=tint if lit else _mix(ground, tint, 0.4))
    top += round(size * 1.1)
    draw.text((x, top), "いま見る理由", font=ImageFont.truetype(font, round(size * 1.05)),
              fill=tint if lit else _mix(ground, tint, 0.34))
    top += round(size * 1.8)
    r = round(size * 0.5)
    for i, text in enumerate(reasons):
        here = lit and (not one or one == i + 1)
        draw.ellipse([x, top + 3, x + r * 2, top + 3 + r * 2],
                     fill=tint if here else _mix(ground, tint, 0.3))
        draw.text((x + r, top + 3 + r), str(i + 1), font=nfont, anchor="mm",
                  fill=ground if here else _mix(ground, VALUE, 0.2))
        wrapped = _wrap(draw, text, rf, width - r * 2 - 18)
        for j, line in enumerate(wrapped):
            draw.text((x + r * 2 + 18, top + j * round(size * 1.35)), line, font=rf,
                      fill=VALUE if here else _mix(ground, VALUE, 0.34))
        top += round(size * 1.35) * len(wrapped) + round(size * 0.8)
    return top


def build(out: Path, spec: dict, focus=None, portrait: bool = False) -> Path:
    """`focus` に番号（0始まり）を渡すとその行だけ、`"reasons"` で柱だけを明るく残す。

    **板を1枚のまま48秒出すと、画面が止まる**（2026-09-20）。読み上げは
    9つの項目を順に説明しているのに、絵は1枚も変わっていなかった。
    いま話している行だけを明るく残せば、**読み上げと画面が一致したまま
    1行ごとに絵が変わる**（テロップを重ねずに済む）。

    `portrait=True` で **1080x1920 の縦版**（2026-09-23 指示「基礎データも見して」）。
    ショートに 16:9 の板を敷くと左右が切り落とされて読めないので、
    **同じ中身を縦に組み直した板**へ差し替える（`shorts._portrait_boards`）。
    """
    font = str(load_config().video.font_path())
    base, accent = (_rgb(c) for c in spec["colors"])
    ground = _mix(base, NEAR_BLACK, 0.90)
    rail_bg = _mix(base, NEAR_BLACK, 0.74)
    if _lum(rail_bg) < 22:      # 地が黒のクラブ（フラム・ハル）だと柱が消える
        rail_bg = (26, 26, 32)
    tint = _readable(accent if _lum(accent) > 40 or _lum(base) < 40 else base)
    # **強調の記号は板に出さない**（2026-09-24 に画面で見つけた）。読み上げ用の文には
    # `**14回**` のように印が入っていて、テロップは render が色に変えるが、
    # **板は文字としてそのまま描いてしまう**（アーセナルのサムネに `**14回**` と出た）
    reasons = [str(r).replace("*", "") for r in (spec.get("reasons") or []) if str(r).strip()][:3]
    # **クラブのキャッチコピー**（2026-09-23 指示「データにチームのキャッチコピーを
    # 入れてそこを読もう」）。動画の1行目で読む一言を、板の中に置く。
    # これで**最初の画面から基礎DATAの板**になる（それまでは実写1枚だった）
    tagline = str(spec.get("tagline") or "").replace("*", "").strip()
    # focus="reasons" で柱ぜんぶ、"reasons:2" なら2つめだけ、"tagline" でキャッチコピー
    one = 0
    if isinstance(focus, str) and focus.startswith("reasons:"):
        one, focus = int(focus.split(":")[1]), "reasons"
    tagline_lit = focus is None or focus == "tagline"
    reasons_lit = focus is None or focus == "reasons"
    tiles = spec["tiles"][:ROWS_MAX]
    name, eyebrow = _name_and_eyebrow(spec["title"])

    size = PORTRAIT if portrait else SIZE
    board = Image.new("RGB", size, ground)
    draw = ImageDraw.Draw(board)

    def _tagline(x: int, top: int, width: int, ground_here, size: int) -> int:
        """キャッチコピー。**読み上げの1行目がこれ**なので、いちばん上に置く。"""
        if not tagline:
            return top
        tf = ImageFont.truetype(font, size)
        # **3行を超えたら縮める。**柱は下に「いま見る理由」が続くので、あふれると重なる
        while size > 16 and len(_wrap(draw, tagline, tf, width)) > 3:
            size -= 2
            tf = ImageFont.truetype(font, size)
        draw.line([(x, top), (x + width, top)],
                  fill=tint if tagline_lit else _mix(ground_here, tint, 0.4))
        top += round(size * 0.7)
        for line in _wrap(draw, tagline, tf, width):
            draw.text((x, top), line, font=tf,
                      fill=VALUE if tagline_lit else _mix(ground_here, VALUE, 0.34))
            top += round(size * 1.3)
        return top + round(size * 0.5)

    if portrait:
        # 縦版。柱を上の帯へ組み直す（横に置くと一覧の幅が足りない）
        crest = None
        # **上に登録カードが乗る**ので、少し下げる（ショートの1コマ目が一覧の絵になる）
        top = 104
        if spec.get("crest") and Path(spec["crest"]).exists():
            crest = Image.open(spec["crest"]).convert("RGBA")
            crest.thumbnail((220, 220))
            board.paste(crest, (56, top), crest)
        x = 56 + (crest.width + 36 if crest else 0)
        draw.text((x, top + 8), eyebrow, font=ImageFont.truetype(font, 30), fill=tint)
        nf = _fit(draw, name, font, 64, size[0] - x - 56, floor=34)
        draw.text((x, top + 58), name, font=nf, fill=VALUE)
        top += max(crest.height if crest else 0, 150) + 40
        top = _tagline(56, top, size[0] - 112, ground, 40)
        if reasons:
            top = _reasons_block(draw, reasons, font, ground, tint, 56, top,
                                 size[0] - 112, reasons_lit, one, 34) + 30
        _rows(draw, tiles, focus, font, ground, tint, 56, size[0] - 56, top, size[1] - 48,
              (28, 56, 26), 0)
        out.parent.mkdir(parents=True, exist_ok=True)
        board.save(out)
        return out

    # 左の柱。クラブの色を残すのはここだけで、一覧の地は黒に近いまま
    draw.rectangle([0, 0, RAIL, size[1]], fill=rail_bg)
    draw.rectangle([RAIL - 3, 0, RAIL, size[1]], fill=tint)
    inner = RAIL - 2 * 28
    draw.text((28, 34), eyebrow, font=ImageFont.truetype(font, 22), fill=tint)

    crest = None
    if spec.get("crest") and Path(spec["crest"]).exists():
        crest = Image.open(spec["crest"]).convert("RGBA")
        # キャッチコピーと理由の両方を置く回は、紋章を小さくして場所を空ける
        crest.thumbnail((inner, 110 if (reasons and tagline) else 132 if reasons else 164))

    # **まず1行に収める。**折り返すと「AFCボーン／マス」のように語の途中で切れる
    nf = _fit(draw, name, font, 40 if reasons else 46, inner, floor=26)
    lines = [name] if draw.textlength(name, font=nf) <= inner else None
    if lines is None:
        nf = ImageFont.truetype(font, 30)
        lines = _wrap(draw, name, nf, inner)
    step = round(nf.size * 1.28)

    block = (crest.height + 26 if crest else 0) + step * len(lines)
    # 理由を置く回は上から積む（柱の下に並べるため）。置かない回は縦の真ん中へ
    top = 64 if reasons else max(96, (size[1] - block) // 2)
    if crest:
        board.paste(crest, (28, top), crest)
        top += crest.height + 26
    for i, line in enumerate(lines):
        draw.text((28, top + i * step), line, font=nf, fill=VALUE)
    top += step * len(lines)

    top = _tagline(28, top + 20, inner, rail_bg, 30)
    if reasons:
        _reasons_block(draw, reasons, font, rail_bg, tint, 28, top + 12, inner,
                       reasons_lit, one, 20)

    _rows(draw, tiles, focus, font, ground, tint, RAIL + MARGIN, size[0] - MARGIN, 30,
          size[1] - 30, (22, 40, 21), RAIL + 3)
    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("--spec", required=True, help="板の中身（JSON）")
    ap.add_argument("--focus", help="この行だけを明るく残す（0始まり。reasons で柱、reasons:2 で理由2つめ）")
    ap.add_argument("--reason", action="append", default=[], help="柱に並べる「いま見る理由」（3つまで）")
    ap.add_argument("--portrait", action="store_true", help="1080x1920 の縦版（ショート用）")
    ap.add_argument("--tagline", help="クラブのキャッチコピー（読み上げの1行目）")
    args = ap.parse_args()
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    if args.reason:
        spec = dict(spec, reasons=args.reason)
    if args.tagline:
        spec = dict(spec, tagline=args.tagline)
    focus = args.focus
    if focus is not None and not str(focus).startswith(("reasons", "tagline")):
        focus = int(focus)
    if len(spec.get("tiles", [])) > ROWS_MAX:
        print(f"■ 行は{ROWS_MAX}つまで（それ以上は字が読めない）", file=sys.stderr)
        return 1
    print(f"基礎DATA板: {build(Path(args.out), spec, focus, args.portrait)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
