# -*- coding: utf-8 -*-
"""板（カード）の字が、スマホで読める大きさと濃さかを測る。

**板は「資料」ではなく「画面の一部」として見られる。**
1920×1080 の本編をスマホの縦画面で見ると、動画の幅は 390pt ほどしかない。
つまり **1920 の画面での 1px は、スマホでは 0.203pt**。28px の字は 5.7pt になる。

## 基準はどこから来たか

別チャンネル「世の中の断面図」が 2026-10-07 に、作った動画をスマホの実寸
（390×219）に落として目で確かめ、`yononaka-danmen/danmen/typo.py` に基準を置いた。
**いちばん小さい字（出典）でも 1920 の画面で 28px ＝ スマホで 5.7pt。
これが読める下限。** その考え方をこのプロジェクトに引き直したのが下の表。

| 役 | あちらの px（1920 の画面） | スマホ | ここでの目安 |
|---|---|---|---|
| 題 | 58 | 11.8pt | 11.8pt |
| 本文・行の字・列の見出し | 48 | 9.8pt | 9.8pt |
| 数字 | 46 | 9.3pt | 9.3pt |
| 注記・単位・添え | 32 | 6.5pt | 6.5pt |
| 出典 | 28 | 5.7pt | 5.7pt |

**基準は px ではなく pt で持つ。** このプロジェクトは画面の大きさが2つあり、
ショート（1080×1920）はスマホで画面いっぱいに出るので **1px = 0.361pt**。
同じ 28px が本編では 5.7pt、ショートでは 10.1pt に見える。px で引くと嘘になる。

- **×** … スマホで **5.7pt** を下回る（読めない）。1つでもあると終了コード 1
- **△** … 役ごとの目安を下回る（読めるが小さい）。終了コードには数えない

## 板は画面に置くときに縮む

`src/render.py` の `_draw_media` は、板が置き場（`Layout.media_slot`）より高いとき
**全体を縮めて**貼る。だから板の中で 28px で描いた字は、画面では 28px より小さい。
**その倍率を掛けてから pt に直す**のが、この道具のいちばんの仕事。

| 置き方 | 板の幅 | 縮むか |
|---|---|---|
| 本編・単独 | 画面の 0.74（左寄せ） | 置き場の高さに収まるまで縮む |
| 本編・写真と横並び | 画面の 0.52 | 縮まない（`_place_beside` は横幅でしか縮めない） |
| ショート | 画面の 0.90（縦に積む） | 置き場の高さに収まるまで縮む |

CLAUDE.md に「本編の3段の換算は縦に積んで縮むので注記の字が小さい（約22px）」と
書いてあるのを、数字で確かめるために作った。

## コントラスト

WCAG の式（相対輝度の比）で、文字と**その背後の色**の比を出す。
下限は画面での大きさで決める。書体が太字なので **24px 以上は「大きい文字」で 3:1**、
それより小さければ本文あつかいで **4.5:1**。どちらも **4:1 を目安**にする
（「世の中の断面図」の `audit_color.py` が「28px 以上の太字だから 3:1、
ただし 3:1 ちょうどは読みにくいので 4:1 を目安」と置いたのを踏襲した）。

- **半透明の板は、合成したあとの色で測る。** 板の地は alpha 248/255 なので、
  下地の写真がわずかに透ける。**いちばん明るい下地（白）を仮に置く**＝最悪の場合で測る。
  合成前の (12,18,28) で測ると、本番より良い数字が出て嘘になる
- **縁（stroke）が付いている字は、縁の色を背後とみなす。** 写真の上に置く字
  （versus・赤ペンの添え書き）は、背後が写真ごとに変わるので縁で読めるようにしている
- node は呼ばない（系列の色の見分けは `dataviz` の検証ツールの仕事で、ここでは測らない）

## 測り方

PIL のフォントの大きさをあとから拾うのは難しいので、**描いている最中に記録する**。
**`cards.ImageDraw` をこの道具の中だけで差し替え**、`draw.text` を記録してから
本物に同じ引数で渡す。だから出来上がりの絵は1pxも変わらない
（`tests/test_typecheck.py` が、差し替えあり・なしの絵を突き合わせて確かめている）。

**置き場の高さは `cards.render(slot=…)` に渡す**（2026-10-08 に `src/cards.py` 側が
受けるようになった）。渡さないと、本番では置き場に収まるよう詰めた板ではなく、
詰める前の高い板を測ることになる。

背後の色は、**字を描かない2周目**を走らせて「字の下の絵」を作り、
字の枠の中でいちばん多い色を拾う（板の地・緑の箱・光っている行を取り違えない）。

## 使い方

    python tools/typecheck.py                      # 全部の型を1枚ずつ（本編とショート）
    python tools/typecheck.py stats convert        # 型か見本の名前で絞る
    python tools/typecheck.py --note research/20261008_finance_arteta.yaml

控えは `research/metrics/typecheck_<日付>.md` に残る。
"""

from __future__ import annotations

import argparse
import inspect
import sys
import unicodedata
from collections import Counter
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import yaml
from PIL import Image, ImageDraw

from src import cards, marks
from src import render as render_mod
from src.config import load_config

# ---------------------------------------------------------------- 基準の数字

PHONE_PT = 390.0        # スマホの画面の幅（pt）。動画はこの幅いっぱいに出る
FLOOR_PT = 5.7          # 読める下限（typo.CREDIT 28px を 1920 の画面で見た大きさ）
LARGE_PX = 24           # 画面でこの px 以上の太字は WCAG の「大きい文字」（下限 3:1）
NEED_LARGE = 3.0
NEED_SMALL = 4.5
GOOD = 4.0              # 目安。これを切ったら △
EDGE_PX = 2             # これ以上の縁が付いていれば、縁の色を背後とみなす（下限は 3:1）

