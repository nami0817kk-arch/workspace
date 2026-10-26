"""物語型の本編（横 1920x1080）の画面と絵の割り当て（10-24 ユーザー決定。第2版は他チャンネル15本の分析に合わせた）。

分析：dev/output/rekishi-chiso/research/main_screen_benchmark_1024.md（全幅の見出し帯 0/15・左上の小さな札 10/15・
字幕は下中央で1行20〜25字・話し手の名前 0/15・章題カード 7/15・終了画面の空き 7/15・BGM が無い本 0/15・1枚の平均 約11秒）。

画面：
- 左上に小さな札「1583年4月｜第4章 北ノ庄城の最後の夜」（高さ約3.7%・半透明の下地・白字）。年月は look の chapters に章ごとの
  「いま」（now）と、語りが年・月日を言った行（dates）を明示し、その行からだけ替える（第3版。card の見出しは拾わない）。
  物語の時間が動かない章（検証）は now: null で章題だけ。最後の余韻（no_tag_from から）と終了画面は札を出さない。
  年表のバーは常には出さない（図のカードで出す）
- 絵：全面。全カットにゆっくりの寄り・パン（10-24 に「背景を動かさない」を物語型の本編では上書き）。替わり目は 0.4 秒の溶け合い
  - ai：AI 絵を全面。1枚から切り出し（wide/left/right/face）を替えて何カットにも使う
  - frame：実在の絵を額のカードにして、直前の AI 絵をぼかして暗くした上に置く（実在の絵は全面の主役にしない）
  - part：横長の屏風・絵巻の一部を全面に
  - 図（台本の figure）の出る間は、その時の絵を暗くして図を真ん中に（時間を稼ぐ）
- 語りの文字：下中央、1行 ROW_MAX 字・2行まで、白の太字に縁と影。下の絵が明るい所だけ半透明の座布団。話し手の名前は出さない。
  想像の台詞だけ文字の左上に小さな「想像」札。記録の言葉（台本の人物の行で imagined でないもの）は明朝で
- 章の頭：声の前に CHAPTER_SECONDS 秒の章題カード（暗くした絵に「第N章」小＋章題を大きな明朝）。序章は場面から始めるので出さない
- 最後：声のあとに END_SECONDS 秒の終了画面の空き（絵だけ。右側を空けた絵を使う）
- 出典は左下に小さく、「AI生成画像」は右上に小さく
- 音：BGM は chiso/storyaudio.py の合成を声よりかなり小さく（書き出しを作るときにつなぐ）。効果音なし

いまは静止画（`stills`）とショットの表（`shotlist`）まで。動画の書き出しはまだ無い。

    python -m chiso.cli story-main scripts/story/oichi_main_look.yaml
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageStat

from . import storyshort as S

MW, MH = 1920, 1080
ROW_MAX = 24                    # 1行の字数（参考は 18〜28字、中央値 約22字）
MERGE_MAX = 36                  # 句をつなぐ上限（2行に収まる長さ）
MERGE_BELOW = 99                # 横長は句をなるべくつなぐ
TEXT_SIZE = 56                  # 文字の高さ 約5%
TEXT_Y = 0.865                  # 文字の中心（縦の割合）
ROW_STEP = 1.32
CPS = 5.5                       # 声の速さの見積もり（字/秒。毎分約330字＝本編の声）
LINE_GAP = 0.45                 # 行と行のあいだ（見積もり）
CHAPTER_SECONDS = 4.0           # 章題カード（声の前）
CHAPTER_PAD = 0.3               # 章題カードの前後の間（10-25。0.6 から詰めた）
GAP_SCALE = 0.75                # 行の間を本編の決まり（gap_before）の 0.75 倍に（10-25 比べで間が 32%、参考の中央値 24%）
DIM_RUN = 45.0                  # 図の間も、これを超えたら1ブロックだけ図を外して絵を見せる（図は語りに合わせて書き込まれるので長めでよい）
CUT_LEAD = 0.2                  # カットを替えるのは次の文の頭の 0.2 秒前（歴史横丁・キンブラは 0.1〜0.3 秒前）
ZOOM_RATE = 0.012               # 寄り・引きの速さ（1秒あたりの拡大率の変化。参考の中央値 1.2%/秒。一定の速さで最初から最後まで）
PAN_RATE = 0.016                # パンの速さ（1秒に画面の幅の約1.6%。参考は 1.4〜2.5%）。長いカットは余白の上限で遅くなる
PAN_MIN, PAN_MAX = 1.08, 1.2    # パンのために絵を置く大きさ（余白の中を端から端へ流す）
SAME_FADE = 0.5                 # 同じ絵の別の構図へ替えるときだけ溶け合わせる（ほかはハードカット）
REVEAL_LEAD = 0.25              # 関係図の札は、その語の 0.25 秒前から出始める（キンブラ：0〜0.3 秒前）
FRAME_CAP = 1.35                # 額のカードを寄せる上限
END_SECONDS = 20.0              # 終了画面の空き
CUT_MAX = 20.0                  # 1カットの長さの上限（これを超えると切り出しを替える）
CUT_MIN = 8.0
RUN_MAX = 20.0                  # 同じ絵を続けて出す上限（図の間は数えない）
IMAGINED_COLOR = (88, 82, 96)   # render.py の「想像」札と同じ灰紫
CROPS = {"wide": (1.0, (0.5, 0.45)), "left": (1.18, (0.36, 0.45)), "right": (1.18, (0.64, 0.45)),
         "face": (1.25, (0.5, 0.40))}   # 1376x768 の絵を 1920x1080 に広げるので、寄りは最大 ZOOM_CAP 倍まで（10-25）
ZOOM_CAP = 1.32
MOVES = ("in", "right", "out", "left")


# --- 絵 ---------------------------------------------------------------------
class Grade(S.Grade):
    """ショートと同じ色調補正を横長で。文字の出る下の方を少し暗く。"""

    def __init__(self, w: int = MW, h: int = MH, band_on: bool = True):
        import numpy as np
        self.np = np
        yy, xx = np.mgrid[0:h, 0:w].astype("float32")
        r = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2
        self.vig = (1 - self.VIGNETTE * np.clip(r / 2, 0, 1) ** 1.2)[..., None].astype("float32")
        rng = np.random.default_rng(7)
        self.noise = [rng.standard_normal((h, w, 1)).astype("float32") for _ in range(6)]
        band = np.zeros(h, dtype="float32")
        top = int(h * 0.70)
        if band_on:
            band[top:] = 0.30 * np.clip((np.arange(top, h) - top) / ((h - top) * 0.6), 0, 1)
        self.band = (1 - band)[:, None, None]


def picture(im: Image.Image, u: float = 0.5, move: str = "in", crop="wide", zoom: float = 0.05) -> Image.Image:
    """全面の絵（1920x1080、補正前）。横長の絵は切り出し（crop＝CROPS の名前か (倍率, (中心x, 中心y))）＋寄り・パン。
    パンは窓が動けるよう 1.12 倍以上に、全体で ZOOM_CAP 倍まで。縦長の絵（仮の絵）は、ぼかした下地に高さいっぱいで。"""
    im = im.convert("RGB")
    cz, focus = crop if isinstance(crop, tuple) else CROPS.get(crop, CROPS["wide"])
    z, dx, dy = S.motion(move, u, zoom)
    z *= cz
    if move in ("left", "right", "up", "down"):
        z = max(z, 1.12)
    z = min(z, ZOOM_CAP)
    if im.width / im.height >= 1.25:
        sw, sh = im.width, im.height
        if sw / sh > MW / MH:
            wh, ww = sh, sh * MW / MH
        else:
            ww, wh = sw, sw * MH / MW
        ww, wh = ww / z, wh / z
        cx = min(max(focus[0] * sw + dx * ww, ww / 2), sw - ww / 2)
        cy = min(max(focus[1] * sh + dy * wh, wh / 2), sh - wh / 2)
        return im.transform((MW, MH), Image.EXTENT, (cx - ww / 2, cy - wh / 2, cx + ww / 2, cy + wh / 2), Image.BICUBIC)
    bg = S._fit_cell(im, MW // 4, MH // 4).filter(ImageFilter.GaussianBlur(10)).resize((MW, MH), Image.BICUBIC)
    bg = Image.eval(bg, lambda v: int(v * 0.42))
    h = round(MH * (1 + (z - 1) * 0.5))
    w = round(im.width * h / im.height)
    fg = im.resize((w, h), Image.LANCZOS)
    x0 = int(MW * {"left": 0.36, "right": 0.64}.get(crop, 0.5) - w / 2 + dx * w)
    y0 = int((MH - h) * (0.5 + dy))
    shadow = Image.new("L", (MW, MH), 0)
    ImageDraw.Draw(shadow).rectangle([x0 - 4, y0, x0 + w + 4, y0 + h], fill=170)
    bg.paste((0, 0, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(24)))
    bg.paste(fg, (x0, y0))
    return bg


def framed(backdrop: Image.Image, painting: Image.Image | None, u: float = 0.5, variant: str = "a") -> Image.Image:
    """実在の絵を額のカードにして、ぼかして暗くした下地の上に置く（b は少し寄せた版）。painting が None なら下地だけ（図の間）。"""
    bg = backdrop.filter(ImageFilter.GaussianBlur(18))
    bg = Image.eval(bg, lambda v: int(v * 0.40))
    if painting is None:
        return bg
    p = painting.convert("RGB")
    if variant == "b":                                   # 2つ目の切り出し：絵の上の方（顔・題字のある所）に寄せる
        p = p.crop((int(p.width * 0.08), 0, int(p.width * 0.92), int(p.height * 0.72)))
    s = min(1180 / p.width, 740 / p.height) * (1 + 0.04 * u)
    w, h = round(p.width * s), round(p.height * s)
    p = p.resize((w, h), Image.LANCZOS)
    x0, y0 = (MW - w) // 2, 92 + (740 - h) // 2
    sh = Image.new("L", (MW, MH), 0)
    ImageDraw.Draw(sh).rectangle([x0 + 10, y0 + 14, x0 + w + 10, y0 + h + 14], fill=190)
    bg.paste((0, 0, 0), (0, 0), sh.filter(ImageFilter.GaussianBlur(16)))
    d = ImageDraw.Draw(bg)
    d.rectangle([x0 - 8, y0 - 8, x0 + w + 8, y0 + h + 8], fill=(150, 118, 74))
    d.rectangle([x0 - 3, y0 - 3, x0 + w + 3, y0 + h + 3], fill=(30, 24, 18))
    bg.paste(p, (x0, y0))
    return bg


# --- 文字・札 -----------------------------------------------------------------
def serif_of(fonts: dict):
    cache = {}

    def f(size: int):
        if size not in cache:
            ft = ImageFont.truetype(fonts["serif"], size)
            try:
                ft.set_variation_by_name("Bold")
            except Exception:
                pass
            cache[size] = ft
        return cache[size]
    return f


def draw_corner(lay: Image.Image, text: str, font_of) -> None:
    """左上の小さな札「1583年4月｜第4章 北ノ庄城の最後の夜」。字の高さは画面の約2.8%（10-25。2.0% はスマホで読みにくかった）、札は約5%。"""
    f = font_of(34)
    d = ImageDraw.Draw(lay, "RGBA")
    w = f.getlength(text)
    d.rounded_rectangle([24, 20, 24 + w + 32, 74], radius=9, fill=(0, 0, 0, 140))
    d.text((40, 47), text, font=f, fill=(255, 255, 255, 240), anchor="lm")


def draw_ai_label(lay: Image.Image, font_of) -> None:
    f = font_of(22)
    tw = f.getlength(S.AI_LABEL)
    d = ImageDraw.Draw(lay, "RGBA")
    d.rounded_rectangle([MW - 24 - tw - 24, 22, MW - 24, 58], radius=8, fill=(0, 0, 0, 120))
    d.text((MW - 36, 40), S.AI_LABEL, font=f, fill=(255, 255, 255, 225), anchor="rm")


def draw_credit(lay: Image.Image, text: str, font_of) -> None:
    f = font_of(20)
    rows = S._wrap_text(text, f, 520)[:3]
    w = int(max(f.getlength(r) for r in rows)) + 24
    h = 28 * len(rows) + 10
    d = ImageDraw.Draw(lay, "RGBA")
    d.rounded_rectangle([20, MH - 18 - h, 20 + w, MH - 18], radius=7, fill=(0, 0, 0, 120))
    for i, r in enumerate(rows):
        d.text((32, MH - 18 - h + 5 + 28 * i + 14), r, font=f, fill=(255, 255, 255, 215), anchor="lm")


def draw_card(lay: Image.Image, head: str, body: str, font_of) -> None:
    """台本の card（見出し＋本文）を右上に小さく（幅約20%）：見出し、赤い下線、下に本文。
    年・月日だけの見出しは出さない（年は左上の札にある。10-25 比べで右上の大きな札は参考 0/15）。is_point_card で選ぶ。"""
    x0, y0, x1 = MW - 36 - 384, 96, MW - 36
    d = ImageDraw.Draw(lay, "RGBA")
    size = 56
    while size > 32 and font_of(size).getlength(head) > (x1 - x0) - 40:
        size -= 4
    bf = font_of(26)
    rows = S._wrap_text(body, bf, (x1 - x0) - 40)[:2] if body else []
    h = 26 + size + 24 + 36 * len(rows) + 16
    d.rounded_rectangle([x0, y0, x1, y0 + h], radius=16, fill=(10, 8, 6, 160))
    cx = (x0 + x1) / 2
    d.text((cx, y0 + 18 + size / 2), head, font=font_of(size), fill=S.WHITE, anchor="mm", stroke_width=4, stroke_fill=S.BLACK)
    uy = y0 + 24 + size + 4
    d.rounded_rectangle([x0 + 40, uy, x1 - 40, uy + 5], radius=2, fill=S.RED + (255,))
    for i, r in enumerate(rows):
        d.text((cx, uy + 28 + 36 * i), r, font=bf, fill=S.WHITE, anchor="mm", stroke_width=3, stroke_fill=S.BLACK)


_DATE_HEAD = re.compile(r"^(紀元前)?\d{1,4}年|^\d{1,2}月|^\d{3,4}〜")


def is_point_card(card) -> bool:
    """右上に出す札か：数・要点（「37歳」「2度目の落城」）は出す。年・月日で始まる見出し（「1583年4月」）は左上の札に任せて出さない。"""
    return card is not None and not _DATE_HEAD.match(card.head)


def chapter_card(backdrop: Image.Image, label: str, title: str, font_of, serif) -> Image.Image:
    """章題カード：暗くした絵に「第N章」（小）＋章題（大きな明朝）。"""
    img = Image.eval(backdrop.filter(ImageFilter.GaussianBlur(6)), lambda v: int(v * 0.28)).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    d.text((MW / 2, MH * 0.36), label, font=font_of(40), fill=S.YELLOW + (255,), anchor="mm")
    d.line([(MW / 2 - 60, MH * 0.36 + 44), (MW / 2 + 60, MH * 0.36 + 44)], fill=S.RED + (255,), width=4)
    size = 92
    rows = [title]
    while size > 56 and serif(size).getlength(title) > MW * 0.8:
        size -= 4
    if serif(size).getlength(title) > MW * 0.8 and "　" in title:
        rows = title.split("　", 1)
    for i, r in enumerate(rows):
        d.text((MW / 2, MH * 0.52 + i * size * 1.3), r, font=serif(size), fill=S.WHITE + (255,), anchor="mm")
    return img.convert("RGB")


def blocks(text: str) -> list:
    """語り1行を、横長の画面に一度に出すブロックに（1行 ROW_MAX 字・2行まで。つなげると語りそのまま）。"""
    return S.blocks_of(text, row_max=ROW_MAX, merge_max=MERGE_MAX, merge_below=MERGE_BELOW)


def _btext(block) -> str:
    return "".join(u.text for u in block.units)


def text_layer(block, font, imagined: bool = False, cushion: bool = False, tag_font=None) -> Image.Image:
    """ブロックの文字（白の太字・黒の縁と影・《》は黄）を下中央に。cushion で半透明の座布団。imagined で左上に「想像」札。"""
    lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    step = int(TEXT_SIZE * ROW_STEP)
    n = len(block.rows)
    top = MH * TEXT_Y - step * n / 2
    rows, x_left, x_right = [], MW, 0
    lists = []
    for row in block.rows:
        items = []
        for u in row:
            s, m = S.phrase_plain(u.text)
            items += list(zip(s, m))
        lists.append(items)
    for ri in range(len(lists) - 1):                     # 行末に開きかっこを残さない（「『」で1行目が終わっていた）
        while lists[ri] and lists[ri][-1][0] in "『「（(":
            lists[ri + 1].insert(0, lists[ri].pop())
    for ri, items in enumerate(lists):
        width = sum(font.getlength(ch) for ch, _ in items)
        x = (MW - width) / 2
        x_left, x_right = min(x_left, x), max(x_right, x + width)
        rows.append((items, x, top + step * ri + TEXT_SIZE * 0.86))
    if cushion:
        d.rounded_rectangle([x_left - 28, top - 12, x_right + 28, top + step * n + 6], radius=14, fill=(0, 0, 0, 120))
    shadow = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for items, x, y in rows:
        for ch, _on in items:
            sd.text((x + 3, y + 4), ch, font=font, fill=(0, 0, 0, 200), anchor="ls", stroke_width=6, stroke_fill=(0, 0, 0, 200))
            x += font.getlength(ch)
    lay.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(4)))
    d = ImageDraw.Draw(lay, "RGBA")
    for pass_ in ("stroke", "fill"):
        for items, x, y in rows:
            for ch, on in items:
                if pass_ == "stroke":
                    d.text((x, y), ch, font=font, fill=S.BLACK + (255,), stroke_width=5, stroke_fill=S.BLACK + (255,), anchor="ls")
                else:
                    d.text((x, y), ch, font=font, fill=(S.YELLOW if on else S.WHITE) + (255,), anchor="ls")
                x += font.getlength(ch)
    if imagined and tag_font is not None:
        w = tag_font.getlength("想像") + 22
        y = top - 30
        d.rounded_rectangle([x_left, y - 17, x_left + w, y + 17], radius=6, fill=IMAGINED_COLOR + (235,))
        d.text((x_left + w / 2, y), "想像", font=tag_font, fill=S.WHITE, anchor="mm")
    return lay


def is_record(line) -> bool:
    """記録の言葉の行（人物の台詞で、想像ではない）。明朝で出す。"""
    return line.speaker not in ("語り", "剣崎", "つむぎ", "二人") and not line.imagined


# --- 時刻とカット -------------------------------------------------------------
@dataclass
class Unit:
    line: int
    block: object
    start: float
    end: float


@dataclass
class Cut:
    kind: str                # ai / frame / part / chapter / end
    ref: str                 # 絵（ai は A01 など）
    crop: str
    start: float
    end: float
    lines: tuple
    dim: bool = False        # 図の間（絵を暗くして図を置く）
    backdrop: str = ""       # frame・図の下地にする AI 絵
    section: int = 0

    @property
    def seconds(self) -> float:
        return self.end - self.start

    @property
    def image_key(self) -> str:
        return f"{self.kind}:{self.ref}"


class Plan:
    """台本と見た目の指定から、ブロックの時刻（見積もり）・カットの並び・左上の札の字を決める。"""

    def __init__(self, look: dict, sc, seconds: list[float] | None = None):
        """seconds＝行ごとの本物の声の長さ（書き出し）。無ければ字数からの見積もり（静止画・表）。
        行のあいだの間は本編の決まり（chiso/voice.py の gap_before）、章の頭は間 0.6 秒＋章題カード＋間 0.6 秒。"""
        from .voice import gap_before
        self.look, self.sc = look, sc
        self.units: list[Unit] = []
        self.chapter_at: dict[int, float] = {}
        self.line_at: dict[int, tuple[float, float]] = {}
        t = 0.0
        prev = None
        for line in sc.lines:
            if prev is not None and line.section != prev.section and line.section > 0:
                t += CHAPTER_PAD
                self.chapter_at[line.section] = t
                t += CHAPTER_SECONDS + CHAPTER_PAD
                gap = line.pause or 0.0
            elif seconds is None:
                gap = (line.pause or 0.0) + (LINE_GAP if prev is not None else 0.0)
            else:
                gap = gap_before(prev, line) * GAP_SCALE if prev is not None else 0.0
            t += gap
            bl = blocks(line.text)
            chars = [max(1, len(S.screen_plain(_btext(b)))) for b in bl]
            dur = seconds[line.index] if seconds is not None else sum(max(1.0, c / CPS) for c in chars)
            t0 = t
            for b, c in zip(bl, chars):
                d = dur * c / sum(chars) if seconds is not None else max(1.0, c / CPS)
                self.units.append(Unit(line.index, b, t, t + d))
                t += d
            self.line_at[line.index] = (t0, t)
            prev = line
        self.voice_end = t + 1.0
        self.total = self.voice_end + END_SECONDS
        self.shots = self._shots()
        self.cuts = self._cuts()

    # --- 図（台本の figure と、look の figure_extend で前後の行に広げたもの）---------------
    def fig(self, idx: int) -> dict | None:
        """行 idx に出す図（dict）。look の figure_extend [{line, from, to, items}] で、その行の図を from〜to の行に広げる
        （語りがその記録・人物を言う行まで図を出しておき、言った瞬間に書き込むため。items で項目の並びを語る順に直せる）。"""
        if not hasattr(self, "_figs"):
            figs: dict[int, dict] = {}
            for line in self.sc.lines:
                if line.figure:
                    figs[line.index] = json.loads(line.figure)
            for ext in self.look.get("figure_extend") or []:
                spec = dict(json.loads(self.sc.lines[int(ext["line"])].figure))
                for k in ("upto", "grow_from"):
                    spec.pop(k, None)
                if ext.get("items"):
                    key = "nodes" if spec.get("type") == "people" else "items"
                    order = {name: i for i, name in enumerate(ext["items"])}
                    spec[key] = sorted(spec[key], key=lambda it: order.get(it[0], 99))
                for i in range(int(ext["from"]), int(ext["to"]) + 1):
                    figs[i] = spec
            for add in self.look.get("figures") or []:       # look だけで足す図（台本に無い関係図・地図。10-26 数正）。spec: null はその行の図を外す
                spec = add.get("spec")
                for i in range(int(add["from"]), int(add.get("to", add["from"])) + 1):
                    if spec is None:
                        figs.pop(i, None)
                    else:
                        figs[i] = dict(spec)
            self._figs = figs
        return self._figs.get(idx)

    def word_time(self, words, t0: float, t1: float) -> float | None:
        """t0〜t1 のあいだで、語りが words（字の並びか、そのリスト）のどれかを言い始める時刻（ブロックの中の字の位置で按分）。"""
        if isinstance(words, str):
            words = [words]
        for u in self.units:
            if u.end <= t0 or u.start >= t1:
                continue
            text = S.screen_plain(_btext(u.block))
            hits = [text.find(w) for w in words if w and text.find(w) >= 0]
            if hits:
                return u.start + (u.end - u.start) * min(hits) / max(1, len(text))
        return None

    def fig_runs(self) -> list[dict]:
        """続けて同じ図が出る行のまとまりごとに、項目（人物・記録・地点）が書き込まれる時刻。
        語りがその名前を言った瞬間に1つずつ出る（言わない項目は、前の項目と一緒に出る）。最初の項目は図が出たときから。"""
        if hasattr(self, "_runs"):
            return self._runs
        from .figures import base_key
        runs: list[dict] = []
        for line in self.sc.lines:
            spec = self.fig(line.index)
            if not spec:
                continue
            key = base_key(spec)
            if runs and runs[-1]["key"] == key and runs[-1]["lines"][-1] == line.index - 1:
                runs[-1]["lines"].append(line.index)
                continue
            runs.append({"key": key, "lines": [line.index], "spec": {k: v for k, v in spec.items() if k not in ("upto", "grow_from")}})
        for r in runs:
            t0 = self.line_at[r["lines"][0]][0] - 0.3
            t1 = self.line_at[r["lines"][-1]][1] + 0.5
            spec = r["spec"]
            kind = spec.get("type")
            if kind == "people":
                names = [n[0] for n in spec.get("nodes", [])]
            elif kind == "map":                         # reveal: true の地図は、道のりではなく地点を語る順に1つずつ打つ（被害の範囲など）
                names = [p[0] for p in spec.get("places", [])] if spec.get("reveal") else list(spec.get("route") or [])
            elif kind in ("stats", "numberline", "bars", "line", "calc"):
                key = {"bars": "bars", "line": "points", "calc": "terms"}.get(kind, "items")
                names = [it[0] for it in spec.get(key, [])]
            else:
                names = []
            times = []
            for i, name in enumerate(names):
                variants = [str(name)] + [v for v in re.split(r"[（）()・]", str(name)) if len(v) >= 1 and v != name]
                variants += [v.replace("の方", "") for v in variants if v.endswith("の方")]
                variants += [v[2:] for v in variants if len(v) >= 4 and not v.endswith("天皇")]   # 「徳川和子」→「和子」（語りは名だけで言う）
                hit = self.word_time(variants, t0, t1) if i else None
                times.append(t0 + 0.3 if hit is None else hit)
            for i in range(1, len(times)):                  # 前の項目より先には出さない（先頭から順に描く図のため）
                times[i] = max(times[i], times[i - 1])
            r["names"], r["times"] = names, times
            r["t0"], r["t1"] = t0, t1
        self._runs = runs
        return runs

    @staticmethod
    def fig_upto(spec: dict, n: int) -> dict:
        """図を先頭 n 項目まで描く形に。reveal の地図は地点を n 個まで（線は引かない）、ほかは upto（前の項目は描き終えたまま）。"""
        if spec.get("type") == "map" and spec.get("reveal"):
            return {k: v for k, v in spec.items() if k not in ("reveal", "upto", "grow_from")} | {"places": spec["places"][:max(1, n)]}
        return dict(spec, upto=n, grow_from=n - 1)

    def run_of(self, idx: int) -> dict | None:
        for r in self.fig_runs():
            if idx in r["lines"]:
                return r
        return None

    def focus_events(self, c: "Cut", spec: dict) -> list[tuple[float, tuple]]:
        """カットの中で、語りが look の focus に書いた語を言った時刻と、寄る先 (倍率, 中心x, 中心y)。
        話に関係のない寄り・パンはしない（10-25 ユーザー「ただ寄るとかは、話に関係ないのはあまり意味ないのでは？」）。"""
        out = []
        for words, target in (spec or {}).items():
            ws = [w for w in str(words).split("|") if w]
            t = self.word_time(ws, c.start, c.end)
            if t is not None:
                out.append((t, tuple(float(x) for x in target)))
        return sorted(out)[:2]

    def _shots(self) -> list[tuple]:
        out = []
        for s in self.look["shots"]:
            parts = str(s).split()
            kind, _, ref = parts[1].partition(":")
            out.append((parts[0], kind, ref, parts[2] if len(parts) > 2 else ("wide" if kind != "frame" else "a")))
        return out

    def shot_of(self, idx: int) -> tuple:
        cur = None
        for frm, kind, ref, crop in self.shots:
            if frm != "end" and int(frm) <= idx:
                cur = (kind, ref, crop)
        return cur

    def _cuts(self) -> list[Cut]:
        lines = self.sc.lines
        cuts: list[Cut] = []
        last_ai = "A01"
        groups = []                                      # (shot, dim, [units])
        for u in self.units:
            shot = self.shot_of(u.line)
            dim = bool(self.fig(u.line))
            if groups and groups[-1][0] == shot and groups[-1][1] == dim and lines[groups[-1][2][-1].line].section == lines[u.line].section:
                groups[-1][2].append(u)
            else:
                groups.append((shot, dim, [u]))
        cycle = {"ai": ["wide", "left", "right", "face"], "part": ["wide", "left", "right"], "frame": ["a", "b"]}
        for shot, dim, us in groups:
            kind, ref, crop = shot
            if kind == "ai":
                last_ai = ref
            sec = lines[us[0].line].section
            if sec in self.chapter_at and not any(c.kind == "chapter" and c.section == sec for c in cuts):
                t0 = self.chapter_at[sec]
                cuts.append(Cut("chapter", ref if kind == "ai" else last_ai, "wide", t0, t0 + CHAPTER_SECONDS, (), section=sec,
                                backdrop=last_ai))
            order = cycle[kind]
            k = order.index(crop) if crop in order else 0
            piece: list[Unit] = []
            breathe = False
            for u in us:
                acc = (piece[-1].end - piece[0].start) if piece else 0.0
                if breathe:                                  # 図を外した1ブロックのあと、図に戻る
                    cuts.append(self._cut(kind, ref, order[k % len(order)], piece, False, last_ai, sec))
                    k += 1
                    piece, breathe = [], False
                elif piece and not dim and acc + (u.end - u.start) > CUT_MAX and acc >= CUT_MIN:
                    cuts.append(self._cut(kind, ref, order[k % len(order)], piece, dim, last_ai, sec))
                    k += 1
                    piece = []
                elif piece and dim and acc + (u.end - u.start) > DIM_RUN and acc >= CUT_MIN:
                    cuts.append(self._cut(kind, ref, order[k % len(order)], piece, True, last_ai, sec))
                    k += 1
                    piece, breathe = [], True             # 次の1ブロックは図を外して絵だけ（画面を替える）
                piece.append(u)
            if piece:
                cuts.append(self._cut(kind, ref, order[k % len(order)], piece, dim and not breathe, last_ai, sec))
        end = [s for s in self.shots if s[0] == "end"]
        if end:
            cuts.append(Cut("end", end[0][2], end[0][3], self.voice_end, self.total, (), section=lines[-1].section))
        for a, b in zip(cuts, cuts[1:]):                 # 次のカットは次の文の頭の CUT_LEAD 秒前から（参考：0.1〜0.3秒前）。隙間は前のカットに含める
            if b.lines and a.kind != "chapter" and b.start - CUT_LEAD > a.start + 1.0:
                b.start -= CUT_LEAD
            a.end = b.start
        return cuts

    def _cut(self, kind, ref, crop, us, dim, last_ai, sec) -> Cut:
        return Cut(kind, ref, crop, us[0].start, us[-1].end, tuple(dict.fromkeys(u.line for u in us)), dim, last_ai, sec)

    def cut_at(self, t: float) -> tuple[int, Cut]:
        for i, c in enumerate(self.cuts):
            if c.start <= t < c.end:
                return i, c
        return len(self.cuts) - 1, self.cuts[-1]

    def unit_at(self, t: float) -> Unit | None:
        """時刻 t に出す語りのブロック。行の間の短い間（1.5秒まで）は前のブロックを残す。"""
        for k, u in enumerate(self.units):
            nxt = self.units[k + 1].start if k + 1 < len(self.units) else u.end + 0.5
            hold = nxt if nxt - u.end <= 1.5 else u.end + 0.3
            if u.start <= t < hold:
                return u
        return None

    def corner(self, idx: int) -> str:
        """左上の札「いま｜章題」。いまは look の chapters の now と、その章の語りが年・月日を言った行（dates）だけで替わる。
        now が null の章は章題だけ。no_tag_from から後（最後の余韻）は空。"""
        if idx >= int(self.look.get("no_tag_from", 10 ** 9)):
            return ""
        line = self.sc.lines[idx]
        ch = (self.look.get("chapters") or {}).get(line.section) or {}
        date = ch.get("now")
        for k, v in sorted((int(k), v) for k, v in (ch.get("dates") or {}).items()):
            if k <= idx:
                date = v
        label = ch.get("label", "")
        return f"{date}｜{label}" if date else label

    def runs(self) -> list[tuple[float, float, str]]:
        """同じ絵が続けて RUN_MAX 秒を超える所（図の間・章題は数えない）。"""
        out, cur, t0, acc = [], None, 0.0, 0.0
        for c in self.cuts:
            if c.dim or c.kind in ("chapter", "end"):
                cur, acc = None, 0.0
                continue
            if c.image_key == cur:
                acc += c.seconds
            else:
                if cur and acc > RUN_MAX:
                    out.append((t0, t0 + acc, cur))
                cur, t0, acc = c.image_key, c.start, c.seconds
        if cur and acc > RUN_MAX:
            out.append((t0, t0 + acc, cur))
        return out


# --- 1コマ -------------------------------------------------------------------
class Look:
    """見た目の指定（look の yaml）と台本から、時刻 t の画面を描く。"""

    def __init__(self, look_path: str | Path, config: dict, seconds: list[float] | None = None):
        from . import render, script
        from .cli import ROOT, assets_dir
        self.look = yaml.safe_load(Path(look_path).read_text(encoding="utf-8"))
        self.sc = script.load(ROOT / self.look["script"])
        self.assets = assets_dir(config)
        self.art = ROOT / self.look.get("art_dir", "out/story/oichi3/gem")
        self.main_art = ROOT / self.look.get("main_art_dir", "out/story/oichi3/main")
        self.font_of = S.make_font_of(config["fonts"])
        self.serif = serif_of(config["fonts"])
        self.painter = render.Painter(config, self.sc, self.assets, (MW, MH))
        self.grade = Grade()
        self.plan = Plan(self.look, self.sc, seconds)
        self.credits = {}
        for l in self.sc.lines:
            for p in (l.background, l.portrait):
                if p and p.image not in self.credits:
                    self.credits[p.image] = p.credit or p.caption
        self.credits.update(self.look.get("credits") or {})   # 台本に出てこない絵の出典（look の credits:）

    def picture_of(self, ref: str) -> Image.Image:
        """部品（覚えてほしい名前）の絵：「ai:K15」は AI 絵、ほかは実在の絵。"""
        return self.ai_image(ref[3:]) if str(ref).startswith("ai:") else self.painting(ref)

    def painting(self, ref: str) -> Image.Image:
        """実在の絵（assets）に look の paint_fx（切り出し・明るさ・コントラスト）をかけたもの。元の画像は変えない。"""
        from PIL import ImageEnhance
        im = Image.open(self.assets / ref).convert("RGB")
        fx = (self.look.get("paint_fx") or {}).get(ref) or {}
        if fx.get("crop"):
            x0, y0, x1, y1 = fx["crop"]
            im = im.crop((int(im.width * x0), int(im.height * y0), int(im.width * x1), int(im.height * y1)))
        if fx.get("bright"):
            im = ImageEnhance.Brightness(im).enhance(float(fx["bright"]))
        if fx.get("contrast"):
            im = ImageEnhance.Contrast(im).enhance(float(fx["contrast"]))
        return im

    def ai_image(self, key: str) -> Image.Image:
        """AI 絵（A01 など）。main_art_dir に届いていればそれ、無ければ stand_in の縦の絵で代える。"""
        p = self.main_art / f"{key}.jpg"                 # 届いた 16:9 の絵（out/story/oichi3/main/A01.jpg〜）
        if not p.exists():
            p = self.art / f"{key}.jpg"
        if not p.exists():
            p = self.art / f"{self.look['ai'][key]['stand_in']}.jpg"
        return Image.open(p)

    def base(self, c: Cut, u: float, n: int) -> Image.Image:
        move = MOVES[n % len(MOVES)]
        if c.kind in ("ai", "end"):
            spec = (self.look.get("ai") or {}).get(c.ref) or {}
            crop = c.crop
            if spec.get("lock"):                          # この絵は決まった切り出しだけ（A21：紙を大きく映さない など）
                z0, fx, fy = spec["lock"]
                crop = (float(z0), (float(fx), float(fy)))
            elif spec.get("crops") and c.crop in spec["crops"]:
                z0, fx, fy = spec["crops"][c.crop]
                crop = (float(z0), (float(fx), float(fy)))
            img = picture(self.ai_image(c.ref), u, move if c.kind == "ai" else "in", crop)
            if spec.get("soften"):                        # 遠景を暗くぼかして目立たせない（A17 の山）
                k = float(spec["soften"])
                top = img.crop((0, 0, MW, int(MH * 0.55))).filter(ImageFilter.GaussianBlur(6))
                top = Image.eval(top, lambda v: int(v * k))
                mask = Image.linear_gradient("L").resize((MW, int(MH * 0.55))).transpose(Image.FLIP_TOP_BOTTOM)
                img.paste(top, (0, 0), mask)
            return img
        if c.kind == "part":
            return picture(self.painting(c.ref), u, move, c.crop)
        if c.kind == "frame":
            back = picture(self.ai_image(c.backdrop), 0.5, "in", "wide")
            return framed(back, None if c.dim else self.painting(c.ref), u, c.crop)   # 図の間は額を出さない（10-25）
        if c.kind == "chapter":
            return picture(self.ai_image(c.backdrop or c.ref), u, "in", "wide")
        return picture(self.ai_image(c.ref), u, "in", c.crop)

    def frame_at(self, t: float) -> tuple[Image.Image, dict]:
        i, c = self.plan.cut_at(t)
        u = (t - c.start) / max(0.01, c.seconds)
        img = self.grade(self.base(c, u, i), i)
        info = {"t": round(t, 1), "cut": i, "kind": c.kind, "ref": c.ref, "crop": c.crop, "dim": c.dim}
        if c.kind == "chapter":
            sec = self.sc.sections[c.section]
            label = ((self.look.get("chapters") or {}).get(c.section) or {}).get("label", "").split(" ", 1)
            img = chapter_card(img, label[0], sec.title, self.font_of, self.serif)
            return img, info
        img = img.convert("RGBA")
        if c.kind == "end":
            return img.convert("RGB"), info
        unit = self.plan.unit_at(t)
        line = self.sc.lines[unit.line if unit else c.lines[0]]
        lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
        if c.dim and self.plan.fig(line.index):
            from . import figures
            img = Image.alpha_composite(img, Image.new("RGBA", (MW, MH), (0, 0, 0, 120)))
            r = self.plan.run_of(line.index)
            n = sum(1 for x in r["times"] if x <= t) if r and r["names"] else None
            spec = dict(self.plan.fig(line.index))
            if n is not None:
                spec = Plan.fig_upto(spec, max(1, n))
                spec.pop("grow_from", None)
            img = figures.draw(self.painter, img, spec, 1.0)
        elif is_point_card(line.card):
            prev = self.sc.lines[line.index - 1].card if line.index else None
            if prev != line.card:
                draw_card(lay, line.card.head, line.card.body, self.font_of)
        tag = self.plan.corner(line.index)
        if tag:
            draw_corner(lay, tag, self.font_of)
        if c.kind in ("ai", "frame", "chapter") or c.dim and c.backdrop:
            draw_ai_label(lay, self.font_of)
        if c.kind in ("frame", "part"):
            draw_credit(lay, self.credits.get(c.ref) or Path(c.ref).stem, self.font_of)
        img.alpha_composite(lay)
        if unit:
            box = (360, int(MH * TEXT_Y) - 70, MW - 360, int(MH * TEXT_Y) + 70)
            bright = ImageStat.Stat(img.crop(box).convert("L")).mean[0] > 105
            font = self.serif(TEXT_SIZE) if is_record(line) else self.font_of(TEXT_SIZE)
            img.alpha_composite(text_layer(unit.block, font, line.imagined, bright, self.font_of(24)))
            info.update(line=line.index, text=S.screen_plain(_btext(unit.block)), cushion=bright)
        return img.convert("RGB"), info

    def time_of(self, spec: dict) -> float:
        if spec.get("end"):
            return self.plan.voice_end + END_SECONDS / 2
        lines = self.sc.lines
        idx = next(i for i, l in enumerate(lines) if spec["find"] in l.text) if "find" in spec else int(spec["line"])
        if spec.get("chapter"):
            return self.plan.chapter_at[lines[idx].section] + CHAPTER_SECONDS / 2
        us = [u for u in self.plan.units if u.line == idx]
        pick = us[0]
        if "find" in spec:
            key = spec["find"].replace("、", "")[:4]
            pick = next((u for u in us if key in S.screen_plain(_btext(u.block))), us[0])
        return pick.start + 0.4


def stills(look_path: str | Path, config: dict, out_dir: Path, suffix: str = "_v2") -> tuple[list[Path], Path, list[dict]]:
    """look の stills: の時点の静止画（PNG）と一覧（JPEG）。返すのは (PNG の並び, 一覧, 各コマの説明)。"""
    lk = Look(look_path, config)
    name = lk.look.get("out", "story_main") + suffix
    single = out_dir / f"{name}_stills"
    single.mkdir(parents=True, exist_ok=True)
    pngs, infos, labels = [], [], []
    for i, spec in enumerate(lk.look["stills"], 1):
        t = lk.time_of(spec)
        img, info = lk.frame_at(t)
        p = single / f"{i:02d}.png"
        img.save(p)
        pngs.append(p)
        infos.append(info)
        m, s = divmod(int(t), 60)
        labels.append(f"{i}. 約{m}分{s:02d}秒  {spec.get('note', '')}")
    sheet = _grid(pngs, labels, out_dir / f"{lk.look.get('out', 'story_main')}_stills{suffix}.jpg", config["fonts"]["gothic"])
    return pngs, sheet, infos


def frames_at(look_path: str | Path, config: dict, specs: list[str], out_dir: Path, sheet: Path | None = None) -> tuple[list[Path], Path]:
    """書き出しと同じ描き方（Video：パン・fx・部品・図の書き込み）で、指定の時点のコマを PNG と一覧に（10-26）。
    時点は「秒」か「L行」（その行の頭の 1 秒後）・「L行+秒」・「C章」（章題カード）・「end」。声の長さは音声の控え（無ければ作る）から。"""
    from . import script
    from .cli import ROOT
    look = yaml.safe_load(Path(look_path).read_text(encoding="utf-8"))
    sc = script.load(ROOT / look["script"])
    seconds = [s.seconds for s in voice_lines(sc, config)]
    v = Video(look_path, config, seconds)
    pl = v.pl
    name = look.get("out", "story_main")
    single = out_dir / f"{name}_frames"
    single.mkdir(parents=True, exist_ok=True)
    pngs, labels = [], []
    for k, s in enumerate(specs, 1):
        s = s.strip()
        if s == "end":
            t = pl.voice_end + END_SECONDS / 2
        elif s.startswith("C"):
            t = pl.chapter_at[int(s[1:])] + CHAPTER_SECONDS / 2
        elif s.startswith("L"):
            ln, _, plus = s[1:].partition("+")
            t = pl.line_at[int(ln)][0] + (float(plus) if plus else 1.0)
        else:
            t = float(s)
        img = Image.fromarray(v.frame(t))
        p = single / f"{k:02d}.png"
        img.save(p)
        pngs.append(p)
        i, c = pl.cut_at(t)
        unit = pl.unit_at(t)
        m, sec = divmod(int(t), 60)
        labels.append(f"{k}. {m}:{sec:02d}  行{unit.line if unit else '-'}  {c.kind}:{Path(c.ref).stem}{'（図）' if c.dim else ''}")
    target = sheet or out_dir / f"{name}_frames.jpg"
    target.parent.mkdir(parents=True, exist_ok=True)
    return pngs, _grid(pngs, labels, target, config["fonts"]["gothic"])


def shotlist(look_path: str | Path, config: dict, target: Path) -> dict:
    """全カットの表（どの絵・どの切り出し・何秒）と、AI 絵の一覧・割合の要約を Markdown に。要約を返す。"""
    lk = Look(look_path, config)
    pl, sc = lk.plan, lk.sc
    ai_def = lk.look.get("ai") or {}
    share = {"AI絵（全面）": 0.0, "実在の絵（額のカード・屏風の一部）": 0.0, "図の間（絵を暗くして図）": 0.0, "章題カード": 0.0, "終了画面": 0.0}
    for c in pl.cuts:
        k = ("図の間（絵を暗くして図）" if c.dim else "章題カード" if c.kind == "chapter" else "終了画面" if c.kind == "end"
             else "AI絵（全面）" if c.kind == "ai" else "実在の絵（額のカード・屏風の一部）")
        share[k] += c.seconds
    used_ai = sorted({c.ref for c in pl.cuts if c.kind in ("ai", "end")} | {c.backdrop for c in pl.cuts if c.kind == "frame"})
    paintings = sorted({c.ref for c in pl.cuts if c.kind in ("frame", "part")})
    body_cuts = [c for c in pl.cuts if c.kind != "end"]
    avg = sum(c.seconds for c in body_cuts) / len(body_cuts)
    runs = pl.runs()
    script_cards = sum(1 for i, l in enumerate(sc.lines) if l.card and (i == 0 or sc.lines[i - 1].card != l.card))
    summary = {"total_min": pl.total / 60, "voice_min": pl.voice_end / 60, "cuts": len(pl.cuts), "avg_cut": avg,
               "ai_count": len(used_ai), "paintings": len(paintings), "share": share, "runs": runs, "script_cards": script_cards}
    out = [f"# {sc.title}｜本編（横）のショットの表（{lk.look.get('out')}）",
           "",
           "chiso/storymain.py の `shotlist` が scripts/story/oichi_main_look.yaml の shots: から作った表。時刻は字数からの見積もり"
           f"（毎分約{int(CPS * 60)}字・行間{LINE_GAP}秒・章題カード{CHAPTER_SECONDS:.0f}秒・終了画面{END_SECONDS:.0f}秒）。",
           "",
           "## 要約",
           "",
           f"- 全体 約{pl.total / 60:.1f}分（声 約{pl.voice_end / 60:.1f}分）／カット {len(pl.cuts)}／**1カットの平均 {avg:.1f}秒**"
           f"（参考15本の中央値 11.2秒）／台本の札（card）{script_cards}枚は絵の上に重ねる",
           f"- 使う AI 絵 **{len(used_ai)}枚**（16:9 横で作る）、実在の絵 {len(paintings)}枚（額のカード・屏風の一部）",
           "- 時間の割合：" + "／".join(f"{k} {v / pl.total * 100:.0f}%" for k, v in share.items()),
           f"- 同じ絵が続けて{RUN_MAX:.0f}秒を超える所：" + ("なし" if not runs else "、".join(
               f"{_mmss(a)}〜{_mmss(b)} {k}（{b - a:.0f}秒）" for a, b, k in runs)),
           "",
           "## カットの表",
           "",
           "| # | 時刻 | 秒 | 種類 | 絵 | 切り出し | 行 | 語りの頭 |",
           "|---:|---|---:|---|---|---|---|---|"]
    kinds = {"ai": "AI", "frame": "額", "part": "屏風の一部", "chapter": "章題カード", "end": "終了画面"}
    for i, c in enumerate(pl.cuts, 1):
        kind = kinds[c.kind] + ("＋図（暗く）" if c.dim else "")
        pic = (f"{c.ref} {ai_def.get(c.ref, {}).get('scene', '')[:24]}" if c.kind in ("ai", "end", "chapter")
               else Path(c.ref).name + (f"（下地 {c.backdrop}）" if c.kind == "frame" else ""))
        head = S.screen_plain(sc.lines[c.lines[0]].text)[:22] if c.lines else (sc.sections[c.section].title[:22] if c.kind == "chapter" else "")
        rng = f"{c.lines[0]}〜{c.lines[-1]}" if len(c.lines) > 1 else (str(c.lines[0]) if c.lines else "")
        out.append(f"| {i} | {_mmss(c.start)} | {c.seconds:.1f} | {kind} | {pic} | {c.crop} | {rng} | {head} |")
    out += ["", "## 作る AI 絵（16:9 横）", "", "| 絵 | 場面 | 何カット | 合計秒 | 既存の縦の絵の横版 |", "|---|---|---:|---:|---|"]
    for k in used_ai:
        cs = [c for c in pl.cuts if c.ref == k and c.kind in ("ai", "end")]
        out.append(f"| {k} | {ai_def.get(k, {}).get('scene', '')} | {len(cs)} | {sum(c.seconds for c in cs):.0f} | "
                   f"{ai_def.get(k, {}).get('horizontal_of', '新しく作る')} |")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(out) + "\n", encoding="utf-8")
    return summary


def _mmss(t: float) -> str:
    m, s = divmod(int(t), 60)
    return f"{m}:{s:02d}"


def _grid(paths: list[Path], labels: list[str], target: Path, font, cols: int = 2, cell_w: int = 960) -> Path:
    cell_h = cell_w * MH // MW
    head = 50
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell_w + 12) + 12, rows * (cell_h + head + 12) + 12), (28, 28, 28))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(str(font), 30)
    for i, p in enumerate(paths):
        x = 12 + (i % cols) * (cell_w + 12)
        y = 12 + (i // cols) * (cell_h + head + 12)
        d.text((x + 4, y + head / 2), labels[i], font=f, fill=(255, 255, 255), anchor="lm")
        sheet.paste(Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS), (x, y + head))
    target.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(target, quality=90)
    return target


# --- 書き出し（10-25）-----------------------------------------------------------
# 1コマずつ PIL で描くと 1コマ約2秒（45,000コマで25時間）かかるので、カットごとに補正済みの絵を1枚だけ作り、
# 寄り・パンは cv2.warpAffine（小数の位置で補間するのでガタつかない）、文字・札・図は透明な画像を範囲だけ重ねる。
# コマの範囲を何本かに分けて並行で描き、それぞれ ffmpeg に流して区切りの mp4 にし、最後につないで音を付ける。
FADE = 0.4                      # 絵の替わり目の溶け合い（秒）
TEXT_FADE = 0.0                 # 語りの文字は一瞬で替える（10-25 参考どおり）
DIM = 0.53                      # 図の間の絵の暗さ（frame_at の黒 120/255 と同じ）
BGM_DIFF_LU = 30.5              # BGM の LUFS を声より 30.5LU 下に。比べの物差し（50ms の音の中央値と、声の切れ目の中央値の差）で約23dB になる
                                # （10-25：22LU では物差しで 14.5dB だった。LUFS は声の大きい所で決まり、切れ目の差とは 8〜9dB ずれる）
FPS = 30


def _premul(layer: Image.Image):
    """透明な層 → 範囲だけの (x0, y0, 前掛けした色, 不透明度) の numpy。中身が無ければ None。"""
    import numpy as np
    box = layer.getbbox()
    if not box:
        return None
    a = np.asarray(layer.crop(box), dtype=np.uint16)
    alpha = a[..., 3:4]
    return box[0], box[1], (a[..., :3] * alpha // 255).astype(np.uint8), np.repeat(alpha, 3, axis=2).astype(np.uint8)


def _put(frame, ov, k: float = 1.0) -> None:
    """frame（H x W x 3 の uint8）に前掛けした層を不透明度 k で重ねる（その範囲だけ）。"""
    import cv2
    import numpy as np
    if ov is None or k <= 0.003:
        return
    x0, y0, pre, al = ov
    h, w = al.shape[:2]
    roi = frame[y0:y0 + h, x0:x0 + w]
    if k < 0.997:
        al = (al.astype(np.float32) * k).astype(np.uint8)
        pre = (pre.astype(np.float32) * k).astype(np.uint8)
    roi[:] = cv2.add(cv2.multiply(roi, 255 - al, scale=1 / 255), pre)


def _put_scaled(frame, ov, scale: float, k: float = 1.0) -> None:
    """前掛けした層を、その範囲の真ん中を中心に scale 倍して重ねる（図の板のゆっくりの寄り）。"""
    import cv2
    import numpy as np
    if ov is None:
        return
    x0, y0, pre, al = ov
    h, w = al.shape[:2]
    px, py = int(w * (scale - 1) / 2) + 2, int(h * (scale - 1) / 2) + 2
    X0, Y0 = max(0, x0 - px), max(0, y0 - py)
    X1, Y1 = min(frame.shape[1], x0 + w + px), min(frame.shape[0], y0 + h + py)
    big_pre = np.zeros((Y1 - Y0, X1 - X0, 3), np.uint8)
    big_al = np.zeros((Y1 - Y0, X1 - X0, 3), np.uint8)
    big_pre[y0 - Y0:y0 - Y0 + h, x0 - X0:x0 - X0 + w] = pre
    big_al[y0 - Y0:y0 - Y0 + h, x0 - X0:x0 - X0 + w] = al
    cx, cy = x0 - X0 + w / 2, y0 - Y0 + h / 2
    m = np.array([[scale, 0, (1 - scale) * cx], [0, scale, (1 - scale) * cy]], dtype=np.float32)
    size = (X1 - X0, Y1 - Y0)
    _put(frame, (X0, Y0, cv2.warpAffine(big_pre, m, size, flags=cv2.INTER_LINEAR),
                 cv2.warpAffine(big_al, m, size, flags=cv2.INTER_LINEAR)), k)


class Video:
    """本物の声の長さ（seconds）で決めたカットを、時刻 t のコマ（numpy）にする。"""

    def __init__(self, look_path, config: dict, seconds: list[float]):
        import numpy as np
        self.np = np
        self.lk = Look(look_path, config, seconds)
        self.pl = self.lk.plan
        self.prepared: dict[int, dict] = {}
        self.ovs: dict = {}
        band = np.ones(MH, dtype=np.float32)
        top = int(MH * 0.70)
        band[top:] = 1 - 0.30 * np.clip((np.arange(top, MH) - top) / ((MH - top) * 0.6), 0, 1)
        self.band_top = top
        self.band = (np.repeat(band[top:, None], MW, axis=1)[..., None].repeat(3, axis=2) * 255).astype(np.uint8)

    # 絵 ------------------------------------------------------------------
    def _crop_of(self, c: Cut):
        spec = ((self.lk.look.get("ai") or {}).get(c.ref) or {}) if c.kind in ("ai", "end") else {}
        if spec.get("lock"):
            z0, fx, fy = spec["lock"]
            return (float(z0), (float(fx), float(fy))), spec
        if spec.get("crops") and c.crop in spec["crops"]:
            z0, fx, fy = spec["crops"][c.crop]
            return (float(z0), (float(fx), float(fy))), spec
        return CROPS.get(c.crop, CROPS["wide"]), spec

    def prep(self, i: int) -> dict:
        if i in self.prepared:
            return self.prepared[i]
        for k in [k for k in self.prepared if k < i - 2]:
            del self.prepared[k]
        np = self.np
        c = self.pl.cuts[i]
        lk = self.lk
        src = None
        if c.kind in ("ai", "end"):
            src = lk.ai_image(c.ref).convert("RGB")
        elif c.kind == "part":
            src = lk.painting(c.ref)
        if src is not None and src.width / src.height >= 1.25:
            crop, spec = self._crop_of(c)
            if src.width > 2600:
                src = src.resize((2600, round(src.height * 2600 / src.width)), Image.LANCZOS)
            if spec.get("soften"):                                   # 上の遠景を暗くぼかす（A17）
                k = float(spec["soften"])
                hh = int(src.height * 0.55)
                top = Image.eval(src.crop((0, 0, src.width, hh)).filter(ImageFilter.GaussianBlur(4)), lambda v: int(v * k))
                mask = Image.linear_gradient("L").resize((src.width, hh)).transpose(Image.FLIP_TOP_BOTTOM)
                src.paste(top, (0, 0), mask)
            a = np.asarray(Grade(src.width, src.height, band_on=False)(src, i))
            fxspec = (lk.look.get("fx") or {}).get(c.ref) if c.kind in ("ai", "end") else None
            fx = FX(a, fxspec, seed=sum(map(ord, c.ref)), dim=DIM if c.dim else 1.0) if fxspec else None
            if c.dim:
                a = (a.astype(np.float32) * DIM).astype(np.uint8)
            p = {"src": a, "crop": crop, "move": MOVES[i % len(MOVES)] if c.kind != "end" else "in", "fx": fx}
        else:                                                         # 額・章題カード・縦長の絵：止まった1枚を少しだけ寄せる
            if c.kind == "chapter":
                back = picture(lk.ai_image(c.backdrop or c.ref), 0.5, "in", "wide")
                img = Grade(band_on=False)(back, i)
                sec = lk.sc.sections[c.section]
                label = ((lk.look.get("chapters") or {}).get(c.section) or {}).get("label", "").split(" ", 1)
                img = chapter_card(img, label[0], sec.title, lk.font_of, lk.serif)
            elif c.kind == "frame":
                back = picture(lk.ai_image(c.backdrop), 0.5, "in", "wide")
                img = Grade(band_on=False)(framed(back, None if c.dim else lk.painting(c.ref), 0.5, c.crop), i)
            else:
                img = Grade(band_on=False)(picture(src, 0.5, "in", c.crop), i)
            a = np.asarray(img.convert("RGB"))
            if c.dim:
                a = (a.astype(np.float32) * DIM).astype(np.uint8)
            p = {"src": a, "crop": (1.0, (0.5, 0.5)), "move": "in", "static": True}
        p["path"] = self._path(i, c, p)
        self.prepared[i] = p
        return p

    def _targets(self, c: Cut) -> list[tuple[float, tuple]]:
        """このカットで語られる物・人・場所（look の focus）の (言う時刻, (倍率, 中心x, 中心y))。額は額の中の絵の位置を画面の位置に直す。"""
        focus = self.lk.look.get("focus") or {}
        if c.kind == "ai":
            return self.pl.focus_events(c, focus.get(c.ref))
        if c.kind == "frame" and not c.dim:
            ev = self.pl.focus_events(c, focus.get(c.ref))
            if not ev:
                return []
            pw, ph = self.lk.painting(c.ref).size
            if c.crop == "b":
                pw, ph = pw * 0.84, ph * 0.72
            s_ = min(1180 / pw, 740 / ph)
            w, h = pw * s_, ph * s_
            x0, y0 = (MW - w) / 2, 92 + (740 - h) / 2
            out = []
            for te, (z, fx, fy) in ev:
                if c.crop == "b":
                    fx, fy = (fx - 0.08) / 0.84, fy / 0.72
                out.append((te, (min(z, FRAME_CAP), (x0 + fx * w) / MW, (y0 + fy * h) / MH)))
            return out
        return []

    def _path(self, i: int, c: Cut, p: dict) -> tuple:
        """カットの最初と最後の窓 (倍率, 中心x, 中心y)。あいだは一定の速さで動かす（10-25 歴史横丁の型）。
        動きはパン（平行移動）が主（10-25 ユーザー「寄せるではなく、上から下に、右から左に動くでは？」）：絵を PAN_SCALE 倍ほどに置き、
        その余白の中を端から端へ流す。縦の構図（look の ai の pan: v）は上下、横の構図（pan: h、既定）は左右。隣のカットとは向きを替える。
        向きと止まる所は話で決める：その行で語る物・人（look の focus）があれば、終わりにそれが画面の主役になる所で止める。
        2つ語られれば1つ目から2つ目へ流す（明かしのパン）。寄り（拡大）は pan: zoom の絵（顔の感情の場面）だけ。"""
        d = max(0.5, c.seconds)
        if c.dim or c.kind == "chapter":                  # 図の間・章題カードは止める（キンブラ：図の場面は寄らない）
            base = (1.0, 0.5, 0.5) if p.get("static") else (p["crop"][0], *p["crop"][1])
            return base, base
        cz, (fx, fy) = ((1.0, (0.5, 0.5)) if p.get("static") else p["crop"])
        spec = ((self.lk.look.get("ai") or {}).get(c.ref) or {}) if c.kind in ("ai", "end") else {}
        mode = str(spec.get("pan", "h"))
        if c.kind == "frame":
            mode = "v" if self.lk.painting(c.ref).height > self.lk.painting(c.ref).width else "h"
        rate = PAN_RATE
        room = min(PAN_MAX - 1, max(PAN_MIN - 1, rate * d))             # 余白（画面の幅に対する割合）
        z = max(cz, 1 + room)
        travel = 1 - 1 / z                                               # 窓が動ける量（絵の幅・高さに対する割合）
        tg = self._targets(c) if c.kind in ("ai", "frame") else []
        if mode == "zoom":                                # 顔の感情の場面：一定の速さでゆっくり寄る
            z1 = min(ZOOM_CAP, cz * (1 + ZOOM_RATE * d))
            ex, ey = (tg[0][1][1], tg[0][1][2]) if tg else (fx, fy)
            return (cz, fx, fy), (z1, ex, ey)
        if len(tg) >= 2:                                  # 明かしのパン：1つ目 → 2つ目
            (_, a), (_, b) = tg[0], tg[1]
            zz = max(z, 1 + min(0.25, abs(b[1] - a[1]) + abs(b[2] - a[2])))
            zz = min(zz, PAN_MAX + 0.1)
            return (zz, a[1], a[2]), (zz, b[1], b[2])
        flip = (i // 1) % 2 == 1
        if mode == "v":
            sx, sy = 0.0, (1 if flip else -1)            # 上→下（窓が下へ）か 下→上
        else:
            sx, sy = (1 if flip else -1), 0.0            # 左→右 か 右→左
        if tg:                                            # 語られる物・人の所で止まるように、反対側から流してくる
            _, (_, tx, ty) = tg[0]
            if mode == "v":
                sy = 1 if ty >= fy else -1
            else:
                sx = 1 if tx >= fx else -1
            end = (tx, ty)
        else:                                             # 余白の端から端へ（流す向きの軸は絵の真ん中に置く）
            end = (0.5 + sx * travel / 2 if sx else fx, 0.5 + sy * travel / 2 if sy else fy)
        start = (end[0] - sx * travel, end[1] - sy * travel)
        return (z, start[0], start[1]), (z, end[0], end[1])
    def base(self, i: int, t: float):
        import cv2
        np = self.np
        c = self.pl.cuts[i]
        p = self.prep(i)
        a = p["src"]
        if p.get("fx") is not None:                          # 炎・灯・煙・霧・水面だけを少し動かす（寄る前の絵にかけるので位置はずれない）
            a = p["fx"].apply(a, t)
        sh, sw = a.shape[:2]
        # カットの最初から最後まで一定の速さで（緩めない）。向きと終点は _path が話で決めている
        (z0, x0_, y0_), (z1, x1_, y1_) = p["path"]
        u = min(1.0, max(0.0, (t - c.start) / max(0.01, c.seconds)))
        z = z0 + (z1 - z0) * u
        focus = (x0_ + (x1_ - x0_) * u, y0_ + (y1_ - y0_) * u)
        dx = dy = 0.0
        if sw / sh > MW / MH:
            wh, ww = sh, sh * MW / MH
        else:
            ww, wh = sw, sw * MH / MW
        ww, wh = ww / z, wh / z
        cx = min(max(focus[0] * sw + dx * ww, ww / 2), sw - ww / 2)
        cy = min(max(focus[1] * sh + dy * wh, wh / 2), sh - wh / 2)
        sx, sy = MW / ww, MH / wh
        m = np.array([[sx, 0, -(cx - ww / 2) * sx], [0, sy, -(cy - wh / 2) * sy]], dtype=np.float32)
        return cv2.warpAffine(a, m, (MW, MH), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)

    # 重ねる物 --------------------------------------------------------------
    def ov(self, key, build):
        if key not in self.ovs:
            if len(self.ovs) > 80:
                self.ovs.pop(next(iter(self.ovs)))
            lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
            r = build(lay)
            self.ovs[key] = _premul(r if isinstance(r, Image.Image) else lay)
        return self.ovs[key]

    def _cut_overlays(self, frame, c: Cut, line, w: float, t: float = 0.0) -> None:
        lk = self.lk
        if c.kind in ("chapter", "end"):
            return
        spec = self.pl.fig(line.index) if line is not None else None
        if c.dim and spec:
            r = self.pl.run_of(line.index)
            if r and r["names"]:                          # 語りが名前を言う REVEAL_LEAD 秒前から、その項目を書き込む
                times = [x - REVEAL_LEAD for x in r["times"]]
                n = max(1, sum(1 for x in times if x <= t))
                if r["spec"].get("type") == "people":     # 関係図・系図はキンブラ型：点線が0.2秒で伸びる→札が0.25秒で出る→関係の小札
                    p = 1.0 if n == 1 and t - times[0] > 0.7 else min(1.0, max(0.0, (t - times[n - 1]) / 0.7))
                    q = round(p * 14) / 14
                    key = ("figk", r["key"], n, q)

                    def fig(lay, spec=r["spec"], n=n, q=q):
                        return people_reveal(lk.painter, lay, spec, n, q)
                else:
                    p = 1.0 if n == 1 and t - times[0] > 0.6 else min(1.0, max(0.0, (t - times[n - 1]) / 0.6))
                    q = round(p * 8) / 8
                    s2 = Plan.fig_upto(r["spec"], n)
                    key = ("fig", r["key"], n, q)

                    def fig(lay, s2=s2, q=q):
                        from . import figures
                        return figures.draw(lk.painter, lay, s2, q)
            else:
                key = ("fig", line.index)

                def fig(lay, s2=spec):
                    from . import figures
                    return figures.draw(lk.painter, lay, s2, 1.0)
            _put(frame, self.ov(key, fig), w)
        if c.kind in ("ai", "frame") or (c.dim and c.backdrop):
            _put(frame, self.ov(("ai",), lambda lay: draw_ai_label(lay, lk.font_of)), w)
        if c.kind in ("frame", "part") and not c.dim:
            text = lk.credits.get(c.ref) or Path(c.ref).stem
            _put(frame, self.ov(("credit", c.ref), lambda lay: draw_credit(lay, text, lk.font_of)), w)

    def _part(self, img, n: int, part: dict, age: float) -> None:
        """look の parts の1つを、出てから age 秒の姿で重ねる（0.25秒で溶け出す。並ぶ物は1つずつ）。"""
        lk = self.lk
        kind = part["type"]
        if kind in ("quote", "doc"):
            k = min(1.0, max(0.0, age / 0.25))
            q = round(k * 5) / 5
            build = (lambda lay: draw_quote_card(lay, part, lk.font_of, lk.serif)) if kind == "quote" else \
                (lambda lay: draw_doc_page(lay, part, lk.painting(part["image"]), lk.font_of))
            _put(img, self.ov(("part", n), build), q)
            return
        items = part.get("items") or []
        gap = float(part.get("every", 0.6))
        shown = max(0, min(len(items), int(age / gap) + 1)) if age >= 0 else 0
        step = min(1.0, max(0.0, (age - (shown - 1) * gap) / 0.25)) if shown else 0.0
        q = round(step * 4) / 4
        if kind == "versus3":
            build = lambda lay: draw_versus_boxes(lay, part, shown, q, lk.font_of)
        else:
            build = lambda lay: draw_name_cards(lay, part, shown, q, lk.font_of, lk.serif, lk.picture_of)
        _put(img, self.ov(("part", n, shown, q), build))

    def frame(self, t: float):
        import cv2
        pl, lk = self.pl, self.lk
        i, c = pl.cut_at(t)
        img = self.base(i, t)
        parts = [(c, 1.0)]
        j, e = None, 0.0
        def same(a: Cut, b: Cut) -> bool:                 # 同じ絵の別の構図（切り出し・図の有無）だけ溶け合わせる。ほかはハードカット
            return a.kind == b.kind and a.ref == b.ref and "chapter" not in (a.kind, b.kind)
        if i + 1 < len(pl.cuts) and t >= c.end - SAME_FADE / 2 and same(c, pl.cuts[i + 1]):
            j, e = i + 1, S._ease((t - (c.end - SAME_FADE / 2)) / SAME_FADE)
        elif i > 0 and t < c.start + SAME_FADE / 2 and same(c, pl.cuts[i - 1]):
            j, e = i - 1, 1 - S._ease((t - (c.start - SAME_FADE / 2)) / SAME_FADE)
        if j is not None and e > 0.002:
            img = cv2.addWeighted(img, 1 - e, self.base(j, t), e, 0)
            parts = [(c, 1 - e), (pl.cuts[j], e)]
        img = self.np.ascontiguousarray(img)
        if c.kind != "chapter":
            img[self.band_top:] = cv2.multiply(img[self.band_top:], self.band, scale=1 / 255)
        unit = pl.unit_at(t)
        line = lk.sc.lines[unit.line] if unit else None
        if line is not None and not c.dim and c.kind not in ("chapter", "end"):   # 部品が主役の間は、絵を図の間と同じだけ暗くする
            for part in lk.look.get("parts") or []:
                if int(part["from"]) <= line.index <= int(part.get("to", part["from"])) and part.get("dim", True):
                    k_ = min(1.0, max(0.0, (t - (pl.line_at[int(part["from"])][0] - 0.2)) / 0.25))
                    img = cv2.convertScaleAbs(img, alpha=1 - (1 - DIM) * k_)
                    break
        for cc, w in parts:
            self._cut_overlays(img, cc, line, w, t)
        if c.kind in ("chapter", "end") or line is None:
            return img
        covered = any(int(p_["from"]) <= line.index <= int(p_.get("to", p_["from"])) for p_ in lk.look.get("parts") or [])
        if not c.dim and is_point_card(line.card) and not covered:   # 部品が出ている行は右上の札を出さない（同じ言葉を2つ並べない。10-26）
            prev = lk.sc.lines[line.index - 1].card if line.index else None
            if prev != line.card:
                t0 = pl.line_at[line.index][0]
                _put(img, self.ov(("card", line.index), lambda lay: draw_card(lay, line.card.head, line.card.body, lk.font_of)),
                     min(1.0, max(0.0, (t - t0) / 0.25)))
        tag = pl.corner(line.index)
        if tag:
            _put(img, self.ov(("corner", tag), lambda lay: draw_corner(lay, tag, lk.font_of)))
        for n_part, part in enumerate(lk.look.get("parts") or []):     # 部品（史料の札・くい違いの箱・覚えてほしい名前・史料の頁）
            a, b = int(part["from"]), int(part.get("to", part["from"]))
            if a <= line.index <= b and not c.dim:
                t0 = pl.line_at[a][0] - 0.2
                self._part(img, n_part, part, t - t0)
        k = pl.units.index(unit)
        key = ("text", k)
        if key not in self.ovs:
            y = int(MH * TEXT_Y)
            bright = float(img[y - 70:y + 70, 360:MW - 360].mean()) > 105
            font = lk.serif(TEXT_SIZE) if is_record(line) else lk.font_of(TEXT_SIZE)
            self.ov(key, lambda lay: text_layer(unit.block, font, line.imagined, bright, lk.font_of(24)))
        _put(img, self.ovs[key])                          # 字幕は文（ブロック）ごとに一瞬で替える（参考どおり。冒頭も0秒からはっきり）
        if is_record(line):                               # 記録の言葉：読んでいる所まで赤ペンの下線を引く（chiso/pen.py の mark の考え方）
            ov = self.ovs[key]
            if ov is not None:
                x0, y0, _pre, al = ov
                h, w_ = al.shape[:2]
                frac = min(1.0, max(0.0, (t - unit.start) / max(0.3, unit.end - unit.start)))
                rows = len(unit.block.rows)
                step = int(TEXT_SIZE * ROW_STEP)
                base_y = int(MH * TEXT_Y - step * rows / 2)
                total = frac * rows
                for ri in range(rows):
                    part = min(1.0, max(0.0, total - ri))
                    if part <= 0:
                        break
                    y = base_y + step * ri + int(TEXT_SIZE * 1.02)
                    xa, xb = x0 + 20, x0 + w_ - 20
                    cv2.line(img, (xa, y), (int(xa + (xb - xa) * part), y), (196, 40, 40), 4, cv2.LINE_AA)
        return img


def _render_segment(job: tuple) -> str:
    """並行の1本：コマ f0〜f1 を描いて ffmpeg に流し、区切りの mp4 を書く。"""
    look_path, config, seconds, f0, f1, target, ffmpeg_exe = job
    import subprocess
    v = Video(look_path, config, seconds)
    cmd = [ffmpeg_exe, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{MW}x{MH}", "-r", str(FPS),
           "-i", "-", "-c:v", "libx264", "-preset", "veryfast", "-crf", "19", "-pix_fmt", "yuv420p", "-g", str(FPS * 2),
           "-threads", "2", str(target)]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for n in range(f0, f1):
        proc.stdin.write(v.frame((n + 0.5) / FPS).tobytes())
    proc.stdin.close()
    if proc.wait() != 0:
        raise RuntimeError(f"ffmpeg が失敗しました: {target}")
    return str(target)


def voice_lines(sc, config) -> list:
    """全行の声（chiso の音声合成。剣崎＝語り、人物の行は config の roles の声。控えは work/<台本>/voice で cli voice と同じ）。"""
    from . import tts
    from .cli import ROOT, load_readings, voices, work_dir
    engine = tts.Voicevox(config["voicevox_url"])
    vs = voices(config)
    readings = load_readings(ROOT / "readings.yaml")
    cache = work_dir(sc) / "voice"
    out = []
    for n, line in enumerate(sc.lines, 1):
        out.append(tts.speak_line(engine, line, vs, readings, cache))
        print(f"\r音声 {n}/{len(sc.lines)}", end="", flush=True)
    print()
    return out


def build(look_path, config: dict, out_dir: Path, limit: float | None = None, workers: int = 4, name: str | None = None) -> dict:
    """本編（横）を書き出す。limit 秒で打ち切る試し書きもできる。仮ファイルに書いて、長さを測ってから置き換える。
    返すのは工程ごとの秒数・長さなど。"""
    import os
    import shutil
    import subprocess
    import time
    from concurrent.futures import ProcessPoolExecutor
    from . import mix, storyaudio
    from .cli import ffmpeg, work_dir
    times: dict[str, float] = {}
    t_all = time.time()
    lk0 = Look(look_path, config)
    sc = lk0.sc
    stem = name or sc.path.stem
    wd = work_dir(sc) / "story_main"
    wd.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    spoken = voice_lines(sc, config)
    times["音声"] = time.time() - t0
    seconds = [s.seconds for s in spoken]
    pl = Plan(lk0.look, sc, seconds)
    total = pl.total if limit is None else min(limit, pl.total)
    t0 = time.time()
    cues = [mix.Cue(line, round(pl.line_at[line.index][0], 3), round(pl.line_at[line.index][1], 3), s.wav)
            for line, s in zip(sc.lines, spoken)]
    import hashlib
    key = hashlib.sha256(json.dumps([[str(c.wav), c.start] for c in cues] + [pl.total, BGM_DIFF_LU]).encode()).hexdigest()[:16]
    keyfile = wd / "voice_bgm.key"
    if (wd / "voice_bgm.wav").exists() and keyfile.exists() and keyfile.read_text() == key:   # 声の並びが同じなら BGM の重ねを使い回す（約6分）
        bgm = json.loads((wd / "voice_bgm.json").read_text(encoding="utf-8"))
    else:
        mix.write_audio(cues, pl.total, wd / "voice.wav")
        bgm = storyaudio.mix_voice_bgm(wd / "voice.wav", wd / "voice_bgm.wav", pl.total, [], ffmpeg(), diff_lu=BGM_DIFF_LU)
        bgm = {k: (float(v) if hasattr(v, "__float__") and not isinstance(v, (list, dict)) else v) for k, v in bgm.items()}
        (wd / "voice_bgm.json").write_text(json.dumps(bgm, ensure_ascii=False), encoding="utf-8")
        keyfile.write_text(key)
    bgm["gap_db"] = pause_gap_db(wd / "voice_bgm.wav")         # 比べと同じ物差し（声の中央値と切れ目の差）。参考の中央値 23dB
    times["声とBGMの重ね"] = time.time() - t0
    t0 = time.time()
    frames = int(round(total * FPS))
    n_seg = max(workers * 2, 1) if limit is None or limit > 120 else workers
    bounds = [frames * k // n_seg for k in range(n_seg + 1)]
    segs = [wd / f"seg{k:02d}.mp4" for k in range(n_seg)]
    jobs = [(str(look_path), config, seconds, bounds[k], bounds[k + 1], str(segs[k]), ffmpeg()) for k in range(n_seg)]
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for k, _ in enumerate(ex.map(_render_segment, jobs), 1):
            print(f"\r映像 {k}/{n_seg}", end="", flush=True)
    print()
    times["映像（描く＋符号化）"] = time.time() - t0
    t0 = time.time()
    lst = wd / "segments.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in segs), encoding="utf-8")
    target = out_dir / f"{stem}.mp4"
    part = out_dir / f"{stem}.{os.getpid()}.part.mp4"
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-i", str(wd / "voice_bgm.wav"),
           "-t", f"{total:.3f}", "-map", "0:v", "-map", "1:a", "-c:v", "copy",
           "-af", loud_gain(wd / "voice_bgm.wav"),     # 全体を同じ倍率で上げる（loudnorm は声の間で BGM を持ち上げ、差が 22→13LU に縮んだ。10-25）
           "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
           "-movflags", "+faststart", str(part)]
    subprocess.run(cmd, check=True)
    dur = probe_seconds(part)
    if abs(dur - total) > 1.0:
        raise RuntimeError(f"書き出した長さ {dur:.1f}秒が予定 {total:.1f}秒と合いません（{part} は残しました）")
    shutil.move(str(part), str(target))
    for p in segs:
        p.unlink(missing_ok=True)
    times["つなぎと音"] = time.time() - t0
    times["合計"] = time.time() - t_all
    return {"target": target, "seconds": dur, "plan_total": pl.total, "times": times, "bgm": bgm, "cuts": len(pl.cuts)}


def probe_seconds(path: Path) -> float:
    """動画の長さ（秒）。ffprobe が無ければ ffmpeg の出力から読む。"""
    import re as _re
    import shutil
    import subprocess
    from .cli import ffmpeg
    probe = shutil.which("ffprobe")
    if probe:
        out = subprocess.run([probe, "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)],
                             capture_output=True, text=True, check=True).stdout
        return float(out.strip())
    err = subprocess.run([ffmpeg(), "-i", str(path)], capture_output=True, text=True, encoding="utf-8", errors="replace").stderr
    h, m, s = _re.search(r"Duration: (\d+):(\d+):([\d.]+)", err).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


TARGET_LUFS = -16.0             # 本編の大きさ（YouTube の基準に近く。上げ過ぎると頭を叩く所が増える）


def loud_gain(wav: Path) -> str:
    """声＋BGM の全体を同じ倍率で TARGET_LUFS へ。はみ出す頭だけ alimiter で抑える（声と BGM の差は変えない）。"""
    from . import storyaudio
    from .cli import ffmpeg
    gain = TARGET_LUFS - storyaudio.lufs(ffmpeg(), wav)
    return f"volume={gain:.2f}dB,alimiter=limit=0.89:level=disabled"


def pause_gap_db(wav: Path) -> float:
    """声と BGM の差の物差し（research の mainana/audio.py と同じ）：50ms ごとの音の大きさの中央値と、
    それより 12dB 以上小さい所（声の切れ目）の中央値の差。"""
    import numpy as np
    from . import storyaudio
    a, sr = storyaudio.read_wav(wav)
    n = int(sr * 0.05)
    fr = a[:len(a) // n * n].reshape(-1, n)
    db = 20 * np.log10(np.sqrt((fr ** 2).mean(1)) + 1e-7)
    p50 = float(np.percentile(db, 50))
    pause = db < p50 - 12
    return p50 - float(np.median(db[pause])) if pause.sum() > 10 else float("nan")


def holds(plan: "Plan", long: float = 30.0) -> tuple[float, float]:
    """画面が大きく替わる所（絵・図の有無が替わる所）の間隔から、(いちばん長い間, long 秒以上替わらない時間の割合)。
    同じ絵の切り出しの替わりは数えない（比べの changes.py では替わりと数えられないことがあるので、厳しい側で見る）。"""
    marks = [0.0]
    prev = None
    for c in plan.cuts:
        key = (c.kind, c.backdrop if c.kind == "frame" else c.ref, c.dim)   # 額どうしは下地が同じなら替わりと見なさない（真ん中の絵だけ替わる）
        if prev is not None and key != prev:
            marks.append(c.start)
        prev = key
    marks.append(plan.total)
    gaps = [b - a for a, b in zip(marks, marks[1:])]
    return max(gaps), sum(g for g in gaps if g >= long) / plan.total


# --- 絵の一部だけを動かす効果（10-25 ユーザー「Bもやろう」）--------------------------------------
# 参考の本編の多くは絵の中身が動いている。話に関係ない寄り・パンはしないまま、場面の絵の「その物」だけを少し生かす：
# 炎のゆらぎ＋舞い上がる火の粉・灯のにじみのちらつき・煙や霧の横流れ・水面の月の揺れ。look の fx: に絵ごとに書く。
# 効果は補正済みの元の絵（寄る前）にかけるので、寄りがかかっても位置はずれない。どれも控えめに（雰囲気を壊さない）。
FX_LOOP = 6.0                   # 火の粉のくり返しの長さ（秒）


def _smooth_noise(t: float, seed: int, lo: float = 1.0, hi: float = 3.0) -> float:
    """lo〜hi Hz のなめらかなゆらぎ（-1〜1）。周波数と位相の違う正弦を3つ重ねる。"""
    import numpy as np
    rng = np.random.default_rng(seed)
    f = rng.uniform(lo, hi, 3)
    ph = rng.uniform(0, 2 * np.pi, 3)
    w = np.array([0.5, 0.3, 0.2])
    return float((w * np.sin(2 * np.pi * f * t + ph)).sum() / w.sum())


def _field(h: int, w: int, seed: int, cell: int = 48):
    """なめらかな空間のむら（0〜1）。小さな乱数を拡大してぼかしたもの。"""
    import cv2
    import numpy as np
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, h // cell), max(2, w // cell))).astype(np.float32)
    f = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    f = cv2.GaussianBlur(f, (0, 0), cell / 2)
    f -= f.min()
    return f / max(1e-6, f.max())


def _region(h: int, w: int, rect) -> tuple[int, int, int, int]:
    if not rect:
        return 0, 0, w, h
    x0, y0, x1, y1 = rect
    return int(w * x0), int(h * y0), int(w * x1), int(h * y1)


class FX:
    """1枚の絵（補正済みの numpy、RGB）に、look の fx の指定で効果を毎コマかける。"""

    def __init__(self, src, spec: dict, seed: int = 0, dim: float = 1.0):
        import cv2
        import numpy as np
        self.np, self.cv2 = np, cv2
        self.spec, self.seed, self.dim = spec or {}, seed, dim
        h, w = src.shape[:2]
        self.h, self.w = h, w
        hsv = cv2.cvtColor(src, cv2.COLOR_RGB2HSV).astype(np.float32)   # H 0〜180, S・V 0〜255
        H, Sat, V = hsv[..., 0], hsv[..., 1] / 255, hsv[..., 2] / 255
        self.layers = []
        if "fire" in self.spec:
            o = self.spec["fire"] or {}
            warm = ((H <= 22) | (H >= 172)).astype(np.float32)
            m = warm * np.clip((Sat - 0.40) / 0.25, 0, 1) * np.clip((V - 0.45) / 0.25, 0, 1)
            m = self._clip(m, o.get("region"))
            m = cv2.GaussianBlur(m, (0, 0), 3)
            self.fire = m
            self.fire_amp = float(o.get("amp", 0.12))
            self.fire_fields = [_field(h, w, seed + k, 40) for k in range(2)]
            if "sparks" in self.spec:
                self._init_sparks(self.spec["sparks"] or {}, m)
        if "lamp" in self.spec:
            o = self.spec["lamp"] or {}
            core = (((H <= 35) | (H >= 170)).astype(np.float32) * np.clip((V - 0.62) / 0.15, 0, 1)
                    * np.clip((Sat - 0.08) / 0.2, 0, 1))
            core = self._clip(core, o.get("region"))
            glow = cv2.GaussianBlur(core, (0, 0), max(6, w / 90))
            self.lamp = glow / max(1e-6, glow.max())
            self.lamp_amp = float(o.get("amp", 0.08))
        for key in ("smoke", "mist"):
            if key in self.spec:
                o = self.spec[key] or {}
                x0, y0, x1, y1 = _region(h, w, o.get("region"))
                band = np.zeros((h, w), np.float32)
                band[y0:y1, x0:x1] = 1
                band = cv2.GaussianBlur(band, (0, 0), max(8, (y1 - y0) / 6))
                tex = [np.tile(_field(h, w, seed + 10 + k, 90 + 40 * k), (1, 2)) for k in range(2)]
                color = np.array(o.get("color", [200, 205, 210] if key == "mist" else [120, 115, 110]), np.float32)
                self.layers.append((band, tex, color, float(o.get("alpha", 0.10)), float(o.get("speed", 10))))
        self.water = None
        if "water" in self.spec:
            o = self.spec["water"] or {}
            self.water = (_region(h, w, o.get("region")), float(o.get("amp", 2.5)))

    def _clip(self, m, rect):
        if not rect:
            return m
        x0, y0, x1, y1 = _region(self.h, self.w, rect)
        out = self.np.zeros_like(m)
        out[y0:y1, x0:x1] = m[y0:y1, x0:x1]
        return out

    def _init_sparks(self, o: dict, mask) -> None:
        np = self.np
        rng = np.random.default_rng(self.seed + 99)
        ys, xs = np.nonzero(mask > 0.5)
        n = int(o.get("count", 40))
        if len(xs) == 0:
            self.sparks = None
            return
        pick = rng.integers(0, len(xs), n)
        self.sparks = {
            "x": xs[pick].astype(np.float32), "y": ys[pick].astype(np.float32),
            "birth": rng.uniform(0, FX_LOOP, n), "life": rng.uniform(1.4, 3.0, n),
            "vy": rng.uniform(18, 55, n) * self.h / 768, "sway": rng.uniform(4, 12, n) * self.h / 768,
            "freq": rng.uniform(0.6, 1.6, n), "size": rng.uniform(1.0, 2.2, n) * self.h / 768,
        }

    @staticmethod
    def _bbox(m, thr: float = 0.01, pad: int = 4, h: int = 0, w: int = 0, up: int = 0):
        import numpy as np
        ys, xs = np.nonzero(m > thr)
        if len(xs) == 0:
            return None
        return (max(0, xs.min() - pad), max(0, ys.min() - pad - up), min(w, xs.max() + pad + 1), min(h, ys.max() + pad + 1))

    def _rois(self):
        """効果がかかる範囲だけを計算する（毎コマ全面を浮動小数で回すと 1コマ 0.3〜0.6 秒かかった）。"""
        if hasattr(self, "_roi"):
            return self._roi
        r = {}
        if hasattr(self, "fire"):
            r["fire"] = self._bbox(self.fire, h=self.h, w=self.w)
        if hasattr(self, "lamp"):
            r["lamp"] = self._bbox(self.lamp, 0.02, h=self.h, w=self.w)
        r["layers"] = [self._bbox(b, 0.02, h=self.h, w=self.w) for b, *_ in self.layers]
        if getattr(self, "sparks", None):
            sp = self.sparks
            rise = int((sp["vy"] * sp["life"]).max()) + 8
            x0, y0 = int(sp["x"].min()) - 20, int(sp["y"].min()) - rise
            x1, y1 = int(sp["x"].max()) + 20, int(sp["y"].max()) + 10
            r["sparks"] = (max(0, x0), max(0, y0), min(self.w, x1), min(self.h, y1))
        self._roi = r
        return r

    def apply(self, src, t: float):
        np, cv2 = self.np, self.cv2
        roi = self._rois()
        out = src.copy()
        if roi.get("fire"):
            x0, y0, x1, y1 = roi["fire"]
            g = self.fire_amp * 0.6 * (self.fire_fields[0][y0:y1, x0:x1] * _smooth_noise(t, self.seed + 1)
                                       + self.fire_fields[1][y0:y1, x0:x1] * _smooth_noise(t, self.seed + 2))   # 場所ごとに違う揺れ（±約10%）
            k = 1 + self.fire[y0:y1, x0:x1] * g
            out[y0:y1, x0:x1] = np.clip(out[y0:y1, x0:x1].astype(np.float32) * k[..., None], 0, 255).astype(np.uint8)
        if roi.get("lamp"):
            x0, y0, x1, y1 = roi["lamp"]
            k = 1 + self.lamp[y0:y1, x0:x1] * self.lamp_amp * _smooth_noise(t, self.seed + 3, 0.5, 2.0)
            out[y0:y1, x0:x1] = np.clip(out[y0:y1, x0:x1].astype(np.float32) * k[..., None], 0, 255).astype(np.uint8)
        for (band, tex, color, alpha, speed), box in zip(self.layers, roi["layers"]):
            if not box:
                continue
            x0, y0, x1, y1 = box
            acc = np.zeros((y1 - y0, x1 - x0), np.float32)
            for j, tx in enumerate(tex):
                off = int((t * speed * (1 + 0.6 * j)) % self.w)
                acc += tx[y0:y1, off + x0:off + x1] * (0.6 if j == 0 else 0.4)
            a = (band[y0:y1, x0:x1] * np.clip(acc * 1.6 - 0.3, 0, 1.3) * alpha)[..., None]   # むらを強めて、流れが見えるように
            part = out[y0:y1, x0:x1].astype(np.float32)
            out[y0:y1, x0:x1] = (part * (1 - a) + color * a).astype(np.uint8)
        if self.water:
            (x0, y0, x1, y1), amp = self.water
            yy, xx = np.mgrid[0:y1 - y0, 0:x1 - x0].astype(np.float32)
            hh, ww = max(1, y1 - y0), max(1, x1 - x0)
            taper = np.sin(np.pi * np.clip(yy / hh, 0, 1)) * np.sin(np.pi * np.clip(xx / ww, 0, 1))   # 範囲の縁では揺らさない（継ぎ目を出さない）
            mx = xx + amp * taper * np.sin(2 * np.pi * ((yy + y0) / 34.0 + t * 0.25))
            out[y0:y1, x0:x1] = cv2.remap(np.ascontiguousarray(src[y0:y1, x0:x1]), mx, yy, cv2.INTER_LINEAR,
                                          borderMode=cv2.BORDER_REFLECT)
        if roi.get("sparks"):
            s = self.sparks
            x0, y0, x1, y1 = roi["sparks"]
            age = (t - s["birth"]) % FX_LOOP
            alive = age < s["life"]
            if alive.any():
                glow = np.zeros((y1 - y0, x1 - x0), np.float32)
                for x, y, a, life, vy, sw, fq, sz in zip(s["x"][alive], s["y"][alive], age[alive], s["life"][alive],
                                                         s["vy"][alive], s["sway"][alive], s["freq"][alive], s["size"][alive]):
                    px = x + sw * np.sin(2 * np.pi * fq * a) - x0
                    py = y - vy * a - y0
                    fade = min(1.0, a / 0.3) * max(0.0, 1 - a / life)
                    cv2.circle(glow, (int(px), int(py)), max(1, int(round(sz))), float(fade), -1, cv2.LINE_AA)
                glow = cv2.GaussianBlur(glow, (0, 0), 1.2)
                add = glow[..., None] * np.array([255, 150, 50], np.float32) * 0.9 * self.dim
                out[y0:y1, x0:x1] = np.clip(out[y0:y1, x0:x1].astype(np.float32) + add, 0, 255).astype(np.uint8)
        return out


# --- 関係図（キンブラ型）と部品（10-25 screen_parts_1025.md）---------------------------------------
def people_reveal(painter, img: Image.Image, spec: dict, n: int, p: float) -> Image.Image:
    """人物の関係図・系図を、先頭 n 人まで描く。n 人目は p（0〜1）で：赤い点線が 0.2 秒で伸びる → 札が 0.25 秒で溶け出す → 線の上の関係の小札。
    並び（円の上の位置）は chiso/figures.py の people と同じ。紙の板・題も同じ（見た目をそろえる）。"""
    import math
    from . import figures as F
    dr, (ax0, ay0, ax1, ay1) = F._panel(painter, img, spec.get("title", ""))
    nodes = spec["nodes"]
    total = len(nodes)
    cx, cy = (ax0 + ax1) / 2, (ay0 + ay1) / 2 + 6
    rx, ry = (ax1 - ax0) / 2 - 170, (ay1 - ay0) / 2 - 60
    pos = {}
    for i, (name, _role) in enumerate(nodes):
        a = -math.pi / 2 + 2 * math.pi * i / total + (math.pi / total if total % 2 == 0 else 0)
        pos[name] = (cx + rx * math.cos(a), cy + ry * math.sin(a))
    shown = [nm for nm, _ in nodes[:n]]
    new = nodes[n - 1][0] if n >= 1 else None
    line_p = min(1.0, p / 0.29)                 # 0.2 秒ぶん（全体 0.7 秒の 0.29）
    card_p = min(1.0, max(0.0, (p - 0.29) / 0.36))
    tag_p = min(1.0, max(0.0, (p - 0.65) / 0.35))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer, "RGBA")
    ef = painter.font("gothic", 24)
    for a, b, label in spec.get("edges", []):
        if a not in shown or b not in shown:
            continue
        pa, pb = pos[a], pos[b]
        k = 1.0
        if new in (a, b) and n > 1:
            k = line_p
            if b == new:
                pass
            else:                                   # 新しい人から伸びるのではなく、前からいる人から新しい人へ伸ばす
                pa, pb = pb, pa
        ex, ey = pa[0] + (pb[0] - pa[0]) * k, pa[1] + (pb[1] - pa[1]) * k
        L = math.hypot(ex - pa[0], ey - pa[1])
        if L > 1:
            ux, uy = (ex - pa[0]) / L, (ey - pa[1]) / L
            dist = 0.0
            while dist < L:                         # 点線（14画素の線と 9画素のすき間）
                e2 = min(L, dist + 14)
                ld.line([(pa[0] + ux * dist, pa[1] + uy * dist), (pa[0] + ux * e2, pa[1] + uy * e2)], fill=F.RED + (255,), width=5)
                dist += 23
        tk = 1.0 if new not in (a, b) or n == 1 else tag_p
        if tk > 0.01:
            mx, my = (pos[a][0] + pos[b][0]) / 2, (pos[a][1] + pos[b][1]) / 2
            w = ef.getlength(label) + 22
            al = int(255 * tk)
            ld.rounded_rectangle([mx - w / 2, my - 19, mx + w / 2, my + 19], radius=8, fill=(255, 248, 230, al),
                                 outline=F.RED + (al,), width=2)
            ld.text((mx, my), label, font=ef, fill=F.RED + (al,), anchor="mm")
    nf = painter.font("serif", 32, bold=True)
    rf = painter.font("gothic", 22)
    for i, (name, role) in enumerate(nodes[:n]):
        al = 255 if (name != new or n == 1 and p >= 1) else int(255 * card_p)
        if name == new and n == 1:
            al = int(255 * min(1.0, p / 0.36))
        if al <= 2:
            continue
        x, y = pos[name]
        w = max(nf.getlength(name), rf.getlength(role)) + 40
        ld.rounded_rectangle([x - w / 2, y - 44, x + w / 2, y + 44], radius=12, fill=(250, 244, 228, al),
                             outline=F.COAST + (al,), width=3)
        ld.text((x, y - 12), name, font=nf, fill=F.INKD + (al,), anchor="mm")
        ld.text((x, y + 24), role, font=rf, fill=(110, 90, 60, al), anchor="mm")
    img.alpha_composite(layer)
    return img


NAVY = (24, 36, 66)
GOLD = (196, 164, 96)


def draw_quote_card(lay: Image.Image, part: dict, font_of, serif) -> None:
    """① 史料・要点の引用札（紺の半透明の板＋金の細枠。上に小見出し、中に太字2行まで、下に書名の小字）。画面の中央左に出す。
    look: {type: quote, from: 行, to: 行, label: 史料|要点, text: 言葉, source: 書名}"""
    d = ImageDraw.Draw(lay, "RGBA")
    w = 980
    x0, y0 = (MW - w) // 2, int(MH * 0.50)            # 出ている間は主役（絵は暗くしてある）。顔の目にかからないよう、字幕のすぐ上に大きく
    tf = serif(54)
    rows = [r for piece in str(part["text"]).split("／") for r in S._wrap_text(piece, tf, w - 80)][:3]   # 「／」で行を分けられる
    h = 84 + 70 * len(rows) + (60 if part.get("source") else 28)
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=10, fill=NAVY + (215,))
    d.rounded_rectangle([x0 + 8, y0 + 8, x0 + w - 8, y0 + h - 8], radius=6, outline=GOLD + (230,), width=2)
    d.text((x0 + 36, y0 + 34), str(part.get("label", "史料")), font=font_of(28), fill=GOLD + (255,), anchor="lm")
    for i, r in enumerate(rows):
        d.text((x0 + 44, y0 + 84 + 70 * i + 30), r, font=tf, fill=(255, 255, 255, 255), anchor="lm")
    if part.get("source"):
        d.text((x0 + w - 36, y0 + h - 30), str(part["source"]), font=font_of(24), fill=(210, 214, 226, 255), anchor="rm")


def draw_versus_boxes(lay: Image.Image, part: dict, shown: int, q: float, font_of) -> None:
    """② 数のくい違い：箱を矢印でつないで横に並べ、最後の箱だけ赤（左から1つずつ出る）。
    look: {type: versus3, from: 行, to: 行, items: [[見出し, 数], ...], every: 秒}"""
    d = ImageDraw.Draw(lay, "RGBA")
    items = part["items"]
    n = len(items)
    bw, bh, gap = 330, 150, 70
    total = n * bw + (n - 1) * gap
    x = (MW - total) / 2
    y = 330
    for i, (head, num) in enumerate(items[:shown]):
        al = 255 if i < shown - 1 else int(255 * q)
        last = i == n - 1
        fill = ((150, 32, 36) if last else NAVY) + (int(225 * al / 255),)
        d.rounded_rectangle([x, y, x + bw, y + bh], radius=12, fill=fill)
        d.rounded_rectangle([x + 6, y + 6, x + bw - 6, y + bh - 6], radius=8, outline=GOLD + (al,), width=2)
        d.text((x + bw / 2, y + 40), str(head), font=font_of(26), fill=(230, 232, 240, al), anchor="mm")
        size = 50
        while size > 26 and font_of(size).getlength(str(num)) > bw - 30:
            size -= 2
        d.text((x + bw / 2, y + 100), str(num), font=font_of(size), fill=(255, 255, 255, al), anchor="mm")
        if i > 0:
            ax = x - gap + 12
            d.line([(ax, y + bh / 2), (x - 14, y + bh / 2)], fill=(255, 255, 255, al), width=5)
            d.polygon([(x - 8, y + bh / 2), (x - 26, y + bh / 2 - 12), (x - 26, y + bh / 2 + 12)], fill=(255, 255, 255, al))
        x += bw + gap


def draw_name_cards(lay: Image.Image, part: dict, shown: int, q: float, font_of, serif, painting) -> None:
    """③ 覚えてほしい名前：肖像（パブリックドメインの古画）＋名前の札を3枚、1枚ずつ。image が無い札は「？」。
    look: {type: names, from: 行, to: 行, title: 見出し, items: [[名前, 一言, 絵の道のり], ...], every: 秒}"""
    d = ImageDraw.Draw(lay, "RGBA")
    items = part["items"]
    n = len(items)
    cw, ch, gap = 360, 470, 50
    total = n * cw + (n - 1) * gap
    x = (MW - total) / 2
    y = 170
    if part.get("title"):
        d.text((MW / 2, y - 40), str(part["title"]), font=font_of(34), fill=(255, 255, 255, 255), anchor="mm",
               stroke_width=4, stroke_fill=(0, 0, 0, 255))
    for i, it in enumerate(items[:shown]):
        name, note = it[0], it[1]
        al = 255 if i < shown - 1 else int(255 * q)
        d.rounded_rectangle([x, y, x + cw, y + ch], radius=12, fill=NAVY + (int(225 * al / 255),))
        d.rounded_rectangle([x + 6, y + 6, x + cw - 6, y + ch - 6], radius=8, outline=GOLD + (al,), width=2)
        box = (int(x + 24), int(y + 24), int(x + cw - 24), int(y + ch - 120))
        if len(it) > 2 and it[2]:
            im = painting(it[2])
            im = S._fit_cell(im, box[2] - box[0], box[3] - box[1], tuple(it[3]) if len(it) > 3 else (0.5, 0.35))   # 4つ目＝顔の位置
            if al < 255:
                im = Image.blend(Image.new("RGB", im.size, NAVY), im, al / 255)
            lay.paste(im, box[:2])
        else:
            d.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), "？", font=font_of(140), fill=(255, 255, 255, al), anchor="mm")
        d.text((x + cw / 2, y + ch - 78), str(name), font=serif(42), fill=(255, 255, 255, al), anchor="mm")
        d.text((x + cw / 2, y + ch - 32), str(note), font=font_of(24), fill=(210, 214, 226, al), anchor="mm")
        x += cw + gap


def draw_doc_page(lay: Image.Image, part: dict, page: Image.Image, font_of) -> None:
    """⑤ 史料の頁：頁の画像を少し傾けて左に大きく置き、該当の行を赤の細枠で囲み、右上に出典の小字。
    look: {type: doc, from: 行, to: 行, image: 頁の画像, box: [左, 上, 右, 下]（頁の割合）, source: 出典, note: 赤枠の横の札}"""
    h = int(MH * 0.82)
    w = int(page.width * h / page.height)
    pg = page.convert("RGB").resize((w, h), Image.LANCZOS)
    pd = ImageDraw.Draw(pg)
    if part.get("box"):
        bx0, by0, bx1, by1 = part["box"]
        pd.rectangle([bx0 * w, by0 * h, bx1 * w, by1 * h], outline=(200, 30, 30), width=6)
    rgba = pg.convert("RGBA").rotate(-2.0, expand=True, resample=Image.BICUBIC)
    x0, y0 = 160, (MH - rgba.height) // 2
    lay.alpha_composite(rgba, (x0, max(0, y0)))
    d = ImageDraw.Draw(lay, "RGBA")
    if part.get("note"):
        f = font_of(40)
        tw = f.getlength(part["note"])
        nx = x0 + rgba.width + 40
        d.rounded_rectangle([nx, MH * 0.42, nx + tw + 40, MH * 0.42 + 70], radius=8, fill=(170, 30, 34, 235))
        d.text((nx + 20, MH * 0.42 + 35), part["note"], font=f, fill=(255, 255, 255, 255), anchor="lm")
    if part.get("source"):
        f = font_of(22)
        d.text((MW - 30, 90), str(part["source"]), font=f, fill=(255, 255, 255, 230), anchor="ra")


# --- 投稿の準備（10-25：物語型の本編の概要欄・目次・字幕は storymain の並びから）-------------------------------
DEFAULT_AI_NOTE = ("この動画の人物・情景の画像の多くは、Google の画像生成AI（Gemini）で作った想像上のイメージで、"
                   "記録映像・実在の写真ではありません（画面の右上に「AI生成画像」と出しています）。")


def look_for(script_path) -> Path | None:
    """台本に対応する見た目の指定（scripts/story/*_main_look.yaml の script: がその台本）。無ければ None（旧型の本編）。"""
    from .cli import ROOT
    name = Path(script_path).name
    for p in sorted((ROOT / "scripts" / "story").glob("*_main_look.yaml")):
        try:
            d = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
        except Exception:
            continue
        if Path(str(d.get("script", ""))).name == name:
            return p
    return None


def timeline(look_path, config: dict) -> "Plan":
    """本物の声の長さ（音声の控えから）で決めた並び。書き出しと同じ Plan。"""
    from . import script
    from .cli import ROOT
    look = yaml.safe_load(Path(look_path).read_text(encoding="utf-8"))
    sc = script.load(ROOT / look["script"])
    spoken = voice_lines(sc, config)
    return Plan(look, sc, [s.seconds for s in spoken])


def _clock(t: float) -> str:
    t = int(t)
    h, rest = divmod(t, 3600)
    m, s = divmod(rest, 60)
    return f"{h}:{m:02}:{s:02}" if h else f"{m}:{s:02}"


def chapters(plan: "Plan") -> list[str]:
    """概要欄の目次。序章は 0:00、ほかの章は章題カードの出る時刻（書き出しと同じ並び）。"""
    titles = [s.title.replace("　", " ") for s in plan.sc.sections]
    out = [f"0:00 {titles[0]}"]
    for sec in sorted(plan.chapter_at):
        out.append(f"{_clock(plan.chapter_at[sec])} {titles[sec]}")
    return out


def chapter_problems(plan: "Plan") -> list[str]:
    """YouTube の章の決まり（0:00 から・3つ以上・各10秒以上）に合わない所。"""
    starts = [0.0] + [plan.chapter_at[s] for s in sorted(plan.chapter_at)]
    out = []
    if len(starts) < 3:
        out.append(f"章が{len(starts)}つしかありません（3つ以上）")
    for i, (a, b) in enumerate(zip(starts, starts[1:] + [plan.total])):
        if b - a < 10:
            out.append(f"{i + 1}つ目の章が{b - a:.0f}秒しかありません（10秒以上）")
    return out


def srt(plan: "Plan") -> str:
    """字幕（画面の語りの文字と同じかたまり・同じ時刻）。想像の台詞は頭に（想像）。"""
    out = []
    units = plan.units
    for n, u in enumerate(units, 1):
        nxt = units[n].start if n < len(units) else u.end + 0.5
        end = min(nxt, u.end + 0.6)
        line = plan.sc.lines[u.line]
        text = "\n".join(S.screen_plain("".join(x.text for x in row)) for row in u.block.rows)
        if line.imagined:
            text = "（想像）" + text
        out.append(f"{n}\n{_srt_clock(u.start)} --> {_srt_clock(end)}\n{text}\n")
    return "\n".join(out)


def _srt_clock(t: float) -> str:
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def voice_names(config: dict, sc) -> list[str]:
    """この台本で実際に話している声だけ（物語型はつむぎが話さないので出さない）。"""
    from . import people
    names = []
    roles = people.roles(config)
    for line in sc.lines:
        info = (config.get("cast") or {}).get(line.speaker) or roles.get(line.speaker) or {}
        n = info.get("name")
        if n and n not in names:
            names.append(n)
    return names


def description(plan: "Plan", config: dict) -> str:
    """物語型の本編の概要欄：物語の頭 → 目次 → 台詞の断り → 画像の断り → 実在の絵の出典 → 音声 → 運営。5000字に収める。"""
    from .cli import DESC_ROOM, assets_dir
    from urllib.parse import unquote
    sc, look = plan.sc, plan.look
    out = []
    if sc.description_head:
        out += [sc.description_head.strip(), ""]
    out += ["■ 目次"] + chapters(plan) + [""]
    if sc.description_note:
        out += ["■ この動画の台詞について", sc.description_note.strip(), ""]
    out += ["■ 画像について", str(look.get("ai_disclosure") or DEFAULT_AI_NOTE).strip(), ""]
    refs = []
    for c in plan.cuts:                                  # 書き出しで使った実在の絵（額・屏風の一部）と部品の肖像
        if c.kind in ("frame", "part") and c.ref not in refs:
            refs.append(c.ref)
    for part in look.get("parts") or []:
        for it in part.get("items") or []:
            if part.get("type") == "names" and len(it) > 2 and it[2] and it[2] not in refs and not str(it[2]).startswith("ai:"):
                refs.append(it[2])
    credits_by_image = {}
    for line in sc.lines:
        for pic in (line.background, line.portrait):
            if pic and pic.image not in credits_by_image:
                credits_by_image[pic.image] = pic.credit or pic.caption
    for k, v in (look.get("credits") or {}).items():
        credits_by_image.setdefault(k, v)
    cf = assets_dir(config) / "paintings" / "credits.json"
    cr = json.loads(cf.read_text(encoding="utf-8")) if cf.exists() else {}
    rows, seen, cc0 = [], set(), 0                       # 1作品1行「作品名（所蔵・年）　URL」。許諾が違うもの（CC0）だけ末尾に（10-25「出典はまとめて」）
    for r in refs:
        lab = credits_by_image.get(r) or Path(r).stem
        info = cr.get(Path(r).stem) or {}
        url = unquote(info.get("source", ""))
        if (url and url in seen) or lab in seen:
            continue
        seen.update({url, lab} - {""})
        mark = ""
        if "CC0" in str(info.get("license", "")) or "CC0" in lab:
            mark, cc0 = " （CC0）", cc0 + 1
            lab = lab.replace("（CC0）", "").rstrip()
        rows.append(f"{lab}　{url}{mark}" if url else f"{lab}{mark}")   # URL のすぐ後ろに字を付けない（リンクが壊れる）
    tail = ["■ 音声"] + [f"VOICEVOX:{n}" for n in voice_names(config, sc)] + ["", f"運営：{config.get('operator', '')}"]
    head = "■ 画面の絵と出典（Wikimedia Commons。著作権の切れた作品" + (f"、写真{cc0}点は CC0）" if cc0 else "）")
    room = DESC_ROOM - len("\n".join(out + tail)) - len(head) - 4
    pics, used = [head], 0
    for k, row in enumerate(rows):
        if used + len(row) + 1 > room:
            pics.append(f"ほか{len(rows) - k}点（Wikimedia Commons）")
            break
        pics.append(row)
        used += len(row) + 1
    body = out + (pics + [""] if rows else []) + tail
    return "\n".join(body).strip() + "\n"
