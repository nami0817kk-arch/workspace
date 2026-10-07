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

構図（10-07 ユーザー決定「量産型に見せない」）：そろえるのは目印（下端の地層の帯・字体・黄白赤）だけ。
構図は回ごとに `thumbnail.layout:` で選ぶ（書かなければ classic＝上の形。画素まで今と同じ）。
    face    顔の大写し。肖像を片側に大きく（side: right／left）、反対側に2段の極太の文字
    scene   場面の全景（戦い・行列・港）。絵を全面、文字は上か下の黒い帯に1行（band: bottom／top）
    versus  2人の対比。left・right に {image, crop, name, number}。数字が両方あれば数字の対、無ければ真ん中に VS
    number  大きな数字が主役（number: 約168cm）。絵は暗く後ろに
    map     地図が主役（map: {route: [...], marks: [...]}。地名は places.yaml、bounds は省けば自動）。名前と一言
どの構図でも name・lead（白）・main（特大の黄）の書き方はそのまま使える。右下の2人は cast: true／false
（既定は classic と number だけ出す）。同じ構図が3回続くと check が知らせる（check.layout_streak）。
"""
from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from . import hooks, thumbfx

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


def _hi(t: dict, x: float) -> float:
    """文字の右端。聞き手の大きな顔（reactor）が右にいれば、その手前まで。いなければ x のまま。"""
    r = t.get("_reactor")
    return min(x, r[0] - 12) if r and r[0] > W / 2 else x


def _lo(t: dict, x: float) -> float:
    """文字の左端。reactor が左にいれば、その右から。"""
    r = t.get("_reactor")
    return max(x, r[2] + 12) if r and r[2] < W / 2 else x


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
_NUM = re.compile(r"(?:約|およそ)?[0-9０-９][0-9０-９,，.．万億千]*(?:cm|km|kg|m|%|％|センチ|キロ|メートル|か月|ヶ月|時間|[人年歳日万億兆円両石回倍つ分秒隻枚本代])?")


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
    if key == "a":                                      # a は台本の構図のまま（classic は内部では "a"）
        layout = layout_of(base)
        return {**base, **over, "layout": "a" if layout == "classic" else layout}
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
    top_r = _hi(t, W) if (t.get("_reactor") or (0, H))[1] < 160 else W      # 聞き手の顔が上まで届くときは手前で止める
    hook_w = top_r - 60 - (stamp.width if stamp else 0)
    if t.get("hook"):
        _text(dr, (36, 88), t["hook"], _fit(gothic, t["hook"], 76, hook_w), WHITE, 9, "lm")
    if stamp:
        img.paste(stamp, (int(top_r) - stamp.width - 24, 22), stamp)
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
        mf = _fit(gothic, t["main"], 168, _hi(t, 820) - x, 96)    # 右下の2人と再生時間の表示にかからない幅
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


# --- 構図（10-07）。目印（地層の帯・字体・黄白赤）だけそろえて、文字の位置・大きさ・色の配分を構図ごとに変える ---

LAYOUTS = ("classic", "face", "scene", "versus", "number", "map")
DEFAULT_CAST = {"a": True, "b": False, "c": True, "face": False, "scene": False, "versus": False,
                "number": True, "map": False}
SAFE_W = W - 170 - 40           # 右下の再生時間の表示にかかる行の、文字の右端
STRATA_TOP = H - 15


def layout_of(t: dict) -> str:
    """台本の thumbnail: の構図の名前（書いていなければ classic）。"""
    return str((t or {}).get("layout") or "classic")


def problems(t: dict) -> list[str]:
    """構図の名前の誤り・構図に要る項目の不足（check が × にする）。"""
    layout = layout_of(t)
    if layout not in LAYOUTS:
        return [f"サムネイルの構図（layout）が分かりません: {layout}（{'・'.join(LAYOUTS)} のどれか）"]
    need = {"classic": ("image", "crop", "name", "main"), "face": ("image", "crop", "name", "main"),
            "scene": ("image", "crop", "name", "main"), "number": ("image", "crop", "number", "name", "main"),
            "versus": ("left", "right"), "map": ("map", "name", "main")}[layout]
    if t.get("contrast"):                               # 落差の二語があれば main は要らない
        need = tuple(k for k in need if k != "main")
    out = [f"サムネイルの {k} がありません（構図 {layout}）" for k in need if not t.get(k)]
    if layout == "versus":
        for side in ("left", "right"):
            v = t.get(side)
            if v is not None and not isinstance(v, dict):
                out.append(f"サムネイルの {side} は {{image, name, crop, number}} の形で書く")
                continue
            for k in ("image", "name"):
                if v and not v.get(k):
                    out.append(f"サムネイルの {side}.{k} がありません（構図 versus）")
    if layout == "map" and t.get("map"):
        m = t["map"]
        if not isinstance(m, dict) or not (m.get("route") or m.get("marks") or m.get("places")):
            out.append("サムネイルの map に route か marks（地名）がありません")
        else:
            from . import figures
            try:
                figures.with_places(dict(m, marks=list(m.get("marks", []))))
            except ValueError as e:
                out.append(f"サムネイルの地図: {e}")
    if layout == "face" and t.get("side", "right") not in ("left", "right"):
        out.append("サムネイルの side は right か left")
    if layout == "scene" and t.get("band", "bottom") not in ("top", "bottom"):
        out.append("サムネイルの band は bottom か top")
    if layout != "classic":
        out += thumbfx.problems(t)
    return out + hooks.problems(t)


def _graded(src: Image.Image, crop, size) -> Image.Image:
    """絵の crop の範囲を size いっぱいに（はみ出す分は真ん中で切る）。色は _background と同じ上げ方。"""
    region = src.crop(tuple(crop)) if crop else src
    tw, th = size
    k = max(tw / region.width, th / region.height)
    rw, rh = max(tw, round(region.width * k)), max(th, round(region.height * k))
    img = region.resize((rw, rh), Image.LANCZOS)
    x0, y0 = (rw - tw) // 2, (rh - th) // 2
    img = img.crop((x0, y0, x0 + tw, y0 + th))
    img = ImageEnhance.Contrast(img).enhance(1.12)
    img = ImageEnhance.Color(img).enhance(1.25)
    return ImageEnhance.Brightness(img).enhance(1.12)


OFF = {"on": False}
OUTER_MIN = 150          # 黄の主役の語に白の外縁を付ける最小の字の大きさ


def _say(img, dr, o, xy, s, f, fill, stroke, anchor="la", tilt=False):
    """文字を1つ。作り込み（o）が切なら今までの _text。入なら黄は主色のグラデーション＋二重の縁取り＋影、白は縁取り＋影。"""
    if not o.get("on"):
        _text(dr, xy, s, f, fill, stroke, anchor)
        return
    if fill == YEL:
        top, bottom = o["palette"]["main"]
        size = getattr(f, "size", 60)
        outer = max(3, size // 28) if size >= OUTER_MIN else 0       # 小さい字に白の外縁を足すと 168px で潰れる
        thumbfx.text(img, xy, s, f, top, bottom, o["palette"]["inner"], stroke, WHITE if outer else None, outer,
                     angle=o["tilt"] if tilt else 0.0, anchor=anchor)
    else:
        thumbfx.text(img, xy, s, f, fill, None, BLACK, stroke, anchor=anchor)


def _tag(dr, xy, text, gothic, size=44, fill=RED, ink=WHITE, o=OFF, img=None):
    """赤い名前札（左上の角を xy に）。札の右端を返す。作り込みが入なら札に影。"""
    f = _font(gothic, size)
    x, y = xy
    w = f.getlength(text)
    if o.get("on") and img is not None:
        sh = Image.new("L", img.size, 0)
        ImageDraw.Draw(sh).rectangle([x + 6, y + 6, x + w + 42, y + int(size * 1.45) + 6], fill=150)
        img.paste(BLACK, (0, 0), sh.filter(ImageFilter.GaussianBlur(4)))
    dr.rectangle([x, y, x + w + 36, y + int(size * 1.45)], fill=fill)
    dr.text((x + 18, y + int(size * 0.72)), text, font=f, fill=ink, anchor="lm")
    return x + w + 36


def _lead_main(dr, x, y, t, gothic, size, width, anchor="lm", minimum=60, o=OFF, img=None, tilt=False):
    """lead（白）＋main（特大の黄）を1行に。width に収まるまで両方そろえて小さくする。"""
    lead, main = str(t.get("lead") or ""), str(t.get("main") or "")
    if not (lead or main):
        return
    lead_k = 0.62                                       # lead は main の6割の大きさ
    while size > minimum:
        lf, mf = _font(gothic, int(size * lead_k)), _font(gothic, size)
        total = (lf.getlength(lead) + 14 if lead else 0) + mf.getlength(main)
        if total <= width:
            break
        size -= 6
    lf, mf = _font(gothic, int(size * lead_k)), _font(gothic, size)
    total = (lf.getlength(lead) + 14 if lead else 0) + mf.getlength(main)
    if anchor == "mm":
        x -= total / 2
    if lead:
        _say(img, dr, o, (x, y + size * 0.08), lead, lf, WHITE, max(6, size // 14), "lm")
        x += lf.getlength(lead) + 14
    _say(img, dr, o, (x, y), main, mf, YEL, max(8, size // 11), "lm", tilt)


def _person(img, t, o, assets, side):
    """台本で渡された透明 PNG（cutout: paintings/x.png か {image, x, y, height}）を前に重ねる。"""
    c = o.get("cutout")
    if o.get("on") and isinstance(c, (str, dict)):
        thumbfx.cutout(img, c, assets, side)


_FILE_HASH: dict = {}


def _pic_key(path: Path, *parts) -> str:
    """切り抜きの控えの名前：絵のファイルの中身と、切り方・大きさのハッシュ。"""
    import hashlib
    st = path.stat()
    fk = (str(path), st.st_size, st.st_mtime_ns)
    if fk not in _FILE_HASH:
        _FILE_HASH[fk] = hashlib.sha1(path.read_bytes()).hexdigest()
    return hashlib.sha1(repr((_FILE_HASH[fk],) + parts).encode()).hexdigest()[:16]


def _pop(img, o, tile, pos, path, crop, clip=None):
    """主役の絵から人物を自動で切り抜いて前に浮かせる（cutout: true。rembg が無ければ何もしない）。"""
    if not (o.get("on") and o.get("cutout") is True):
        return
    m = thumbfx.person_mask(tile, _pic_key(path, crop, tile.size), o.get("cache"))
    if m is not None:
        thumbfx.pop_out(img, tile, pos, m, thumbfx.OUTLINE.get(o["layout"], WHITE), clip=clip)


def _side_light(img, o, side):
    lt = o.get("light")
    if lt == "auto":
        lt = side
    if lt in ("left", "right", "top"):
        thumbfx.light(img, lt, o["palette"]["light"])


def _tint(img, o, split=None):
    tn = o.get("tint")
    color = thumbfx.VERMILION
    if isinstance(tn, dict):
        color = tuple(tn.get("color") or color)
        tn = tn.get("side")
    if tn in ("left", "right"):
        thumbfx.tint(img, tn, color, split=split)


def _rays(img, o, center):
    r = o.get("rays")
    if r:
        thumbfx.rays(img, tuple(r) if isinstance(r, (list, tuple)) else center, o["palette"]["light"])


FACE_FADE = 220


def _layout_face(img, t, gothic, src, o=OFF, assets=None):
    """肖像を片側（既定は右）に大きく、反対側の暗い所に2段の極太の文字。"""
    right = t.get("side", "right") == "right"
    pw = 720
    back = _graded(src, t["crop"], (W, H)).filter(ImageFilter.GaussianBlur(28))
    img.paste(ImageEnhance.Brightness(back).enhance(0.32))
    face = _graded(src, t["crop"], (pw, H))
    mask = Image.new("L", (pw, H), 255)
    fade = Image.linear_gradient("L").rotate(90, expand=True).resize((FACE_FADE, H))    # 左が0・右が255。文字の側へ溶かす
    mask.paste(fade if right else fade.transpose(Image.FLIP_LEFT_RIGHT), (0 if right else pw - FACE_FADE, 0))
    img.paste(face, (W - pw if right else 0, 0), mask)
    if o.get("on"):
        side = "right" if right else "left"
        _side_light(img, o, side)
        _rays(img, o, (W - pw // 2 if right else pw // 2, 250))
        _tint(img, o)
        if o.get("blur"):
            cx = W - pw // 2 if right else pw // 2
            thumbfx.depth(img, (cx - 420, -260, cx + 420, H + 120), radius=6, dark=0.85)
        _pop(img, o, face, (W - pw if right else 0, 0), assets / t["image"],
             [*t["crop"], "flip"] if t.get("_flip") else t["crop"])
        _person(img, t, o, assets, side)
    hooks.under_text(img, t, gothic, o.get("cache"))
    dr = ImageDraw.Draw(img)
    x0 = _lo(t, 44 if right else W - pw + 120)
    tw = _hi(t, W - pw + 100 if right else SAFE_W) - x0
    top = "" if t.get("_contrast") else str(t.get("lead") or t.get("name") or "")
    if t.get("lead") or t.get("_contrast"):              # lead があれば名前は札、無ければ名前を白の大きな段に
        _tag(dr, (x0 + 4, 150), str(t["name"]), gothic, 46, o=o, img=img)
    _say(img, dr, o, (x0, 300), top, _fit(gothic, top, 130, tw, 70), WHITE, 11, "lm")
    if t.get("main"):
        _say(img, dr, o, (x0 - 4, 480), t["main"], _fit(gothic, t["main"], 230, tw, 90), YEL, 17, "lm", tilt=True)


SCENE_BAND = 200


def _layout_scene(img, t, gothic, src, o=OFF, assets=None):
    """絵を全面に（暗くしない）、上か下の黒い帯に1行。名前は帯の縁に赤い札。"""
    img.paste(_graded(src, t["crop"], (W, H)))
    bottom = t.get("band", "bottom") == "bottom"
    y0 = STRATA_TOP - SCENE_BAND if bottom else 0
    if o.get("on"):
        _side_light(img, o, "top")
        _rays(img, o, (W // 2, 0 if bottom else H))
        _tint(img, o)
        if o.get("blur"):
            thumbfx.depth(img, (-200, -260 if bottom else 120, W + 200, y0 + 160 if bottom else H + 260), radius=7, dark=0.8)
        _person(img, t, o, assets, "right")
    hooks.under_text(img, t, gothic, o.get("cache"))
    if o.get("on") and o.get("torn"):
        thumbfx.torn_edge(img, y0 if bottom else y0 + SCENE_BAND, below=(6, 4, 2), up=not bottom)
    else:
        band = Image.new("RGBA", (W, SCENE_BAND), (6, 4, 2, 225))
        img.paste(band, (0, y0), band)
    dr = ImageDraw.Draw(img)
    if t.get("name"):
        f = 48
        _tag(dr, (40, y0 - int(f * 1.45) if bottom else y0 + SCENE_BAND), str(t["name"]), gothic, f, o=o, img=img)
    _lead_main(dr, 40, y0 + SCENE_BAND // 2 + 4, t, gothic, 160, _hi(t, SAFE_W if bottom else W - 80) - 40, o=o, img=img)


def _layout_versus(img, t, gothic, assets, o=OFF):
    """左右に2枚の絵（斜めの金の線で分ける）。数字が両方あれば数字の対、無ければ真ん中に大きな VS。"""
    sides = []
    for key in ("left", "right"):
        v = t[key]
        with Image.open(assets / v["image"]) as im:
            pic, crop = im.convert("RGB"), v.get("crop")
            if hooks.want_flip(v, "right" if key == "left" else "left"):     # 2人とも真ん中を向かせる
                pic, crop = hooks.mirror(pic, crop)
            sides.append(_graded(pic, crop, (W // 2 + 60, H)))
    img.paste(sides[0], (0, 0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([(W // 2 + 50, 0), (W, 0), (W, H), (W // 2 - 50, H)], fill=255)
    right = Image.new("RGB", (W, H))
    right.paste(sides[1], (W // 2 - 60, 0))
    img.paste(right, (0, 0), mask)
    numbers = all(t[k].get("number") for k in ("left", "right"))
    if o.get("on"):
        _tint(img, o, split=(W // 2 + 50, W // 2 - 50))
        _side_light(img, o, "top")
        if o.get("blur"):
            thumbfx.depth(img, radius=6, dark=0.85)
        if not numbers:
            _rays(img, o, (W // 2, 360))
        for i, key in enumerate(("left", "right")):
            clip = mask if i else ImageChops.invert(mask)
            crop = t[key].get("crop")
            if hooks.want_flip(t[key], "right" if key == "left" else "left"):
                crop = [*(crop or []), "flip"]
            _pop(img, o, sides[i], (W // 2 - 60 if i else 0, 0), assets / t[key]["image"], crop, clip)
        _person(img, t, o, assets, "right")
    hooks.under_text(img, t, gothic, o.get("cache"))
    _shade(img, 150, 0.85, 330, 0.95)
    dr = ImageDraw.Draw(img)
    if o.get("on") and o.get("torn"):
        thumbfx.crack(img, W // 2 + 50, W // 2 - 50)
    else:
        dr.line([(W // 2 + 50, 0), (W // 2 - 50, H)], fill=YEL, width=12)
    for i, key in enumerate(("left", "right")):
        v = t[key]
        cx = W // 4 + (W // 2) * i - (20 if i else -10)
        width = W // 2 - 100 if i == 0 else SAFE_W - W // 2 - 40
        _say(img, dr, o, (cx, 610), str(v["name"]), _fit(gothic, str(v["name"]), 96, width, 50), WHITE, 10, "mm")
        if numbers:
            n = str(v["number"])
            _say(img, dr, o, (cx, 470), n, _fit(gothic, n, 180, width, 80), YEL, 15, "mm")
    if not numbers:
        _say(img, dr, o, (W // 2, 360), "VS", _font(gothic, 210), YEL, 18, "mm", tilt=True)
        dr = ImageDraw.Draw(img)
    if t.get("main") or t.get("lead"):
        _lead_main(dr, W // 2, 78, t, gothic, 120, W - 120, "mm", o=o, img=img)


_NUM_PART = re.compile(r"[0-9０-９][0-9０-９,，.．]*")


def _number_parts(text: str) -> list[tuple[str, bool]]:
    """数字の所と、それ以外（約・cm・年）に分ける。数字は大きく、それ以外は半分の大きさで描く。"""
    out, i = [], 0
    for m in _NUM_PART.finditer(text):
        if m.start() > i:
            out.append((text[i:m.start()], False))
        out.append((m.group(0), True))
        i = m.end()
    if i < len(text):
        out.append((text[i:], False))
    return out or [(text, True)]


def _big_number(dr, x, y, text, gothic, size, width, o=OFF, img=None):
    """大きな数字を描き、範囲（左, 上, 右, 下）を返す。"""
    parts = _number_parts(text)
    while size > 80:
        big, small = _font(gothic, size), _font(gothic, size // 2)
        if sum((big if n else small).getlength(s) for s, n in parts) <= width:
            break
        size -= 8
    big, small = _font(gothic, size), _font(gothic, size // 2)
    x_start = x
    for s, is_num in parts:                              # 下の線をそろえる
        f = big if is_num else small
        _say(img, dr, o, (x, y), s, f, YEL if is_num else WHITE, 20 if is_num else 11, "ls")
        x += f.getlength(s) + (4 if not is_num else 0)
    return x_start, y - size * 0.78, x, y


def _layout_number(img, t, gothic, src, cast: bool, o=OFF, assets=None):
    """大きな数字（画面の半分の高さ）が主役。絵は暗くぼかして後ろに。上に名前、下に lead＋main。"""
    back = _graded(src, t["crop"], (W, H)).filter(ImageFilter.GaussianBlur(5))
    img.paste(ImageEnhance.Brightness(back).enhance(0.38))
    right = _hi(t, SAFE_W - 220 if cast else W - 60)       # 2人（右下）にかからない幅
    if o.get("on"):
        _side_light(img, o, "left")
        _tint(img, o)
        if o.get("blur"):
            thumbfx.depth(img, radius=4, dark=0.8)
        _rays(img, o, (right // 2 + 20, 380))
        _person(img, t, o, assets, "right")
    hooks.under_text(img, t, gothic, o.get("cache"))
    dr = ImageDraw.Draw(img)
    _say(img, dr, o, (44, 92), str(t["name"]), _fit(gothic, str(t["name"]), 92, right - 44, 50), WHITE, 9, "lm")
    _big_number(dr, 40, 470, str(t["number"]), gothic, 340, right - 40, o=o, img=img)
    _lead_main(dr, 44, 590, t, gothic, 120, _hi(t, SAFE_W - 160 if cast else SAFE_W) - 44, o=o, img=img)


MAP_SEA = (38, 58, 78)
MAP_LAND = (214, 190, 140)
MAP_COAST = (96, 72, 44)
FX_SEA = ((14, 30, 62), (30, 58, 98))        # 作り込み：紺（外→真ん中）
FX_LAND = (226, 200, 146)
FX_COAST = (176, 134, 58)                    # 金の海岸線


def _layout_map(img, t, gothic, assets, o=OFF):
    """地図を全面に（海は濃い色、陸は古地図の色）、道のりは赤い点線。左上に名前（白）と一言（黄）。"""
    import math
    from . import figures
    spec = figures.with_places(dict(t["map"], marks=list(t["map"].get("marks", []))))
    lon0, lon1, lat0, lat1 = spec["bounds"]
    kx = math.cos(math.radians((lat0 + lat1) / 2))
    top, bottom = 170, STRATA_TOP - 30                   # 名前と一言の下から地図を見せる
    s = min((W - 120) / ((lon1 - lon0) * kx), (bottom - top) / (lat1 - lat0))
    cx, cy = (lon0 + lon1) / 2, (lat0 + lat1) / 2
    ox, oy = W / 2 + 40, (top + bottom) / 2
    P = lambda lon, lat: (ox + (lon - cx) * kx * s, oy - (lat - cy) * s)
    vis = (cx - (W / 2 + 60) / (kx * s), cx + (W / 2 + 60) / (kx * s), cy - H / s, cy + H / s)
    fx = o.get("on")
    if fx:                                               # 海は紺の放射状（真ん中が少し明るい）
        sea = Image.radial_gradient("L").resize((W, W)).crop((0, (W - H) // 2, W, (W + H) // 2))
        img.paste(Image.composite(Image.new("RGB", (W, H), FX_SEA[0]), Image.new("RGB", (W, H), FX_SEA[1]), sea))
    else:
        img.paste(MAP_SEA, (0, 0, W, H))
    dr = ImageDraw.Draw(img)
    land = Image.new("L", (W, H), 0) if fx else None
    ld = ImageDraw.Draw(land) if fx else None
    for poly in figures._land(str(assets / "maps" / "land_50m.geojson")):
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        if max(xs) < vis[0] or min(xs) > vis[1] or max(ys) < vis[2] or min(ys) > vis[3]:
            continue
        if fx:
            ld.polygon([P(x, y) for x, y in poly], fill=255)
        else:
            dr.polygon([P(x, y) for x, y in poly], fill=MAP_LAND, outline=MAP_COAST)
    if fx:                                               # 陸は古地図の紙（紙の目を濃く）、海岸は金の線と内側の焼け
        parch = Image.new("RGB", (W, H), FX_LAND)
        thumbfx.paper(parch, 2)
        parch = parch.filter(ImageFilter.GaussianBlur(0.7))
        burnt = ImageChops.subtract(land, land.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(6)))
        parch.paste((168, 128, 72), (0, 0), burnt.point(lambda v: v * 3 // 5))
        glow = land.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(8))
        img.paste((70, 96, 140), (0, 0), ImageChops.subtract(glow, land).point(lambda v: v // 2))
        img.paste(parch, (0, 0), land)
        coast = ImageChops.subtract(land.filter(ImageFilter.MaxFilter(3)), land.filter(ImageFilter.MinFilter(3)))
        img.paste(FX_COAST, (0, 0), coast)
        thumbfx.depth(img, radius=3, dark=0.72)
        dr = ImageDraw.Draw(img)
    _shade(img, 260, 0.75, 0, 0)
    dr = ImageDraw.Draw(img)
    places = {n: P(lon, lat) for n, lon, lat in spec["places"]}
    route = [places[n] for n in spec.get("route", []) if n in places]
    legs = list(zip(route, route[1:]))
    for k, (a, b) in enumerate(legs):                    # 白い縁の赤い点線
        if fx and k == len(legs) - 1 and math.dist(a, b) > 90:
            continue                                     # 最後の区間は矢印で
        n = max(2, int(math.dist(a, b) / 22))
        for j in range(0, n, 2):
            p0 = (a[0] + (b[0] - a[0]) * j / n, a[1] + (b[1] - a[1]) * j / n)
            p1 = (a[0] + (b[0] - a[0]) * (j + 1) / n, a[1] + (b[1] - a[1]) * (j + 1) / n)
            dr.line([p0, p1], fill=WHITE, width=16)
            dr.line([p0, p1], fill=RED, width=10)
    if fx and legs and math.dist(*legs[-1]) > 90:
        a, b = legs[-1]
        stop = 24 / math.dist(a, b)                      # 点の手前で止める
        thumbfx.arrow(img, a, (b[0] - (b[0] - a[0]) * stop, b[1] - (b[1] - a[1]) * stop), bend=0.12, width=14)
        dr = ImageDraw.Draw(img)
    pf = _font(gothic, 42)
    taken = []
    for name, (x, y) in places.items():
        dr.ellipse([x - 15, y - 15, x + 15, y + 15], fill=RED, outline=WHITE, width=5)
        taken.append((x - 16, y - 16, x + 16, y + 16))
    for name, (x, y) in places.items():                  # 地名は右→左→上→下の順に、ほかの地名と点に重ならない所へ
        w = pf.getlength(name)
        spots = [(x + 22, y, "lm"), (x - 22, y, "rm"), (x, y - 40, "mm"), (x, y + 40, "mm")]
        spots += [(x + 22, y + d, "lm") for d in (50, -50, 100, -100)] + [(x - 22, y + d, "rm") for d in (50, -50, 100, -100)]
        for bx, by, anchor in spots:
            x0 = {"lm": bx, "rm": bx - w, "mm": bx - w / 2}[anchor]
            box = (x0 - 6, by - 26, x0 + w + 6, by + 26)
            if box[0] >= 10 and box[2] <= W - 10 and not any(
                    box[0] < b[2] and b[0] < box[2] and box[1] < b[3] and b[1] < box[3] for b in taken):
                break
        taken.append(box)
        _say(img, dr, o, (bx, by), name, pf, WHITE, 6, anchor)
    _say(img, dr, o, (40, 70), str(t["name"]), _fit(gothic, str(t["name"]), 96, W - 80, 50), WHITE, 9, "lm")
    _lead_main(dr, 40, 175, t, gothic, 140, _hi(t, W - 40) - 40, o=o, img=img)


_LAYOUTS = {"a": _layout_a, "b": _layout_b, "c": _layout_c}


def _prepare(t: dict, config: dict, assets: Path) -> dict:
    """引きの要素（chiso/hooks.py）のための下ごしらえ。書いていなければ t をそのまま返す（画素まで今と同じ）。"""
    if not hooks.used(t):
        return t
    t = dict(t)
    if t.get("reactor") not in (None, False):
        t["_reactor"] = hooks.reactor_box(t, config, assets)
        t.setdefault("cast", False)                     # 大きな顔を出すときは右下の小さい2人は出さない
    if t.get("contrast") not in (None, False):          # 落差の二語は lead・main の所に出す
        t["_contrast"] = True
        t["lead"] = t["main"] = None
    return t


CONTRAST_ZONE = {      # 落差の二語を置く所（x0, y0, x1, y1）。lead・main がふだん出る所
    "a": (30, 528, 820, 704), "c": (30, 528, 820, 704), "b": (34, 470, 734, 704),
    "number": (44, 492, SAFE_W, 704), "versus": (60, 6, W - 60, 168), "map": (40, 112, W - 40, 250),
}


def contrast_zone(t: dict, layout: str):
    if layout == "face":
        right = t.get("side", "right") == "right"
        z = (40, 226, W - 720 + 100, 650) if right else (W - 720 + 120, 226, SAFE_W, 650)
    elif layout == "scene":
        bottom = t.get("band", "bottom") == "bottom"
        y0 = STRATA_TOP - SCENE_BAND if bottom else 0
        z = (40, y0 + 10, SAFE_W if bottom else W - 40, y0 + SCENE_BAND - 10)
    else:
        z = CONTRAST_ZONE[layout]
    return (_lo(t, z[0]), z[1], _hi(t, z[2]), z[3])


def render_spec(t: dict, config: dict, assets: Path, cache: Path | None = None) -> Image.Image:
    """cache は人物の切り抜きの控えの置き場（work/<台本>）。無ければ控えない。"""
    gothic = (config.get("fonts") or {}).get("gothic")
    t = _prepare(t, config, assets)
    layout = t.get("layout", "a")
    cast = bool(t.get("cast", DEFAULT_CAST[layout]))
    o = thumbfx.options(t, layout)                       # 作り込み（face・scene・versus・number・map だけ）
    o["cache"] = cache
    if layout in _LAYOUTS:
        src = Image.open(assets / t["image"]).convert("RGB")
        img = _background(src, t)
        hooks.under_text(img, t, gothic, cache)
        _LAYOUTS[layout](img, t, gothic)
    else:
        img = Image.new("RGB", (W, H), BLACK)
        if layout in ("face", "scene"):
            with Image.open(assets / t["image"]) as im:
                src = im.convert("RGB")
            if layout == "face" and hooks.want_flip(t, "left" if t.get("side", "right") == "right" else "right"):
                src, crop = hooks.mirror(src, t["crop"])     # 顔を文字の方へ向ける
                t = dict(t, crop=crop, _flip=True)
            {"face": _layout_face, "scene": _layout_scene}[layout](img, t, gothic, src, o, assets)
        elif layout == "number":
            with Image.open(assets / t["image"]) as im:
                _layout_number(img, t, gothic, im.convert("RGB"), cast, o, assets)
        elif layout == "versus":
            _layout_versus(img, t, gothic, assets, o)
        elif layout == "map":
            _layout_map(img, t, gothic, assets, o)
            hooks.under_text(img, t, gothic, cache)
        else:
            raise ValueError(f"サムネイルの構図が分かりません: {layout}")
    if t.get("_contrast"):
        hooks.draw_contrast(img, t, contrast_zone(t, layout), gothic, center=layout == "versus")
    if o.get("on"):
        thumbfx.finish(img, o, gothic, assets, _font)
    hooks.put_reactor(img, t, config, assets)
    if cast:                                            # b は顔が主役なので2人を出さない（既定）
        _cast(img, assets)
    dr = ImageDraw.Draw(img)
    for i, c in enumerate(STRATA):                        # 目印：下端の細い地層
        dr.rectangle([0, H - 15 + i * 3, W, H - 12 + i * 3], fill=c)
    return img


def make(script, config: dict, assets: Path, cache: Path | None = None) -> Image.Image:
    """台本の thumbnail: のとおりのサムネイル（案 a と同じ）。"""
    return render_spec(variant_spec(script.thumbnail, "a"), config, assets, cache)


def make_variants(script, config: dict, assets: Path, cache: Path | None = None) -> dict[str, Image.Image]:
    """3案（a・b・c）。YouTube Studio の「テストと比較」に載せる。"""
    t = script.thumbnail
    if not (t.get("image") and t.get("crop")):          # versus・map は絵1枚の b・c が作れないので a だけ
        return {"a": render_spec(variant_spec(t, "a"), config, assets, cache)}
    with Image.open(assets / t["image"]) as im:
        size = im.size
    return {k: render_spec(variant_spec(t, k, size), config, assets, cache) for k in VARIANTS}


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
