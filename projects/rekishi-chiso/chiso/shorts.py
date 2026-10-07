"""1本の本編から、何本もショート（縦長 1080x1920）を切り出す。

台本で `short: s1` を付けた行だけを集め、間を詰め直して1本にする。
ショートは音を消して見る人が多いので、せりふを画面に出す（本編は出さない）。
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw

from .render import DIM, GOLD, INK, LISTENER_DIM, Painter, State
from . import people
from .subs import emphasis_mask


NO_HEAD = "、。，．・！？!?」』）)ーっゃゅょッャュョ…"   # 行の頭に来てはいけない文字


def _wrap(text: str, font, width: int) -> list[str]:
    """幅で折り返す。「／」は必ず改行。句読点や閉じかっこは行の頭に置かず、前の行に残す。"""
    out: list[str] = []
    for para in text.split("／"):
        cur = ""
        for ch in para:
            if font.getlength(cur + ch) > width and cur and ch not in NO_HEAD:
                out.append(cur)
                cur = ch
            else:
                cur += ch
        if cur:
            out.append(cur)
    return out


END_SECONDS = 3.5   # 最後の「続きは本編で」（10-04「視聴者誘導用のショート」。声は入れない）
TEXT_SIZES = (54, 48, 42)   # 長いせりふは字を小さくして全部入れる
TEXT_MAX_ROWS = 5


class ShortPainter(Painter):
    def __init__(self, config, script, assets, title: str):
        sz = config["short"]
        super().__init__(config, script, assets, (sz["width"], sz["height"]))
        self.title = title
        self.current_text = ""

    def base(self, state: State, year=None, slide: float = 1.0, fig: float = 1.0, icon_t: float = 1.0) -> Image.Image:
        """縦長の画面。引数は本編の Painter.base と同じ形にそろえる（10-04、そろっていなくて止まった）。"""
        W, H = self.W, self.H
        img = self._background(state.background)
        dr = ImageDraw.Draw(img, "RGBA")
        # 上：ショートの題
        f = self.font("serif", 76, bold=True)
        y = 150
        for row in _wrap(self.title, f, W - 140):
            dr.text((W / 2, y), row, font=f, fill=INK, anchor="mt")
            y += 96
        dr.text((W / 2, y + 10), "歴史の地層", font=self.font("gothic", 34), fill=GOLD, anchor="mt")
        # 中：図（お金の札・グラフ・地図など）があれば図、なければ肖像か年号の札
        if state.figure is not None:
            import json as _json
            from . import figures
            canvas = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
            fake = _Landscape(self)
            canvas = figures.draw(fake, canvas, _json.loads(state.figure), fig)
            x0, y0, x1, y1 = figures.PANEL
            if '"type": "versus"' in state.figure:      # 左右の全画面比べは、画面ぜんぶを縮めて出す
                x0, y0, x1, y1 = 12, 12, 1920 - 22, 1080 - 26
            panel = canvas.crop((x0 - 12, y0 - 12, x1 + 22, y1 + 26))
            s = (W - 60) / panel.width
            panel = panel.resize((int(panel.width * s), int(panel.height * s)), Image.LANCZOS)
            img = img.convert("RGBA")
            img.alpha_composite(panel, ((W - panel.width) // 2, y + 90))
            dr = ImageDraw.Draw(img, "RGBA")
        elif state.portrait is not None:
            p = self.image(state.portrait.image).convert("RGB")
            ph = 540                                # 字幕の箱（y=1080〜）に重ねない
            p = p.resize((int(p.width * ph / p.height), ph), Image.LANCZOS)
            px, py = (W - p.width) // 2, y + 90
            dr.rectangle([px - 12, py - 12, px + p.width + 12, py + ph + 12], fill=(30, 24, 16, 255),
                         outline=GOLD, width=3)
            img.paste(p, (px, py))
            dr = ImageDraw.Draw(img, "RGBA")
        elif state.card is not None:
            dr.rounded_rectangle([90, y + 160, W - 90, y + 360], radius=14, fill=(20, 16, 10, 200), outline=GOLD, width=3)
            dr.text((W / 2, y + 200), state.card.head, font=self.font("gothic", 48), fill=GOLD, anchor="mt")
            if state.card.body:
                dr.text((W / 2, y + 275), state.card.body, font=self.font("serif", 52), fill=INK, anchor="mt")
        names = "　".join(f"VOICEVOX:{n}" for n in people.credit_names(self.config, self.script))
        dr.text((40, 40), names, font=self.font("serif", 24), fill=DIM, anchor="lt")
        return img.convert("RGBA")       # with_cast が立ち絵の光を重ねるので RGBA で返す

    def end_card(self, background) -> Image.Image:
        """本編へ誘う締めの画面。本編の題（問いの部分）と、チャンネル名。"""
        W, H = self.W, self.H
        img = self._background(background).convert("RGBA")
        img.alpha_composite(Image.new("RGBA", img.size, (8, 6, 4, 170)))
        dr = ImageDraw.Draw(img, "RGBA")
        dr.rounded_rectangle([W / 2 - 230, 300, W / 2 + 230, 400], radius=16, fill=(176, 40, 40))
        dr.text((W / 2, 350), "続きは本編で", font=self.font("gothic", 56), fill=(255, 255, 255), anchor="mm")
        f = self.font("serif", 72, bold=True)
        y = 500
        for row in _wrap(self.script.question, f, W - 160):
            dr.text((W / 2, y), row, font=f, fill=INK, anchor="mt", stroke_width=3, stroke_fill=(12, 10, 8))
            y += 96
        dr.text((W / 2, y + 40), "約30分・聞き流しで", font=self.font("gothic", 40), fill=DIM, anchor="mt")
        dr.text((W / 2, y + 150), "歴史の地層", font=self.font("serif", 64, bold=True), fill=GOLD, anchor="mt")
        dr.text((W / 2, y + 240), "チャンネルの動画一覧から", font=self.font("gothic", 36), fill=DIM, anchor="mt")
        return img

    def character(self, speaker: str) -> Image.Image:
        key = ("char-short", speaker)
        if key not in self._images:
            cast = self.config["cast"][speaker]
            im = self.image(cast["image"])
            im = im.crop(im.getbbox())
            h = int(cast.get("height", 1150) * 1.05)
            im = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
            self._images[key] = im.crop((0, 0, im.width, int(h * cast.get("bust", 0.4))))
        return self._images[key]

    def with_cast(self, base: Image.Image, speaker: str, hop: float = 0.0, text: str = "",
                  tone: str = "普通", mouth: bool = False, blink: bool = False, reaction=None) -> Image.Image:
        # つむぎの寄り（reaction）はショートでは出さない（縦長の画面はいつもの形のまま）
        img = super().with_cast(base, speaker, hop, "", tone, mouth, blink).convert("RGBA")
        if text:
            dr = ImageDraw.Draw(img, "RGBA")
            body, mask = emphasis_mask(text)
            for size in TEXT_SIZES:
                f = self.font("serif", size, bold=True)
                rows = _wrap(body, f, self.W - 160)
                if len(rows) <= TEXT_MAX_ROWS:
                    break
            step = int(size * 1.33)
            top = 1080 - max(0, len(rows) - 3) * step   # 4行以上は上に伸ばして、立ち絵に重ねない
            box_h = 40 + step * len(rows)
            dr.rounded_rectangle([60, top, self.W - 60, top + box_h], radius=18, fill=(250, 246, 236, 235),
                                 outline=GOLD, width=4)
            name = people.label(self.config, speaker)
            dr.text((90, top - 14), name, font=self.font("gothic", 34), fill=GOLD, anchor="ls")
            pos = 0
            for i, row in enumerate(rows):
                start = body.find(row, pos)
                self.draw_rich(dr, self.W / 2, top + 30 + step * i, row, mask[start:start + len(row)], f,
                               (40, 30, 20))
                pos = start + len(row)
        return img.convert("RGB")


class _Landscape:
    """図を横長（1920x1080）の座標で描くための代役。字形・絵・素材はショートの Painter のものを使う。"""
    def __init__(self, painter):
        self._p = painter
        self.W, self.H = 1920, 1080

    def __getattr__(self, name):
        return getattr(self._p, name)


def seconds_ok(total: float, limit: float) -> bool:
    return total <= limit + 1e-6 and not math.isnan(total)
