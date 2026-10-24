"""物語型の本編（横 1920x1080）の画面。物語型ショート（chiso/storyshort.py）と同じ見た目を横長に組み直したもの（10-24 ユーザー決定）。

立ち絵・メモ欄・肖像の額は出さない。画面は次の5つだけ：
- 上の見出し帯（案B を横長に。高さ BAND_H＝画面の13%）：左に赤い札＋題（1行）、右に「いま」の札と年表のバー。
  章が替わると、帯のすぐ下に「第N章 章題」を CHAPTER_SECONDS 秒だけ出す（序章は「序章」）
- 絵：全面。ゆっくりの寄り・パン、替わり目は 0.4 秒の溶け合い、ショートと同じ色調補正。
  縦長の絵（AI の 9:16・掛け軸の肖像）は、同じ絵をぼかして暗くした下地に、高さいっぱいで左・中央・右に置く
- 語りの文字：画面の下寄り中央に、ブロックで一度に（語りそのまま・1行 ROW_MAX 字・2行まで）。白＋黒の太縁、《》は黄
  人物の台詞は文字の左上に小さく名札。想像の台詞（imagined）は灰紫の「想像」札＋「お市（想像）」
- 図解：台本の card（年号・見出しの札）は右に、figure（地図・相関図・数字の図。chiso/figures.py）は中央〜右に縮めて
- 出典は左下に小さく、「AI生成画像」は右上（帯の下）に小さく

旧型の本編の描画（chiso/render.py）には触らない。いまは静止画（`stills`）で見た目を合わせる段階で、動画の書き出しはまだ無い。

    python -m chiso.cli story-main scripts/story/oichi_main_look.yaml     # 見た目の指定（look）に書いた時点の静止画と一覧
"""
from __future__ import annotations

import json
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFilter

from . import storyshort as S

MW, MH = 1920, 1080
BAND_H = 140                    # 見出し帯（画面の約13%）
ROW_MAX = 20                    # 1行の字数（横長なのでショートの2倍）
MERGE_MAX = 32                  # 句をつなぐ上限（2行に収まる長さ。ショートの16に当たる）
MERGE_BELOW = 99                # 横長は句をなるべくつなぐ（ショートは6字未満の句だけ）
TEXT_SIZE = 62
TEXT_Y = 0.835                  # 文字の中心（画面の縦の割合）
ROW_STEP = 1.30
CHAPTER_SECONDS = 4.0           # 章の題を出しておく秒数
CPS = 6.5                       # 声の速さの見積もり（字/秒。毎分約390字）
LINE_GAP = 0.35                 # 行と行のあいだ（見積もり）
FIG_BOX = (748, 172, MW - 40, 730)   # 図を置く枠（中央〜右）
CARD_BOX = (1210, 222, MW - 44, 520)  # 札を置く枠（右）
IMAGINED_COLOR = (88, 82, 96)   # render.py の「想像」札と同じ灰紫
NAME_COLOR = (150, 30, 36)      # 記録の人物の名札（深い赤）


# --- 絵 ---------------------------------------------------------------------
class Grade(S.Grade):
    """ショートと同じ色調補正（彩度・暖色・コントラスト・周辺の暗さ・粒子）を横長で。文字の帯は画面の下。"""

    def __init__(self, w: int = MW, h: int = MH):
        import numpy as np
        self.np = np
        yy, xx = np.mgrid[0:h, 0:w].astype("float32")
        r = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2
        self.vig = (1 - self.VIGNETTE * np.clip(r / 2, 0, 1) ** 1.2)[..., None].astype("float32")
        rng = np.random.default_rng(7)
        self.noise = [rng.standard_normal((h, w, 1)).astype("float32") for _ in range(6)]
        band = np.zeros(h, dtype="float32")
        top, bot = int(h * 0.66), h
        k = np.clip((np.arange(top, bot) - top) / ((bot - top) * 0.5), 0, 1)
        band[top:bot] = 0.34 * k
        self.band = (1 - band)[:, None, None]


