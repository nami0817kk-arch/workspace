"""書き込み（赤ペン）。表・判定表・数字の板の項目や、写真の顔に、手で書いたような印を足す（2026-10-07）。

ユーザーが「2（書き込みの板）」を選んだ。世の中の断面図の annotate（手書き風の赤丸・取り消し線・
下線・矢印・×・レ・添え書き）と sequence.reveal（1つずつ足す）を、こちらの描き方に合わせて移した。

**座標は手で書かせない。**行に `mark:` を書き、そのとき画面に出ているカードの「何番目の項目か」
（`row:` / `item:`、列は `col:`）か、写真の顔（`on: photo`、`face:` で左から何人目）で指す::

    mark: {kind: strike, row: 0}                       # 表の0行目に取り消し線
    mark: {kind: note, row: 0, text: アジアカップで抜ける}  # その横に添え書き
    mark: {kind: circle, row: 4, col: 判定}              # 判定表の×の印を赤丸で
    mark: {kind: circle, item: 0}                       # 数字の板の1つ目を囲む
    mark: {kind: circle, item: 2}                       # 散らばり図の3つ目の点を囲む（換算の板も item）
    mark: {kind: circle, on: photo}                     # 写真のいちばん大きい顔を囲む

- 書き込みは**前の行から引き継いで積もる**。カードが替われば消える（光らせる行だけ違う同じ表
  ＝ `cards.same_table` のあいだは残る）。写真の上の書き込みは写真が替わっても消える
- **1画面2つまで**（`MAX_ON_SCREEN`）。超えたら draft・台本の読み込みが止める
- 新しく足した書き込みは数コマかけて描き進める（線が伸びる・字が1字ずつ出る。render.MARK_IN）
- 色は朱（チャンネルの緑・黄の板の上で目立つ赤系）。**透明を保つ**：透明の層に描いてから
  `alpha_composite` する（断面図の apply は RGB に落として黒い枠が出ていた）
"""

from __future__ import annotations

import json
import math
import random
import zlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

KINDS = ("circle", "box", "strike", "underline", "arrow", "cross", "check", "note")
KIND_NAMES = {"circle": "赤丸", "box": "四角", "strike": "取り消し線", "underline": "下線",
              "arrow": "矢印", "cross": "×", "check": "レ", "note": "添え書き"}
KEYS = frozenset({"kind", "row", "item", "col", "on", "face", "text"})
# 写真の顔に足せるもの（線を引く相手の字が無いので、取り消し線・下線・レは使えない）
PHOTO_KINDS = ("circle", "box", "arrow", "cross", "note")
PHOTO_WORDS = ("photo", "写真", "顔")
MAX_ON_SCREEN = 2
NOTE_MAX = 16             # 添え書きの字数。手書きの一言なので短く

PEN = (238, 56, 30, 255)          # 朱。緑・黄の板の上でも写真の上でも目立つ赤系
HALO = (255, 255, 255, 255)       # 添え書きの縁（写真の上でも読める）
SHADOW = (0, 0, 0, 120)           # 線の下に敷く影（明るい写真の上で線が沈まない）
WIDTH = 8                         # 線の太さ（px、1080 の画面で）
SS = 2                            # 描くときの拡大率（線のギザギザを消す）
NOTE_SIZES = (44, 38, 32)         # 添え書きの字の大きさ（入らなければ順に小さく）
NOTE_TILT = 3.5                   # 添え書きの傾き（度）
TOP_BAND = 124                    # 画面の上の帯（節の名前のピル・節の点）。添え書きを置かない
# 手書きらしく見える字（Windows にあるもの）。無ければ画面の字で書く
NOTE_FONTS = ("C:/Windows/Fonts/HGRPP1.TTC", "C:/Windows/Fonts/UDDigiKyokashoN-B.ttc")


class MarkError(ValueError):
    pass


# ------------------------------------------------------------------ 書き方


def parse(value, where: str = "") -> list[dict]:
    """`mark:` の値（辞書・辞書の並び・`{kind: …}` の文字）を、確かめた辞書の並びにする。"""
    if value is None or value == "" or value == []:
        return []
    if isinstance(value, str):
        import yaml

        try:
            value = yaml.safe_load(value)
        except yaml.YAMLError as exc:
            raise MarkError(f"{where}mark の書き方が読めません（{{kind: strike, row: 0}} の形で）: {exc}") from exc
    items = value if isinstance(value, list) else [value]
    out = []
    for item in items:
        if not isinstance(item, dict):
            raise MarkError(f"{where}mark は {{kind: circle, row: 0}} の形で書いてください（{str(item)[:30]}）")
        out.append(_normalize(item, where))
    return out