# 役ごとの目安（pt）。typo.py の表をそのまま pt に直したもの
TARGET_PT = {
    "題": 11.8,
    "列の見出し": 9.8, "行の字": 9.8, "箇条書きの字": 9.8, "本文": 9.8,
    "反応の本文": 9.8, "移籍の行": 9.8, "選手名": 9.8, "名前": 9.8,
    "点の名前": 9.8, "棒の名前と値": 9.8, "背番号と名前": 9.8,
    "数字": 9.3, "記号": 9.3, "スコアとチーム名": 9.3,
    "単位": 6.5, "注記": 6.5, "添え": 6.5, "換算の式": 6.5,
    "軸と目盛り": 6.5, "添え書き": 6.5, "凡例": 6.5,
    "年表の行": 9.8, "段の名前と値": 9.3, "点の値": 9.3,
    "出典": 5.7,
}
DEFAULT_TARGET_PT = 9.8     # 知らない役は本文あつかい（甘く見ない）

# 板の地（PANEL）は alpha 248 なので、下地の写真がわずかに透ける。
# **いちばん明るい下地**を仮に置いて、最悪の場合で測る
BACKDROP = (255, 255, 255)


def phone_pt(px: float, screen_w: int) -> float:
    """その大きさが、スマホでは何 pt に見えるか。

    動画はスマホの画面の幅（390pt）いっぱいに出るので、画面の横 px で割る。
    本編（1920）は 1px=0.203pt、ショート（1080）は 1px=0.361pt。
    """
    return px * PHONE_PT / screen_w


# ---------------------------------------------------------------- 色の計算


def rgb(color) -> tuple[int, int, int]:
    """色を (r, g, b) に。`#rrggbb` も RGBA の4つ組も受ける。"""
    if isinstance(color, str):
        text = color.lstrip("#")
        return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))      # type: ignore[return-value]
    return tuple(int(v) for v in tuple(color)[:3])                    # type: ignore[return-value]


def over(color, backdrop=BACKDROP) -> tuple[int, int, int]:
    """半透明の色を下地に重ねたあとの、実際の色。

    **合成前の色で測ると嘘になる。** 板の地は alpha 248 で、わずかに下地が透ける。
    """
    values = tuple(color) if not isinstance(color, str) else rgb(color) + (255,)
    alpha = (values[3] if len(values) > 3 else 255) / 255.0
    base = rgb(color)
    return tuple(int(round(backdrop[i] * (1 - alpha) + base[i] * alpha)) for i in range(3))


def luminance(color) -> float:
    """WCAG の相対輝度。"""
    def channel(value: float) -> float:
        value /= 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    r, g, b = rgb(color)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(fore, back) -> float:
    """WCAG のコントラスト比（1.0〜21.0）。"""
    a, b = luminance(fore), luminance(back)
    high, low = max(a, b), min(a, b)
    return (high + 0.05) / (low + 0.05)


def hexs(color) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb(color))


# ---------------------------------------------------------------- 描いた字の記録


@dataclass
class Shot:
    """描かれた字ひとつ。板の中の px で記録する（画面の px はあとで倍率を掛ける）。"""

    text: str
    px: int
    fill: tuple
    anchor: str | None
    stroke: int
    stroke_fill: tuple | None
    box: tuple[float, float, float, float] | None
    where: str                  # 描いた関数の名前（役を当てるのに使う）
    role: str = ""


# 描いた関数の名前 → 役。`src/cards.py` の関数名なので、あちらが変われば
# 「字（関数名）」として出る（黙って落とさない）
_ROLE_BY_FUNC = {
    "render": "出典",
    "render_versus": "全画面の字",
    "_title_block.<locals>.<lambda>": "題",
    "_bars.<locals>.<lambda>": "題",
    "_kit.<locals>.<lambda>": "題",
    "_reactions.<locals>.<lambda>": "題",
    "_table.<locals>.draw_head": "列の見出し",
    "_verdict.<locals>.draw_head": "列の見出し",
    "_table.<locals>.draw_row": "行の字",
    "_verdict.<locals>.draw_row": "行の字",
    "_bars.<locals>.draw_row": "棒の名前と値",
    "_kit.<locals>.draw_row": "背番号と名前",
    "_points.<locals>.draw_item": "箇条書きの字",
    "_points.<locals>.<lambda>": "題",
    "_table.<locals>.<lambda>": "題",
    "_stats.<locals>.draw_item": "注記",
    "_calc.<locals>.draw_term": "注記",
    # 2026-10-08 に `_convert` を「横に並べる」「縦に積む」の2つに分けたので、名前が増えた
    "_convert_across.<locals>.draw_value": "注記",
    "_convert_across.<locals>.draw_arrow": "換算の式",
    "_convert_down.<locals>.draw_value": "注記",
    "_convert_down.<locals>.draw_arrow": "換算の式",
    "_scatter.<locals>.draw_axes": "軸と目盛り",
    # 2026-10-08 に、横軸の名前と添えを1行にまとめた段（図を低くするため）
    "_scatter.<locals>.draw_foot": "軸と目盛り",
    # 2026-10-08 に足された3つ（年表・増減の内訳・折れ線）
    "_timeline.<locals>.draw_row": "年表の行",
    "_waterfall.<locals>.draw_head": "題",
    "_waterfall.<locals>.draw_row": "段の名前と値",
    "_line.<locals>.draw_axes": "軸と目盛り",
    "_line.<locals>.draw_legend": "凡例",
    "_line.<locals>.draw_step": "点の値",
    "_scatter.<locals>.draw_point": "点の名前",
    "_transfer.<locals>.draw_move": "移籍の行",
    "_transfer.<locals>.<lambda>": "選手名",
    "_score.<locals>.draw_line": "スコアとチーム名",
    "_score.<locals>.<lambda>": "添え",
    "_reactions.<locals>.draw_bubble": "反応の本文",
    "_text_block.<locals>.draw_text": "本文",
}
_DIGITS = "0123456789０１２３４５６７８９"
_SUB = tuple(cards.SUB[:3])


