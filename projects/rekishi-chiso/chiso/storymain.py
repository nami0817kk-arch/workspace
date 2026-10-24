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
END_SECONDS = 20.0              # 終了画面の空き
CUT_MAX = 18.0                  # 1カットの長さの上限（これを超えると切り出しを替える）
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

    def __init__(self, w: int = MW, h: int = MH):
        import numpy as np
        self.np = np
        yy, xx = np.mgrid[0:h, 0:w].astype("float32")
        r = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2
        self.vig = (1 - self.VIGNETTE * np.clip(r / 2, 0, 1) ** 1.2)[..., None].astype("float32")
        rng = np.random.default_rng(7)
        self.noise = [rng.standard_normal((h, w, 1)).astype("float32") for _ in range(6)]
        band = np.zeros(h, dtype="float32")
        top = int(h * 0.70)
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


def framed(backdrop: Image.Image, painting: Image.Image, u: float = 0.5, variant: str = "a") -> Image.Image:
    """実在の絵を額のカードにして、ぼかして暗くした下地の上に置く（b は少し寄せた版）。"""
    bg = backdrop.filter(ImageFilter.GaussianBlur(18))
    bg = Image.eval(bg, lambda v: int(v * 0.40))
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
    """左上の小さな札「1583年4月｜第4章 北ノ庄城の最後の夜」（高さ40px＝約3.7%）。"""
    f = font_of(25)
    d = ImageDraw.Draw(lay, "RGBA")
    w = f.getlength(text)
    d.rounded_rectangle([24, 22, 24 + w + 28, 62], radius=8, fill=(0, 0, 0, 140))
    d.text((38, 42), text, font=f, fill=(255, 255, 255, 240), anchor="lm")


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
    """台本の card（見出し＋本文）を右上に：見出しを大きく、赤い下線、下に本文。"""
    x0, y0, x1 = 1330, 84, MW - 36
    d = ImageDraw.Draw(lay, "RGBA")
    size = 76
    while size > 40 and font_of(size).getlength(head) > (x1 - x0) - 50:
        size -= 4
    bf = font_of(34)
    rows = S._wrap_text(body, bf, (x1 - x0) - 50)[:2] if body else []
    h = 34 + size + 30 + 46 * len(rows) + 22
    d.rounded_rectangle([x0, y0, x1, y0 + h], radius=16, fill=(10, 8, 6, 160))
    cx = (x0 + x1) / 2
    d.text((cx, y0 + 24 + size / 2), head, font=font_of(size), fill=S.WHITE, anchor="mm", stroke_width=5, stroke_fill=S.BLACK)
    uy = y0 + 32 + size + 4
    d.rounded_rectangle([x0 + 50, uy, x1 - 50, uy + 7], radius=3, fill=S.RED + (255,))
    for i, r in enumerate(rows):
        d.text((cx, uy + 38 + 46 * i), r, font=bf, fill=S.WHITE, anchor="mm", stroke_width=3, stroke_fill=S.BLACK)


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
    for ri, row in enumerate(block.rows):
        items = []
        for u in row:
            s, m = S.phrase_plain(u.text)
            items += list(zip(s, m))
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

    def __init__(self, look: dict, sc):
        self.look, self.sc = look, sc
        self.units: list[Unit] = []
        self.chapter_at: dict[int, float] = {}
        t = 0.0
        prev_sec = None
        for line in sc.lines:
            if line.section != prev_sec:
                if line.section > 0:
                    self.chapter_at[line.section] = t
                    t += CHAPTER_SECONDS
                prev_sec = line.section
            t += line.pause or 0.0
            for b in blocks(line.text):
                d = max(1.0, len(S.screen_plain(_btext(b))) / CPS)
                self.units.append(Unit(line.index, b, t, t + d))
                t += d
            t += LINE_GAP
        self.voice_end = t
        self.total = t + END_SECONDS
        self.shots = self._shots()
        self.cuts = self._cuts()

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
            dim = bool(lines[u.line].figure)
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
            for u in us:
                acc = (piece[-1].end - piece[0].start) if piece else 0.0
                if piece and not dim and acc + (u.end - u.start) > CUT_MAX and acc >= CUT_MIN:
                    cuts.append(self._cut(kind, ref, order[k % len(order)], piece, dim, last_ai, sec))
                    k += 1
                    piece = []
                piece.append(u)
            if piece:
                cuts.append(self._cut(kind, ref, order[k % len(order)], piece, dim, last_ai, sec))
        end = [s for s in self.shots if s[0] == "end"]
        if end:
            cuts.append(Cut("end", end[0][2], end[0][3], self.voice_end, self.total, (), section=lines[-1].section))
        for a, b in zip(cuts, cuts[1:]):                 # 隙間（行間・間）は前のカットに含める
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
        for u in self.units:
            if u.start <= t < u.end + LINE_GAP:
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

    def __init__(self, look_path: str | Path, config: dict):
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
        self.plan = Plan(self.look, self.sc)
        self.credits = {}
        for l in self.sc.lines:
            for p in (l.background, l.portrait):
                if p and p.image not in self.credits:
                    self.credits[p.image] = p.credit or p.caption

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
            return picture(Image.open(self.assets / c.ref), u, move, c.crop)
        if c.kind == "frame":
            back = picture(self.ai_image(c.backdrop), 0.5, "in", "wide")
            return framed(back, Image.open(self.assets / c.ref), u, c.crop)
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
        if c.dim and line.figure:
            from . import figures
            img = Image.alpha_composite(img, Image.new("RGBA", (MW, MH), (0, 0, 0, 120)))
            img = figures.draw(self.painter, img, json.loads(line.figure), 1.0)
        elif line.card is not None:
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