def _normalize(item: dict, where: str) -> dict:
    unknown = sorted(str(k) for k in item if k not in KEYS)
    if unknown:
        raise MarkError(f"{where}mark に知らない鍵があります（{unknown[0]}）。使えるのは {'・'.join(sorted(KEYS))}")
    kind = str(item.get("kind") or "").strip().lower()
    if kind not in KINDS:
        raise MarkError(f"{where}mark の kind『{item.get('kind')}』は使えません。"
                        f"{' / '.join(f'{k}（{KIND_NAMES[k]}）' for k in KINDS)} のどれか")
    out: dict = {"kind": kind}
    on = str(item.get("on") or "card").strip().lower()
    photo = on in PHOTO_WORDS
    if not photo and on not in ("card", "カード", "表"):
        raise MarkError(f"{where}mark の on『{item.get('on')}』は photo か card です")
    if photo:
        out["on"] = "photo"
        for key in ("row", "item", "col"):
            if key in item:
                raise MarkError(f"{where}写真の書き込み（on: photo）に {key} は書けません。顔は face: で指します")
        if kind not in PHOTO_KINDS:
            raise MarkError(f"{where}写真の上には {kind}（{KIND_NAMES[kind]}）は描けません。"
                            f"{'・'.join(PHOTO_KINDS)} のどれか")
        if "face" in item:
            out["face"] = _index(item["face"], "face", where)
    else:
        if "face" in item:
            raise MarkError(f"{where}face は写真の書き込み（on: photo）にだけ書けます")
        has = [k for k in ("row", "item") if k in item]
        if not has:
            raise MarkError(f"{where}mark には row（行）か item（項目）の番号が要ります（0 から数える）。"
                            "写真なら on: photo")
        if len(has) == 2:
            raise MarkError(f"{where}mark の row と item はどちらか1つにしてください")
        out[has[0]] = _index(item[has[0]], has[0], where)
        if "col" in item:
            col = item["col"]
            if isinstance(col, bool) or not isinstance(col, (int, str)) or (isinstance(col, int) and col < 0):
                raise MarkError(f"{where}mark の col は列の番号（0 から）か列の名前で書いてください")
            out["col"] = col if isinstance(col, int) else str(col).strip()
    text = str(item.get("text") or "").strip()
    if kind == "note" and not text:
        raise MarkError(f"{where}添え書き（note）には text が要ります")
    if text:
        if len(text) > NOTE_MAX:
            raise MarkError(f"{where}添え書き「{text}」は{len(text)}字です。{NOTE_MAX}字までにしてください")
        out["text"] = text
    return out