def picture(im: Image.Image, u: float = 0.5, move: str = "in", focus=(0.5, 0.4), side: str = "center",
            zoom: float = 0.06) -> Image.Image:
    """全面の絵（1920x1080、補正前）。横長の絵は寄り・パンで切り出し、縦長の絵はぼかした下地に高さいっぱいで置く。"""
    im = im.convert("RGB")
    z, dx, dy = S.motion(move, u, zoom)
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
    h = round(MH * z)
    w = round(im.width * h / im.height)
    fg = im.resize((w, h), Image.LANCZOS)
    cx = {"left": MW * 0.27, "right": MW * 0.73}.get(side, MW / 2)
    x0 = int(cx - w / 2)
    y0 = int((MH - h) * (0.5 + dy))
    shadow = Image.new("L", (MW, MH), 0)
    ImageDraw.Draw(shadow).rectangle([x0 - 4, y0, x0 + w + 4, y0 + h], fill=170)
    bg.paste((0, 0, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(24)))
    bg.paste(fg, (x0, y0))
    return bg


# --- 上の見出し帯 -------------------------------------------------------------
def draw_band(lay: Image.Image, header: dict, now_text: str | None, labels: list, active: int, font_of) -> None:
    """案B の横長：黒い帯（BAND_H）＋赤い線。左に赤い札（上）と題（下、1行・《》は赤）、右に「いま」の札（上）と年表のバー（下）。"""
    d = ImageDraw.Draw(lay, "RGBA")
    d.rectangle([0, 0, MW, BAND_H], fill=(6, 5, 4, 238))
    d.rectangle([0, BAND_H, MW, BAND_H + 5], fill=S.RED + (255,))
    tf = font_of(30)
    tw = int(tf.getlength(header["tag"])) + 32
    d.rounded_rectangle([36, 16, 36 + tw, 60], radius=7, fill=S.RED + (255,))
    d.text((36 + tw / 2, 38), header["tag"], font=tf, fill=S.WHITE, anchor="mm")
    title = header["title"]
    size = 56
    while size > 36 and font_of(size).getlength(S.screen_plain(title)) > MW * 0.45:
        size -= 2
    S.red_marked(d, 36, 102, title, font_of(size), stroke=0)
    if now_text:
        tmp = ImageDraw.Draw(Image.new("RGBA", (10, 10)), "RGBA")
        w = S._now_badge(tmp, font_of, 0, 0, now_text, 32, box=False)
        S._now_badge(d, font_of, MW - 36 - w, 12, now_text, 32, box=False)
    if labels:
        tmp = ImageDraw.Draw(Image.new("RGBA", (10, 10)), "RGBA")
        w = S._bar_strip(tmp, font_of, labels, active, 0, 0, 26, max_w=MW * 0.42, box=False)
        S._bar_strip(d, font_of, labels, active, MW - 36 - w, 104, 26, max_w=MW * 0.42, box=False)


def draw_chapter(lay: Image.Image, label: str, title: str, font_of) -> None:
    """帯のすぐ下・左に「第N章 章題」（章の頭の数秒だけ）。"""
    d = ImageDraw.Draw(lay, "RGBA")
    lf, f = font_of(34), font_of(40)
    lw, tw = lf.getlength(label), f.getlength(title)
    y0, y1 = BAND_H + 18, BAND_H + 86
    d.rounded_rectangle([28, y0, 28 + 24 + lw + 22 + tw + 30, y1], radius=10, fill=(8, 6, 4, 200))
    d.rectangle([28, y0, 36, y1], fill=S.RED + (255,))
    d.text((52, (y0 + y1) / 2), label, font=lf, fill=S.YELLOW + (255,), anchor="lm")
    d.text((52 + lw + 22, (y0 + y1) / 2 + 1), title, font=f, fill=S.WHITE + (255,), anchor="lm", stroke_width=3, stroke_fill=S.BLACK)


