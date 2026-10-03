"""サムネイル（1280x720）。2026-10-04 にユーザーと決めた形（「融合3」）を、台本の thumbnail 欄から作る。

    thumbnail:
      image: paintings/marie_chemise_1783.jpg
      crop: [60, 200, 1740, 1145]     # 絵のどこを使うか（16:9 に近い範囲。顔がやや左の中央）
      focus: [150, 60, 1000, 760]     # 明るく残す範囲（サムネイルの座標）。外側は少し落とす
      hook: 「パンがなければ…」          # 上：通説
      stamp: 言ってない！                # 上：通説を打ち消す赤い判子
      name: マリー・アントワネット          # 下：小さな赤い名前札
      lead: 本当に                       # 下：白
      main: 悪女？                       # 下：特大の黄

決まり（人気の歴史動画の型から）：絵は全面に敷く／文字は上下の2〜3かたまり、1語だけ特大の黄／
右下に反応する2人（剣崎雌雄が後ろ、驚き顔のつむぎが手前）／シリーズ名・チャンネル名の札は入れない。
目印は下端の細い地層の帯だけ。右下は YouTube の再生時間の表示が重なるので、文字を置かない。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1280, 720
YEL = (255, 214, 40)
RED = (205, 30, 40)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
STRATA = [(70, 58, 44), (92, 74, 52), (120, 96, 62), (150, 118, 74), (110, 52, 44)]
TIME_BADGE = (W - 170, H - 70, W, H)     # 再生時間の表示が重なる範囲（文字を置かない）


def _font(path: str, size: int):
    return ImageFont.truetype(path, size)


def _fit(path: str, text: str, size: int, width: int, minimum: int = 40):
    """幅に収まるまで字を小さくする。"""
    f = _font(path, size)
    while size > minimum and f.getlength(text) > width:
        size -= 4
        f = _font(path, size)
    return f


def _text(dr, xy, s, f, fill, stroke, anchor="la"):
    dr.text(xy, s, font=f, fill=fill, stroke_width=stroke, stroke_fill=BLACK, anchor=anchor)


def _stamp(text: str, gothic: str, size: int = 70, angle: float = -8) -> Image.Image:
    f = _font(gothic, size)
    w, h = int(f.getlength(text)) + 90, int(size * 1.6)
    st = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    sd.rounded_rectangle([8, 8, w - 8, h - 8], radius=20, outline=RED, width=12, fill=(255, 255, 255, 235))
    sd.text((w // 2, h // 2 + 4), text, font=f, fill=RED, anchor="mm")
    return st.rotate(angle, expand=True, resample=Image.BICUBIC)


def _bust(path: Path, height: int, ratio: float) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getbbox())
    im = im.crop((0, 0, im.width, int(im.height * ratio)))
    return im.resize((int(im.width * height / im.height), height), Image.LANCZOS)


def make(script, config: dict, assets: Path) -> Image.Image:
    t = script.thumbnail
    gothic = config["fonts"]["gothic"]
    src = Image.open(assets / t["image"]).convert("RGB")
    img = src.crop(tuple(t["crop"])).resize((W, H), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.12)
    img = ImageEnhance.Color(img).enhance(1.25)
    img = ImageEnhance.Brightness(img).enhance(1.12)
    focus = Image.new("L", (W, H), 0)
    ImageDraw.Draw(focus).ellipse(t.get("focus", [150, 60, 1000, 760]), fill=255)
    img = Image.composite(img, ImageEnhance.Brightness(img).enhance(0.6), focus.filter(ImageFilter.GaussianBlur(160)))
    top = Image.linear_gradient("L").resize((W, 230)).transpose(Image.FLIP_TOP_BOTTOM)
    img.paste((8, 6, 4), (0, 0, W, 230), top.point(lambda v: int(v * 0.85)))
    bottom = Image.linear_gradient("L").resize((W, 300))
    img.paste((8, 6, 4), (0, H - 300, W, H), bottom.point(lambda v: int(v * 0.92)))
    dr = ImageDraw.Draw(img)

    # 上：通説＋判子
    stamp = _stamp(t["stamp"], gothic) if t.get("stamp") else None
    hook_w = W - 60 - (stamp.width if stamp else 0)
    if t.get("hook"):
        _text(dr, (36, 88), t["hook"], _fit(gothic, t["hook"], 76, hook_w), WHITE, 9, "lm")
    if stamp:
        img.paste(stamp, (W - stamp.width - 24, 22), stamp)
        dr = ImageDraw.Draw(img)

    # 下：名前札＋問い
    if t.get("name"):
        nf = _font(gothic, 40)
        nw = nf.getlength(t["name"])
        dr.rectangle([36, 462, 36 + nw + 36, 520], fill=RED)
        dr.text((54, 491), t["name"], font=nf, fill=WHITE, anchor="lm")
    x = 30
    if t.get("lead"):
        lf = _font(gothic, 96)
        _text(dr, (x, 612), t["lead"], lf, WHITE, 10, "lm")
        x += int(lf.getlength(t["lead"])) + 12
    if t.get("main"):
        mf = _fit(gothic, t["main"], 168, 820 - x, 96)    # 右下の2人と再生時間の表示にかからない幅
        _text(dr, (x, 612), t["main"], mf, YEL, 15, "lm")

    # 右下：剣崎雌雄（後ろ）と驚き顔のつむぎ（手前）
    chars = assets / "characters"
    if (chars / "kenzaki_helmet.png").exists():
        k = _bust(chars / "kenzaki_helmet.png", 340, 0.33)
        img.paste(k, (W - k.width - 175, H - k.height + 10), k)
    surprised = chars / "tsumugi_surprised_helmet.png"
    tsu = _bust(surprised if surprised.exists() else chars / "tsumugi_helmet.png", 320, 0.36)
    img.paste(tsu, (W - tsu.width + 25, H - tsu.height - 4), tsu)

    dr = ImageDraw.Draw(img)
    for i, c in enumerate(STRATA):                        # 目印：下端の細い地層
        dr.rectangle([0, H - 15 + i * 3, W, H - 12 + i * 3], fill=c)
    return img


def preview(img: Image.Image) -> Image.Image:
    """一覧で見える大きさ（横 320px）と、その2倍を並べた確認用。"""
    small = img.resize((320, 180), Image.LANCZOS)
    mid = img.resize((640, 360), Image.LANCZOS)
    out = Image.new("RGB", (640 + 20 + 320, 360), (240, 240, 240))
    out.paste(mid, (0, 0))
    out.paste(small, (660, 90))
    return out