def _index(value, key: str, where: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise MarkError(f"{where}mark の {key} は 0 から数えた番号で書いてください（{value}）")
    return value


def dump(mark: dict) -> str:
    """台本の `  mark: …` に書く1行（JSON は YAML の流れ書きとしても読める）。"""
    return json.dumps(mark, ensure_ascii=False)


def is_photo(mark: dict) -> bool:
    return mark.get("on") == "photo"


def index_of(mark: dict) -> int:
    return int(mark.get("row", mark.get("item", 0)))


def describe(mark: dict) -> str:
    target = "写真" if is_photo(mark) else f"{'row' if 'row' in mark else 'item'} {index_of(mark)}"
    return f"{KIND_NAMES[mark['kind']]}（{target}）"


def column_of(mark: dict, spec: dict) -> int | None:
    """`col:` を列の番号にする。無ければ None。名前が合わなければ MarkError。"""
    from . import cards

    if "col" not in mark:
        return None
    names = cards.mark_columns(spec)
    col = mark["col"]
    if not names:
        raise MarkError(f"{spec.get('type')} カードには列がありません（col は書けません）")
    if isinstance(col, int):
        if col >= len(names):
            raise MarkError(f"col {col} はありません（列は 0〜{len(names) - 1}：{'・'.join(n or '（空）' for n in names)}）")
        return col
    if col in names:
        return names.index(col)
    raise MarkError(f"列『{col}』はありません（{'・'.join(n or '（空）' for n in names)}）")


def check_target(mark: dict, spec: dict | None) -> list[str]:
    """書き込みの先が、そのとき画面に出ているカードの中にあるか。"""
    from . import cards

    if is_photo(mark):
        return []
    what = describe(mark)
    if not spec:
        return [f"{what}の先にカードがありません（その行で画面に出ている表・板を指します）"]
    kind = str(spec.get("type", "")).lower()
    if kind not in cards.MARKABLE_TYPES:
        return [f"{what}：{kind} カードには書き込みを足せません（{'・'.join(cards.MARKABLE_TYPES)}）"]
    count = cards.mark_units(spec)
    if index_of(mark) >= count:
        return [f"{what}：{kind} カードの"
                f"{'行' if kind in ('table', 'verdict', 'bars', 'waterfall', 'timeline') else '項目'}は"
                f" 0〜{count - 1} です（{spec.get('title') or kind}）"]
    try:
        column_of(mark, spec)
    except MarkError as exc:
        return [f"{what}：{exc}"]
    return []


class Board:
    """1行ずつ進めて、画面に出ている書き込みを数える（render・台本の点検・script.json で同じ決まり）。

    - カードが替われば全部消える（光らせる行だけ違う同じ表のあいだは残る）
    - 写真が替われば写真の上の書き込みだけ消える
    - 新しい書き込みは後ろに積む（`step` の返り値の最後の len(new) 個が新しいもの）
    """

    def __init__(self):
        self.card: str | None = None
        self.spec: dict | None = None
        self.image: str | None = None
        self.marks: list[dict] = []

    def step(self, card: str | None, spec: dict | None, image: str | None, new: list[dict]) -> list[dict]:
        from . import cards

        same = card == self.card or cards.same_table(self.spec, spec)
        if not same:
            self.marks = []
        elif image != self.image:
            self.marks = [m for m in self.marks if not is_photo(m)]
        self.card, self.spec, self.image = card, spec, image
        self.marks = self.marks + list(new or [])
        return list(self.marks)


def check_steps(steps: list[dict]) -> list[str]:
    """行の並び（`{where, card, spec, image, marks}`）を順に見て、先と数を確かめる。"""
    problems: list[str] = []
    board = Board()
    for step in steps:
        shown = board.step(step.get("card"), step.get("spec"), step.get("image"), step.get("marks") or [])
        where = step.get("where", "")
        for mark in step.get("marks") or []:
            problems += [f"{where}: {p}" for p in check_target(mark, step.get("spec"))]
        if len(shown) > MAX_ON_SCREEN:
            problems.append(
                f"{where}: 画面の書き込みが{len(shown)}つになります（{'・'.join(describe(m) for m in shown)}）。"
                f"1画面{MAX_ON_SCREEN}つまで。カードを替えるか（同じ表で光らせる行を替えるだけでは消えません）、減らしてください")
    return problems


def script_steps(script) -> list[dict]:
    """台本（script_model.Script）の行を、check_steps に渡す並びにする。カードは節の中で引き継ぐ。"""
    steps = []
    for scene in script.scenes:
        card = None
        for line in scene.lines:
            if line.card is not None:
                card = None if line.card in ("none", "なし") else line.card
            steps.append({"where": f"{line.source_line}行目（{scene.title}）", "card": card,
                          "spec": script.cards.get(card) if card else None,
                          "image": line.image, "marks": list(getattr(line, "marks", None) or []),
                          "first": line is scene.lines[0]})
    return steps


def check_script(script) -> list[str]:
    """台本の書き込みを確かめる。節の頭で数え直す（カードは節をまたいで引き継がない）。"""
    problems: list[str] = []
    scene_steps: list[dict] = []
    for step in script_steps(script):
        if step.pop("first") and scene_steps:
            problems += check_steps(scene_steps)
            scene_steps = []
        scene_steps.append(step)
    if scene_steps:
        problems += check_steps(scene_steps)
    return problems


def on_screen(scene, cards_def: dict) -> list[list[dict]]:
    """節の各行で、画面に出ている書き込み（script.json・review・spread_long_cards 用）。"""
    board = Board()
    out = []
    card = None
    for line in scene.lines:
        if line.card is not None:
            card = None if line.card in ("none", "なし") else line.card
        out.append(board.step(card, cards_def.get(card) if card else None, line.image,
                              list(getattr(line, "marks", None) or [])))
    return out


# ------------------------------------------------------------------ 的（画面の座標）


def card_target(mark: dict, spec: dict, geo: dict, origin: tuple[float, float], scale: float) -> dict | None:
    """カードの中の的。geo は cards.layout の返り値、origin・scale は画面に置いた位置と倍率。"""
    units = geo["units"]
    index = index_of(mark)
    if index >= len(units):
        return None
    try:
        col = column_of(mark, spec)
    except MarkError:
        return None
    unit = units[index]
    ox, oy = origin

    def tr(box):
        if not box:
            return None
        return (ox + box[0] * scale, oy + box[1] * scale, ox + box[2] * scale, oy + box[3] * scale)

    if col is None and str(spec.get("type", "")).lower() in ("stats", "calc", "convert", "scatter",
                                                             "line"):
        col = 0          # 数字の板・式・換算は、指さなければ数字そのもの（注記まで囲むと板の縁にかかる）。
        #                  散らばり図と折れ線は点そのもの（名前の札は col: 名前、折れ線の値は col: 値）
    box = unit["cells"][col] if col is not None and col < len(unit["cells"]) else unit["text"]
    if not box:
        box = unit["box"]
    w, h = geo["size"]
    return {"box": tr(box), "row": tr(unit["box"]), "text": tr(unit["text"]),
            "card": (ox, oy, ox + w * scale, oy + h * scale),
            "texts": [tr(u["text"]) for u in units] + [tr(c) for u in units for c in u["cells"] if c]}


def photo_target(mark: dict, heads: list[tuple[int, int, int, int]]) -> dict | None:
    """写真の顔の的。heads は頭の枠（x, y, w, h）。face: は左から何人目、無ければいちばん大きい顔。"""
    if not heads:
        return None
    big = max(h[2] for h in heads)
    usable = [h for h in heads if h[2] >= big * 0.5]
    if "face" in mark:
        ordered = sorted(usable, key=lambda h: h[0])
        if mark["face"] >= len(ordered):
            return None
        x, y, w, h = ordered[mark["face"]]
    else:
        x, y, w, h = max(usable, key=lambda h: h[2] * h[3])
    box = (float(x), float(y), float(x + w), float(y + h))
    return {"box": box, "row": box, "text": box, "card": None, "texts": [], "photo": True}


# ------------------------------------------------------------------ 描く


def _rnd(mark: dict) -> random.Random:
    return random.Random(zlib.crc32(dump(mark).encode("utf-8")))


def _wobble(pts, rnd: random.Random, amp: float = 2.0):
    out = []
    for i, (x, y) in enumerate(pts):
        k = math.sin(i * 0.35) * amp + rnd.uniform(-amp * 0.5, amp * 0.5)
        out.append((x + k * 0.4, y + k * 0.6))
    return out


def _segment(a, b, n: int = 24):
    return [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1)]


