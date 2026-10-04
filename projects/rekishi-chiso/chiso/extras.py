"""編集の部品：絵画の吹き出し・1文の挿絵（アイコン）・人物を並べて比べる。

    bubble: {text: 王妃さまからのお手紙だ…！, x: 0.5, y: 0.25}     # 肖像の上の位置（0〜1）。その行のあいだだけ出る
    icon: envelope-simple                                       # 挿絵。その行のあいだ、真ん中の丸い板に出る
    figure: {type: compare, title: 中国三大悪女, people: [[呂雉, paintings/a.jpg, 漢], [武則天, paintings/b.jpg, 唐]]}

挿絵は Phosphor Icons（MIT ライセンス）の塗りつぶし版のフォント。assets/icons/ に置く（map.json が名前→文字）。
使える名前の例は ICON_HINTS。
"""
from __future__ import annotations

import json
import math
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

INK = (60, 44, 28)
PAPER = (240, 228, 200)
GOLD = (214, 178, 110)

ICON_HINTS = {
    "手紙": "envelope-simple", "巻物": "scroll", "お金": "coins", "大金": "money", "王冠": "crown",
    "宝石": "diamond", "城": "castle-turret", "馬": "horse", "群衆": "users-three", "怒り": "hand-fist",
    "見張り": "eye", "本": "book-open-text", "筆": "pen-nib", "ドレス": "dress", "赤ちゃん": "baby",
    "裁判": "gavel", "刷り物": "newspaper", "戦い": "sword", "船": "boat", "牢": "lock", "鍵": "key",
    "別れ": "heart-break", "悲しみ": "mask-sad", "疑問": "question", "噂": "chat-circle-dots",
    "逃亡": "footprints", "火": "fire", "死": "skull", "教会": "church", "パン": "bread", "地図": "map-trifold",
}


@lru_cache(maxsize=2)
def _icon_map(folder: str) -> dict[str, str]:
    return json.loads((Path(folder) / "map.json").read_text(encoding="utf-8"))


def known_icons() -> set[str]:
    """使える挿絵の名前（素材の置き場の map.json。無ければ例の一覧だけ）。"""
    import os
    folder = Path(os.environ.get("CHISO_ASSETS", Path(__file__).resolve().parent.parent / "../../../output/rekishi-chiso/assets")) / "icons"
    try:
        return set(_icon_map(str(folder.resolve())))
    except OSError:
        return set(ICON_HINTS.values())


def icon_char(assets: Path, name: str) -> str:
    m = _icon_map(str(assets / "icons"))
    if name not in m:
        raise ValueError(f"挿絵の名前が分かりません: {name}（例: {', '.join(list(ICON_HINTS.values())[:8])} …）")
    return chr(int(m[name], 16))


def draw_icon(painter, img: Image.Image, name: str, t: float = 1.0) -> Image.Image:
    """真ん中の丸い板に挿絵。t は出てくる途中（0→1 で大きくなる）。"""
    img = img.copy()
    e = 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))
    r = int(160 * (0.7 + 0.3 * e))
    cx, cy = 1030, 420                                     # メモ（左）と肖像（右）のあいだ
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r + 8, cy - r + 12, cx + r + 8, cy + r + 12], fill=(0, 0, 0, int(140 * e)))
    layer = layer.filter(ImageFilter.GaussianBlur(10))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=PAPER + (int(250 * e),), outline=GOLD + (int(255 * e),), width=5)
    d.ellipse([cx - r + 12, cy - r + 12, cx + r - 12, cy + r - 12], outline=(190, 160, 110, int(255 * e)), width=2)
    f = ImageFont.truetype(str(painter.assets / "icons" / "Phosphor-Fill.ttf"), int(r * 1.15))
    d.text((cx, cy), icon_char(painter.assets, name), font=f, fill=INK + (int(255 * e),), anchor="mm")
    img.alpha_composite(layer)
    return img


def portrait_box(painter, pic) -> tuple[int, int, int, int]:
    """肖像が画面のどこに出ているか（render._portrait と同じ計算）。"""
    p = painter.image(pic.image)
    ph = 440
    pw = int(p.width * ph / p.height)
    px, py = painter.W - pw - 330, 70
    return px, py, pw, ph