def role_of(where: str, text: str, px: int, fill, anchor: str | None) -> str:
    """その字の役。描いた関数の名前を主に、色と大きさで細かく分ける。

    `cards.put_number` は数字を大きく・単位を半分で描くので、**同じ呼び出しの中で
    役が2つ**ある。数字で始まるかたまりが「数字」、それ以外が「単位」。
    """
    if "put_number" in where:
        head = str(text)[:1]
        return "数字" if head in _DIGITS else "単位"
    name = where.split(" <- ")[0]
    role = _ROLE_BY_FUNC.get(name)
    if role is None:
        # 知らない描き方。色と大きさから当てて、役の名前に関数名を添える
        guess = "添え" if rgb(fill) == _SUB else ("題" if px >= 44 else "行の字")
        return f"{guess}（{name}）"
    if role == "全画面の字":
        # versus は1つの関数で題・名前・注記・出典を描く
        if anchor == "mm":
            return "題"
        if px <= cards.SOURCE_PX:
            # 写真の出典（2026-10-08 に 22px → 28px）。注記は36px なので境は切れている
            return "出典"
        return "名前" if px >= 56 else "注記"
    if role == "注記" and anchor == "lm":
        return "記号"            # 計算の式の ÷ ＝
    if role in ("本文", "選手名") and rgb(fill) == _SUB:
        return "添え"
    return role


class _Spy:
    """`ImageDraw.ImageDraw` の代わり。`text` を記録してから本物に同じ引数で渡す。

    記録だけが仕事なので、`paint=True` のときの絵は本物と1px も変わらない。
    `paint=False` では字を描かない＝**字の下の色だけ**が残った絵になり、
    コントラストを測るときの「背後の色」が取れる。
    ほかのメソッド（`textlength`・`textbbox`・図形）はそのまま本物へ流す。
    """

    def __init__(self, inner: ImageDraw.ImageDraw, log: list[Shot], paint: bool):
        self._inner = inner
        self._log = log
        self._paint = paint

    def text(self, xy, text, fill=None, font=None, **kw):
        body = str(text)
        if body.strip():
            quals = []
            frame = inspect.currentframe().f_back
            for _ in range(4):
                if frame is None:
                    break
                quals.append(frame.f_code.co_qualname)
                frame = frame.f_back
            where = " <- ".join(quals)
            anchor = kw.get("anchor")
            stroke = int(kw.get("stroke_width") or 0)
            try:
                box = tuple(float(v) for v in self._inner.textbbox(
                    xy, body, font=font, anchor=anchor, stroke_width=stroke))
            except Exception:       # 測れなくても記録は残す（大きさは font から取れる）
                box = None
            px = int(getattr(font, "size", 0) or 0)
            shot = Shot(body, px, tuple(fill) if fill is not None else (255, 255, 255, 255),
                        anchor, stroke,
                        tuple(kw["stroke_fill"]) if kw.get("stroke_fill") is not None else None,
                        box, where)
            shot.role = role_of(where, body, px, shot.fill, anchor)
            self._log.append(shot)
        if self._paint:
            self._inner.text(xy, text, fill=fill, font=font, **kw)

    def __getattr__(self, name):
        return getattr(self._inner, name)


class _Shim:
    """`cards.ImageDraw` に差し込む見せかけのモジュール。`Draw` だけ差し替える。"""

    def __init__(self, log: list[Shot], paint: bool):
        self._log = log
        self._paint = paint

    def Draw(self, image, mode=None):       # noqa: N802  PIL と同じ名前にする
        return _Spy(ImageDraw.Draw(image, mode), self._log, self._paint)

    def __getattr__(self, name):
        return getattr(ImageDraw, name)


def shoot(spec: dict, width: int, size: tuple[int, int], font: str, latin: str,
          out: Path, paint: bool = True, slot: int | None = None) -> tuple[list[Shot], Image.Image]:
    """板を1枚描いて、使った字を全部記録する。`paint=False` なら字を描かない。

    `slot` は置き場の高さ。**`render.py` の `_card` と同じ値を渡す**（2026-10-08 に
    `cards.render` が受けるようになった）。渡さないと、本番より高い板を測ってしまう。
    """
    log: list[Shot] = []
    keep_mod, keep_ruler = cards.ImageDraw, cards._RULER
    cards.ImageDraw = _Shim(log, paint)
    cards._RULER = None
    try:
        if cards.is_full_screen(spec):
            cards.render_versus(spec, size, font, out, latin)
        else:
            cards.render(spec, width, font, out, latin, slot=slot)
    finally:
        cards.ImageDraw = keep_mod
        cards._RULER = keep_ruler
    with Image.open(out) as opened:
        image = opened.convert("RGBA")
    return log, image


# ---------------------------------------------------------------- 置き方


@dataclass(frozen=True)
class Place:
    """板を画面に置く形。`src/render.py` の `_card` と `_draw_media` から引いた。"""

    name: str
    screen: tuple[int, int]
    width: int          # 板を描く幅
    room: int           # 板を置ける高さ（Layout.media_slot）
    beside: bool = False    # 写真と横に並べるか（横並びは高さでは縮まない）

    def scale(self, card_h: int) -> float:
        """板を画面に貼るときの倍率。"""
        if self.beside:
            return 1.0
        return min(1.0, self.room / card_h) if card_h else 1.0

    def overflow(self, card_h: int) -> bool:
        """縮めずに貼るので、置き場からはみ出すか（横並びのときだけ起きる）。"""
        return self.beside and card_h > self.room