def _ellipse(box, rnd: random.Random, turns: float = 1.12, power: float = 2.0):
    """手で付けた丸。power を上げると角の張った丸（横に長い行を、はみ出さずに囲む）。"""
    x0, y0, x1, y1 = box
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    n = 160
    e = 2.0 / power
    start = math.pi * 0.85 + rnd.uniform(-0.25, 0.25)       # 左上から書き始める（手で丸を付けるときの癖）
    pts = []
    for i in range(n + 1):
        t = start + i / n * 2 * math.pi * turns
        k = 1.0 + math.sin(t * 2.0) * 0.015 + rnd.uniform(-0.005, 0.005)
        # 書き終わりは少し外へ逃がす（閉じきらない丸）
        k += max(0.0, (i / n - 0.88)) * 0.35
        c, s_ = math.cos(t), math.sin(t)
        pts.append((cx + math.copysign(abs(c) ** e, c) * rx * k, cy + math.copysign(abs(s_) ** e, s_) * ry * k))
    return pts


def _room(box, texts, default: float) -> tuple[float, float]:
    """的のまわりの空き（横・縦）。隣の字にかからない余白を返す。"""
    x0, y0, x1, y1 = box
    room_x = room_y = default
    for b in texts or []:
        if not b or (b[0] >= x0 - 1 and b[2] <= x1 + 1 and b[1] >= y0 - 1 and b[3] <= y1 + 1):
            continue          # 的そのもの・的の中の字
        if b[0] < x1 and b[2] > x0:           # 上下に並ぶ字
            gap = (b[1] - y1) if b[1] >= y1 else (y0 - b[3]) if b[3] <= y0 else None
            if gap is not None:
                room_y = min(room_y, gap)
        elif b[1] < y1 and b[3] > y0:         # 左右に並ぶ字
            gap = (b[0] - x1) if b[0] >= x1 else (x0 - b[2]) if b[2] <= x0 else None
            if gap is not None:
                room_x = min(room_x, gap)
    return room_x, room_y