def draw_ai_label(lay: Image.Image, font_of) -> None:
    f = font_of(26)
    tw = f.getlength(S.AI_LABEL)
    d = ImageDraw.Draw(lay, "RGBA")
    x1, y0 = MW - 28, BAND_H + 18
    d.rounded_rectangle([x1 - tw - 28, y0, x1, y0 + 44], radius=9, fill=(0, 0, 0, 130))
    d.text((x1 - 14, y0 + 22), S.AI_LABEL, font=f, fill=(255, 255, 255, 235), anchor="rm")


def draw_credit(lay: Image.Image, text: str, font_of) -> None:
    f = font_of(22)
    rows = S._wrap_text(text, f, 560)[:3]
    w = int(max(f.getlength(r) for r in rows)) + 28
    h = 32 * len(rows) + 12
    d = ImageDraw.Draw(lay, "RGBA")
    d.rounded_rectangle([20, MH - 20 - h, 20 + w, MH - 20], radius=8, fill=(0, 0, 0, 125))
    for i, r in enumerate(rows):
        d.text((34, MH - 20 - h + 6 + 32 * i + 16), r, font=f, fill=(255, 255, 255, 220), anchor="lm")


# --- 図解 -------------------------------------------------------------------
def draw_card(lay: Image.Image, head: str, body: str, font_of) -> None:
    """台本の card（見出し＋本文）を右の枠に：年号・見出しを大きく、赤い下線、下に本文。"""
    x0, y0, x1, y1 = CARD_BOX
    d = ImageDraw.Draw(lay, "RGBA")
    size = 92
    while size > 44 and font_of(size).getlength(head) > (x1 - x0) - 60:
        size -= 4
    bf = font_of(40)
    rows = S._wrap_text(body, bf, (x1 - x0) - 60)[:2] if body else []
    h = 40 + size + 34 + 54 * len(rows) + 30
    d.rounded_rectangle([x0, y0, x1, y0 + h], radius=20, fill=(10, 8, 6, 165))
    cx = (x0 + x1) / 2
    d.text((cx, y0 + 30 + size / 2), head, font=font_of(size), fill=S.WHITE, anchor="mm", stroke_width=6, stroke_fill=S.BLACK)
    uy = y0 + 40 + size + 6
    d.rounded_rectangle([x0 + 60, uy, x1 - 60, uy + 9], radius=4, fill=S.RED + (255,))
    for i, r in enumerate(rows):
        d.text((cx, uy + 46 + 54 * i), r, font=bf, fill=S.WHITE, anchor="mm", stroke_width=3, stroke_fill=S.BLACK)


def figure_layer(painter, spec: dict) -> Image.Image:
    """chiso/figures.py の図（1920x1080 の真ん中の板）を描いて、FIG_BOX に縮めて置いた透明な層。"""
    from . import figures
    canvas = figures.draw(painter, Image.new("RGBA", (MW, MH), (0, 0, 0, 0)), spec, 1.0)
    px0, py0, px1, py1 = figures.PANEL
    m = 30
    panel = canvas.crop((px0 - m, py0 - m, px1 + m, py1 + m))
    bx0, by0, bx1, by1 = FIG_BOX
    s = min((bx1 - bx0) / panel.width, (by1 - by0) / panel.height)
    panel = panel.resize((round(panel.width * s), round(panel.height * s)), Image.LANCZOS)
    lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
    lay.alpha_composite(panel, (bx1 - panel.width, by0))
    return lay


# --- 語りの文字 ---------------------------------------------------------------
def blocks(text: str) -> list:
    """語り1行を、横長の画面に一度に出すブロックに（1行 ROW_MAX 字・2行まで。つなげると語りそのまま）。"""
    return S.blocks_of(text, row_max=ROW_MAX, merge_max=MERGE_MAX, merge_below=MERGE_BELOW)


def _btext(block) -> str:
    return "".join(u.text for u in block.units)


