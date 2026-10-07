"""話の中身を図にする：地図で旅をたどる（map）・数字のグラフ（pie / bars）・人物の相関図（people）。

台本の行に `figure:` を書くと、その行から画面の真ん中に図の板が出る（節が変わるか `figure: null` まで続く）。
出たときは t=0→1 で描き進める（地図は線がのびる、円グラフは回って埋まる、棒はのびる、相関図は順に現れる）。

    figure: {type: map, title: 花嫁の旅, bounds: [-2, 16, 46, 51],     # 経度・緯度の範囲（西, 東, 南, 北）
             places: [[ウィーン, 16.37, 48.21], [ストラスブール, 7.75, 48.58], [ヴェルサイユ, 2.13, 48.80]],
             route: [ウィーン, ストラスブール, ヴェルサイユ], note: 約3週間}
    figure: {type: pie, title: 1788年の支出, parts: [[借金の返済と利息, 46], [そのほか, 54]], unit: "%"}
    figure: {type: bars, title: 首飾りの値段, bars: [[日雇いの日当, 1], [首飾り, 1100000]], note: …}
    figure: {type: people, title: 首飾り事件, nodes: [[ジャンヌ, 詐欺を考えた], [ロアン枢機卿, だまされた], …],
             edges: [[ジャンヌ, ロアン枢機卿, ニセの手紙]], cross: [王妃]}           # cross: 「関わっていない」印

数字の図（10-07、世の中の断面図の charts から移した。数字は大きく、単位は小さく）:

    figure: {type: stats, title: 信長の数字, items: [[生涯, 49年, 本能寺で], [元服, 13歳], [石高, 約700万石, 最盛期]]}
    figure: {type: calc, title: 中国大返し, terms: [[200km, 備中高松→山崎], [7日], [約29km/日, 1日あたり]], ops: [÷, ＝]}
    figure: {type: numberline, title: 享年くらべ, items: [[織田信長, 49], [豊臣秀吉, 62], [徳川家康, 75]], unit: 歳, focus: 織田信長}
    figure: {type: line, title: 石高の移り変わり, points: [[1560年, 20], [1570年, 100], [1582年, 700]], unit: 万石}
    figure: {type: versus, title: 同じ年の2人, left: {image: paintings/a.jpg, name: 織田信長, number: 49歳, note: 本能寺で死す},
             right: {image: paintings/b.jpg, name: 明智光秀, number: 55歳?, note: 11日後に死す}}   # 全画面の左右

1項目ずつ増やす（10-07）：`upto: n` を書くと先頭 n 項目だけ描く（bars・people・compare・map の route・
stats・calc・numberline・line）。台本で同じ図を行ごとに upto: 1, 2, 3 と書くと、script.parse が前の行の
upto を grow_from に入れ、新しく増えた項目だけが描き進む（前からある項目は動かない）。
配置は最後の数で決めるので、項目が増えても前の項目は跳ねない。

地図の形は Natural Earth（パブリックドメイン、クレジット不要）。古地図ふうの色で描く。
"""
from __future__ import annotations

import json
import math
import re
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

PANEL = (300, 235, 1620, 840)            # 図の板（画面の真ん中。メモ・肖像・年表は図のあいだ隠す）
PAPER = (232, 218, 186)
SEA = (196, 204, 196)
LAND = (226, 208, 166)
COAST = (120, 96, 62)
INKD = (60, 44, 28)
RED = (176, 40, 40)
PALETTE = [(176, 40, 40), (120, 96, 62), (70, 96, 128), (150, 118, 74), (96, 120, 80)]


def _ease(t: float) -> float:
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


GROW_KEYS = ("upto", "grow_from")


def base_key(spec) -> str:
    """upto・grow_from を除いた図の中身（同じ図が1項目ずつ増えているだけかを見る）。"""
    if spec is None:
        return ""
    if isinstance(spec, str):
        spec = json.loads(spec)
    return json.dumps({k: v for k, v in spec.items() if k not in GROW_KEYS}, ensure_ascii=False, sort_keys=True)


def _grow(spec: dict, n: int) -> tuple[int, int]:
    """(lo, hi)：先頭 hi 項目を描き、lo より前は描き終えた項目（動かさない）。upto が無ければ (0, n)。"""
    upto = spec.get("upto")
    hi = n if upto is None else max(0, min(n, int(upto)))
    lo = max(0, min(hi, int(spec.get("grow_from", 0) or 0)))
    return lo, hi