def _arrow_strokes(tail, end, rnd: random.Random, bend: float = 0.22):
    sx, sy = tail
    ex, ey = end
    mx, my = (sx + ex) / 2, (sy + ey) / 2
    dx, dy = ex - sx, ey - sy
    cx, cy = mx - dy * bend, my + dx * bend
    n = 36
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u * u * sx + 2 * u * t * cx + t * t * ex, u * u * sy + 2 * u * t * cy + t * t * ey))
    shaft = _wobble(pts, rnd, 1.0)
    px, py = pts[-5]
    ang = math.atan2(ey - py, ex - px)
    length = max(18.0, min(30.0, math.hypot(dx, dy) * 0.3))
    heads = []
    for s in (+1, -1):
        a = ang + math.pi + s * 0.45
        heads.append(_segment((ex, ey), (ex + math.cos(a) * length, ey + math.sin(a) * length), 6))
    return [shaft] + heads


def _strokes(mark: dict, target: dict, rnd: random.Random, canvas: tuple[int, int]) -> list[list]:
    """線の書き込みを、筆の通る点の並び（ひと筆ずつ）にする。添え書きの字は別（_note_image）。"""
    kind = mark["kind"]
    x0, y0, x1, y1 = target["box"]
    w, h = x1 - x0, y1 - y0
    my = (y0 + y1) / 2
    if kind == "circle":
        if target.get("photo"):
            return [_ellipse((x0 - w * 0.16, y0 - h * 0.10, x1 + w * 0.16, y1 + h * 0.10), rnd)]
        # 隣の字にかからない余白で囲む。横に長い的は角の張った丸（楕円だと両端が大きくはみ出す）
        room_x, room_y = _room(target["box"], target.get("texts"), 60.0)
        pad_y = max(6.0, min(h * 0.45, room_y * 0.62))
        wide = w > h * 2.6
        pad_x = max(8.0, min(70.0 if not wide else 26.0, room_x * 0.62, w * 0.2))
        return [_ellipse((x0 - pad_x, y0 - pad_y, x1 + pad_x, y1 + pad_y), rnd,
                         power=4.0 if wide else 2.0)]
    if kind == "box":
        p = 12.0 if not target.get("photo") else w * 0.08
        bx0, by0, bx1, by1 = x0 - p, y0 - p, x1 + p, y1 + p
        o = 14
        sides = [((bx0 - o, by0), (bx1 + o, by0)), ((bx1, by0 - 4), (bx1, by1 + 4)),
                 ((bx1 + o, by1), (bx0 - o, by1)), ((bx0, by1 + 4), (bx0, by0 - 4))]
        return [_wobble(_segment(a, b), rnd, 1.6) for a, b in sides]
    if kind == "strike":
        n = 30
        pts = [(x0 - 10 + (w + 20) * i / n, my + 2 + math.sin(i * 0.4) * 2.0 - (i / n) * 4) for i in range(n + 1)]
        return [_wobble(pts, rnd, 1.0)]
    if kind == "underline":
        n = 40
        y = y1 + 9
        pts = [(x0 - 6 + (w + 12) * i / n, y + math.sin(i * 0.55) * 3.0) for i in range(n + 1)]
        return [_wobble(pts, rnd, 0.8)]
    if kind == "cross":
        s = max(48.0, min(130.0, max(h * 1.3, min(w, h * 2.2) * 0.6)))
        cx = (x0 + x1) / 2
        a = (cx - s / 2, my - s / 2, cx + s / 2, my + s / 2)
        return [_wobble(_segment((a[0], a[1]), (a[2], a[3]), 16), rnd, 1.6),
                _wobble(_segment((a[2], a[1]), (a[0], a[3]), 16), rnd, 1.6)]
    if kind == "check":
        s = max(40.0, min(80.0, h * 1.2))
        bx = x1 + 14
        card = target.get("card")
        if card and bx + s > card[2] - 8:
            bx = x0 - 14 - s
        pts = [(bx, my - s * 0.05), (bx + s * 0.38, my + s * 0.42), (bx + s, my - s * 0.55)]
        return [_wobble(_segment(pts[0], pts[1], 10) + _segment(pts[1], pts[2], 14)[1:], rnd, 1.2)]
    return []