def places(config) -> list[Place]:
    """本編とショートの置き方。高さは `render.Layout` から取るので、あちらが変われば付いてくる。"""
    out: list[Place] = []
    for label, size in (("本編", (1920, 1080)), ("ショート", (1080, 1920))):
        layout = render_mod.Layout(size[0], size[1], config.video.show_characters)
        top, bottom = layout.media_slot
        room = bottom - top
        if layout.is_portrait:
            # `_card`: 縦型は幅をほぼ使い切る（0.90）
            out.append(Place(f"{label}・縦に積む", size, int(size[0] * 0.90), room))
        else:
            # `_card`: 立ち絵なしの単独は 0.74、写真と横並びは 0.52
            out.append(Place(f"{label}・単独", size, int(size[0] * 0.74), room))
            out.append(Place(f"{label}・写真と横並び", size, int(size[0] * 0.52), room, beside=True))
    return out


# ---------------------------------------------------------------- 見本の板


def samples(photos: tuple[str, str] | None = None) -> dict[str, dict]:
    """型ごとに1枚ずつ。中身は実際の回（10/8 アルテタの契約）に近づけてある。

    **分量を本物に合わせる**のが大事で、行が1行しかない表を測っても、
    本番で縮む倍率は出てこない。
    """
    out: dict[str, dict] = {
        "quote": {
            "type": "quote", "title": "アルテタの言葉",
            "text": "自分の将来をこのクラブに預けられるのは、光栄なことです。",
            "source": "アーセナル公式",
        },
        "transfer": {
            "type": "transfer", "title": "契約の移り", "player": "ミケル・アルテタ",
            "from": "2026年まで", "to": "2030年6月まで", "fee": "4年で8000万ポンド超",
            "note": "額は報道。クラブは期限だけを出している",
        },
        "score": {
            "type": "score", "title": "第3節", "home": "フラム", "away": "クリスタル・パレス",
            "score": "2-3", "note": "2026年9月・2度追いついて逆転",
        },
        "points": {
            "type": "points", "title": "発表で分かっていること",
            "items": ["期限は2030年6月まで", "さらに4年ぶんの延長", "額はクラブから出ていない"],
            "source": "プレミアリーグ公式",
        },
        "bars": {
            "type": "bars", "title": "報じられている年俸", "unit": "万ポンド",
            "items": [{"label": "アルテタ（監督）", "value": 2500, "highlight": True},
                      {"label": "サカ", "value": 1820},
                      {"label": "ライス", "value": 1248}],
            "note": "週給は52週で足した", "source": "football365",
        },
        "table": {
            "type": "table", "title": "アルテタの新しい契約",
            "columns": ["項目", "内容"],
            "rows": [["契約の期限", "2030年6月まで（4年）"],
                     ["4年の総額", "8000万ポンド超（報道）"],
                     ["年俸", "最大2500万ポンド（報道）"],
                     ["前の契約", "最大1500万ポンド（報道）"],
                     ["就任", "2019年12月22日"],
                     ["指揮した試合", "361試合220勝67分74敗"]],
            "highlight_row": 2, "source": "アーセナル公式・報道",
        },
        "reactions": {
            "type": "reactions", "title": "ネットの反応",
            "items": ["この額を出せるクラブになったということ",
                      "4年は長いけど、いまの順位なら納得",
                      "選手より監督が高いのは少し驚いた"],
        },
        "kit": {
            "type": "kit", "title": "登録の入れ替え",
            "items": [{"player": "遠藤 航", "number": 3, "colors": ["#C8102E"], "mark": "×"},
                      {"player": "エキティケ", "number": 22, "colors": ["#C8102E"], "mark": "○"}],
        },
        "stats": {
            "type": "stats", "title": "アルテタの新しい契約",
            "items": [["4", "年", "2030年6月まで"],
                      ["8000万", "ポンド超", "4年の総額"],
                      ["44", "歳", "スペイン出身"]],
            "focus": 1,
        },
        "verdict": {
            "type": "verdict", "title": "この契約はクラブに見合うか",
            "columns": ["項目", "判定", "一言"],
            "rows": [["成績", "◎", "昨季は勝ち点85"],
                     ["額", "△", "リーグでいちばん高い"],
                     ["期限の長さ", "○", "4年は長いほう"]],
            "highlight_row": 1,
        },
        "calc": {
            "type": "calc", "title": "前の契約の何倍か",
            "terms": [["2500万", "いまの上限"], ["1500万", "前の上限"], ["1.7倍", "伸び"]],
            "ops": ["÷", "＝"], "note": "どちらも報じられた額",
        },
        "scatter": {
            "type": "scatter", "title": "在任の長さと年俸",
            "x": {"label": "在任", "unit": "年"}, "y": {"label": "年俸", "unit": "万ポンド"},
            "points": [["アルテタ", 6.8, 2500], ["エメリ", 3.9, 800],
                       ["デ・ゼルビ", 0.5, 600], ["マレスカ", 0.3, 500]],
            "focus": "アルテタ", "note": "年俸は報じられた額",
        },
        "convert（2段）": {
            "type": "convert", "title": "年俸の上限を円に直すと",
            "from": ["2500万", "ポンド", "年俸の上限"], "to": ["約52", "億円", "1年ぶん"],
            "via": "1ポンド＝209円",
        },
        "timeline": {
            "type": "timeline", "title": "アルテタの契約の移り",
            "rows": [["2019", "アーセナルの監督に就任"], ["2022", "最初の延長（2025年まで）"],
                     ["2024", "2年の延長（2026年まで）"], ["2026", "2030年6月まで4年"]],
            "focus": "2026", "highlight_row": 3,
        },
        "waterfall": {
            "type": "waterfall", "title": "4年の総額の中身",
            "start": ["基本の年俸", 2000], "steps": [["ボーナス", 500], ["前の契約ぶん", -1500]],
            "total": ["上限", 1000], "unit": "万ポンド", "note": "どれも報じられた額",
        },
        "line": {
            "type": "line", "title": "アーセナルの勝ち点の5季",
            "x": ["2021-22", "2022-23", "2023-24", "2024-25", "2025-26"],
            "series": [["アーセナル", [69, 84, 89, 74, 85]],
                       ["リヴァプール", [92, 67, 82, 84, 80]]],
            "unit": "勝ち点", "focus": "アーセナル", "highlight": "2025-26",
        },
        "convert（3段）": {
            "type": "convert", "title": "週給を円に直すと",
            "steps": [["35万", "ポンド", "サカの週給"], ["1820万", "ポンド", "52週ぶん"],
                      ["約38", "億円", "1ポンド＝209円"]],
            "via": ["×52週", "×209円"], "source": "報道",
        },
    }
    if photos:
        out["versus"] = {
            "type": "versus", "title": "在任の長さ",
            "left": {"image": photos[0], "name": "アルテタ", "number": "6.8年", "note": "2019年12月から"},
            "right": {"image": photos[1], "name": "エメリ", "number": "3.9年", "note": "2022年11月から"},
            "credit": "写真: Wikimedia Commons",
        }
    return out


