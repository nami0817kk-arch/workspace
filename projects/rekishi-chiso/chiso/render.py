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

from .figures import _ease  # noqa: F401  ゆるい出入り（図・寄り・赤ペンと同じ式）
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
OPENING_CUES = 1     # 冒頭で題名の問いを大きく出す行数（10-08 に2→1。長く出て字幕が読めなかった）
POP_SECONDS = 1.6    # 強調語が画面の真ん中に飛び出している長さ
POP_FRAMES = 6       # 飛び出すときの大きくなる動き（フレーム数）
SHAKE_FRAMES = 6     # 驚きで画面が揺れる長さ（フレーム数）
SHAKE_PX = 10        # 揺れの大きさ
WIPE_FRAMES = 14     # 節の頭の地層のワイプ（フレーム数）
FIG_FRAMES = 45      # 図が出たときに描き進める長さ（フレーム数。1.5秒）
ICON_FRAMES = 8      # 挿絵が出るときに大きくなる長さ（フレーム数）
TIMELINE_ROWS = 2    # 年表の名札の段の数（3段目は字幕の箱にかかる。10-09）
TIMELINE_ROW_H = 34  # 名札の段の高さ
TITLE_X = 120        # 節の題の左の端
TITLE_BAND = (140, 215)   # 節の題の上下（64px の題が入る高さ）
TITLE_MIN = 36       # 節の題はこの大きさまで縮める（収まらなければ check が止める）
BASE_CACHE = 24      # 前景の下の層（base）を控えておく数。1枚 8MB（1920x1080 RGBA）


