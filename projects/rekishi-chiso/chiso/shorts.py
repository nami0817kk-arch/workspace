"""1本の本編から、何本もショート（縦長 1080x1920）を切り出す。

台本で `short: s1` を付けた行だけを集め、間を詰め直して1本にする。
ショートは音を消して見る人が多いので、せりふを画面に出す（本編は出さない）。
"""
from __future__ import annotations


from PIL import Image, ImageDraw

from .render import DIM, GOLD, INK, Painter, State
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

# --- 頭の大きな問いと、ループしやすい終わり（10-08 ユーザー指示）-------------------------------
# ショートは最初の2秒で何の話か分からないと流され、最後まで見た人は頭にそのまま戻る（ループ）。
# hook_intro：頭の約2秒、画面の上半分に short の hook（無ければ title）を特大で出し、いつもの題の位置へ縮める。
# loop：「続きは本編で」を短くし、最後に頭と同じ画（大きな問い）を1秒置く。最後のコマ＝最初のコマなので、
#       ループした瞬間に問いがそのまま続いて見える。音は足さない（最後は無音のまま）。
# どちらも config.yaml の short.hook_intro / short.loop で切れる（書かなければ入）。
HOOK_HOLD = 1.8            # 特大のまま見せる秒数
HOOK_SHRINK = 0.4          # いつもの題の位置へ縮む秒数（合わせて約2秒）
HOOK_SIZES = (132, 118, 104, 92)   # 長い問いは字を小さくして3行に収める
HOOK_MAX_ROWS = 3
LOOP_END_SECONDS = 2.0     # loop のときの「続きは本編で」
LOOP_TAIL = 1.0            # loop のときに最後に置く、頭と同じ画
TITLE_SIZE, TITLE_TOP, TITLE_STEP = 76, 150, 96   # いつもの題（base と同じ値）


def options(config: dict) -> tuple[bool, bool]:
    """(hook_intro, loop)。config.yaml の short: に書けば切れる。"""
    sz = config.get("short", {}) or {}
    return bool(sz.get("hook_intro", True)), bool(sz.get("loop", True))


def hook_text(meta: dict) -> str:
    """頭に大きく出す問い。台本の shorts.sN.hook、無ければ title（「／」で改行）。"""
    return str(meta.get("hook") or meta.get("title") or "").strip()


def hook_size(text: str, font_of, width: int) -> int:
    """問いの字の大きさ。「／」の区切りがそれぞれ1行に収まる最大（「た」だけの行を作らない）。
    どれでも収まらなければ、HOOK_MAX_ROWS 行に収まる最大。"""
    parts = len(text.split("／"))
    for size in HOOK_SIZES:
        if len(_wrap(text, font_of(size), width)) == parts:
            return size
    for size in HOOK_SIZES:
        if len(_wrap(text, font_of(size), width)) <= HOOK_MAX_ROWS:
            return size
    return HOOK_SIZES[-1]


def end_seconds(loop: bool) -> float:
    """最後の「続きは本編で」と、ループ用の頭の画を合わせた、声の後ろの秒数。"""
    return (LOOP_END_SECONDS + LOOP_TAIL) if loop else END_SECONDS


def _ease(t: float) -> float:
    return t * t * (3 - 2 * t)


def intro_cuts(items: list, fps: int, hold: float = HOOK_HOLD, shrink: float = HOOK_SHRINK) -> list:
    """頭の (元の画像, 秒数, 縮みの進み t) の並びと、その後ろの元の並び。t=0 は特大、1 に近いほどいつもの題。

    元の並びの区切りを保ったまま、hold 秒までは t=0、そこから shrink 秒は1コマずつ t を進める。"""
    n = max(1, int(round(shrink * fps)))
    cuts = {0.0, hold} | {hold + k / fps for k in range(1, n + 1)}
    t, bounds = 0.0, []
    for path, dur in items:
        bounds.append((t, t + dur, path))
        t += dur
    end = min(hold + n / fps, t)
    cuts |= {a for a, _b, _p in bounds if a < end}
    cuts = sorted(c for c in cuts if c <= end)
    head = []
    for a, b in zip(cuts, cuts[1:]):
        if b - a < 1e-6:
            continue
        src = next(p for x, y, p in bounds if x <= a + 1e-9 < y)
        k = 0 if a < hold - 1e-9 else int(round((a - hold) * fps)) + 1
        head.append((src, b - a, k / (n + 1)))
    tail = []
    for x, y, p in bounds:
        if y <= end + 1e-9:
            continue
        tail.append((p, y - max(x, end)))
    return head, tail

TEXT_SIZES = (54, 48, 42)   # 長いせりふは字を小さくして全部入れる
TEXT_MAX_ROWS = 5