def _font(path: str, size: int) -> ImageFont.FreeTypeFont:
    for candidate in NOTE_FONTS:
        if Path(candidate).exists():
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                continue
    return ImageFont.truetype(path, size)


def _note_image(text: str, size: int, font_path: str, scale: int = 1) -> Image.Image:
    """添え書きの絵（朱の字＋白い縁、少し傾ける）。透明の地。"""
    font = _font(font_path, size * scale)
    stroke = 6 * scale
    probe = ImageDraw.Draw(Image.new("RGBA", (4, 4)))
    x0, y0, x1, y1 = probe.textbbox((0, 0), text, font=font, stroke_width=stroke)
    pad = 6 * scale
    image = Image.new("RGBA", (int(x1 - x0) + pad * 2, int(y1 - y0) + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(image).text((pad - x0, pad - y0), text, font=font, fill=PEN,
                               stroke_width=stroke, stroke_fill=HALO)
    return image.rotate(NOTE_TILT, expand=True, resample=Image.BICUBIC)


def _hits(rect, boxes, pad: float = 6.0) -> bool:
    x0, y0, x1, y1 = rect
    for b in boxes:
        if not b:
            continue
        if x0 < b[2] + pad and x1 > b[0] - pad and y0 < b[3] + pad and y1 > b[1] - pad:
            return True
    return False


def _inside(rect, area) -> bool:
    return rect[0] >= area[0] and rect[1] >= area[1] and rect[2] <= area[2] and rect[3] <= area[3]


def place_note(text: str, target: dict, canvas: tuple[int, int], avoid: list, taken: list,
               font_path: str) -> tuple[tuple[float, float, float, float], int, bool]:
    """添え書きを置く場所（枠・字の大きさ・矢印で結ぶか）。字・顔・帯にかからないところから選ぶ。"""
    W, H = canvas
    screen = (16, TOP_BAND, W - 16, H - 16)
    x0, y0, x1, y1 = target["box"]
    my = (y0 + y1) / 2
    card = target.get("card")
    texts = target.get("texts") or []
    unit_text = target.get("text") or target["box"]
    gap = 22
    for size in NOTE_SIZES:
        image = _note_image(text, size, font_path)
        w, h = image.size
        tries = []
        if card:
            inner = (card[0] + 10, card[1] + 6, card[2] - 10, card[3] - 6)
            # 1) 的のすぐ右（同じ行の空き）、2) 行の字の右、3) カードの右の外、4) 下、5) 上、6) 左の外
            tries += [((x1 + gap, my - h / 2), inner, texts, False),
                      ((unit_text[2] + gap, my - h / 2), inner, texts, False)]
            outside = avoid + [card]
            tries += [((card[2] + gap, my - h / 2), screen, outside, abs(card[2] + gap - x1) > 160),
                      ((max(card[0], min(x0, W - 16 - w)), card[3] + gap), screen, outside, True),
                      ((max(card[0], min(x0, W - 16 - w)), card[1] - gap - h), screen, outside, True),
                      ((card[0] - gap - w, my - h / 2), screen, outside, True)]
        else:
            # 写真の顔：横・下・上（顔そのものには重ねない）
            tries += [((x1 + gap * 2, my - h / 2), screen, avoid, True),
                      ((x0 - gap * 2 - w, my - h / 2), screen, avoid, True),
                      (((x0 + x1) / 2 - w / 2, y1 + gap * 2), screen, avoid, True),
                      (((x0 + x1) / 2 - w / 2, y0 - gap * 2 - h), screen, avoid, True)]
        for (nx, ny), area, blocks, link in tries:
            rect = (nx, ny, nx + w, ny + h)
            if _inside(rect, area) and not _hits(rect, blocks) and not _hits(rect, taken) and not _hits(rect, avoid):
                return rect, size, link
    # どこにも入らない：行の字の右に小さく置いて、画面の内側へ寄せる（見本で目で見る）
    image = _note_image(text, NOTE_SIZES[-1], font_path)
    w, h = image.size
    nx = min(max(16, unit_text[2] + gap), W - 16 - w)
    ny = min(max(TOP_BAND, my - h / 2), H - 16 - h)
    return (nx, ny, nx + w, ny + h), NOTE_SIZES[-1], False


def _link_points(note_rect, box):
    """添え書きから的へ引く矢印の、根元と先。"""
    nx0, ny0, nx1, ny1 = note_rect
    bx0, by0, bx1, by1 = box
    ncx, ncy = (nx0 + nx1) / 2, (ny0 + ny1) / 2
    # 的の枠のうち、添え書きにいちばん近い辺の真ん中あたりへ
    end_x = min(max(ncx, bx0 + 6), bx1 - 6)
    end_y = min(max(ncy, by0 + 4), by1 - 4)
    if ncy > by1:
        end_y = by1 + 6
    elif ncy < by0:
        end_y = by0 - 6
    elif ncx > bx1:
        end_x = bx1 + 8
    elif ncx < bx0:
        end_x = bx0 - 8
    start_x = min(max(end_x, nx0), nx1)
    start_y = ny0 - 4 if end_y < ny0 else (ny1 + 4 if end_y > ny1 else ncy)
    if ny0 <= end_y <= ny1:
        start_x = nx0 - 6 if end_x < nx0 else nx1 + 6
    return (start_x, start_y), (end_x, end_y)


def _crosses(points, boxes, skip) -> bool:
    """線（点の並び）が、字の枠を通るか。的のそば（終わりの1割）は見ない。"""
    n = len(points)
    for x, y in points[int(n * 0.06):int(n * 0.88)]:
        for b in boxes:
            if not b or b is skip:
                continue
            if b[0] - 4 <= x <= b[2] + 4 and b[1] - 4 <= y <= b[3] + 4:
                return True
    return False


def _clear_link(note_rect, target: dict, rnd: random.Random) -> list:
    """添え書きから的へ引く矢印。**ほかの行の字を横切らない道**を選ぶ（縦長の画面で、
    下に置いた添え書きからの矢印が2行の字の上を通った）。どれも通れば、矢印は引かない。"""
    texts = [b for b in (target.get("texts") or []) if b]
    box = target["box"]
    x0, y0, x1, y1 = box
    my = (y0 + y1) / 2
    nx0, ny0, nx1, ny1 = note_rect
    options = []
    tail, end = _link_points(note_rect, box)
    options.append((tail, end))
    unit = target.get("text") or box
    for ex in (unit[0] - 12, unit[2] + 12, x0 - 10, x1 + 10):
        end = (ex, my)
        tx = min(max(ex, nx0 + 10), nx1 - 10)
        ty = ny0 - 4 if my < ny0 else ny1 + 4
        options.append(((tx, ty), end))
    for tail, end in options:
        for bend in (0.18, -0.18, 0.4, -0.4, 0.65, -0.65):
            strokes = _arrow_strokes(tail, end, random.Random(0), bend=bend)
            if not _crosses(strokes[0], [b for b in texts if not _same(b, box)], None):
                return _arrow_strokes(tail, end, rnd, bend=bend)
    return []


def _same(a, b) -> bool:
    return all(abs(p - q) < 0.5 for p, q in zip(a, b))


def _arrow_tail(target: dict, canvas: tuple[int, int], avoid: list):
    """文の無い矢印の、根元と先。的の右下・右上・左下・左上の空いているほうから指す。"""
    W, H = canvas
    x0, y0, x1, y1 = target["box"]
    my = (y0 + y1) / 2
    card = target.get("card")
    blocks = list(avoid) + ([card] if card else [])
    for end, (dx, dy) in (((x1 + 10, my), (170, 80)), ((x1 + 10, my), (170, -80)),
                          ((x0 - 10, my), (-170, 80)), ((x0 - 10, my), (-170, -80))):
        tail = (end[0] + dx, end[1] + dy)
        rect = (min(tail[0], end[0] + dx * 0.4) - 10, min(tail[1], end[1] + dy * 0.4) - 10,
                max(tail[0], end[0] + dx * 0.4) + 10, max(tail[1], end[1] + dy * 0.4) + 10)
        if _inside(rect, (16, TOP_BAND, W - 16, H - 16)) and not _hits(rect, blocks if not card else avoid):
            return tail, end
    end = (x1 + 10, my)
    return (min(W - 20, end[0] + 150), min(H - 20, end[1] + 70)), end


def _partial(strokes: list[list], t: float) -> list[list]:
    """筆の進み t（0〜1）までの線。ひと筆ずつ順に引く。"""
    if t >= 1.0:
        return strokes
    total = sum(max(1, len(s) - 1) for s in strokes)
    left = total * max(0.0, t)
    out = []
    for stroke in strokes:
        n = max(1, len(stroke) - 1)
        if left <= 0:
            break
        if left >= n:
            out.append(stroke)
        else:
            k = int(left)
            part = stroke[:k + 1]
            frac = left - k
            if k + 1 < len(stroke) and frac > 0:
                a, b = stroke[k], stroke[k + 1]
                part = part + [(a[0] + (b[0] - a[0]) * frac, a[1] + (b[1] - a[1]) * frac)]
            if len(part) >= 2:
                out.append(part)
        left -= n
    return out


def _draw_strokes(draw: ImageDraw.ImageDraw, strokes: list[list], width: int) -> None:
    for stroke in strokes:
        if len(stroke) < 2:
            continue
        pts = [(x * SS, y * SS) for x, y in stroke]
        shadow = [(x + 2 * SS, y + 3 * SS) for x, y in pts]
        draw.line(shadow, fill=SHADOW, width=(width + 2) * SS, joint="curve")
    for stroke in strokes:
        if len(stroke) < 2:
            continue
        pts = [(x * SS, y * SS) for x, y in stroke]
        draw.line(pts, fill=PEN, width=width * SS, joint="curve")
        r = width * SS / 2           # 端を丸める
        for x, y in (pts[0], pts[-1]):
            draw.ellipse([x - r, y - r, x + r, y + r], fill=PEN)


def plan(marks: list[dict], targets: list[dict | None], canvas: tuple[int, int], avoid: list,
         font_path: str) -> list[dict]:
    """書き込みごとに、線と添え書きの置き場所を決める（同じ書き込みは毎コマ同じ場所）。"""
    taken: list = []
    out = []
    for mark, target in zip(marks, targets):
        if target is None:
            out.append(None)
            continue
        rnd = _rnd(mark)
        item = {"mark": mark, "strokes": _strokes(mark, target, rnd, canvas), "note": None, "link": []}
        if mark["kind"] in ("circle", "box", "cross"):
            x0, y0, x1, y1 = target["box"]
            taken.append((x0 - 40, y0 - 30, x1 + 40, y1 + 30))
        text = mark.get("text", "")
        if text:
            rect, size, link = place_note(text, target, canvas, avoid, taken, font_path)
            taken.append(rect)
            item["note"] = {"text": text, "rect": rect, "size": size}
            if link or mark["kind"] == "arrow":
                item["link"] = _clear_link(rect, target, rnd)
        elif mark["kind"] == "arrow":
            tail, end = _arrow_tail(target, canvas, avoid)
            item["link"] = _arrow_strokes(tail, end, rnd)
        out.append(item)
    return out


def render_layer(size: tuple[int, int], planned: list[dict | None], fresh: int, t: float,
                 font_path: str) -> Image.Image | None:
    """書き込みの層（透明の地、画面と同じ大きさ）。後ろの fresh 個は筆の進み t で途中まで描く。"""
    items = [(i, p) for i, p in enumerate(planned) if p]
    if not items:
        return None
    W, H = size
    big = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    notes = []
    for index, item in items:
        progress = t if index >= len(planned) - fresh else 1.0
        if progress <= 0:
            continue
        # 線を先に引き、添え書きはあとから書く（取り消し線→「アジアカップで抜ける」）
        has_note = bool(item["note"])
        line_t = min(1.0, progress / 0.55) if has_note else progress
        note_t = max(0.0, (progress - 0.35) / 0.65) if has_note else 0.0
        strokes = item["strokes"]
        if item["mark"]["kind"] == "arrow" and not has_note:
            strokes = strokes + item["link"]
        _draw_strokes(draw, _partial(strokes, line_t), WIDTH)
        if has_note:
            notes.append((item, note_t))
    for item, note_t in notes:
        if note_t <= 0:
            continue
        note = item["note"]
        text = note["text"]
        shown = text[:max(1, math.ceil(len(text) * min(1.0, note_t / 0.8)))]
        image = _note_image(shown, note["size"], font_path, scale=SS)
        x0, y0 = note["rect"][0], note["rect"][1]
        big.alpha_composite(image, (int(x0 * SS), int(y0 * SS)))
        if item["link"] and note_t > 0.8:
            _draw_strokes(draw, _partial(item["link"], (note_t - 0.8) / 0.2), WIDTH - 2)
    return big.resize((W, H), Image.LANCZOS)