def _steps(t: float, lo: int, hi: int) -> list[float]:
    """新しく出る項目（lo〜hi）を順に出すときの、それぞれの出かた（0〜1）。前からある項目は 1。"""
    m = max(1, hi - lo)
    e = _ease(t) * m
    return [1.0 if i < lo else max(0.0, min(1.0, e - (i - lo))) for i in range(hi)]


# --- 数字の組み方（数字は太く大きく、単位は小さく。断面図の parts.put_number から） ----------
NUM = re.compile(r"(\d+(?:[,.]\d+)*)|([^\d]+)")
UNIT_RATIO = 0.5


def number_width(painter, text: str, size: int) -> float:
    w = 0.0
    for m in NUM.finditer(str(text)):
        f = painter.font("gothic", size if m.group(1) else int(size * UNIT_RATIO))
        w += f.getlength(m.group(0))
    return w


def put_number(painter, dr, x: float, baseline: float, text: str, size: int, fill, stroke: int = 0,
               stroke_fill=(20, 14, 8), unit_fill=None) -> float:
    """数字を大きく、単位（数字でない部分）を半分の大きさで、下の線（ベースライン）をそろえて描く。右端の x を返す。"""
    for m in NUM.finditer(str(text)):
        big = bool(m.group(1))
        f = painter.font("gothic", size if big else int(size * UNIT_RATIO))
        dr.text((x, baseline), m.group(0), font=f, fill=fill if big or unit_fill is None else unit_fill,
                anchor="ls", stroke_width=stroke if big else max(0, stroke * 2 // 3), stroke_fill=stroke_fill)
        x += f.getlength(m.group(0))
    return x


def fit_number(painter, text: str, size: int, width: float, floor: int = 28) -> int:
    while size > floor and number_width(painter, text, size) > width:
        size -= 4
    return size


def _items(raw, keys=("label", "value", "note")) -> list[dict]:
    """[[名前, 値, 説明], …] か [{label, value, note}, …] を辞書の並びに。"""
    out = []
    for it in raw or []:
        if isinstance(it, dict):
            d = {k: "" for k in keys}
            d.update(it)
            out.append(d)
        else:
            it = list(it)
            out.append({k: (it[i] if i < len(it) else "") for i, k in enumerate(keys)})
    return out


@lru_cache(maxsize=4)
def _land(path: str):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    polys = []
    for f in data["features"]:
        g = f["geometry"]
        parts = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in parts:
            polys.append(poly[0])
    return polys


@lru_cache(maxsize=4)
def _rivers(path: str):
    if not Path(path).exists():
        return []
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    out = []
    for f in data["features"]:
        g = f["geometry"]
        if g is None:
            continue
        parts = g["coordinates"] if g["type"] == "MultiLineString" else [g["coordinates"]]
        out.extend(parts)
    return out


def _panel(painter, img: Image.Image, title: str) -> tuple[ImageDraw.ImageDraw, tuple[int, int, int, int]]:
    """紙の板と題。中の描ける範囲を返す。"""
    x0, y0, x1, y1 = PANEL
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x0 + 10, y0 + 14, x1 + 10, y1 + 14], radius=16, fill=(0, 0, 0, 150))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))
    dr = ImageDraw.Draw(img, "RGBA")
    dr.rounded_rectangle([x0, y0, x1, y1], radius=16, fill=PAPER + (250,), outline=(150, 118, 74), width=4)
    dr.rounded_rectangle([x0 + 10, y0 + 10, x1 - 10, y1 - 10], radius=10, outline=(190, 160, 110), width=2)
    top = y0 + 18
    if title:
        f = painter.font("serif", 40, bold=True)
        dr.text(((x0 + x1) / 2, top + 22), title, font=f, fill=INKD, anchor="mm")
        top += 58
    return dr, (x0 + 30, top, x1 - 30, y1 - 24)


def draw(painter, img: Image.Image, spec: dict, t: float = 1.0) -> Image.Image:
    kind = spec.get("type")
    from .extras import draw_compare, draw_money
    from .numbers import draw_calc, draw_line, draw_numberline, draw_stats, draw_versus
    fn = {"map": _map, "pie": _pie, "bars": _bars, "people": _people, "compare": draw_compare,
          "money": draw_money, "stats": draw_stats, "calc": draw_calc, "numberline": draw_numberline,
          "line": draw_line, "versus": draw_versus}.get(kind)
    if fn is None:
        raise ValueError(f"図の種類が分かりません: {kind}")
    img = img.copy()
    fn(painter, img, spec, t)
    return img


