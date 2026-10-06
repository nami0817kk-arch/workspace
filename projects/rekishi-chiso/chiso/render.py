"""画面を描く。絵画（背景）・肖像・掘り出したメモ・地層の年表・字幕・2人の立ち絵。

画面は「状態」（背景・肖像・札・年号・メモ・話している人・字幕）が変わったときだけ描き、
同じ状態が続くあいだは同じ1枚を流す。動きは次の4つだけ：
話し始めに話す側が跳ねる／絵が替わるときの溶け合い／年表の印の移動／新しいメモの滑り込み。
"""
from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from .subs import chunks as subtitle_chunks, emphasis_mask, wrap, wrap_balanced
from . import people

INK = (244, 236, 220)
GOLD = (214, 178, 110)
DIM = (176, 164, 140)
EMPH = (196, 72, 24)            # 字幕の強調語（明るい箱の上で読める濃い朱）
STRATA = [(70, 58, 44), (92, 74, 52), (120, 96, 62), (150, 118, 74), (110, 52, 44)]
SPEAKER_COLORS = {"left": (96, 112, 150), "right": (214, 140, 40)}
ROLE_COLOR = (140, 36, 52)        # 人物の言葉（roles の声）の字幕。2人のどちらでもない深い赤

HOP_PX = 22          # 話し始めに跳ねる高さ
HOP_FRAMES = 8       # 跳ねる長さ（フレーム数）
TRANS_FRAMES = 8     # 絵・札・年号が替わるときの移り変わり（フレーム数）
LISTENER_DIM = 0.72  # 聞いている側の明るさ
SUB_ROWS = 2         # 本編の字幕は2行まで
END_SECONDS = 12.0   # 最後の次回予告の画面の長さ（YouTube の終了画面を置ける長さ）
OPENING_CUES = 2     # 冒頭で題名の問いを大きく出す行数
POP_SECONDS = 1.6    # 強調語が画面の真ん中に飛び出している長さ
POP_FRAMES = 6       # 飛び出すときの大きくなる動き（フレーム数）
SHAKE_FRAMES = 6     # 驚きで画面が揺れる長さ（フレーム数）
SHAKE_PX = 10        # 揺れの大きさ
WIPE_FRAMES = 14     # 節の頭の地層のワイプ（フレーム数）
FIG_FRAMES = 45      # 図が出たときに描き進める長さ（フレーム数。1.5秒）
ICON_FRAMES = 8      # 挿絵が出るときに大きくなる長さ（フレーム数）


@dataclass(frozen=True)
class State:
    section: int
    background: object
    portrait: object
    card: object
    year: int | None
    speaker: str
    memo: tuple = ()
    figure: str | None = None
    bubble: str | None = None
    icon: str | None = None
    term: tuple | None = None
    place: tuple | None = None


def _ease(t: float) -> float:
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


