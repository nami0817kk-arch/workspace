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

3案（10-07。YouTube Studio の「テストと比較」に1本3枚まで載せる）は `thumb --variants`：
    a … 今の形（上の thumbnail: のとおり）
    b … 絵を人物の顔に寄せる＋文字は名前と main だけ（2人も出さない。顔が主役）
    c … 上の一言を大きな数字か短い語に（判子なし）、下は赤い帯に白抜き（色の配分を変える）
台本で上書きできる：
    thumbnail:
      variants:
        b: {crop: [左, 上, 右, 下]}         # 無ければ focus の上のほう（顔のあたり）に自動で寄せる
        c: {top: 約168cm, main: 小男？}     # top が無ければ判子→見出しの数字→見出しの順に自動で選ぶ
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1280, 720
YEL = (255, 214, 40)
RED = (205, 30, 40)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
STRATA = [(70, 58, 44), (92, 74, 52), (120, 96, 62), (150, 118, 74), (110, 52, 44)]
TIME_BADGE = (W - 170, H - 70, W, H)     # 再生時間の表示が重なる範囲（文字を置かない）


def _font(path: str | None, size: int):
    if not path:                       # テスト（CI に日本語フォントが無い）は内蔵のフォントで
        return ImageFont.load_default(size)
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


DEFAULT_FOCUS = [150, 60, 1000, 760]
VARIANTS = ("a", "b", "c")
FACE_AT = (0.64, 0.42)        # b：顔の中心をサムネイルのどこに置くか（左に名前と main を置くので、やや右）
FACE_ZOOM = 0.62              # b：focus の高さの何割を画面の高さにするか（小さいほど寄る）
MIN_CROP_H = 360              # b：寄りすぎて粗くならないよう、元の絵で最低この高さは使う
TOP_WORD_MAX = 8              # c：上の一言に使う字数の上限（これより長い判子・見出しは数字だけ抜く）
_NUM = re.compile(r"(?:約|およそ)?[0-9０-９][0-9０-９,，.．]*[^\s！!？?、。」』（）()]{0,3}")


FACE_IN_A = (0.485, 0.39)     # a の切り方で顔があるおおよその所（「顔はやや左の中央」の決まり。6本の実測の平均）


def face_crop(crop, focus, src_size) -> list[int]:
    """b の絵の切り方：a の切り方で顔があるはずの所（focus の中に寄せる）を中心に、focus の高さの6割まで寄せる。
    元の絵の座標で返す。顔の検出は使わない（絵画・古写真では外れが多かった）。"""
    cx0, cy0, cx1, cy1 = crop
    sx, sy = (cx1 - cx0) / W, (cy1 - cy0) / H
    fx0, fy0, fx1, fy1 = focus
    fx0, fy0, fx1, fy1 = max(fx0, 0), max(fy0, 0), min(fx1, W), min(fy1, H)
    ax = min(max(W * FACE_IN_A[0], fx0), fx1)
    ay = min(max(H * FACE_IN_A[1], fy0), fy1)
    face_x, face_y = cx0 + ax * sx, cy0 + ay * sy
    sw, sh = src_size
    h = max((fy1 - fy0) * sy * FACE_ZOOM, MIN_CROP_H)
    h = min(h, sh, sw * H / W)
    w = h * W / H
    x0 = min(max(face_x - FACE_AT[0] * w, 0), sw - w)
    y0 = min(max(face_y - FACE_AT[1] * h, 0), sh - h)
    return [round(x0), round(y0), round(x0 + w), round(y0 + h)]


def top_word(t: dict) -> str:
    """c の上の一言：短い判子 → 見出しの数字 → 短い見出し → main の順。"""
    def bare(x):
        return re.sub(r"^[「『]|[」』]$", "", str(x or "")).rstrip("！!")
    stamp, hook = bare(t.get("stamp")), bare(t.get("hook"))
    if stamp and len(stamp) <= TOP_WORD_MAX:
        return stamp
    for text in (stamp, hook):
        m = _NUM.search(text)
        if m:
            return m.group(0)
    if hook and len(hook) <= TOP_WORD_MAX:
        return hook
    return str(t.get("main", ""))