def draw_bubble(painter, img: Image.Image, pic, bubble: dict) -> Image.Image:
    """肖像の人物から出る吹き出し。尾は (x, y) を指し、吹き出し本体は肖像の左側に置く。"""
    img = img.copy()
    px, py, pw, ph = portrait_box(painter, pic)
    tx, ty = px + pw * float(bubble.get("x", 0.5)), py + ph * float(bubble.get("y", 0.3))
    text = str(bubble["text"])
    f = painter.font("gothic", 38)
    from .subs import wrap_balanced
    rows = wrap_balanced(text, f, 460)[:3]
    w = int(max(f.getlength(r) for r in rows)) + 60
    h = 50 * len(rows) + 40
    bx1 = px - 30
    bx0 = bx1 - w
    by0 = max(40, int(ty) - h // 2 - 40)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([bx0 + 6, by0 + 8, bx1 + 6, by0 + h + 8], radius=30, fill=(0, 0, 0, 120))
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    d = ImageDraw.Draw(layer)
    d.polygon([(bx1 - 10, by0 + h * 0.45), (bx1 - 10, by0 + h * 0.75), (tx, ty)], fill=(255, 255, 255, 255),
              outline=INK + (255,))
    d.rounded_rectangle([bx0, by0, bx1, by0 + h], radius=30, fill=(255, 255, 255, 255), outline=INK + (255,), width=4)
    d.polygon([(bx1 - 12, by0 + h * 0.45 + 3), (bx1 - 12, by0 + h * 0.75 - 3), (bx1 + 2, by0 + h * 0.6)],
              fill=(255, 255, 255, 255))
    for k, row in enumerate(rows):
        d.text(((bx0 + bx1) / 2, by0 + 20 + 50 * k), row, font=f, fill=(30, 22, 14), anchor="mt")
    img.alpha_composite(layer)
    return img


def draw_compare(painter, img: Image.Image, spec: dict, t: float = 1.0) -> None:
    """人物を並べて比べる（figures.draw から呼ばれる）。順に現れる。"""
    from .figures import _panel
    dr, (ax0, ay0, ax1, ay1) = _panel(painter, img, spec.get("title", ""))
    people = spec["people"]
    n = len(people)
    gap = 30
    w = (ax1 - ax0 - gap * (n - 1)) / n
    shown = (0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))) * n
    nf = painter.font("serif", 40, bold=True)
    sf = painter.font("gothic", 26)
    for i, person in enumerate(people):
        if shown < i + 0.3:
            break
        name, image = person[0], person[1]
        note = person[2] if len(person) > 2 else ""
        x0 = ax0 + i * (w + gap)
        ph = ay1 - ay0 - 100
        p = painter.image(image).convert("RGB")
        s = max(w / p.width, ph / p.height)
        p = p.resize((int(p.width * s) + 1, int(p.height * s) + 1), Image.LANCZOS)
        ox, oy = (p.width - int(w)) // 2, int((p.height - ph) * 0.2)
        p = p.crop((ox, oy, ox + int(w), oy + int(ph)))
        img.paste(p, (int(x0), int(ay0)))
        dr = ImageDraw.Draw(img, "RGBA")
        dr.rectangle([x0, ay0, x0 + w, ay0 + ph], outline=GOLD, width=4)
        dr.text((x0 + w / 2, ay0 + ph + 34), name, font=nf, fill=INK, anchor="mm")
        if note:
            dr.text((x0 + w / 2, ay0 + ph + 76), note, font=sf, fill=(110, 90, 60), anchor="mm")


# --- 当時のお金を今の円に ------------------------------------------------------
# 10-04 追加。換算は「1リーヴル＝何円」が資料によって300〜2,000円と大きく割れるので使わない。
# 当時の稼ぎ（日雇いの年収など）を今の稼ぎに置き換える。置き換えの前提（basis）は必ず画面に出す。
def format_yen(v: float) -> str:
    """金額を「約100億円」「約3,000万円」の形に。1万円未満はそのまま。"""
    if v >= 1e8:
        oku = v / 1e8
        return f"約{oku:,.0f}億円" if oku >= 10 else f"約{oku:.1f}億円".replace(".0億", "億")
    if v >= 1e4:
        return f"約{v / 1e4:,.0f}万円"
    return f"約{v:,.0f}円"


def draw_money(painter, img: Image.Image, spec: dict, t: float = 1.0) -> None:
    """当時の金額 → 今の円。円の数字は0から数え上がる（figures.draw から呼ばれる）。"""
    from .figures import _panel
    dr, (ax0, ay0, ax1, ay1) = _panel(painter, img, spec.get("title", ""))
    cx = (ax0 + ax1) / 2
    e = 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))
    lf = painter.font("gothic", 32)
    dr.text((cx, ay0 + 40), "当時", font=lf, fill=(110, 90, 60), anchor="mm")
    dr.text((cx, ay0 + 115), spec["then"], font=painter.font("serif", 84, bold=True), fill=INK, anchor="mm")
    ay = ay0 + 190
    dr.polygon([(cx - 46, ay), (cx + 46, ay), (cx, ay + 50)], fill=GOLD)
    dr.text((cx, ay0 + 290), "今の円で", font=lf, fill=(110, 90, 60), anchor="mm")
    yen = float(spec["yen"]) * (e if t < 1 else 1.0)
    dr.text((cx, ay0 + 385), format_yen(yen) if yen >= 1 else "　", font=painter.font("serif", 120, bold=True),
            fill=(176, 40, 30), anchor="mm")
    if t >= 1:
        bf = painter.font("gothic", 26)
        dr.text((cx, ay1 - 10), f"※{spec['basis']}", font=bf, fill=(110, 90, 60), anchor="ms")