def collect_note(path: str | Path) -> dict[str, dict]:
    """取材メモ（YAML）に実際に書かれた板を拾う。

    板は `card:` の値として、節や行の中に散らばっている。中身が同じものは1つに畳むが、
    畳み方は **`cards.same_table` と同じ見方**にする。つまり**光らせる行
    （`highlight_row`・`highlight`）だけが違う板は同じ1枚**として数える。
    1つの表を1行ずつ光らせる書き方だと、同じ表が10枚並んで表が読めなくなるため。

    代表に採るのは**光らせてある版**（光った行の黄の字・明るい地も測れる）。
    """
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    found: dict[str, dict] = {}
    order: dict[str, str] = {}      # 畳んだ鍵 → 名前
    lit: set[str] = set()           # 光らせてある版を代表に採れた鍵

    def mark_of(spec: dict) -> str:
        plain = {k: v for k, v in spec.items() if k not in cards.HIGHLIGHT_KEYS}
        return cards.card_key(plain, 0)

    def walk(node) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "card" and isinstance(value, dict) and value.get("type"):
                    mark = mark_of(value)
                    shines = any(k in value for k in cards.HIGHLIGHT_KEYS)
                    if mark in order:
                        if shines and mark not in lit:   # 光らせてある版に差し替える
                            found[order[mark]] = value
                            lit.add(mark)
                    else:
                        kind = str(value.get("type"))
                        title = str(value.get("title") or "").strip()
                        name = f"{kind}「{title}」" if title else kind
                        while name in found:
                            name += "（別）"
                        order[mark] = name
                        found[name] = value
                        if shines:
                            lit.add(mark)
                walk(value)
        elif isinstance(node, (list, tuple)):
            for item in node:
                walk(item)

    walk(data)
    return found


# ---------------------------------------------------------------- 測る


@dataclass
class SizeRow:
    """字の大きさ1行ぶん（同じ役・同じ px はまとめてある）。"""

    card: str
    place: str
    role: str
    asked: int          # 板の中で使った px
    scale: float
    screen_px: float
    pt: float
    count: int
    example: str
    mark: str


@dataclass
class ColorRow:
    """コントラスト1行ぶん（同じ役・同じ色の組はまとめてある）。"""

    card: str
    place: str
    role: str
    fore: tuple
    back: tuple
    ratio: float
    screen_px: float
    edged: bool
    need: float
    count: int
    mark: str


@dataclass
class Result:
    sizes: list[SizeRow] = field(default_factory=list)
    colors: list[ColorRow] = field(default_factory=list)
    skipped: list[tuple[str, str, str]] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    @property
    def bad(self) -> list[str]:
        out = [f"{r.card}／{r.place}／{r.role} {r.pt:.1f}pt" for r in self.sizes if r.mark == "×"]
        out += [f"{r.card}／{r.place}／{r.role} {r.ratio:.1f}:1" for r in self.colors if r.mark == "×"]
        return out


def judge_size(pt: float, role: str) -> str:
    """スマホでの実寸から ○△× を付ける。"""
    if pt + 0.05 < FLOOR_PT:
        return "×"
    base = role.split("（")[0]
    if pt + 0.05 < TARGET_PT.get(base, DEFAULT_TARGET_PT):
        return "△"
    return "○"


def need_ratio(screen_px: float, edged: bool) -> float:
    """そのコントラストの下限。縁があれば縁が背後になるので WCAG の 3:1。"""
    if edged:
        return NEED_LARGE
    return NEED_LARGE if screen_px >= LARGE_PX else NEED_SMALL


def judge_contrast(ratio: float, screen_px: float, edged: bool) -> str:
    need = need_ratio(screen_px, edged)
    if ratio + 0.05 < need:
        return "×"
    return "○" if ratio >= GOOD else "△"