def variant_spec(t: dict, key: str, src_size=None) -> dict:
    """台本の thumbnail: から、案 a / b / c の中身を作る。variants: の同じ名前の欄が優先。"""
    if key not in VARIANTS:
        raise ValueError(f"サムネイルの案は {VARIANTS} のどれか: {key}")
    base = {k: v for k, v in t.items() if k != "variants"}
    over = dict((t.get("variants") or {}).get(key) or {})
    if key == "a":
        return {**base, **over, "layout": "a"}
    keep = ("image", "crop", "focus", "name", "main") + (("lead",) if key == "c" else ())
    spec = {k: base[k] for k in keep if k in base}
    if key == "b" and "crop" not in over:
        if src_size is None:
            raise ValueError("b の自動の切り方には元の絵の大きさが要ります")
        spec["crop"] = face_crop(base["crop"], base.get("focus", DEFAULT_FOCUS), src_size)
        spec["focus"] = [int(W * FACE_AT[0]) - 380, 0, int(W * FACE_AT[0]) + 380, H]
    if key == "c":
        spec["top"] = top_word(base)
    spec.update(over)
    spec["layout"] = key
    return spec


def _background(src: Image.Image, t: dict) -> Image.Image:
    img = src.crop(tuple(t["crop"])).resize((W, H), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.12)
    img = ImageEnhance.Color(img).enhance(1.25)
    img = ImageEnhance.Brightness(img).enhance(1.12)
    focus = Image.new("L", (W, H), 0)
    ImageDraw.Draw(focus).ellipse(t.get("focus", DEFAULT_FOCUS), fill=255)
    return Image.composite(img, ImageEnhance.Brightness(img).enhance(0.6), focus.filter(ImageFilter.GaussianBlur(160)))


def _shade(img: Image.Image, top_h: int, top_a: float, bottom_h: int, bottom_a: float) -> None:
    if top_h:
        top = Image.linear_gradient("L").resize((W, top_h)).transpose(Image.FLIP_TOP_BOTTOM)
        img.paste((8, 6, 4), (0, 0, W, top_h), top.point(lambda v: int(v * top_a)))
    if bottom_h:
        bottom = Image.linear_gradient("L").resize((W, bottom_h))
        img.paste((8, 6, 4), (0, H - bottom_h, W, H), bottom.point(lambda v: int(v * bottom_a)))


def _cast(img: Image.Image, assets: Path) -> None:
    """右下：剣崎雌雄（後ろ）と驚き顔のつむぎ（手前）。"""
    chars = assets / "characters"
    if (chars / "kenzaki_helmet.png").exists():
        k = _bust(chars / "kenzaki_helmet.png", 340, 0.33)
        img.paste(k, (W - k.width - 175, H - k.height + 10), k)
    surprised = chars / "tsumugi_surprised_helmet.png"
    plain = chars / "tsumugi_helmet.png"
    if surprised.exists() or plain.exists():
        tsu = _bust(surprised if surprised.exists() else plain, 320, 0.36)
        img.paste(tsu, (W - tsu.width + 25, H - tsu.height - 4), tsu)


def _layout_a(img, t, gothic):
    _shade(img, 230, 0.85, 300, 0.92)
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


B_TEXT_W = 700        # b：左の文字の幅（顔にかからないように）


def _layout_b(img, t, gothic):
    """顔に寄せた絵の左に、名前（白・大）と main（黄・特大）の2段だけ。"""
    left = Image.linear_gradient("L").rotate(90, expand=True).transpose(Image.FLIP_LEFT_RIGHT).resize((760, H))   # 左ほど暗い
    img.paste((8, 6, 4), (0, 0, 760, H), left.point(lambda v: int(v * 0.8)))
    _shade(img, 0, 0, 260, 0.7)
    dr = ImageDraw.Draw(img)
    if t.get("name"):
        _text(dr, (40, 420), t["name"], _fit(gothic, t["name"], 116, B_TEXT_W, 64), WHITE, 11, "lm")
    if t.get("main"):
        _text(dr, (34, 590), t["main"], _fit(gothic, t["main"], 210, B_TEXT_W, 110), YEL, 16, "lm")