class Painter:
    def __init__(self, config: dict, script, assets: Path, size: tuple[int, int]):
        self.config = config
        self.script = script
        self.assets = assets
        self.W, self.H = size
        self._fonts: dict = {}
        self._images: dict = {}
        # layered=True（本編）：背景は video.py が動かすので、ここでは透明な前景だけを描く
        self.layered = False

    # --- 素材 -------------------------------------------------------------
    def font(self, kind: str, size: int, bold: bool = False):
        key = (kind, size, bold)
        if key not in self._fonts:
            f = ImageFont.truetype(self.config["fonts"][kind], size)
            if bold:
                try:
                    f.set_variation_by_name("Bold")
                except Exception:
                    pass
            self._fonts[key] = f
        return self._fonts[key]

    def image(self, rel: str) -> Image.Image:
        if rel not in self._images:
            path = self.assets / rel
            if not path.exists():
                raise FileNotFoundError(f"素材がありません: {path}")
            self._images[rel] = Image.open(path).convert("RGBA")
        return self._images[rel]

    def character(self, speaker: str) -> Image.Image:
        key = ("char", speaker)
        if key not in self._images:
            cast = self.config["cast"][speaker]
            im = self.image(cast["image"])
            im = im.crop(im.getbbox())
            h = int(cast.get("height", 1150) * self.H / 1080)
            im = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
            self._images[key] = im.crop((0, 0, im.width, int(h * cast.get("bust", 0.4))))
        return self._images[key]

    def face(self, speaker: str, tone: str, mouth_open: bool, blink: bool) -> Image.Image:
        """表情のある立ち絵（cast に faces があるとき）。無ければ1枚の立ち絵。"""
        cast = self.config["cast"][speaker]
        folder = cast.get("faces")
        if not folder:
            return self.character(speaker)
        from .faces import EXPRESSIONS, face_key
        tone = tone if tone in EXPRESSIONS else "普通"
        key = ("face", speaker, tone, mouth_open, blink)
        if key not in self._images:
            path = self.assets / folder / f"{face_key(tone, mouth_open, blink)}.png"
            if not path.exists():
                return self.character(speaker)
            im = Image.open(path).convert("RGBA")
            im = im.crop(im.getbbox())
            h = int(cast.get("height", 1150) * self.H / 1080)
            im = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
            self._images[key] = im.crop((0, 0, im.width, int(h * cast.get("bust", 0.4))))
        return self._images[key]

    def listener(self, speaker: str) -> Image.Image:
        """聞いている側の立ち絵：少し暗く、少し色を落とす。"""
        key = ("listen", speaker)
        if key not in self._images:
            ch = self.character(speaker)
            a = ch.split()[3]
            rgb = ImageEnhance.Brightness(ch.convert("RGB")).enhance(LISTENER_DIM)
            rgb = ImageEnhance.Color(rgb).enhance(0.75)
            out = rgb.convert("RGBA")
            out.putalpha(a)
            self._images[key] = out
        return self._images[key]

    # --- 背景 -------------------------------------------------------------
    def _cover(self, im: Image.Image) -> Image.Image:
        s = max(self.W / im.width, self.H / im.height)
        im = im.resize((math.ceil(im.width * s), math.ceil(im.height * s)), Image.LANCZOS)
        x, y = (im.width - self.W) // 2, (im.height - self.H) // 2
        return im.crop((x, y, x + self.W, y + self.H))

    def _background(self, pic) -> Image.Image:
        key = ("bg", pic, self.W, self.H)
        if key in self._images:
            return self._images[key].copy()
        W, H = self.W, self.H
        if pic is None:
            bg = Image.new("RGB", (W, H), (24, 19, 14))
        else:
            bg = self._cover(self.image(pic.image).convert("RGB"))
            bg = ImageEnhance.Brightness(bg).enhance(0.55)
            bg = ImageEnhance.Color(bg).enhance(0.8)
        dark = Image.new("RGB", (W, H), (12, 10, 8))
        # 下を暗く（年表と字幕を読みやすく）・上を暗く（題名を読みやすく）
        lin = Image.linear_gradient("L").resize((W, H))
        bottom = lin.point(lambda v: int(max(0, (v - 140) / 115) * 200))
        top = lin.transpose(Image.FLIP_TOP_BOTTOM).point(lambda v: int(max(0, (v - 190) / 65) * 150))
        bg = Image.composite(dark, bg, bottom)
        bg = Image.composite(dark, bg, top)
        # 四隅を少し落として、真ん中に目を集める
        vig = Image.new("L", (W, H), 0)
        ImageDraw.Draw(vig).ellipse([-W * 0.15, -H * 0.25, W * 1.15, H * 1.25], fill=255)
        vig = vig.filter(ImageFilter.GaussianBlur(W / 12))
        bg = Image.composite(bg, ImageEnhance.Brightness(bg).enhance(0.7), vig)
        out = bg.convert("RGBA")
        self._images[key] = out
        return out.copy()

    def _shade(self) -> Image.Image:
        """前景の下敷き：上と下を暗く（題名・年表・字幕を読みやすく）、四隅を少し落とす。透明な層。"""
        key = ("shade", self.W, self.H)
        if key not in self._images:
            W, H = self.W, self.H
            lin = Image.linear_gradient("L").resize((W, H))
            bottom = lin.point(lambda v: int(max(0, (v - 140) / 115) * 200))
            top = lin.transpose(Image.FLIP_TOP_BOTTOM).point(lambda v: int(max(0, (v - 190) / 65) * 150))
            vig = Image.new("L", (W, H), 0)
            ImageDraw.Draw(vig).ellipse([-W * 0.15, -H * 0.25, W * 1.15, H * 1.25], fill=255)
            vig = vig.filter(ImageFilter.GaussianBlur(W / 12)).point(lambda v: int((255 - v) * 0.3))
            from PIL import ImageChops
            alpha = ImageChops.lighter(ImageChops.lighter(bottom, top), vig)
            layer = Image.new("RGBA", (W, H), (12, 10, 8, 0))
            layer.putalpha(alpha)
            self._images[key] = layer
        return self._images[key].copy()

    def _canvas(self, background) -> Image.Image:
        return self._shade() if self.layered else self._background(background)

    # --- 年表 -------------------------------------------------------------
    def _timeline(self, dr: ImageDraw.ImageDraw, x0: float, x1: float, yb: float, year):
        sc = self.script
        if sc.timeline_start is None or sc.timeline_end is None:
            return
        y0, y1 = sc.timeline_start, sc.timeline_end
        X = lambda y: x0 + (x1 - x0) * (y - y0) / max(1, (y1 - y0))
        marks = sorted({y for y, _ in sc.events} | {y0, y1})
        for i, (a, b) in enumerate(zip(marks, marks[1:])):
            color = STRATA[min(i, len(STRATA) - 2)] if b != y1 or len(marks) < 3 else STRATA[-1]
            if year is not None and a >= year:              # これから先の地層は暗く
                color = tuple(int(c * 0.45) for c in color)
            dr.rectangle([X(a), yb - 14, X(b), yb + 14], fill=color + (255,))
        u = self.H / 1080
        placed: list[tuple[float, float]] = []           # ラベルの重なりを避ける
        years: list[tuple[float, float]] = []            # 年の数字の重なりを避ける（10-05「1894189 1900」と重なった）
        for y, label in sc.events:
            on = (year is not None and round(year) == y)
            dr.line([X(y), yb - 26, X(y), yb + 26], fill=(GOLD if on else DIM) + (255,), width=4 if on else 2)
            yf = self.font("gothic", int((30 if on else 26) * u))
            half = yf.getlength(str(y)) / 2
            if on or not any(X(y) - half < b + 6 and X(y) + half > a - 6 for a, b in years):
                dr.text((X(y), yb - 40 * u), str(y), font=yf, fill=GOLD if on else DIM, anchor="ms")
                years.append((X(y) - half, X(y) + half))
            lf = self.font("serif", int((30 if on else 24) * u))
            lw = lf.getlength(label)
            ly = yb + 44 * u
            for (px0, px1) in placed:
                if X(y) - lw / 2 < px1 + 8 and X(y) + lw / 2 > px0 - 8:
                    ly += 34 * u
            placed.append((X(y) - lw / 2, X(y) + lw / 2))
            dr.text((X(y), ly), label, font=lf, fill=INK if on else DIM, anchor="mt",
                    stroke_width=3, stroke_fill=(12, 10, 8))
        if year is not None and y0 <= year <= y1:
            cx = X(year)
            dr.polygon([(cx - 14, yb - 108 * u), (cx + 14, yb - 108 * u), (cx, yb - 88 * u)], fill=GOLD)
            pf = self.font("gothic", int(26 * u))
            txt = f"{round(year)}年"
            pw = pf.getlength(txt) + 24
            dr.rounded_rectangle([cx - pw / 2, yb - 150 * u, cx + pw / 2, yb - 114 * u], radius=8,
                                 fill=(20, 16, 10, 220), outline=GOLD, width=2)
            dr.text((cx, yb - 132 * u), txt, font=pf, fill=GOLD, anchor="mm")

    # --- 本編の画面（立ち絵と字幕より下の層） ------------------------------
    def base(self, state: State, year=None, slide: float = 1.0, fig: float = 1.0, icon_t: float = 1.0) -> Image.Image:
        """year：年表の印の位置（移動の途中を描くとき）／slide：新しいメモの滑り込み（0〜1）。"""
        W, H = self.W, self.H
        img = self._canvas(state.background)
        dr = ImageDraw.Draw(img, "RGBA")
        n_sec = len(self.script.sections)
        title = self.script.sections[state.section].title
        dr.text((120, 100), f"第{state.section + 1}節", font=self.font("gothic", 30), fill=GOLD)
        for k in range(n_sec):                             # 節の進み具合
            cx = 250 + k * 30
            r = 9 if k == state.section else 6
            fill = GOLD if k <= state.section else (90, 80, 66)
            dr.ellipse([cx - r, 117 - r, cx + r, 117 + r], fill=fill)
        dr.text((250 + n_sec * 30 + 6, 117), f"全{n_sec}節", font=self.font("gothic", 22), fill=DIM, anchor="lm")
        limit = (W - 330 - 400 - 40 - 120) if state.portrait is not None else (W - 240)
        size = 64
        while size > 36 and self.font("serif", size, bold=True).getlength(title) > limit:
            size -= 2
        dr.text((120, 145 + (64 - size) // 2), title, font=self.font("serif", size, bold=True), fill=INK,
                stroke_width=2, stroke_fill=(12, 10, 8))

        if state.figure is None:
            self._memo(img, state, slide)
            if state.portrait is not None:
                self._portrait(img, state.portrait)
                self._age(img, state)
            from . import extras
            if state.icon:
                img = extras.draw_icon(self, img, state.icon, icon_t)
            elif state.portrait is None and state.background is not None and self.config.get("center_panel", True):
                self._panel(img, state.background)         # 真ん中が空かないように、その場面の絵を額に入れて出す
            if state.bubble and state.portrait is not None:
                import json as _j
                img = extras.draw_bubble(self, img, state.portrait, _j.loads(state.bubble))
        else:                                              # 図のあいだは、メモと肖像を隠して図を大きく
            import json as _json
            from . import figures
            img = figures.draw(self, img, _json.loads(state.figure), fig)
        from . import extras
        top = extras.TERM_BOX[1]
        if state.term:                                     # 用語の札は右上（肖像と図の右の空き）
            img, top = extras.draw_term(self, img, *state.term)
            top += 18
        is_map = state.figure is not None and '"type": "map"' in state.figure
        if state.place and not is_map:                     # 地図の図が出ているあいだは要らない
            img = extras.draw_minimap(self, img, state.place, top)
        dr = ImageDraw.Draw(img, "RGBA")
        if state.figure is None:                           # 図のあいだは年表も隠す（図の板を下まで広げる）
            self._timeline(dr, 470, W - 470, 770, state.year if year is None else year)
        if state.background is not None and state.background.credit:
            dr.text((W / 2, H - 14), f"背景：{state.background.credit}", font=self.font("serif", 18),
                    fill=DIM, anchor="ms", stroke_width=2, stroke_fill=(12, 10, 8))
        names = "　".join(f"VOICEVOX:{n}" for n in people.credit_names(self.config, self.script))
        dr.text((W - 40, 34), names, font=self.font("serif", 20), fill=DIM, anchor="rs",
                stroke_width=2, stroke_fill=(12, 10, 8))
        return img

    def _memo(self, img: Image.Image, state: State, slide: float) -> None:
        """掘り出したメモ：その節で出た札が新しい順に3枚まで。いまの札は明るく、前の札は暗く。"""
        if not state.memo:
            return
        dr = ImageDraw.Draw(img, "RGBA")
        dr.text((124, 240), "▼ 掘り出したメモ", font=self.font("gothic", 22), fill=DIM)
        y = 272
        for k, card in enumerate(state.memo):
            current = (k == 0 and card == state.card)
            hf = self.font("gothic", 30 if current else 26)
            size = 38 if current else 30
            bf = self.font("serif", size)
            while size > 24 and bf.getlength(card.body or "") > 760:
                size -= 2
                bf = self.font("serif", size)
            w = max(440, int(max(hf.getlength(card.head), bf.getlength(card.body or ""))) + 64)
            h = 118 if current else 96
            dx = -int((1 - _ease(slide)) * (w + 140)) if k == 0 else 0
            dr.rounded_rectangle([120 + dx, y, 120 + dx + w, y + h], radius=10,
                                 fill=(20, 16, 10, 205 if current else 150),
                                 outline=GOLD if current else (120, 100, 70), width=3 if current else 1)
            dr.text((146 + dx, y + 12), card.head, font=hf, fill=GOLD if current else DIM)
            if card.body:
                dr.text((146 + dx, y + (54 if current else 46)), card.body, font=bf, fill=INK if current else DIM)
            y += h + 16

    def _age(self, img: Image.Image, state) -> None:
        """肖像の左上に「この時○歳」（台本の people: に生没がある人物だけ。10-04）。"""
        from .script import age_at, person_of
        people = getattr(self.script, "people", {}) or {}
        who = person_of(people, state.portrait)
        age = age_at(people[who], state.year, state.card) if who else None
        if age is None:
            return
        from .extras import portrait_box
        px, py, pw, ph = portrait_box(self, state.portrait)
        dr = ImageDraw.Draw(img, "RGBA")
        sf, bf = self.font("gothic", 20), self.font("serif", 40, bold=True)
        text = f"{age}歳"
        w = max(bf.getlength(text), sf.getlength("この時")) + 34
        x0, y0 = px - 34, py - 34
        dr.rounded_rectangle([x0, y0, x0 + w, y0 + 82], radius=10, fill=(150, 36, 30, 235), outline=GOLD, width=2)
        dr.text((x0 + w / 2, y0 + 18), "この時", font=sf, fill=(255, 236, 210), anchor="mm")
        dr.text((x0 + w / 2, y0 + 54), text, font=bf, fill=(255, 255, 255), anchor="mm")

    PANEL_BOX = (960, 250, 1600, 720)                     # メモ（左、右端 x≈940）と用語の札（x=1640〜）のあいだ、年表の上

    def _panel(self, img: Image.Image, pic) -> None:
        """真ん中の額：背景と同じ絵を、暗くせずに額に入れて出す（10-06 ユーザー「画面の真ん中に何もない時を避けて」）。"""
        key = ("panel", pic.image, getattr(pic, "crop", None))
        p = self._images.get(key)
        if p is None:
            src = self.image(pic.image).convert("RGB")
            x0, y0, x1, y1 = self.PANEL_BOX
            bw, bh = x1 - x0 - 40, y1 - y0 - 40
            s = min(bw / src.width, bh / src.height)
            p = src.resize((max(1, int(src.width * s)), max(1, int(src.height * s))), Image.LANCZOS)
            self._images[key] = p
        x0, y0, x1, y1 = self.PANEL_BOX
        px = (x0 + x1) // 2 - p.width // 2
        py = (y0 + y1) // 2 - p.height // 2
        dr = ImageDraw.Draw(img, "RGBA")
        dr.rectangle([px - 18, py - 18, px + p.width + 18, py + p.height + 18], fill=(30, 24, 16, 255),
                     outline=GOLD, width=2)                     # 肖像と同じ二重の金の額
        dr.rectangle([px - 7, py - 7, px + p.width + 7, py + p.height + 7], outline=GOLD, width=3)
        img.paste(p, (px, py))

    def _portrait(self, img: Image.Image, pic) -> None:
        W = self.W
        dr = ImageDraw.Draw(img, "RGBA")
        p = self.image(pic.image).convert("RGB")
        ph = 440
        p = p.resize((int(p.width * ph / p.height), ph), Image.LANCZOS)
        px, py = W - p.width - 330, 70
        dr.rectangle([px - 20, py - 20, px + p.width + 20, py + ph + 20], fill=(30, 24, 16, 255),
                     outline=GOLD, width=2)                     # 額は二重の金の線
        dr.rectangle([px - 8, py - 8, px + p.width + 8, py + ph + 8], outline=GOLD, width=3)
        img.paste(p, (px, py))
        if not pic.caption:
            return
        dr = ImageDraw.Draw(img, "RGBA")
        name, _, detail = pic.caption.partition("（")
        detail = detail.rstrip("）")
        box_w = max(p.width + 40, 300)
        cx = px + p.width / 2
        size = 32
        while size > 22 and self.font("serif", size, bold=True).getlength(name) > box_w - 24:
            size -= 2
        top = py + ph + 28
        bottom = top + (78 if detail else 48)
        dr.rounded_rectangle([cx - box_w / 2, top, cx + box_w / 2, bottom], radius=8, fill=(20, 16, 10, 215))
        dr.text((cx, top + 24), name, font=self.font("serif", size, bold=True), fill=INK, anchor="mm")
        if detail:
            df = self.font("serif", 20)
            while df.size > 14 and df.getlength(detail) > box_w - 20:
                df = self.font("serif", df.size - 1)
            dr.text((cx, top + 58), detail, font=df, fill=DIM, anchor="mm")

    # --- 立ち絵と字幕 -----------------------------------------------------
    def with_cast(self, base: Image.Image, speaker: str, hop: float = 0.0, text: str = "",
                  tone: str = "普通", mouth: bool = False, blink: bool = False) -> Image.Image:
        """立ち絵を重ねる。話している側は明るく、足もとに光、hop（0〜1）のぶん跳ねる。text は字幕。
        表情のある話者は、話しているあいだ tone の顔で mouth のとき口を開け、blink のとき目を閉じる。"""
        img = base.copy()
        for who, cast in self.config["cast"].items():
            talking = who == speaker or speaker == "二人"
            if cast.get("faces"):
                ch = self.face(who, tone if talking else "聞く", mouth and talking, blink)
                if not talking:
                    ch = self._dim(ch, ("listen-face", who, blink))
            else:
                ch = self.character(who) if talking else self.listener(who)
            lift = int(HOP_PX * math.sin(math.pi * hop)) if talking else 0
            x = 20 if cast.get("side", "left") == "left" else self.W - ch.width - 10
            if talking:                                     # 話している側の足もとに柔らかい光
                img.alpha_composite(self._glow(who, x, ch.width))
            img.alpha_composite(ch, (x, self.H - ch.height + 10 - lift))
        if text:
            self._subtitle(img, speaker, text)
        return img if self.layered else img.convert("RGB")

    def _dim(self, ch: Image.Image, key) -> Image.Image:
        if key not in self._images:
            a = ch.split()[3]
            rgb = ImageEnhance.Brightness(ch.convert("RGB")).enhance(LISTENER_DIM)
            rgb = ImageEnhance.Color(rgb).enhance(0.75)
            out = rgb.convert("RGBA")
            out.putalpha(a)
            self._images[key] = out
        return self._images[key]

    def _glow(self, who: str, x: int, width: int) -> Image.Image:
        key = ("glow", who, x, width, self.W, self.H)
        if key not in self._images:
            glow = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
            gx = x + width / 2
            ImageDraw.Draw(glow).ellipse([gx - width * 0.6, self.H - 140, gx + width * 0.6, self.H + 120],
                                         fill=(255, 220, 150, 70))
            self._images[key] = glow.filter(ImageFilter.GaussianBlur(40))
        return self._images[key]

    def draw_rich(self, dr, cx: float, y: float, row: str, mask: list[bool], font, color, emph=EMPH) -> None:
        """1行を、強調の字だけ色を変えて中央ぞろえで描く。"""
        x = cx - font.getlength(row) / 2
        for ch, on in zip(row, mask):
            dr.text((x, y), ch, font=font, fill=emph if on else color)
            x += font.getlength(ch)

    def _subtitle(self, img: Image.Image, speaker: str, text: str) -> None:
        """2人のあいだの下に字幕。高さは2行ぶんで固定。話している人の名前をその人の側に寄せて出す。"""
        x0, x1, y1 = 440, self.W - 440, self.H - 34
        h = 34 + 60 * SUB_ROWS
        y0 = y1 - h
        shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([x0 + 6, y0 + 10, x1 + 6, y1 + 10], radius=14, fill=(0, 0, 0, 140))
        img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
        dr = ImageDraw.Draw(img, "RGBA")
        side = self.config["cast"].get(speaker, {}).get("side", "center")
        color = SPEAKER_COLORS.get(side, GOLD if speaker == "二人" else ROLE_COLOR)
        name = people.label(self.config, speaker)
        dr.rounded_rectangle([x0, y0, x1, y1], radius=14, fill=(250, 246, 236, 240), outline=color, width=4)
        if side != "center":
            stripe = [x0 + 4, y0 + 14, x0 + 12, y1 - 14] if side == "left" else [x1 - 12, y0 + 14, x1 - 4, y1 - 14]
            dr.rounded_rectangle(stripe, radius=4, fill=color)
        nf = self.font("gothic", 28)
        nw = nf.getlength(name) + 28
        nx = {"left": x0 + 20, "right": x1 - 20 - nw}.get(side, (x0 + x1 - nw) / 2)
        dr.rounded_rectangle([nx, y0 - 20, nx + nw, y0 + 18], radius=8, fill=color)
        dr.text((nx + nw / 2, y0 - 1), name, font=nf, fill=(255, 255, 255), anchor="mm")
        body, mask = emphasis_mask(text)
        f = self.font("serif", 44, bold=True)
        rows = wrap_balanced(body, f, x1 - x0 - 70)[:SUB_ROWS]
        top = y0 + 22 + (60 * (SUB_ROWS - len(rows))) // 2   # 1行のときは上下の真ん中に
        pos = 0
        for k, row in enumerate(rows):
            start = body.find(row, pos)
            self.draw_rich(dr, (x0 + x1) / 2, top + 60 * k, row, mask[start:start + len(row)], f, (40, 30, 20))
            pos = start + len(row)

    # --- 編集の効果 -------------------------------------------------------
    def pop(self, img: Image.Image, word: str, t: float, speaker: str) -> Image.Image:
        """強調語を画面の真ん中に大きく飛び出させる。t は 0→1 で大きくなる（1 で止まる）。"""
        img = img.copy()
        e = _ease(t)
        scale = 0.6 + 0.5 * e if t < 1 else 1.0
        if t < 1:
            scale = 0.6 + 0.55 * math.sin(math.pi / 2 * e) - 0.05 * e    # 少し行き過ぎて戻る
        size = int(150 * scale)
        while size > 40 and self.font("gothic", size).getlength(word) > 920:
            size -= 4
        f = self.font("gothic", size)
        cx, cy = 740, self.H * 0.43                       # 右上の肖像（x 1270〜）にかからない
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dr = ImageDraw.Draw(layer)
        side = self.config["cast"].get(speaker, {}).get("side", "left")
        color = (255, 214, 40) if side == "left" else (255, 170, 60)
        dr.text((cx + 8, cy + 10), word, font=f, fill=(0, 0, 0, int(160 * e)), anchor="mm")
        dr.text((cx, cy), word, font=f, fill=color + (int(255 * min(1, e * 1.5)),), anchor="mm",
                stroke_width=max(4, size // 14), stroke_fill=(20, 14, 8, int(255 * min(1, e * 1.5))))
        img.alpha_composite(layer)
        return img

    def burst(self, img: Image.Image, side: str, t: float) -> Image.Image:
        """驚きの集中線（話している人のまわりから外へ）。t は 0→1 で消えていく。"""
        img = img.copy()
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dr = ImageDraw.Draw(layer)
        cx = 230 if side == "left" else self.W - 230
        cy = self.H - 260
        import random
        rnd = random.Random(7)
        alpha = int(200 * (1 - t))
        for _ in range(26):
            a = rnd.uniform(0, 2 * math.pi)
            r0 = rnd.uniform(170, 210)
            r1 = r0 + rnd.uniform(60, 120)
            w = rnd.uniform(3, 7)
            x0, y0 = cx + r0 * math.cos(a), cy + r0 * math.sin(a)
            x1, y1 = cx + r1 * math.cos(a), cy + r1 * math.sin(a)
            dr.line([(x0, y0), (x1, y1)], fill=(255, 240, 200, alpha), width=int(w))
        img.alpha_composite(layer)
        return img

    def shake(self, img: Image.Image, k: int) -> Image.Image:
        """画面を少し揺らす（前景だけ。背景は動いているので気にならない）。"""
        dx = int(SHAKE_PX * math.sin(k * 2.3) * (1 - k / (SHAKE_FRAMES + 1)))
        dy = int(SHAKE_PX * 0.6 * math.cos(k * 3.1) * (1 - k / (SHAKE_FRAMES + 1)))
        out = Image.new(img.mode, img.size, (0, 0, 0, 0) if img.mode == "RGBA" else (0, 0, 0))
        out.paste(img, (dx, dy))
        return out

    def wipe(self, img: Image.Image, t: float) -> Image.Image:
        """節の頭：地層の帯が下から上へ通り過ぎる。t は 0→1。"""
        img = img.copy()
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dr = ImageDraw.Draw(layer)
        band = self.H * 0.9
        top = self.H - (self.H + band) * _ease(t)
        bands = STRATA + STRATA[::-1]
        bh = band / len(bands)
        for i, c in enumerate(bands):
            y = top + i * bh
            dr.rectangle([0, y, self.W, y + bh + 1], fill=c + (255,))
        img.alpha_composite(layer)
        return img

    # --- 特別な画面 -------------------------------------------------------
    def overlay_title(self, img: Image.Image, head: str, body: str, strength: float = 1.0) -> Image.Image:
        """画面の真ん中に大きな題（冒頭の問い・節の頭）。strength は暗くする強さ。"""
        img = img.convert("RGBA")
        dim = Image.new("RGBA", img.size, (8, 6, 4, int(150 * strength)))
        img = Image.alpha_composite(img, dim)        # 透明な前景でも、暗幕のぶん下の背景が暗くなる
        dr = ImageDraw.Draw(img, "RGBA")
        cy = self.H * 0.40
        if head:
            dr.text((self.W / 2, cy - 70), head, font=self.font("gothic", 40), fill=GOLD, anchor="mm")
        size = 76
        while size > 40 and self.font("serif", size, bold=True).getlength(body) > self.W - 240:
            size -= 2
        dr.text((self.W / 2, cy + 10), body, font=self.font("serif", size, bold=True), fill=INK, anchor="mm",
                stroke_width=4, stroke_fill=(12, 10, 8))
        y = cy + 70
        for i, c in enumerate(STRATA):                      # 下に地層の線
            dr.rectangle([self.W / 2 - 300, y + i * 6, self.W / 2 + 300, y + i * 6 + 5], fill=c)
        return img if self.layered else img.convert("RGB")

    def end_card(self, background) -> Image.Image:
        """次回予告とお礼。右側は YouTube の終了画面（動画・登録ボタン）を置く場所として空ける。"""
        nxt = getattr(self.script, "next", {}) or {}
        img = self._canvas(background)
        img.alpha_composite(Image.new("RGBA", img.size, (8, 6, 4, 150)))
        dr = ImageDraw.Draw(img, "RGBA")
        x = 120
        dr.text((x, 150), "ご視聴ありがとうございました", font=self.font("gothic", 34), fill=DIM)
        if nxt:
            dr.rounded_rectangle([x, 230, x + 190, 290], radius=10, fill=(176, 40, 40))
            dr.text((x + 95, 260), "次回予告", font=self.font("gothic", 34), fill=(255, 255, 255), anchor="mm")
            series = nxt.get("series", self.script.series)      # 次の回が別のシリーズなら next.series で（"" で出さない）
            if series:
                dr.text((x, 330), series, font=self.font("gothic", 30), fill=GOLD)
            dr.text((x, 380), nxt.get("title", ""), font=self.font("serif", 76, bold=True), fill=INK,
                    stroke_width=3, stroke_fill=(12, 10, 8))
            teaser = nxt.get("teaser", "")
            for k, row in enumerate(wrap(teaser, self.font("serif", 40), 760)[:3]):
                dr.text((x, 500 + 56 * k), row, font=self.font("serif", 40), fill=INK)
        # 右側（x 1080〜1800, y 200〜605）は、YouTube の終了画面（次の動画・登録ボタン）を置くために空けておく
        return img


def state_of(line) -> State:
    return State(line.section, line.background, line.portrait, line.card, line.year, line.speaker,
                 getattr(line, "memo", ()), getattr(line, "figure", None), getattr(line, "bubble", None),
                 getattr(line, "icon", None), getattr(line, "term", None), getattr(line, "place", None))


def end_key(script) -> tuple:
    """次回予告の画面の中身。控えの画像の名前に入れる（10-05：予告を差し替えても前の回の画像が使い回された）。"""
    nxt = getattr(script, "next", {}) or {}
    return (getattr(script, "series", ""), tuple(sorted((str(k), str(v)) for k, v in nxt.items())))


def _salt(painter) -> str:
    """描き方（このファイル・字幕の切り方・設定）が変わったら、控えの画像を使い回さない。"""
    src = Path(__file__).read_bytes() + (Path(__file__).parent / "subs.py").read_bytes()
    try:
        src += Path(type(painter).__module__.replace(".", "/") + ".py").read_bytes()
    except OSError:
        pass
    src += json.dumps(painter.config, sort_keys=True, ensure_ascii=False).encode("utf-8")
    src += type(painter).__name__.encode()
    return hashlib.sha1(src).hexdigest()[:8]


def _name(salt: str, *parts) -> str:
    h = hashlib.sha1(repr((salt,) + parts).encode("utf-8")).hexdigest()[:14]
    return f"{h}.png"


def frames(painter: Painter, cues: list, total: float, frame_dir: Path, fps: int,
           with_text: bool = False, end_card: bool = False, workers: int = 10,
           end_seconds: float = END_SECONDS) -> list[tuple[Path, float]]:
    """(画像, 表示する秒数) の並びを作る。同じ状態の画像は使い回す。画像は同時に描く（CPU を並べる）。

    1行のあいだに起きること（本編）：
      話し始めに跳ねる／絵・札・年号の移り変わり／驚きの集中線と揺れ／
      口パクとまばたき（表情のある話者）／字幕のかたまりの切り替え／《》の強調語の飛び出し。
    節の頭の間には地層のワイプと「第N節 題名」。最後に次回予告。
    with_text=True（ショート）は、せりふ全体を画面に焼き込み、効果は跳ねるだけ。
    """
    from concurrent.futures import ThreadPoolExecutor

    from . import lipsync
    from .subs import plain

    subtitles = (not with_text) and bool(painter.config.get("subtitles"))
    special = not with_text
    frame_dir.mkdir(parents=True, exist_ok=True)
    salt = _salt(painter)
    out: list[tuple[Path, float]] = []
    todo: dict[Path, object] = {}
    prev_state: State | None = None
    prev_speaker = None
    plain_len = lambda x: len(emphasis_mask(x)[0])
    has_faces = lambda who: (who == "二人" or bool(painter.config["cast"].get(who, {}).get("faces")))   # 人物の行は誰も口を動かさない

    def emit(path: Path, make, dur: float):
        if dur <= 0:
            return
        if not path.exists() and path not in todo:
            todo[path] = make
        out.append((path, dur))

    for i, cue in enumerate(cues):
        line = cue.line
        state = state_of(line)
        # 節が替わる行は、前の行の話し終わりから始める（その間に節の頭の画面を出す）。
        # 同じ節の中は、次の行の話し始めまでをこの行の時間にする（間も字幕を出したまま）
        new_sec = i > 0 and cues[i - 1].line.section != line.section
        start = 0.0 if i == 0 else (cues[i - 1].end if new_sec else cue.start)
        if i + 1 < len(cues):
            nxt = cues[i + 1]
            end = cue.end if (special and nxt.line.section != line.section) else nxt.start
        else:
            end = total - (end_seconds if end_card else 0.0)
        side = painter.config["cast"].get(line.speaker, {}).get("side", "left")
        n_hop = HOP_FRAMES if line.speaker != prev_speaker else 0

        # 字幕のかたまり（行の中の時刻と長さ）
        if with_text:
            subs_ = [(line.text, 0.0, end - cue.start)]
        elif subtitles:
            cs = subtitle_chunks(line.text)
            talk = max(cue.end - cue.start, 1 / fps)
            n_chars = sum(plain_len(c) for c in cs) or 1
            subs_, t = [], 0.0
            for c in cs:
                d = talk * plain_len(c) / n_chars
                subs_.append((c, t, d))
                t += d
            last = subs_[-1]
            subs_[-1] = (last[0], last[1], last[2] + max(0.0, end - cue.end))
        else:
            subs_ = [("", 0.0, end - cue.start)]

        # 節の頭：行の前の間に、地層のワイプと題
        lead = max(0.0, cue.start - start) if i > 0 else cue.start
        if lead > 0:
            new_section = special and prev_state is not None and prev_state.section != state.section
            title = painter.script.sections[state.section].title
            def base_lead(s=state):
                return painter.with_cast(painter.base(s), s.speaker, 0, "", "聞く")
            if new_section:
                n_w = min(WIPE_FRAMES, int(lead * fps) - 1)
                for k in range(1, n_w + 1):
                    emit(frame_dir / _name(salt, "wipe", state, k, n_w),
                         lambda s=state, k=k, n=n_w, t=title: painter.wipe(
                             painter.overlay_title(base_lead(s), f"第{s.section + 1}節", t), k / (n + 1)), 1 / fps)
                emit(frame_dir / _name(salt, "sec", state, title),
                     lambda s=state, t=title: painter.overlay_title(base_lead(s), f"第{s.section + 1}節", t),
                     lead - n_w / fps)
            else:
                emit(frame_dir / _name(salt, "lead", state), base_lead, lead)

        # 口パクとまばたき（表情のある話者だけ）。無ければ「閉じたまま」1区間
        talk_len = end - cue.start
        if special and has_faces(line.speaker) and getattr(cue, "wav", None) is not None and Path(cue.wav).exists():
            mouth = lipsync.mouth_track(Path(cue.wav))
            face_segs = lipsync.segments(mouth, lipsync.blinks(line.index, talk_len), talk_len)
        else:
            face_segs = [(talk_len, False, False)]

        # 区切りの時刻：字幕の切り替え・口と目・効果の頭
        cuts = {0.0, talk_len}
        for _, t0, _d in subs_:
            cuts.add(t0)
        t = 0.0
        for d, _m, _b in face_segs:
            t += d
            cuts.add(min(talk_len, t))
        changed = special and prev_state is not None and prev_state.section == state.section and (
            (prev_state.background, prev_state.portrait, prev_state.memo, prev_state.year, prev_state.figure)
            != (state.background, state.portrait, state.memo, state.year, state.figure))
        surprised = special and line.tone == "驚き"
        # 強調語の飛び出しは 10-04「4は不要」で外した（config の pop: true で戻せる）
        words = ([w for w in (plain(x) for x in __import__("re").findall(r"《(.+?)》", line.text))]
                 if special and painter.config.get("pop") else [])
        fig_new = special and state.figure is not None and (prev_state is None or prev_state.figure != state.figure)
        icon_new = special and state.icon is not None and (prev_state is None or prev_state.icon != state.icon)
        n_fx = max(n_hop, TRANS_FRAMES if changed else 0, SHAKE_FRAMES if surprised else 0,
                   POP_FRAMES if words else 0, FIG_FRAMES if fig_new else 0, ICON_FRAMES if icon_new else 0)
        for k in range(1, n_fx + 1):
            cuts.add(min(talk_len, k / fps))
        pop_len = POP_SECONDS if words else 0.0
        if words:
            cuts.add(min(talk_len, pop_len))
        times = sorted(x for x in cuts if 0 <= x <= talk_len)

        opening = special and i < OPENING_CUES and painter.script.question
        for a, b in zip(times, times[1:]):
            if b - a < 1e-6:
                continue
            mid = (a + b) / 2
            text = next((c for c, t0, d in subs_ if t0 <= mid < t0 + d), subs_[-1][0])
            acc, mouth_open, blink = 0.0, False, False
            for d, m, e in face_segs:
                if acc <= mid < acc + d:
                    mouth_open, blink = m, e
                    break
                acc += d
            k = int(round(a * fps)) + 1 if a < n_fx / fps else 0       # 効果の何コマ目か（0 は効果なし）
            hop_k = k if (n_hop and k and k <= n_hop) else 0
            tr = (k / (TRANS_FRAMES + 1)) if (changed and k and k <= TRANS_FRAMES) else 1.0
            shake_k = k if (surprised and k and k <= SHAKE_FRAMES) else 0
            pop_t = (min(1.0, k / (POP_FRAMES + 1)) if k else 1.0) if (words and a < pop_len) else None
            fig_t = (k / (FIG_FRAMES + 1)) if (fig_new and k and k <= FIG_FRAMES) else 1.0
            icon_t = (k / (ICON_FRAMES + 1)) if (icon_new and k and k <= ICON_FRAMES) else 1.0

            def make(s=state, ps=prev_state, text=text, hop_k=hop_k, n_hop=n_hop, tr=tr, shake_k=shake_k,
                     pop_t=pop_t, mouth_open=mouth_open, blink=blink, tone=line.tone, opening=opening,
                     words=tuple(words), side=side, fig_t=fig_t, icon_t=icon_t):
                hop_t = hop_k / (n_hop + 1) if hop_k else 0.0
                if tr < 1.0 and ps is not None:
                    year = s.year
                    if ps.year is not None and s.year is not None:
                        year = ps.year + (s.year - ps.year) * _ease(tr)
                    slide = tr if (s.memo and s.memo != ps.memo) else 1.0
                    base = painter.base(s, year=year, slide=slide, fig=fig_t, icon_t=icon_t)
                    changed_pic = (((ps.background, ps.portrait, ps.figure, ps.icon) != (s.background, s.portrait, s.figure, s.icon)) if painter.layered
                                   else (ps.background, ps.portrait) != (s.background, s.portrait))
                    if changed_pic:
                        base = Image.blend(painter.base(ps), base, _ease(tr))
                else:
                    base = painter.base(s, fig=fig_t, icon_t=icon_t)
                if pop_t is not None:
                    base = painter.pop(base, words[0], pop_t, s.speaker)
                im = painter.with_cast(base, s.speaker, hop_t, text, tone, mouth_open, blink)
                if shake_k:
                    im = painter.burst(im, side, shake_k / (SHAKE_FRAMES + 1))
                    im = painter.shake(im, shake_k)
                if opening:
                    im = painter.overlay_title(im, painter.script.series, painter.script.question, 0.8)
                return im

            key = ("f2", state, prev_state if tr < 1.0 else None, round(tr, 3), hop_k, n_hop, text, shake_k,
                   None if pop_t is None else (words[0], round(pop_t, 3)), round(fig_t, 3), round(icon_t, 3),
                   mouth_open, blink,
                   line.tone,
                   bool(opening))
            emit(frame_dir / _name(salt, *key), make, b - a)
        prev_state = state
        prev_speaker = line.speaker

    if end_card and cues:
        bg = cues[-1].line.background
        emit(frame_dir / _name(salt, "end", bg, end_key(painter.script)),
             lambda: painter.with_cast(painter.end_card(bg), "語り", 0, "", "明るい"), end_seconds)

    # まとめて描く（同じ画像は1回だけ）。Pillow の描画は GIL を外すので、スレッドを並べると速くなる
    def run(item):
        path, make = item
        make().save(path, compress_level=1)
    with ThreadPoolExecutor(max_workers=workers) as ex:
        list(ex.map(run, todo.items()))
    return out


def concat_list(items: list[tuple[Path, float]]) -> str:
    """ffmpeg の concat 用の並び。最後の1枚は2回書く（ffmpeg の決まり）。"""
    lines = []
    for path, dur in items:
        lines.append(f"file '{path.as_posix()}'")
        lines.append(f"duration {dur:.4f}")
    if items:
        lines.append(f"file '{items[-1][0].as_posix()}'")
    return "\n".join(lines) + "\n"