def behind(background: Image.Image, shot: Shot) -> tuple[tuple[int, int, int], bool]:
    """その字の背後の色（合成したあと）と、縁で担保しているか。

    まず**字を描かない絵**から、字の枠の中でいちばん多い色を拾って下地に重ねる
    （板の地・緑の箱・光っている行・印の丸地を取り違えないため）。
    縁（stroke）が付いていれば、**縁の色が背後**になる（PIL の縁は字の輪郭を
    なぞるので、字に接しているのは縁）。縁が半透明なら、いま拾った色に重ねてから測る。
    写真の上の字は背後が写真ごとに変わるので、縁で読めるようにしている。
    """
    base = over(cards.PANEL)
    if shot.box is not None:
        x0, y0, x1, y1 = (int(round(v)) for v in shot.box)
        x0, y0 = max(0, x0), max(0, y0)
        x1 = min(background.width, max(x0 + 1, x1))
        y1 = min(background.height, max(y0 + 1, y1))
        if x1 > x0 and y1 > y0:
            # getcolors は色数が上限を超えると None を返す（写真の上の字）。そのときは板の地で見る
            colors = background.crop((x0, y0, x1, y1)).getcolors(maxcolors=1 << 18)
            if colors:
                base = over(max(colors, key=lambda item: item[0])[1])
    if shot.stroke >= EDGE_PX and shot.stroke_fill is not None:
        return over(shot.stroke_fill, backdrop=base), True
    return base, False


def measure(name: str, spec: dict, place: Place, font: str, latin: str,
            work: Path, result: Result) -> None:
    """板を1枚描いて測り、`result` に足す。"""
    if cards.is_full_screen(spec):
        if place.beside:
            return              # 画面いっぱいの絵は写真と並べない
        width, size = place.screen[0], place.screen
    else:
        width, size = place.width, place.screen
    out = work / f"{abs(hash((name, place.name)))}.png"
    try:
        shots, _ = shoot(spec, width, size, font, latin, out, paint=True, slot=place.room)
        _, background = shoot(spec, width, size, font, latin,
                              work / ("bg_" + out.name), paint=False, slot=place.room)
    except Exception as error:
        result.skipped.append((name, place.name, f"{type(error).__name__}: {error}"))
        return
    if not shots:
        result.skipped.append((name, place.name, "字を1つも使っていません"))
        return
    card_h = background.height
    scale = 1.0 if cards.is_full_screen(spec) else place.scale(card_h)
    if place.overflow(card_h):
        result.notes.append(
            f"{name}／{place.name}: 板が {card_h}px で置き場（{place.room}px）を超える。"
            "横並びは縮めずに貼るので、はみ出す（preview4 で見る）")

    # 同じ役・同じ px はまとめる（表が読めなくなる）
    grouped: dict[tuple[str, int], list[Shot]] = {}
    for shot in shots:
        grouped.setdefault((shot.role, shot.px), []).append(shot)
    for (role, asked), group in sorted(grouped.items(), key=lambda kv: (-kv[0][1], kv[0][0])):
        screen_px = asked * scale
        pt = phone_pt(screen_px, place.screen[0])
        result.sizes.append(SizeRow(name, place.name, role, asked, scale, screen_px, pt,
                                    len(group), group[0].text[:18], judge_size(pt, role)))

    # コントラストは「役 × 文字の色 × 背後の色」でまとめる
    pairs: dict[tuple[str, tuple, tuple, bool], list[Shot]] = {}
    for shot in shots:
        back, edged = behind(background, shot)
        pairs.setdefault((shot.role, over(shot.fill), back, edged), []).append(shot)
    for (role, fore, back, edged), group in sorted(pairs.items(), key=lambda kv: kv[0][0]):
        screen_px = max(s.px for s in group) * scale
        ratio = contrast(fore, back)
        result.colors.append(ColorRow(name, place.name, role, fore, back, ratio, screen_px,
                                      edged, need_ratio(screen_px, edged), len(group),
                                      judge_contrast(ratio, screen_px, edged)))


def run(specs: dict[str, dict], config, work: Path) -> Result:
    """全部の板を、全部の置き方で測る。"""
    font = str(config.video.font_path())
    latin = str(config.video.latin_font_path())
    result = Result()
    for place in places(config):
        for name, spec in specs.items():
            measure(name, spec, place, font, latin, work, result)
    return result


# ---------------------------------------------------------------- 赤ペンの添え書き


def mark_rows(config) -> list[SizeRow]:
    """赤ペンの添え書き（`src/marks.py`）の字。

    添え書きは**板の中ではなく画面に直接描く**ので縮まない（`render._draw_marks` は
    画面の大きさで層を作って重ねるだけ）。だから板の字とは分けて測る。
    """
    out: list[SizeRow] = []
    for label, size in (("本編", (1920, 1080)), ("ショート", (1080, 1920))):
        for order, px in enumerate(marks.NOTE_SIZES):
            name = ("大", "中", "小")[order] if order < 3 else str(order)
            pt = phone_pt(px, size[0])
            out.append(SizeRow("添え書き（赤ペン）", f"{label}・画面に直接", f"添え書き（{name}）",
                               px, 1.0, px, pt, 1, "入らなければ順に小さくする",
                               judge_size(pt, "添え書き")))
    return out


def mark_color_rows(config) -> list[ColorRow]:
    """添え書きの朱と、その白い縁の比。写真の上に出るので縁で担保している。"""
    out: list[ColorRow] = []
    for label, size in (("本編", (1920, 1080)), ("ショート", (1080, 1920))):
        px = float(marks.NOTE_SIZES[0])
        ratio = contrast(over(marks.PEN), over(marks.HALO))
        out.append(ColorRow("添え書き（赤ペン）", f"{label}・画面に直接", "添え書き",
                            over(marks.PEN), over(marks.HALO), ratio, px, True,
                            need_ratio(px, True), 1, judge_contrast(ratio, px, True)))
    return out