# --- 地図 -------------------------------------------------------------------
def _map(painter, img, spec, t):
    spec = with_places(spec)
    dr, (ax0, ay0, ax1, ay1) = _panel(painter, img, spec.get("title", ""))
    lon0, lon1, lat0, lat1 = spec["bounds"]
    # 縦横比をそろえる（緯度の真ん中で経度を縮める）
    kx = math.cos(math.radians((lat0 + lat1) / 2))
    w_deg, h_deg = (lon1 - lon0) * kx, (lat1 - lat0)
    s = min((ax1 - ax0) / w_deg, (ay1 - ay0) / h_deg)
    ox = ax0 + ((ax1 - ax0) - w_deg * s) / 2
    oy = ay0 + ((ay1 - ay0) - h_deg * s) / 2
    P = lambda lon, lat: (ox + (lon - lon0) * kx * s, oy + (lat1 - lat) * s)
    box = [ox, oy, ox + w_deg * s, oy + h_deg * s]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rectangle(box, fill=SEA + (255,))
    maps = painter.assets / "maps"
    for poly in _land(str(maps / "land_50m.geojson")):
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        if max(xs) < lon0 - 5 or min(xs) > lon1 + 5 or max(ys) < lat0 - 5 or min(ys) > lat1 + 5:
            continue
        ld.polygon([P(x, y) for x, y in poly], fill=LAND + (255,), outline=COAST + (255,))
    for line in _rivers(str(maps / "rivers_50m.geojson")):
        if not any(lon0 <= x <= lon1 and lat0 <= y <= lat1 for x, y in line):
            continue
        ld.line([P(x, y) for x, y in line], fill=(150, 168, 170, 220), width=2)
    from PIL import ImageChops
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle(box, fill=255)
    layer.putalpha(ImageChops.multiply(layer.split()[3], mask))      # 地図の枠の外は切り落とす
    img.alpha_composite(layer)
    dr = ImageDraw.Draw(img, "RGBA")
    dr.rectangle(box, outline=COAST, width=2)
    places = {name: P(lon, lat) for name, lon, lat in spec.get("places", [])}
    names = [n for n in spec.get("route", []) if n in places]
    lo, hi = _grow(spec, len(names))                     # upto：道のりを先頭 hi 地点まで（前の行の分は描き終えたまま）
    # 線は t でのびる（全長に対する割合）
    if lo >= 2:
        _route_line(dr, [places[n] for n in names[:lo]], 1.0)
    _route_line(dr, [places[n] for n in names[max(lo, 1) - 1:hi]], _ease(t))
    f = painter.font("serif", 28, bold=True)
    for i, (name, lon, lat) in enumerate(spec.get("places", [])):
        x, y = places[name]
        if name in names and names.index(name) >= hi:
            continue                                       # まだ着いていない先の地点は出さない
        if "upto" in spec and name in names:
            first = max(lo, 1) - 1
            reached = names.index(name) <= first + _ease(t) * (hi - 1 - first) + 1e-6
        else:
            reached = name not in spec.get("route", []) or _route_reached(spec, name, t)
        dr.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(RED if reached else COAST), outline=(255, 248, 230), width=3)
        dr.text((x + 14, y - 4), name, font=f, fill=INKD, anchor="lm", stroke_width=4, stroke_fill=(245, 236, 210))
    if spec.get("note") and t >= 1 and hi >= len(names):
        nf = painter.font("gothic", 30)
        w = nf.getlength(spec["note"]) + 40
        bx, by = box[2] - w - 14, box[3] - 64
        dr.rounded_rectangle([bx, by, bx + w, by + 48], radius=10, fill=RED)
        dr.text((bx + w / 2, by + 24), spec["note"], font=nf, fill=(255, 255, 255), anchor="mm")