C_BAND = (548, H - 15)      # c：下の赤い帯（地層の目印の上まで）


def _layout_c(img, t, gothic):
    """上に大きな数字か短い語（黄）、下は赤い帯に白抜きの名前と問い。判子は置かない。"""
    _shade(img, 300, 0.9, 0, 0)
    dr = ImageDraw.Draw(img)
    if t.get("top"):
        _text(dr, (40, 130), t["top"], _fit(gothic, t["top"], 200, W - 80, 100), YEL, 16, "lm")
    band = Image.new("RGBA", (W, C_BAND[1] - C_BAND[0]), RED + (238,))
    img.paste(band, (0, C_BAND[0]), band)
    dr = ImageDraw.Draw(img)
    if t.get("name"):
        nf = _font(gothic, 52)
        nw = nf.getlength(t["name"])
        dr.rectangle([36, C_BAND[0] - 68, 36 + nw + 36, C_BAND[0]], fill=YEL)
        dr.text((54, C_BAND[0] - 34), t["name"], font=nf, fill=BLACK, anchor="lm")
    words = "".join(str(t.get(k, "")) for k in ("lead", "main"))
    if words:
        _text(dr, (36, (C_BAND[0] + C_BAND[1]) // 2 + 2), words, _fit(gothic, words, 130, 820 - 36, 72), WHITE, 8, "lm")


_LAYOUTS = {"a": _layout_a, "b": _layout_b, "c": _layout_c}


def render_spec(t: dict, config: dict, assets: Path) -> Image.Image:
    gothic = (config.get("fonts") or {}).get("gothic")
    src = Image.open(assets / t["image"]).convert("RGB")
    img = _background(src, t)
    layout = t.get("layout", "a")
    _LAYOUTS[layout](img, t, gothic)
    if layout != "b":                                   # b は顔が主役なので2人を出さない
        _cast(img, assets)
    dr = ImageDraw.Draw(img)
    for i, c in enumerate(STRATA):                        # 目印：下端の細い地層
        dr.rectangle([0, H - 15 + i * 3, W, H - 12 + i * 3], fill=c)
    return img


def make(script, config: dict, assets: Path) -> Image.Image:
    """台本の thumbnail: のとおりのサムネイル（案 a と同じ）。"""
    return render_spec(variant_spec(script.thumbnail, "a"), config, assets)


def make_variants(script, config: dict, assets: Path) -> dict[str, Image.Image]:
    """3案（a・b・c）。YouTube Studio の「テストと比較」に載せる。"""
    t = script.thumbnail
    with Image.open(assets / t["image"]) as im:
        size = im.size
    return {k: render_spec(variant_spec(t, k, size), config, assets) for k in VARIANTS}


def variants_preview(imgs: dict[str, Image.Image], gothic: str | None = None) -> Image.Image:
    """3案を1枚に：各段に 640px（大きめ）・320px（一覧）・168px（スマホの関連動画）を並べる。"""
    sizes = [(640, 360), (320, 180), (168, 94)]
    gap, label_w = 20, 60
    width = label_w + sum(w for w, _ in sizes) + gap * len(sizes)
    out = Image.new("RGB", (width, len(imgs) * (360 + gap) + gap), (240, 240, 240))
    dr = ImageDraw.Draw(out)
    lf = _font(gothic, 44)
    for row, (key, img) in enumerate(imgs.items()):
        y = gap + row * (360 + gap)
        dr.text((label_w // 2, y + 180), key, font=lf, fill=(40, 40, 40), anchor="mm")
        x = label_w
        for w, h in sizes:
            out.paste(img.resize((w, h), Image.LANCZOS), (x, y + (360 - h) // 2))
            x += w + gap
    return out


def preview(img: Image.Image) -> Image.Image:
    """一覧で見える大きさ（横 320px）と、その2倍を並べた確認用。"""
    small = img.resize((320, 180), Image.LANCZOS)
    mid = img.resize((640, 360), Image.LANCZOS)
    out = Image.new("RGB", (640 + 20 + 320, 360), (240, 240, 240))
    out.paste(mid, (0, 0))
    out.paste(small, (660, 90))
    return out