# ---------------------------------------------------------------- 手で見るもの

BY_EYE = [
    "**板が主役の顔にかかっていないか。** 本編の板は幅0.74・左寄せなので、"
    "真ん中に人が写った写真では顔に乗る（`python tools/preview4.py` で見る）",
    "**写真と横に並べた板がはみ出していないか。** 横並びは縮めずに貼るので、"
    "板が高いと置き場（`Layout.media_slot`）を超える",
    "**写真の上の字（versus）が読めるか。** 背後は写真ごとに変わる。"
    "縁で担保しているが、明るい空に白い名前が乗ると沈む",
    "**赤ペンの添え書きが、板の字の上に乗っていないか。** `marks.plan` は字の枠を避けるが、"
    "避けきれないときは重なる",
    "**字幕の帯（下 250px）と板が重なっていないか。** 板の置き場は字幕の上で終わるが、"
    "はみ出した板はここに入る",
    "**実機のスマホで見る。** 390pt は目安で、機種で違う。この道具の pt は計算値",
    "**字幕そのものの大きさ**（`config/project.yaml` の `telop_size`）は、"
    "板ではなく `src/render.py` が描くので、この道具は測らない",
    "**系列の色が色覚の違いで見分けられるか。** `dataviz` の検証ツール（node）の仕事で、"
    "ここでは測らない",
]


# ---------------------------------------------------------------- 出し方


def _w(text: str) -> int:
    """見た目の幅（全角は2つ分）。表の桁をそろえるのに使う。"""
    return sum(2 if unicodedata.east_asian_width(c) in "FWA" else 1 for c in str(text))


def _pad(text: str, width: int, right: bool = False) -> str:
    space = " " * max(0, width - _w(text))
    return (space + str(text)) if right else (str(text) + space)


def _grid(headers: list[str], rows: list[list[str]], right: set[int] | None = None) -> str:
    """標準出力に出す表。"""
    right = right or set()
    widths = [max([_w(h)] + [_w(r[i]) for r in rows]) for i, h in enumerate(headers)]
    lines = ["  " + "  ".join(_pad(h, widths[i], i in right) for i, h in enumerate(headers))]
    lines.append("  " + "  ".join("-" * widths[i] for i in range(len(headers))))
    for row in rows:
        lines.append("  " + "  ".join(_pad(row[i], widths[i], i in right)
                                      for i in range(len(headers))))
    return "\n".join(lines)


def _md(headers: list[str], rows: list[list[str]]) -> str:
    """控えに書く markdown の表。"""
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(out)


SIZE_HEAD = ["", "板", "置き方", "役", "使った", "倍率", "画面", "スマホ", "件", "例"]
COLOR_HEAD = ["", "板", "置き方", "役", "文字", "背後", "比", "下限", "件"]


def _size_cells(row: SizeRow) -> list[str]:
    return [row.mark, row.card, row.place, row.role, f"{row.asked}px", f"{row.scale:.2f}",
            f"{row.screen_px:.0f}px", f"{row.pt:.1f}pt", str(row.count), row.example]


def _color_cells(row: ColorRow) -> list[str]:
    return [row.mark, row.card, row.place, row.role, hexs(row.fore), hexs(row.back),
            f"{row.ratio:.1f}:1", f"{row.need:.1f}:1" + ("（縁）" if row.edged else ""),
            str(row.count)]


def _summary(result: Result) -> list[str]:
    lines = []
    sizes, colors = result.sizes, result.colors
    for label, rows in (("字の大きさ", sizes), ("コントラスト", colors)):
        tally = Counter(r.mark for r in rows)
        lines.append("{}: × {} 件 / △ {} 件 / ○ {} 件（全 {} 行）".format(
            label, tally["×"], tally["△"], tally["○"], len(rows)))
    return lines


def show(result: Result, only_bad: bool = False) -> None:
    """標準出力に日本語の表で出す。"""
    print("■ 字の大きさ")
    print("  （基準: スマホで {:.1f}pt 以上＝読める下限。△ は役ごとの目安を下回るもの）\n".format(FLOOR_PT))
    rows = [r for r in result.sizes if not only_bad or r.mark != "○"]
    rows.sort(key=lambda r: (r.pt, r.card))
    print(_grid(SIZE_HEAD, [_size_cells(r) for r in rows], right={4, 5, 6, 7, 8}))
    print()
    print("■ コントラスト（WCAG）")
    print("  （下限: 画面で {}px 以上の太字は {:.1f}:1、それより小さければ {:.1f}:1。"
          "目安 {:.1f}:1。板の alpha を合成したあとの色で測った）\n".format(
              LARGE_PX, NEED_LARGE, NEED_SMALL, GOOD))
    crows = [r for r in result.colors if not only_bad or r.mark != "○"]
    crows.sort(key=lambda r: (r.ratio, r.card))
    print(_grid(COLOR_HEAD, [_color_cells(r) for r in crows], right={6, 7, 8}))
    print()
    if result.notes:
        print("■ 置き方で気づいたこと")
        for note in result.notes:
            print("  ・" + note)
        print()
    if result.skipped:
        print("■ 測れなかったもの")
        for name, place, why in result.skipped:
            print(f"  ・{name}／{place}: {why}")
        print()
    print("■ 手で見る（機械では測れない）")
    for item in BY_EYE:
        print("  ・" + item.replace("**", ""))
    print()
    for line in _summary(result):
        print(line)
    bad = result.bad
    if bad:
        print("\n直すもの（{}件）:".format(len(bad)))
        for item in bad:
            print("  ・" + item)
    else:
        print("\n基準（{:.1f}pt・コントラストの下限）を切るものはありません。".format(FLOOR_PT))