def _route_line(dr, route: list, frac: float) -> None:
    """道のりの点線。frac（0〜1）は全長のうち描く割合。"""
    if len(route) < 2:
        return
    segs = list(zip(route, route[1:]))
    lens = [math.dist(a, b) for a, b in segs]
    total = sum(lens) or 1
    left = total * frac
    for (a, b), L in zip(segs, lens):
        if left <= 0:
            break
        k = min(1.0, left / L) if L else 1.0
        end = (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
        n = max(2, int(L * k / 14))
        for j in range(n):                             # 点線
            if j % 2 == 0:
                p0 = (a[0] + (end[0] - a[0]) * j / n, a[1] + (end[1] - a[1]) * j / n)
                p1 = (a[0] + (end[0] - a[0]) * (j + 1) / n, a[1] + (end[1] - a[1]) * (j + 1) / n)
                dr.line([p0, p1], fill=RED, width=6)
        left -= L
        if k < 1:
            dr.ellipse([end[0] - 10, end[1] - 10, end[0] + 10, end[1] + 10], fill=RED)


GAZETTEER = Path(__file__).resolve().parent.parent / "places.yaml"


def gazetteer() -> dict[str, tuple[float, float]]:
    import yaml
    if not GAZETTEER.exists():
        return {}
    return {k: (float(v[0]), float(v[1])) for k, v in (yaml.safe_load(GAZETTEER.read_text(encoding="utf-8")) or {}).items()}


def with_places(spec: dict, _unused=None) -> dict:
    """places を省いた地図は、route と marks の地名を辞書（places.yaml）から引く。bounds も省けば自動で決める。"""
    spec = dict(spec)
    if not spec.get("places"):
        g = gazetteer()
        names = list(dict.fromkeys(list(spec.get("route", [])) + list(spec.get("marks", []))))
        missing = [n for n in names if n not in g]
        if missing:
            raise ValueError(f"地名の辞書（places.yaml）にない地名: {missing}")
        spec["places"] = [[n, g[n][0], g[n][1]] for n in names]
    if not spec.get("bounds"):
        lons = [p[1] for p in spec["places"]]
        lats = [p[2] for p in spec["places"]]
        mx = max(1.5, (max(lons) - min(lons)) * 0.25)
        my = max(1.0, (max(lats) - min(lats)) * 0.35)
        spec["bounds"] = [min(lons) - mx, max(lons) + mx, min(lats) - my, max(lats) + my]
    return spec


def _route_reached(spec, name, t) -> bool:
    r = spec.get("route", [])
    if name not in r or len(r) < 2:
        return True
    return r.index(name) <= _ease(t) * (len(r) - 1) + 1e-6


# --- 円グラフ ---------------------------------------------------------------
def _pie(painter, img, spec, t):
    dr, (ax0, ay0, ax1, ay1) = _panel(painter, img, spec.get("title", ""))
    parts = spec["parts"]
    total = sum(v for _, v in parts) or 1
    r = min((ay1 - ay0) / 2 - 10, 190)
    cx, cy = ax0 + 40 + r, (ay0 + ay1) / 2
    start = -90.0
    sweep = 360 * _ease(t)
    unit = spec.get("unit", "")
    lf = painter.font("serif", 36, bold=True)
    vf = painter.font("gothic", 54)
    ly = cy - len(parts) * 60
    for i, (label, v) in enumerate(parts):
        ang = 360 * v / total
        a1 = start + min(ang, max(0.0, sweep))
        color = PALETTE[i % len(PALETTE)]
        if a1 > start:
            dr.pieslice([cx - r, cy - r, cx + r, cy + r], start, a1, fill=color, outline=PAPER, width=4)
        sweep -= ang
        start += ang
        # 凡例（右）
        x = cx + r + 80
        y = ly + i * 120
        dr.rectangle([x, y + 10, x + 40, y + 50], fill=color)
        dr.text((x + 60, y + 30), label, font=lf, fill=INKD, anchor="lm")
        if t >= 1:
            dr.text((x + 60, y + 86), f"{v:g}{unit}", font=vf, fill=color, anchor="lm")
    if spec.get("note") and t >= 1:
        nf = painter.font("gothic", 28)
        dr.text(((ax0 + ax1) / 2, ay1 - 6), spec["note"], font=nf, fill=INKD, anchor="ms")


# --- 棒グラフ ---------------------------------------------------------------
def _bars(painter, img, spec, t):
    dr, (ax0, ay0, ax1, ay1) = _panel(painter, img, spec.get("title", ""))
    bars = spec["bars"]
    log = spec.get("log", False)
    vals = [math.log10(v) + 1 if log else v for _, v in bars]
    top = max(vals) or 1
    lf = painter.font("serif", 34, bold=True)
    vf = painter.font("gothic", 34)
    n = len(bars)
    row = (ay1 - ay0 - (40 if spec.get("note") else 0)) / n
    label_w = int(max(lf.getlength(lb) for lb, _ in bars)) + 40
    texts = [(spec.get("labels") or [None] * n)[i] or f"{v:,}{spec.get('unit', '')}" for i, (_, v) in enumerate(bars)]
    room = ax1 - ax0 - label_w - int(max(vf.getlength(x) for x in texts)) - 40     # 数字が板からはみ出さない長さ
    lo, hi = _grow(spec, n)                            # upto：先頭 hi 本だけ。並びと長さの物差しは全部の本数で決める
    for i, ((label, v), sv) in enumerate(zip(bars, vals)):
        if i >= hi:
            break
        y = ay0 + row * i + row * 0.2
        h = row * 0.6
        w = max(0, room) * sv / top * (1.0 if i < lo else _ease(t))
        dr.text((ax0 + label_w - 16, y + h / 2), label, font=lf, fill=INKD, anchor="rm")
        color = PALETTE[i % len(PALETTE)]
        dr.rounded_rectangle([ax0 + label_w, y, ax0 + label_w + max(6, w), y + h], radius=6, fill=color)
        if t >= 1 or i < lo:
            dr.text((ax0 + label_w + w + 14, y + h / 2), texts[i], font=vf, fill=color, anchor="lm")
    if spec.get("note") and t >= 1 and hi >= n:
        nf = painter.font("gothic", 28)
        dr.text(((ax0 + ax1) / 2, ay1 - 6), spec["note"], font=nf, fill=INKD, anchor="ms")


# --- 相関図 ----------------------------------------------------------------
def _people(painter, img, spec, t):
    dr, (ax0, ay0, ax1, ay1) = _panel(painter, img, spec.get("title", ""))
    nodes = spec["nodes"]
    n = len(nodes)
    cx, cy = (ax0 + ax1) / 2, (ay0 + ay1) / 2 + 6
    rx, ry = (ax1 - ax0) / 2 - 170, (ay1 - ay0) / 2 - 60
    pos = {}
    for i, (name, _role) in enumerate(nodes):
        a = -math.pi / 2 + 2 * math.pi * i / n + (math.pi / n if n % 2 == 0 else 0)
        pos[name] = (cx + rx * math.cos(a), cy + ry * math.sin(a))
    lo, hi = _grow(spec, n)                       # upto：先頭 hi 人と、その人たちのあいだの線だけ
    seen = {nm for nm, _ in nodes[:hi]}
    old = {nm for nm, _ in nodes[:lo]}
    edges = [e for e in spec.get("edges", []) if "upto" not in spec or (e[0] in seen and e[1] in seen)]
    is_old = [e[0] in old and e[1] in old for e in edges]
    n_new = hi - lo
    shown = _ease(t) * (n_new + sum(not o for o in is_old))           # 人 → 線 の順に現れる
    ef = painter.font("gothic", 26)
    j_new = 0
    for (a, b, label), o in zip(edges, is_old):
        if not o:
            if shown < n_new + j_new + 0.5:
                break
            j_new += 1
        pa, pb = pos[a], pos[b]
        dr.line([pa, pb], fill=RED, width=5)
        ang = math.atan2(pb[1] - pa[1], pb[0] - pa[0])            # 矢印
        tip = (pb[0] - 92 * math.cos(ang), pb[1] - 92 * math.sin(ang) * 0.6)
        for s in (2.6, -2.6):
            dr.line([tip, (tip[0] + 22 * math.cos(ang + s), tip[1] + 22 * math.sin(ang + s))], fill=RED, width=5)
        mx, my = (pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2
        w = ef.getlength(label) + 24
        dr.rounded_rectangle([mx - w / 2, my - 20, mx + w / 2, my + 20], radius=8, fill=(255, 248, 230), outline=RED,
                             width=2)
        dr.text((mx, my), label, font=ef, fill=RED, anchor="mm")
    nf = painter.font("serif", 32, bold=True)
    rf = painter.font("gothic", 22)
    for i, (name, role) in enumerate(nodes):
        if i >= hi or (i >= lo and shown < i - lo + 0.5):
            break
        x, y = pos[name]
        w = max(nf.getlength(name), rf.getlength(role)) + 40
        crossed = name in spec.get("cross", [])
        dr.rounded_rectangle([x - w / 2, y - 44, x + w / 2, y + 44], radius=12,
                             fill=(250, 244, 228), outline=(COAST if not crossed else (120, 120, 120)), width=3)
        dr.text((x, y - 12), name, font=nf, fill=INKD, anchor="mm")
        dr.text((x, y + 24), role, font=rf, fill=(110, 90, 60), anchor="mm")
        if crossed and (t >= 1 or i < lo):
            dr.line([x - w / 2 + 8, y + 40, x + w / 2 - 8, y - 40], fill=(90, 90, 90, 180), width=4)