def look(config: dict, script, name: str) -> bool:
    """画面の道具（texture・recap）を使うか。台本の一番上に書いたものが config.yaml より優先。"""
    mine = getattr(script, "look", None) or {}
    return bool(mine[name]) if name in mine else bool(config.get(name, False))


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
    reaction: str | None = None
    detail: str | None = None
    mark: str | None = None


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

    def look(self, name: str) -> bool:
        """画面の道具（texture・recap）を使うか。台本の一番上に書いたものが config.yaml より優先。"""
        return look(self.config, self.script, name)

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

    def _bust(self, im: Image.Image, cast: dict) -> Image.Image:
        """立ち絵を中身だけに詰め、cast の height に縮めて、上から bust の割合だけ切る。"""
        im = im.crop(im.getbbox())
        h = int(cast.get("height", 1150) * self.H / 1080)
        im = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
        return im.crop((0, 0, im.width, int(h * cast.get("bust", 0.4))))

    def character(self, speaker: str) -> Image.Image:
        key = ("char", speaker)
        if key not in self._images:
            cast = self.config["cast"][speaker]
            self._images[key] = self._bust(self.image(cast["image"]), cast)
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
            self._images[key] = self._bust(Image.open(path).convert("RGBA"), cast)
        return self._images[key]

    def listener(self, speaker: str) -> Image.Image:
        """聞いている側の立ち絵：少し暗く、少し色を落とす。"""
        return self._dim(self.character(speaker), ("listen", speaker))

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
        from .years import astro, label as year_label, tick
        y0, y1 = sc.timeline_start, sc.timeline_end
        # 紀元前は負の年。0年が無いので位置は天文学の年で（古い方が左。chiso/years.py）
        X = lambda y: x0 + (x1 - x0) * (astro(y) - astro(y0)) / max(1, (astro(y1) - astro(y0)))
        marks = sorted({y for y, _ in sc.events} | {y0, y1})
        for i, (a, b) in enumerate(zip(marks, marks[1:])):
            color = STRATA[min(i, len(STRATA) - 2)] if b != y1 or len(marks) < 3 else STRATA[-1]
            if year is not None and a >= year:              # これから先の地層は暗く
                color = tuple(int(c * 0.45) for c in color)
            dr.rectangle([X(a), yb - 14, X(b), yb + 14], fill=color + (255,))
        u = self.H / 1080
        years: list[tuple[float, float]] = []            # 年の数字の重なりを避ける（10-05「1894189 1900」と重なった）
        for y, _ in sc.events:                           # いまの年を先に場所取り（10-06 明智で 1566 と 1582 がくっついた）
            if year is not None and round(year) == y:
                half = self.font("gothic", int(30 * u)).getlength(tick(y)) / 2
                years.append((X(y) - half, X(y) + half))
        for y, label in sc.events:
            on = (year is not None and round(year) == y)
            dr.line([X(y), yb - 26, X(y), yb + 26], fill=(GOLD if on else DIM) + (255,), width=4 if on else 2)
            yf = self.font("gothic", int((30 if on else 26) * u))
            half = yf.getlength(tick(y)) / 2
            if on or not any(X(y) - half < b + 12 and X(y) + half > a - 12 for a, b in years):
                dr.text((X(y), yb - 40 * u), tick(y), font=yf, fill=GOLD if on else DIM, anchor="ms")
                if not on:
                    years.append((X(y) - half, X(y) + half))
        for (y, label), row in zip(sc.events, self.timeline_rows(x0, x1, year)):
            if row is None:
                continue                                  # 近い出来事に押し出された名札は出さない（10-09）
            on = (year is not None and round(year) == y)
            lf = self.font("serif", int((30 if on else 24) * u))
            dr.text((X(y), yb + (44 + TIMELINE_ROW_H * row) * u), label, font=lf, fill=INK if on else DIM, anchor="mt",
                    stroke_width=3, stroke_fill=(12, 10, 8))
        if year is not None and y0 <= year <= y1:
            cx = X(year)
            dr.polygon([(cx - 14, yb - 108 * u), (cx + 14, yb - 108 * u), (cx, yb - 88 * u)], fill=GOLD)
            pf = self.font("gothic", int(26 * u))
            txt = year_label(year)
            pw = pf.getlength(txt) + 24
            dr.rounded_rectangle([cx - pw / 2, yb - 150 * u, cx + pw / 2, yb - 114 * u], radius=8,
                                 fill=(20, 16, 10, 220), outline=GOLD, width=2)
            dr.text((cx, yb - 132 * u), txt, font=pf, fill=GOLD, anchor="mm")

    def timeline_rows(self, x0: float, x1: float, year) -> list[int | None]:
        """年表の出来事の名札を置く段（0＝すぐ下、1＝その下）。重なる名札は下の段へ。2段でも重なる名札は出さない
        （10-09 秀吉の回で「長浜城主・大返し・関白」が3段まで下がり、字幕の箱に隠れた）。いまの年の名札は先に置くので必ず出る。"""
        sc = self.script
        from .years import astro
        y0, y1 = sc.timeline_start, sc.timeline_end
        X = lambda y: x0 + (x1 - x0) * (astro(y) - astro(y0)) / max(1, (astro(y1) - astro(y0)))
        u = self.H / 1080
        spans = []
        on = []
        for y, label in sc.events:
            hot = year is not None and round(year) == y
            w = self.font("serif", int((30 if hot else 24) * u)).getlength(label)
            spans.append((X(y) - w / 2, X(y) + w / 2))
            on.append(hot)
        rows: list[int | None] = [None] * len(spans)
        taken: list[list[tuple[float, float]]] = [[] for _ in range(TIMELINE_ROWS)]
        for i in sorted(range(len(spans)), key=lambda k: not on[k]):
            a, b = spans[i]
            for r in range(TIMELINE_ROWS):
                if not any(a < q1 + 8 and b > q0 - 8 for q0, q1 in taken[r]):
                    rows[i] = r
                    taken[r].append((a, b))
                    break
            else:
                if on[i]:
                    rows[i] = 0                            # いまの年が2つ以上重なるときも出す
        return rows

    # --- 本編の画面（立ち絵と字幕より下の層） ------------------------------
    def base(self, state: State, year=None, slide: float = 1.0, fig: float = 1.0, icon_t: float = 1.0,
             mark_t: float = 1.0) -> Image.Image:
        """year：年表の印の位置（移動の途中を描くとき）／slide：新しいメモの滑り込み（0〜1）／
        mark_t：新しい赤ペンの描き進み（0〜1）。"""
        W, H = self.W, self.H
        img = self._canvas(state.background)
        if state.reaction:                                 # つむぎの「寄り」：背景を落として集中線と大きな数字
            from . import reaction
            img = reaction.backdrop(self, img, state.reaction, fig)
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
        size = self.title_size(title, self.title_room(state))
        if size is not None or not state.reaction:          # 寄りのあいだは、立ち絵の左に収まらない題は出さない（10-09）
            size = size or TITLE_MIN
            dr.text((TITLE_X, 145 + (64 - size) // 2), title, font=self.font("serif", size, bold=True), fill=INK,
                    stroke_width=2, stroke_fill=(12, 10, 8))

        is_versus = state.figure is not None and '"type": "versus"' in state.figure
        on = None                                          # 赤ペンの乗る所（chiso/pen.py）
        if state.reaction:
            pass                                           # 寄りのあいだは、メモ・肖像・図・年表を隠す
        elif state.detail:                                 # 絵の一部を大きく（その行だけ。肖像と図は隠す）
            import json as _json
            from . import pen
            self._memo(img, state, slide)
            spec = _json.loads(state.detail)
            view = pen.draw_detail(self, img, spec)
            on = ("pic", view, pen.detail_tile(self, spec)[1], self.DETAIL_BOX)
        elif state.figure is None:
            self._memo(img, state, slide)
            if state.portrait is not None:
                self._portrait(img, state.portrait)
                self._age(img, state)
                if state.mark:
                    from .extras import portrait_box
                    pb = portrait_box(self, state.portrait)
                    on = ("pic", pb, self.image(state.portrait.image).size,
                          (pb[0], pb[1], pb[0] + pb[2], pb[1] + pb[3]))
            from . import extras
            if state.icon:
                img = extras.draw_icon(self, img, state.icon, icon_t)
            elif state.portrait is None and state.background is not None and self.config.get("center_panel", True):
                view = self._panel(img, state.background)  # 真ん中が空かないように、その場面の絵を額に入れて出す
                on = ("pic", view, self.image(state.background.image).size, self.PANEL_BOX)
            if state.bubble and state.portrait is not None:
                import json as _j
                img = extras.draw_bubble(self, img, state.portrait, _j.loads(state.bubble))
        else:                                              # 図のあいだは、メモと肖像を隠して図を大きく
            import json as _json
            from . import figures
            img = figures.draw(self, img, _json.loads(state.figure), fig)
            on = ("fig", _json.loads(state.figure))
        if state.mark and on is not None:
            img = self._marks(img, state.mark, on, mark_t)
        from . import extras
        top = extras.TERM_BOX[1]
        if state.term and not state.reaction and not is_versus:   # 用語の札は右上（肖像と図の右の空き）
            img, top = extras.draw_term(self, img, *state.term)
            top += 18
        is_map = state.figure is not None and '"type": "map"' in state.figure
        if state.place and not is_map and not is_versus and not state.reaction:   # 地図の図が出ているあいだは要らない
            img = extras.draw_minimap(self, img, state.place, top)
        dr = ImageDraw.Draw(img, "RGBA")
        if state.figure is None and not state.reaction and not state.detail:   # 図・絵の一部のあいだは年表も隠す
            self._timeline(dr, 470, W - 470, 770, state.year if year is None else year)
        if state.background is not None and state.background.credit and not is_versus:   # 左右比べは絵の出典を図が出す
            dr.text((W / 2, H - 14), f"背景：{state.background.credit}", font=self.font("serif", 18),
                    fill=DIM, anchor="ms", stroke_width=2, stroke_fill=(12, 10, 8))
        names = "　".join(f"VOICEVOX:{n}" for n in people.credit_names(self.config, self.script))
        dr.text((W - 40, 34), names, font=self.font("serif", 20), fill=DIM, anchor="rs",
                stroke_width=2, stroke_fill=(12, 10, 8))
        return img

    def title_room(self, state: State) -> float:
        """節の題を置ける幅（x 120 から、右の札・肖像の額・寄りの立ち絵の手前まで）。10-09 点検で、
        長い題が右上の用語の札・場所の地図・横長の額・寄りのヘルメットに隠れた。"""
        right = self.W - TITLE_X
        fig = state.figure or ""
        is_versus = '"type": "versus"' in fig
        is_map = '"type": "map"' in fig
        if state.reaction:
            from . import reaction
            right = min(right, reaction.left_edge(self, state.reaction, *TITLE_BAND) - 30)
            return right - TITLE_X
        if not is_versus and (state.term or (state.place and not is_map)):
            from .extras import TERM_BOX
            right = min(right, TERM_BOX[0] - 24)
        if state.portrait is not None and state.figure is None and not state.detail:
            from .extras import portrait_box
            px, py, _pw, _ph = portrait_box(self, state.portrait)
            if py - 34 < TITLE_BAND[1]:                       # 額（と「この時○歳」）が題の高さにかかる
                right = min(right, px - 34 - 24)
        return right - TITLE_X

    def title_size(self, title: str, room: float) -> int | None:
        """節の題の字の大きさ（64 から縮める）。TITLE_MIN でも room に収まらなければ None。"""
        size = 64
        while size > TITLE_MIN and self.font("serif", size, bold=True).getlength(title) > room:
            size -= 2
        return size if self.font("serif", size, bold=True).getlength(title) <= room else None

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
            if self.look("texture"):                            # 札の中にだけ紙の目（枠の線は残す）
                from . import texture
                b = 3 if current else 1
                texture.apply(img, (120 + dx + b, y + b, 120 + dx + w - b + 1, y + h - b + 1), radius=8)
                dr = ImageDraw.Draw(img, "RGBA")
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
    DETAIL_BOX = (960, 236, 1610, 830)                    # 絵の一部を大きく（年表を隠して下まで使う。字幕の名札 y≈872 の上）

    def frame(self, img: Image.Image, px: int, py: int, w: int, h: int) -> None:
        """肖像と同じ二重の金の額（台紙は暗い茶）。texture のときは台紙に紙の目。"""
        dr = ImageDraw.Draw(img, "RGBA")
        dr.rectangle([px - 18, py - 18, px + w + 18, py + h + 18], fill=(30, 24, 16, 255), outline=GOLD, width=2)
        if self.look("texture"):
            from . import texture
            texture.apply(img, (px - 16, py - 16, px + w + 17, py + h + 17))
            dr = ImageDraw.Draw(img, "RGBA")
        dr.rectangle([px - 7, py - 7, px + w + 7, py + h + 7], outline=GOLD, width=3)

    def _marks(self, img: Image.Image, mark: str, on, t: float) -> Image.Image:
        """赤ペン（chiso/pen.py）。on は ("pic", 絵の場所, 元の絵の大きさか切り抜き範囲, 描いてよい範囲) か ("fig", 図)。"""
        from . import pen
        if on[0] == "fig":
            from . import figures
            spec = on[1]
            boxes = figures.item_boxes(self, spec)
            x0, y0, x1, y1 = figures.PANEL
            area = figures.PANEL

            def locate(at):
                if isinstance(at, int):
                    return boxes.get(at - 1)
                if max(at) <= 1.0:
                    return pen.resolve(at, (x0, y0, x1 - x0, y1 - y0))
                return tuple(at) * (2 if len(at) == 2 else 1)
        else:
            _, view, src, area = on

            def locate(at):
                return None if isinstance(at, int) else pen.resolve(at, view, src)
        return pen.draw_marks(self, img, mark, locate, area, t)

    def _panel(self, img: Image.Image, pic) -> tuple[int, int, int, int]:
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
        self.frame(img, px, py, p.width, p.height)              # 肖像と同じ二重の金の額
        img.paste(p, (px, py))
        return px, py, p.width, p.height

    def _portrait(self, img: Image.Image, pic) -> None:
        from .extras import portrait_box
        dr = ImageDraw.Draw(img, "RGBA")
        px, py, pw, ph = portrait_box(self, pic)
        p = self.image(pic.image).convert("RGB").resize((pw, ph), Image.LANCZOS)
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
                  tone: str = "普通", mouth: bool = False, blink: bool = False, reaction: str | None = None) -> Image.Image:
        """立ち絵を重ねる。話している側は明るく、足もとに光、hop（0〜1）のぶん跳ねる。text は字幕。
        表情のある話者は、話しているあいだ tone の顔で mouth のとき口を開け、blink のとき目を閉じる。
        reaction（つむぎの寄り）があれば、下の小さい2人の代わりに聞き手を腰から上で大きく出す。"""
        img = base.copy()
        if reaction:
            from . import reaction as _r
            who = _r.spec_of(reaction).get("who") or "聞き"
            _r.put_figure(self, img, reaction, speaker in (who, "二人"), mouth, blink, hop)
            if text:
                self._subtitle(img, speaker, text)
            return img if self.layered else img.convert("RGB")
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
        from .figures import soft_shadow                     # 影はいつも同じ。毎コマぼかすと1コマ約0.14秒かかっていた（10-08）
        img.alpha_composite(soft_shadow(img.size, (x0 + 6, y0 + 10, x1 + 6, y1 + 10), 14, 140, 8))
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
    def recap(self, img: Image.Image, section: int, cards: tuple) -> Image.Image:
        """節の頭の「第N節 題名」の下に、前の節で出たメモの札を小さく並べて振り返る（10-07）。section は前の節の番号（1から）。"""
        if not cards:
            return img
        img = img.copy()
        dr = ImageDraw.Draw(img, "RGBA")
        hf = self.font("gothic", 22)
        cy = self.H * 0.40 + 128
        # 下に暗い帯：肖像の名札や真ん中の額の上に札が重なって読みにくかった（10-08 見本の通し確認）
        band = Image.new("L", (1, 140), 0)
        band.putdata([int(200 * min(1.0, k / 20, (139 - k) / 20)) for k in range(140)])
        img.paste((10, 8, 6), (0, int(cy - 30)), band.resize((self.W, 140)))
        dr = ImageDraw.Draw(img, "RGBA")
        dr.text((self.W / 2, cy), f"▼ ここまでの地層（第{section}節）", font=self.font("gothic", 24), fill=DIM,
                anchor="mm")
        ws = []
        for c in cards:
            size = 26
            while size > 18 and self.font("serif", size).getlength(c.body or "") > 380:
                size -= 2
            body_w = self.font("serif", size).getlength(c.body or "")
            ws.append((max(240, int(max(hf.getlength(c.head), body_w)) + 44), size))
        gap = 22
        x = self.W / 2 - (sum(w for w, _ in ws) + gap * (len(ws) - 1)) / 2
        top = cy + 26
        for c, (w, size) in zip(cards, ws):
            dr.rounded_rectangle([x, top, x + w, top + 86], radius=8, fill=(20, 16, 10, 225),
                                 outline=(150, 124, 84), width=2)
            if self.look("texture"):
                from . import texture
                texture.apply(img, (x + 2, top + 2, x + w - 1, top + 85), radius=6)
                dr = ImageDraw.Draw(img, "RGBA")
            dr.text((x + 20, top + 12), c.head, font=hf, fill=GOLD)
            if c.body:
                dr.text((x + 20, top + 44), c.body, font=self.font("serif", size), fill=INK)
            x += w + gap
        return img

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

    END_RIGHT = 1060          # 次回予告の字の右の端。右側（x 1080〜1800）は YouTube の終了画面の場所
    TEASER_SIZES = (40, 28)   # 紹介文の字の大きさ（収まるまで縮める）

    def end_cast_top(self) -> int:
        """次回予告の画面で、左下の立ち絵（ヘルメットの先）の上端の y。"""
        for who, cast in self.config["cast"].items():
            if cast.get("side", "left") == "left":
                return self.H - self.character(who).height + 10
        return self.H

    def teaser_rows(self, teaser: str, top: int, bottom: int) -> tuple[int, int, list[str]]:
        """次回予告の紹介文の (字の大きさ, 行の高さ, 行)。文ごとに改行し、1文は2行まで、
        2行目が2字以下にならないように（10-09「…小説だっ／た。」の「た。」だけが落ちて立ち絵に重なった）。
        収まるまで字を縮め、行は top〜bottom に入るだけにする。"""
        import re
        sents = re.findall(r"[^。]+。?", teaser) or [teaser]
        width = self.END_RIGHT - 120
        big, small = self.TEASER_SIZES
        for size in range(big, small - 1, -2):
            f = self.font("serif", size)
            rows, ok = [], True
            for sent in sents:
                r = wrap(sent, f, width)
                if len(r) == 2 and len(r[-1]) <= 2:
                    r = wrap_balanced(sent, f, width)             # 最後の1・2字だけが落ちるなら、半分ずつに割り直す
                if len(r) > 2 or (len(r) == 2 and len(r[-1]) <= 2):
                    ok = False
                    break
                rows += r
            lh = int(size * 1.4)
            if ok and top + lh * (len(rows) - 1) + size * 1.25 <= bottom:
                return size, lh, rows
        f = self.font("serif", small)
        rows = [r for sent in sents for r in wrap_balanced(sent, f, width)]
        lh = int(small * 1.4)
        n = max(1, int((bottom - top - small * 1.25) // lh) + 1)
        return small, lh, rows[:n]

    def end_card(self, background) -> Image.Image:
        """次回予告とお礼。右側は YouTube の終了画面（動画・登録ボタン）を置く場所として空ける。
        字は左下の立ち絵（剣崎のヘルメット）より上に収める（10-09）。"""
        nxt = getattr(self.script, "next", {}) or {}
        img = self._canvas(background)
        img.alpha_composite(Image.new("RGBA", img.size, (8, 6, 4, 150)))
        dr = ImageDraw.Draw(img, "RGBA")
        x = 120
        dr.text((x, 100), "ご視聴ありがとうございました", font=self.font("gothic", 34), fill=DIM)
        if nxt:
            dr.rounded_rectangle([x, 170, x + 190, 230], radius=10, fill=(176, 40, 40))
            dr.text((x + 95, 200), "次回予告", font=self.font("gothic", 34), fill=(255, 255, 255), anchor="mm")
            series = nxt.get("series", self.script.series)      # 次の回が別のシリーズなら next.series で（"" で出さない）
            if series:
                dr.text((x, 260), series, font=self.font("gothic", 30), fill=GOLD)
            size = 76
            while size > 48 and self.font("serif", size, bold=True).getlength(nxt.get("title", "")) > self.END_RIGHT - x:
                size -= 4
            dr.text((x, 305), nxt.get("title", ""), font=self.font("serif", size, bold=True), fill=INK,
                    stroke_width=3, stroke_fill=(12, 10, 8))
            top = 305 + size + 34
            fs, lh, rows = self.teaser_rows(nxt.get("teaser", ""), top, self.end_cast_top() - 14)
            for k, row in enumerate(rows):
                dr.text((x, top + lh * k), row, font=self.font("serif", fs), fill=INK)
        # 右側（x 1080〜1800, y 200〜605）は、YouTube の終了画面（次の動画・登録ボタン）を置くために空けておく
        return img


def state_of(line) -> State:
    return State(line.section, line.background, line.portrait, line.card, line.year, line.speaker,
                 getattr(line, "memo", ()), getattr(line, "figure", None), getattr(line, "bubble", None),
                 getattr(line, "icon", None), getattr(line, "term", None), getattr(line, "place", None),
                 getattr(line, "reaction", None), getattr(line, "detail", None), getattr(line, "mark", None))


RECAP_MAX = 3


def recap_cards(script, section: int) -> tuple:
    """節の頭で振り返る札：前の節で出たメモの札から、最初・真ん中・最後のように散らして3枚まで。
    最初の節の頭（間が無い）とまとめの節の頭、札が2枚に満たない節は出さない。"""
    if section <= 0 or section >= len(script.sections) - 1:
        return ()
    cards = []
    for l in script.lines:
        if l.section == section - 1 and l.card is not None and l.card not in cards:
            cards.append(l.card)
    if len(cards) < 2:
        return ()
    if len(cards) > RECAP_MAX:
        n = len(cards)
        cards = [cards[round(k * (n - 1) / (RECAP_MAX - 1))] for k in range(RECAP_MAX)]
    return tuple(cards)


def recap_sections(config: dict, script) -> set[int]:
    """「ここまでの地層」の札が出る節の番号。その節の頭は間を長くとる（chiso/voice.py の GAP_RECAP）。"""
    if not look(config, script, "recap"):
        return set()
    return {k for k in range(len(script.sections)) if recap_cards(script, k)}


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
    src += json.dumps(getattr(painter.script, "look", {}) or {}, sort_keys=True).encode("utf-8")
    for extra in ("pen.py", "texture.py"):
        try:
            src += (Path(__file__).parent / extra).read_bytes()
        except OSError:
            pass
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

    import threading
    from collections import OrderedDict
    _bases: OrderedDict = OrderedDict()
    _lock = threading.Lock()

    def base_of(s, **kw):
        """painter.base の控え（10-08）。口パク・まばたき・字幕のかたまりごとにコマが分かれても、下の層は同じなので
        1回だけ描く。描いた画像は with_cast・pop・blend が写してから使う（書き換えない）。"""
        key = (s, tuple(sorted(kw.items())))
        with _lock:
            if key in _bases:
                _bases.move_to_end(key)
                return _bases[key]
        img = painter.base(s, **kw)
        with _lock:
            _bases[key] = img
            while len(_bases) > BASE_CACHE:
                _bases.popitem(last=False)
        return img

    def _rk(s) -> dict:                  # つむぎの寄り（本編だけ。ショートはいつもの画面）
        return {"reaction": s.reaction} if (special and s.reaction) else {}

    def _mk(t) -> dict:                  # 赤ペンの描き進み（ショートの base は受け取らない）
        return {"mark_t": t} if (special and t < 1.0) else {}

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
                return painter.with_cast(base_of(s), s.speaker, 0, "", "聞く", **_rk(s))
            if new_section:
                rc = recap_cards(painter.script, state.section) if painter.look("recap") else ()
                more = ("recap", rc) if rc else ()

                def head(s=state, t=title, rc=rc):
                    im = painter.overlay_title(base_lead(s), f"第{s.section + 1}節", t)
                    return painter.recap(im, s.section, rc) if rc else im
                n_w = min(WIPE_FRAMES, int(lead * fps) - 1)
                for k in range(1, n_w + 1):
                    emit(frame_dir / _name(salt, "wipe", state, k, n_w, *more),
                         lambda k=k, n=n_w, head=head: painter.wipe(head(), k / (n + 1)), 1 / fps)
                emit(frame_dir / _name(salt, "sec", state, title, *more), head, lead - n_w / fps)
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
            (prev_state.background, prev_state.portrait, prev_state.memo, prev_state.year, prev_state.figure,
             prev_state.detail)
            != (state.background, state.portrait, state.memo, state.year, state.figure, state.detail))
        surprised = special and line.tone == "驚き" and not state.reaction   # 寄りは集中線を自分で持つ
        # 強調語の飛び出しは 10-04「4は不要」で外した（config の pop: true で戻せる）
        words = ([w for w in (plain(x) for x in __import__("re").findall(r"《(.+?)》", line.text))]
                 if special and painter.config.get("pop") else [])
        # 図が出る・図が1項目増える（upto。script.parse が grow_from を付けるので、新しい項目だけが描き進む）・
        # つむぎの寄りが出る（数字が弾む）。どれも FIG_FRAMES のあいだ t=0→1
        fig_new = special and state.figure is not None and (prev_state is None or prev_state.figure != state.figure)
        fig_new = fig_new or (special and state.reaction is not None
                              and (prev_state is None or prev_state.reaction != state.reaction))
        icon_new = special and state.icon is not None and (prev_state is None or prev_state.icon != state.icon)
        # 赤ペン：新しく足した印だけを、行の頭で1つずつ描き進める（chiso/pen.py）
        from .pen import MARK_FRAMES, spec_of
        m_items, m_from = spec_of(state.mark)
        n_mark = MARK_FRAMES * (len(m_items) - m_from) if (special and state.mark and (
            prev_state is None or prev_state.mark != state.mark)) else 0
        # 図が描き進むのと同じ行で印を足すと、伸びきる前の棒に取り消し線が引かれた（10-08 見本の通し確認）。図が出終わってから描く
        m_wait = FIG_FRAMES if (n_mark and fig_new) else 0
        n_fx = max(n_hop, TRANS_FRAMES if changed else 0, SHAKE_FRAMES if surprised else 0,
                   POP_FRAMES if words else 0, FIG_FRAMES if fig_new else 0, ICON_FRAMES if icon_new else 0,
                   m_wait + n_mark)
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
            mark_t = (max(0, k - m_wait) / (n_mark + 1)) if (n_mark and k and k <= m_wait + n_mark) else 1.0

            def make(s=state, ps=prev_state, text=text, hop_k=hop_k, n_hop=n_hop, tr=tr, shake_k=shake_k,
                     pop_t=pop_t, mouth_open=mouth_open, blink=blink, tone=line.tone, opening=opening,
                     words=tuple(words), side=side, fig_t=fig_t, icon_t=icon_t, mark_t=mark_t):
                hop_t = hop_k / (n_hop + 1) if hop_k else 0.0
                if tr < 1.0 and ps is not None:
                    year = s.year
                    if ps.year is not None and s.year is not None:
                        year = ps.year + (s.year - ps.year) * _ease(tr)
                    slide = tr if (s.memo and s.memo != ps.memo) else 1.0
                    base = base_of(s, year=year, slide=slide, fig=fig_t, icon_t=icon_t, **_mk(mark_t))
                    from .figures import base_key       # 同じ図が1項目増えただけなら溶け合わせない（前の項目は動かさない）
                    changed_pic = (((ps.background, ps.portrait, base_key(ps.figure), ps.icon, ps.detail)
                                    != (s.background, s.portrait, base_key(s.figure), s.icon, s.detail)) if painter.layered
                                   else (ps.background, ps.portrait, ps.detail) != (s.background, s.portrait, s.detail))
                    if changed_pic:
                        base = Image.blend(base_of(ps), base, _ease(tr))
                else:
                    base = base_of(s, fig=fig_t, icon_t=icon_t, **_mk(mark_t))
                if pop_t is not None:
                    base = painter.pop(base, words[0], pop_t, s.speaker)
                if opening:                         # 冒頭の題は字幕と2人の下に敷く（10-08「字幕が見えない」）
                    base = painter.overlay_title(base, painter.script.series, painter.script.question, 0.8).convert("RGBA")
                im = painter.with_cast(base, s.speaker, hop_t, text, tone, mouth_open, blink, **_rk(s))
                if shake_k:
                    im = painter.burst(im, side, shake_k / (SHAKE_FRAMES + 1))
                    im = painter.shake(im, shake_k)
                return im

            key = ("f2", state, prev_state if tr < 1.0 else None, round(tr, 3), hop_k, n_hop, text, shake_k,
                   None if pop_t is None else (words[0], round(pop_t, 3)), round(fig_t, 3), round(icon_t, 3),
                   *((round(mark_t, 3),) if state.mark else ()),
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
    # （10-08 に PNG を書くのを別プロセスに分けても測って速くならなかったので、スレッドのまま）
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