def markdown(result: Result, specs: dict[str, dict], when: str) -> str:
    """控えに残す markdown。"""
    out = [f"# 板の字がスマホで読めるかの点検（{when}）", "",
           "`python tools/typecheck.py` の出力。**板は画面に置くときに縮む**ので、"
           "倍率を掛けてからスマホの実寸（画面の幅 390pt）に直してある。", "",
           "## 0. 測り方", "",
           _md(["項目", "中身"],
               [["読める下限", f"スマホで {FLOOR_PT}pt（「世の中の断面図」の `danmen/typo.py` の "
                 "出典 28px＝1920 の画面での下限を引き継いだ）"],
                ["スマホに落とす比", "本編 1px=0.203pt（1920 幅）／ショート 1px=0.361pt（1080 幅）"],
                ["板の幅", "本編 単独 0.74・横並び 0.52／ショート 0.90（`src/render.py` の `_card`）"],
                ["板の倍率", "置き場（`Layout.media_slot`）の高さに収まるまで縮む（`_draw_media`）"],
                ["コントラストの下限", f"画面で {LARGE_PX}px 以上の太字 {NEED_LARGE}:1／"
                 f"それ未満 {NEED_SMALL}:1／目安 {GOOD}:1"],
                ["背後の色", "板の alpha 248 を**いちばん明るい下地（白）に合成したあと**の色。"
                 "縁の付いた字は縁の色"],
                ["測った板", "、".join(specs) or "（なし）"]]),
           "", "## 1. 字の大きさ", ""]
    rows = sorted(result.sizes, key=lambda r: (r.pt, r.card))
    out.append(_md(SIZE_HEAD[1:] + ["判定"],
                   [_size_cells(r)[1:] + [r.mark] for r in rows]))
    out += ["", "## 2. コントラスト", ""]
    crows = sorted(result.colors, key=lambda r: (r.ratio, r.card))
    out.append(_md(COLOR_HEAD[1:] + ["判定"],
                   [_color_cells(r)[1:] + [r.mark] for r in crows]))
    if result.notes:
        out += ["", "## 3. 置き方で気づいたこと", ""] + ["- " + n for n in result.notes]
    if result.skipped:
        out += ["", "## 4. 測れなかったもの", ""]
        out += [f"- {name}／{place}: {why}" for name, place, why in result.skipped]
    out += ["", "## 5. 手で見る（機械では測れない）", ""] + ["- " + item for item in BY_EYE]
    out += ["", "## 6. まとめ", ""] + ["- " + line for line in _summary(result)]
    bad = result.bad
    out += ["", "**直すもの（{}件）**".format(len(bad)), ""] if bad else \
           ["", f"**基準（{FLOOR_PT}pt・コントラストの下限）を切るものはありません。**", ""]
    out += ["- " + item for item in bad]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- 入口


def build_specs(args, work: Path) -> dict[str, dict]:
    """測る板を決める。`--note` があれば取材メモの板、無ければ型ごとの見本。"""
    if args.note:
        specs = collect_note(args.note)
        if not specs:
            print(f"{args.note} に板（card:）が書かれていません。", file=sys.stderr)
        return _filter(specs, args.only)
    photos = None
    try:
        photos = _dummy_photos(work)
    except Exception:
        photos = None           # 仮の写真が作れなくても、ほかの型は測る
    return _filter(samples(photos), args.only)


def _dummy_photos(work: Path) -> tuple[str, str]:
    """versus を測るための仮の写真2枚（中身は見ないので単色でよい）。"""
    paths = []
    for name, color in (("typecheck_a.jpg", (92, 118, 150)), ("typecheck_b.jpg", (148, 112, 92))):
        path = work / name
        Image.new("RGB", (1600, 1000), color).save(path)
        paths.append(str(path))
    return paths[0], paths[1]


def _filter(specs: dict[str, dict], only: list[str]) -> dict[str, dict]:
    if not only:
        return specs
    out = {}
    for name, spec in specs.items():
        kind = str(spec.get("type", ""))
        if any(word in name or word == kind for word in only):
            out[name] = spec
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="板（カード）の字が、スマホで読める大きさと濃さかを測る")
    parser.add_argument("only", nargs="*", help="型か見本の名前で絞る（例: stats convert）")
    parser.add_argument("--note", help="取材メモ（YAML）に実際に書かれた板だけを測る")
    parser.add_argument("--out", help="控えの置き場（既定 research/metrics/typecheck_<日付>.md）")
    parser.add_argument("--no-save", action="store_true", help="控えを書かない")
    parser.add_argument("--only-bad", action="store_true", help="○ の行は出さない")
    parser.add_argument("--config", default=str(ROOT / "config" / "project.yaml"))
    args = parser.parse_args(argv)

    config = load_config(args.config)
    with TemporaryDirectory(prefix="typecheck_") as temp:
        work = Path(temp)
        specs = build_specs(args, work)
        if not specs:
            print("測る板がありません。", file=sys.stderr)
            return 1
        result = run(specs, config, work)
    result.sizes += mark_rows(config)
    result.colors += mark_color_rows(config)

    show(result, only_bad=args.only_bad)
    if not args.no_save:
        when = date.today().strftime("%Y-%m-%d")
        out = Path(args.out) if args.out else \
            ROOT / "research" / "metrics" / f"typecheck_{when.replace('-', '')}.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(markdown(result, specs, when), encoding="utf-8")
        print(f"\n控え: {out}")
    return 1 if result.bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