def text_layer(block, font_of, tag: tuple | None = None) -> Image.Image:
    """ブロックの文字（白＋黒の太縁・《》は黄）を画面の下寄り中央に。tag＝(札の字, 色, 名前) を文字の左上に小さく。"""
    lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = font_of(TEXT_SIZE)
    step = int(TEXT_SIZE * ROW_STEP)
    n = len(block.rows)
    top = MH * TEXT_Y - step * n / 2
    sw = 7
    x_left = MW
    rows = []
    for ri, row in enumerate(block.rows):
        items = []
        for u in row:
            s, m = S.phrase_plain(u.text)
            items += list(zip(s, m))
        width = sum(f.getlength(ch) for ch, _ in items)
        x = (MW - width) / 2
        x_left = min(x_left, x)
        rows.append((items, x, top + step * ri + TEXT_SIZE * 0.86))
    for pass_ in ("stroke", "fill"):
        for items, x, y in rows:
            for ch, on in items:
                if pass_ == "stroke":
                    d.text((x + 3, y + 5), ch, font=f, fill=(0, 0, 0, 140), stroke_width=sw, stroke_fill=(0, 0, 0, 140), anchor="ls")
                    d.text((x, y), ch, font=f, fill=S.BLACK + (255,), stroke_width=sw, stroke_fill=S.BLACK + (255,), anchor="ls")
                else:
                    d.text((x, y), ch, font=f, fill=(S.YELLOW if on else S.WHITE) + (255,), anchor="ls")
                x += f.getlength(ch)
    if tag:
        label, color, name = tag
        dd = ImageDraw.Draw(lay, "RGBA")
        tf, nf = font_of(26), font_of(28)
        x, y = x_left, top - 40
        if label:
            w = tf.getlength(label) + 24
            dd.rounded_rectangle([x, y - 19, x + w, y + 19], radius=7, fill=color + (235,))
            dd.text((x + w / 2, y), label, font=tf, fill=S.WHITE, anchor="mm")
            x += w + 10
        if name:
            dd.text((x, y + 1), name, font=nf, fill=S.WHITE, anchor="lm", stroke_width=4, stroke_fill=S.BLACK)
    return lay


def speaker_tag(line) -> tuple | None:
    """人物の台詞の名札。想像なら（"想像", 灰紫, "お市（想像）"）、記録なら（"", -, "勝家"）。語りは None。"""
    if line.speaker in ("語り", "剣崎", "つむぎ", "二人"):
        return None
    name = line.speaker.replace("想像", "")
    if line.imagined:
        return ("想像", IMAGINED_COLOR, f"{name}（想像）")
    return ("記録", NAME_COLOR, name)