class ShortPainter(Painter):
    def __init__(self, config, script, assets, title: str):
        sz = config["short"]
        super().__init__(config, script, assets, (sz["width"], sz["height"]))
        self.title = title

    def base(self, state: State, year=None, slide: float = 1.0, fig: float = 1.0, icon_t: float = 1.0) -> Image.Image:
        """縦長の画面。引数は本編の Painter.base と同じ形にそろえる（10-04、そろっていなくて止まった）。"""
        W = self.W
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

    def hook_overlay(self, img: Image.Image, text: str, t: float = 0.0) -> Image.Image:
        """頭の大きな問い。t=0 で上半分に特大、t→1 でいつもの題の大きさと位置へ縮み、暗い幕は消える。"""
        W, H = self.W, self.H
        e = _ease(min(1.0, max(0.0, t)))
        img = img.convert("RGBA")
        # 上半分を暗くして、問いだけを読ませる（下の端はぼかす）
        veil = Image.new("L", (W, H), 0)
        vd = ImageDraw.Draw(veil)
        edge = int(H * 0.56)
        vd.rectangle([0, 0, W, edge - 160], fill=255)
        for i in range(160):
            vd.line([(0, edge - 160 + i), (W, edge - 160 + i)], fill=int(255 * (1 - i / 160)))
        a = 255 * (1 - e)                            # 幕は不透明（下のいつもの題を透かさない）。縮みながら溶かす
        img.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (W, H), (10, 8, 6)).split(),
                                                 veil.point(lambda v: int(v * a / 255)))))
        big = hook_size(text, lambda n: self.font("serif", n, bold=True), W - 100)
        size = round(big + (TITLE_SIZE - big) * e)
        f = self.font("serif", size, bold=True)
        rows = _wrap(text, f, W - (100 + 40 * e))
        step = big * 1.22 + (TITLE_STEP - big * 1.22) * e
        top_big = int(H * 0.27 - step * len(rows) / 2)
        top = top_big + (TITLE_TOP - top_big) * e
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        sw = round(6 * (1 - e)) + 1
        for i, row in enumerate(rows):
            ld.text((W / 2, top + step * i), row, font=f, fill=INK, anchor="mt", stroke_width=sw,
                    stroke_fill=(12, 10, 8))
        if e < 0.5:                                  # 問いの下に金の細い線（縮み始めたら消す）
            y = top + step * len(rows) + 24
            ld.line([(W / 2 - 120, y), (W / 2 + 120, y)], fill=GOLD + (int(255 * (1 - 2 * e)),), width=5)
        if e > 0:                                    # 縮みながら溶けて、いつもの題に入れ替わる
            layer.putalpha(layer.getchannel("A").point(lambda v: int(v * (1 - e))))
        img.alpha_composite(layer)
        return img.convert("RGB")

    def end_card(self, background) -> Image.Image:
        """本編へ誘う締めの画面。本編の題（問いの部分）と、チャンネル名。"""
        W = self.W
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


def finish(items: list, painter, text: str, frame_dir, fps: int, loop: bool, workers: int = 8) -> list:
    """render.frames の並びに、頭の大きな問い（text が空でなければ）とループ用の最後の画を足す。

    頭は元のコマの上に問いを重ねた画像に差し替える（長さは変えない）。loop なら最後に頭の1枚目を LOOP_TAIL 秒。"""
    import hashlib
    from concurrent.futures import ThreadPoolExecutor
    from pathlib import Path

    items = list(items)
    if text and items:
        frame_dir = Path(frame_dir)
        frame_dir.mkdir(parents=True, exist_ok=True)
        salt = hashlib.sha1(Path(__file__).read_bytes()).hexdigest()[:8]
        head, tail = intro_cuts(items, fps)
        todo, new = {}, []
        for src, dur, t in head:
            h = hashlib.sha1(repr((salt, Path(src).name, text, round(t, 3), painter.W, painter.H)).encode("utf-8"))
            dst = frame_dir / f"hook_{h.hexdigest()[:14]}.png"
            if not dst.exists():
                todo[dst] = (src, t)
            new.append((dst, dur))
        items = new + tail

        def run(kv):
            dst, (src, t) = kv
            with Image.open(src) as im:
                painter.hook_overlay(im.convert("RGB"), text, t).save(dst, compress_level=1)
        with ThreadPoolExecutor(max_workers=workers) as ex:
            list(ex.map(run, todo.items()))
    if loop and items:
        items.append((items[0][0], LOOP_TAIL))
    return items


class _Landscape:
    """図を横長（1920x1080）の座標で描くための代役。字形・絵・素材はショートの Painter のものを使う。"""
    def __init__(self, painter):
        self._p = painter
        self.W, self.H = 1920, 1080

    def __getattr__(self, name):
        return getattr(self._p, name)