# --- 1コマ -------------------------------------------------------------------
class Look:
    """見た目の指定（look の yaml）と台本から、行ごとの画面を描く。"""

    def __init__(self, look_path: str | Path, config: dict):
        from . import render, script
        from .cli import ROOT, assets_dir
        self.look = yaml.safe_load(Path(look_path).read_text(encoding="utf-8"))
        self.root = ROOT
        self.sc = script.load(ROOT / self.look["script"])
        self.assets = assets_dir(config)
        self.art = ROOT / self.look.get("art_dir", "out/story/oichi3/gem")
        self.font_of = S.make_font_of(config["fonts"])
        self.painter = render.Painter(config, self.sc, self.assets, (MW, MH))
        self.grade = Grade()
        self.labels = self.look.get("timeline") or []
        # 行ごとの時刻の見積もり（音声を作らない。字数 ÷ CPS ＋ 行間）
        self.starts, t = [], 0.0
        for line in self.sc.lines:
            self.starts.append(t)
            t += len(S.screen_plain(line.text)) / CPS + LINE_GAP + (line.pause or 0.0)
        self.total = t
        self.section_start = {}
        for line, t0 in zip(self.sc.lines, self.starts):
            self.section_start.setdefault(line.section, t0)

    def image(self, ref: str) -> tuple[Image.Image, bool]:
        """絵の参照（"gem:P6" か assets からの相対パス）→ (絵, AI の絵か)。"""
        if ref.startswith("gem:"):
            return Image.open(self.art / f"{ref[4:]}.jpg"), True
        return Image.open(self.assets / ref), False

    def frame(self, spec: dict) -> tuple[Image.Image, dict]:
        """spec＝{line|find, block, picture, side, focus, move, u, chapter, credit} の1コマと、その説明。"""
        lines = self.sc.lines
        if "find" in spec:
            idx = next(i for i, l in enumerate(lines) if spec["find"] in l.text)
        else:
            idx = int(spec["line"])
        line = lines[idx]
        bl = blocks(line.text)
        bi = int(spec.get("block", 0))
        if "find" in spec and "block" not in spec:
            key = S.screen_plain(spec["find"]).replace("、", "").replace("。", "")
            for i, b in enumerate(bl):
                if key[:4] in S.screen_plain(_btext(b)):
                    bi = i
                    break
        block = bl[bi]
        t = self.starts[idx] + sum(len(S.screen_plain(_btext(b))) for b in bl[:bi]) / CPS + 0.3
        # 絵
        ref = spec.get("picture")
        credit = spec.get("credit")
        if not ref:
            pic = line.portrait or line.background
            ref, credit = pic.image, credit or pic.credit or pic.caption
        im, ai = self.image(ref)
        if not ai and credit is None:
            pic = line.background if line.background and line.background.image == ref else line.portrait
            credit = (pic.credit or pic.caption) if pic and pic.image == ref else ""
        fig = json.loads(line.figure) if line.figure else None
        new_card = line.card is not None and (idx == 0 or lines[idx - 1].card != line.card or spec.get("card"))
        side = spec.get("side") or ("left" if (fig or new_card) else "center")
        img = picture(im, float(spec.get("u", 0.5)), spec.get("move", "in"), tuple(spec.get("focus", (0.5, 0.4))), side)
        img = self.grade(img, idx).convert("RGBA")
        # 図解（図が優先。図のある行は札を出さない）
        if fig:
            img.alpha_composite(figure_layer(self.painter, fig))
        elif new_card:
            lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
            draw_card(lay, line.card.head, line.card.body, self.font_of)
            img.alpha_composite(lay)
        # 帯・章・ラベル・出典
        now = (self.look.get("now") or {}).get(line.section) or (None, -1)
        lay = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
        draw_band(lay, self.look["header"], now[0], self.labels, int(now[1]), self.font_of)
        sec = self.sc.sections[line.section]
        chapter_on = spec.get("chapter") or (t - self.section_start[line.section] < CHAPTER_SECONDS)
        if chapter_on:
            label = "序章" if line.section == 0 else f"第{line.section}章"
            draw_chapter(lay, label, sec.title.replace("　", " "), self.font_of)
        if ai:
            draw_ai_label(lay, self.font_of)
        elif credit:
            draw_credit(lay, credit, self.font_of)
        img.alpha_composite(lay)
        img.alpha_composite(text_layer(block, self.font_of, speaker_tag(line)))
        info = {"line": idx, "section": line.section, "t": t, "text": S.screen_plain(_btext(block)), "picture": ref,
                "ai": ai, "figure": bool(fig), "card": bool(new_card and not fig), "chapter": bool(chapter_on)}
        return img.convert("RGB"), info


def stills(look_path: str | Path, config: dict, out_dir: Path) -> tuple[list[Path], Path, list[dict]]:
    """look の stills: に書いた時点の静止画（PNG）と一覧（JPEG）。返すのは (PNG の並び, 一覧, 各コマの説明)。"""
    lk = Look(look_path, config)
    name = lk.look.get("out", "story_main")
    single = out_dir / f"{name}_stills"
    single.mkdir(parents=True, exist_ok=True)
    pngs, infos, labels = [], [], []
    for i, spec in enumerate(lk.look["stills"], 1):
        img, info = lk.frame(spec)
        p = single / f"{i:02d}.png"
        img.save(p)
        pngs.append(p)
        infos.append(info)
        m, s = divmod(int(info["t"]), 60)
        labels.append(f"{i}. 約{m}分{s:02d}秒  {spec.get('note', '')}")
    sheet = _grid(pngs, labels, out_dir / f"{name}_stills.jpg", config["fonts"]["gothic"])
    return pngs, sheet, infos


def _grid(paths: list[Path], labels: list[str], target: Path, font, cols: int = 2, cell_w: int = 960) -> Path:
    from PIL import ImageFont
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
