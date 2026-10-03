"""世界の通貨辞典（A5・裁ち落としあり・オールカラー）。

1ページに1通貨。国旗・通貨コードと記号・補助単位・使っている国と地域・円との為替（今と10年前）・為替制度・
名前の由来・豆知識。データは books/currency-data.json（為替は全通貨同じ日付。出典は通貨ごとに記録）。
国旗は assets/flags（flag-icons、MIT）。お札や硬貨の図柄は、各国の法律の制限があるので載せない。
紙面の部品は build_sekai・build_metals と共通。
"""

from __future__ import annotations

import argparse
import json
import warnings
from dataclasses import dataclass, field
from pathlib import Path

from reportlab.graphics import renderPDF
from reportlab.lib.colors import CMYKColor
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

import kdp_spec
from art import FONT_ROUNDED, outlined_text
from build_book import FONT_BOLD, FONT_REGULAR
from build_kotoba import CMYK
from build_metals import _has, draw_mix
from build_sekai import (BLEED, GOLD, INK, NAVY, PAPER, SUB, WHITE, Frame, _heading, _para, fill_page, folio, frame,
                         kana_key, wrap, wrap_even)

_ROOT = Path(__file__).resolve().parent.parent
FLAG_DIR = _ROOT / "assets" / "flags"

# 地域（章）と色。通貨ごとの地域と、ページに出す国旗（多くの国で使う通貨は主な国を並べる）
REGIONS = [
    ("アジア・オセアニア", (0.0, 0.70, 0.90, 0.05), (0.0, 0.08, 0.11, 0.0)),
    ("ヨーロッパ", (0.85, 0.50, 0.0, 0.10), (0.10, 0.05, 0.0, 0.0)),
    ("南北アメリカ", (0.70, 0.0, 0.85, 0.10), (0.08, 0.0, 0.10, 0.0)),
    ("中東", (0.0, 0.30, 0.95, 0.12), (0.0, 0.04, 0.12, 0.0)),
    ("アフリカ", (0.45, 0.75, 0.0, 0.10), (0.06, 0.09, 0.0, 0.0)),
]
REGION_COLOR = {r: (c, t) for r, c, t in REGIONS}
CUR = {
    "JPY": ("アジア・オセアニア", ["jp"]), "CNY": ("アジア・オセアニア", ["cn"]), "KRW": ("アジア・オセアニア", ["kr"]),
    "TWD": ("アジア・オセアニア", ["tw"]), "HKD": ("アジア・オセアニア", ["hk"]), "SGD": ("アジア・オセアニア", ["sg"]),
    "THB": ("アジア・オセアニア", ["th"]), "VND": ("アジア・オセアニア", ["vn"]), "IDR": ("アジア・オセアニア", ["id"]),
    "PHP": ("アジア・オセアニア", ["ph"]), "MYR": ("アジア・オセアニア", ["my"]), "INR": ("アジア・オセアニア", ["in"]),
    "PKR": ("アジア・オセアニア", ["pk"]), "BDT": ("アジア・オセアニア", ["bd"]), "NPR": ("アジア・オセアニア", ["np"]),
    "MNT": ("アジア・オセアニア", ["mn"]), "KZT": ("アジア・オセアニア", ["kz"]), "KHR": ("アジア・オセアニア", ["kh"]),
    "AUD": ("アジア・オセアニア", ["au"]), "NZD": ("アジア・オセアニア", ["nz"]),
    "EUR": ("ヨーロッパ", ["eu"]), "GBP": ("ヨーロッパ", ["gb"]), "CHF": ("ヨーロッパ", ["ch"]), "RUB": ("ヨーロッパ", ["ru"]),
    "TRY": ("ヨーロッパ", ["tr"]), "SEK": ("ヨーロッパ", ["se"]), "NOK": ("ヨーロッパ", ["no"]), "DKK": ("ヨーロッパ", ["dk"]),
    "ISK": ("ヨーロッパ", ["is"]), "PLN": ("ヨーロッパ", ["pl"]), "CZK": ("ヨーロッパ", ["cz"]), "HUF": ("ヨーロッパ", ["hu"]),
    "UAH": ("ヨーロッパ", ["ua"]),
    "USD": ("南北アメリカ", ["us"]), "CAD": ("南北アメリカ", ["ca"]), "MXN": ("南北アメリカ", ["mx"]),
    "BRL": ("南北アメリカ", ["br"]), "ARS": ("南北アメリカ", ["ar"]), "VES": ("南北アメリカ", ["ve"]),
    "PEN": ("南北アメリカ", ["pe"]), "CLP": ("南北アメリカ", ["cl"]), "COP": ("南北アメリカ", ["co"]),
    "PAB": ("南北アメリカ", ["pa"]), "XCD": ("南北アメリカ", ["ag", "dm", "gd", "kn", "lc", "vc"]),
    "SAR": ("中東", ["sa"]), "AED": ("中東", ["ae"]), "KWD": ("中東", ["kw"]), "IRR": ("中東", ["ir"]),
    "ILS": ("中東", ["il"]), "QAR": ("中東", ["qa"]), "BHD": ("中東", ["bh"]), "OMR": ("中東", ["om"]),
    "ZAR": ("アフリカ", ["za"]), "EGP": ("アフリカ", ["eg"]), "XOF": ("アフリカ", ["sn", "ci", "ml", "bf", "ne", "bj"]),
    "XAF": ("アフリカ", ["cm", "ga", "td", "cg", "cf", "gq"]), "ZWG": ("アフリカ", ["zw"]), "NGN": ("アフリカ", ["ng"]),
    "KES": ("アフリカ", ["ke"]), "MAD": ("アフリカ", ["ma"]),
}
# 為替制度の短い説明（ページの下に添える）
REGIME_NOTE = {
    "自由変動相場制": "市場の売り買いだけで値段が決まります。",
    "変動相場制": "市場で値段が決まり、中央銀行がときどき売り買いして動きをならします。",
    "その他の管理": "中央銀行が強く関わりながら、値段を動かしています。",
    "通貨ボード制": "決めた外貨と同じ額を手もとに持ち、その外貨との交換比率を固定します。",
    "固定相場制": "ほかの通貨（または通貨のかご）との交換比率を固定しています。",
    "独自の法定通貨なし": "自分の国の通貨を持たず、ほかの国の通貨を使っています。",
}
FRONT_PAGES = 6  # 表題・はじめに・この本の見方・為替のしくみ・価値くらべ・もくじ
BACK_PAGES = 3  # さくいん・参考にした資料・奥付


@dataclass
class CurrencySpec:
    title: str
    subtitle: str
    data: str
    publisher: str = "つるはし社"
    trim: str = "a5"
    ink: str = "premium"
    edition_date: str = ""
    extra: dict = field(default_factory=dict)

    @classmethod
    def load(cls, path: str | Path) -> "CurrencySpec":
        return cls(**json.loads(Path(path).read_text(encoding="utf-8")))


def load_currencies(spec: CurrencySpec) -> tuple[list[dict], dict]:
    d = json.loads((_ROOT / spec.data).read_text(encoding="utf-8"))
    order = {r: i for i, (r, *_x) in enumerate(REGIONS)}
    cs = d["currencies"]
    for x in cs:
        x["region"], x["flags"] = CUR[x["code"]]
    # 地域の順。地域の中は、日本の読者になじみのある順（データの並び）のまま
    cs = sorted(cs, key=lambda x: order[x["region"]])
    return cs, d["meta"]


def chapters(cs: list[dict]) -> list[tuple[str, list[int]]]:
    return [(r, [k for k, x in enumerate(cs) if x["region"] == r]) for r, *_x in REGIONS]


def page_count(cs: list[dict]) -> int:
    return FRONT_PAGES + sum(1 + len(i) for _, i in chapters(cs)) + BACK_PAGES


def item_page(cs: list[dict], k: int) -> int:
    p = FRONT_PAGES
    for _, idx in chapters(cs):
        p += 1
        for j in idx:
            p += 1
            if j == k:
                return p
    raise IndexError(k)


def chapter_page(cs: list[dict], ci: int) -> int:
    return FRONT_PAGES + 1 + sum(1 + len(i) for _, i in chapters(cs)[:ci])


# --- 国旗 ------------------------------------------------------------------------


_FLAG_CACHE: dict[str, object] = {}


def draw_flag(c: canvas.Canvas, code: str, x: float, y: float, w: float) -> float:
    """国旗（4:3）を (x, y) を左下に幅 w で置き、細い灰色の縁を付ける。高さを返す。"""
    from svglib.svglib import svg2rlg

    path = FLAG_DIR / f"{code}.svg"
    h = w * 0.75
    if code not in _FLAG_CACHE:
        from art import _convert

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            dr = svg2rlg(str(path))
        _convert(dr)  # 国旗の色を CMYK に（KDP の表紙・本文は CMYK で入れる）
        _FLAG_CACHE[code] = dr
    d = _FLAG_CACHE[code]
    s = w / d.width
    c.saveState()
    c.translate(x, y)
    c.scale(s, h / d.height)
    renderPDF.draw(d, c, 0, 0)
    c.restoreState()
    c.setStrokeColorCMYK(0, 0, 0, 0.25)
    c.setLineWidth(0.75)
    c.rect(x, y, w, h, stroke=1, fill=0)
    return h


# --- 数の書き方 ------------------------------------------------------------------


def yen_text(v: float) -> str:
    if v >= 100:
        return f"{v:,.2f}".rstrip("0").rstrip(".")
    return f"{v:,.2f}"


def unit_text(x: dict, r: dict) -> str:
    u = r.get("unit", 1)
    return f"{u:,}{x['short']}" if u != 1 else f"1{x['short']}"


def printable(text: str) -> str:
    """本の書体（日本語・欧文）で描けない字を含む（ ）の部分を省く（タイ文字・ハングル・アラビア文字の綴りなど）。"""
    import re

    def ok(t: str) -> bool:
        return all(_has(FONT_REGULAR, ch) or _has("LAT", ch) for ch in t)

    out = re.sub(r"（[^（）]*）|\([^()]*\)", lambda m: m.group(0) if ok(m.group(0)) else "", text)
    return "".join(ch for ch in out if ok(ch))


def fit_name(c: canvas.Canvas, name: str, width: float) -> tuple[str, float]:
    """もくじ・さくいん用。8.5pt から 7pt まで縮め、それでも入らなければ（ ）の補足を外す。"""
    import re

    fs = 8.5
    while c.stringWidth(name, FONT_REGULAR, fs) > width and fs > 7:
        fs -= 0.25
    if c.stringWidth(name, FONT_REGULAR, fs) > width:
        name = re.sub(r"（.*?）", "", name)
    return name, fs


def symbol_ok(sym: str) -> bool:
    return bool(sym) and all(_has(FONT_REGULAR, ch) or _has("LAT", ch) for ch in sym)


# --- 1通貨のページ ----------------------------------------------------------------


def draw_currency(c: canvas.Canvas, f: Frame, x: dict, no: int, label: str) -> None:
    """収まらなければ、下の2つの枠の字と、国名の一覧を詰めて組み直す。"""
    import io

    last = None
    for tight in (0, 1, 2):
        try:
            _draw_currency(canvas.Canvas(io.BytesIO(), pagesize=(f.pw, f.ph)), f, x, no, label, tight)
        except AssertionError as e:
            last = e
            continue
        return _draw_currency(c, f, x, no, label, tight)
    raise AssertionError(f"1ページに収まらない: {x['code']} {last}")


def _draw_currency(c: canvas.Canvas, f: Frame, x: dict, no: int, label: str, tight: int) -> None:
    col, tint = REGION_COLOR[x["region"]]
    L, R, w = f.left, f.right, f.width
    fill_page(c, f, PAPER)
    band_bottom = f.top - 112
    c.setFillColorCMYK(*col)
    c.rect(0, band_bottom, f.pw, f.ph - band_bottom, stroke=0, fill=1)
    # 国旗
    flags = x["flags"]
    if len(flags) == 1:
        fw = 84
        c.setFillColorCMYK(*WHITE)
        c.rect(L - 3, f.top - 6 - fw * 0.75 - 3, fw + 6, fw * 0.75 + 6, stroke=0, fill=1)
        draw_flag(c, flags[0], L, f.top - 6 - fw * 0.75, fw)
        nx = L + fw + 16
    else:
        fw = 38
        for i, fc in enumerate(flags[:6]):
            fx = L + (i % 2) * (fw + 4)
            fy = f.top - 4 - (i // 2 + 1) * (fw * 0.75 + 4)
            draw_flag(c, fc, fx, fy, fw)
        nx = L + 2 * fw + 4 + 16
    # 名前・コード・記号
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 9)
    c.drawString(nx, f.top - 12, f"{no:02d}　{x['region']}")
    fs = 28
    while c.stringWidth(x["name"], FONT_ROUNDED, fs) > R - nx and fs > 12:
        fs -= 0.5
    c.setFont(FONT_ROUNDED, fs)
    c.drawString(nx, f.top - 16 - fs, x["name"])
    code_y = f.top - 34 - fs
    c.setFont("LAT-B", 15)
    c.drawString(nx, code_y - 12, x["code"])
    cw = c.stringWidth(x["code"], "LAT-B", 15)
    sym = x.get("symbol") or ""
    if symbol_ok(sym):
        c.setFont(FONT_BOLD, 9)
        c.drawString(nx + cw + 12, code_y - 11, "記号")
        draw_mix(c, nx + cw + 12 + 22, code_y - 12, sym, FONT_BOLD, 14)
    sub = x.get("subunit") or {}
    if sub.get("name"):
        c.setFont(FONT_REGULAR, 8.5)
        per = sub.get("per_unit")
        sname = printable(sub["name"])
        txt = f"補助単位: 1{x['short']}＝{per}{sname}" if per else f"補助単位: {sname}"
        draw_mix(c, nx, code_y - 28, wrap_even(c, txt, FONT_REGULAR, 8.5, R - nx, False)[0], FONT_REGULAR, 8.5)
    y = band_bottom - 22
    # いくら？（今と10年前）
    now, old = x.get("rate_now") or {}, x.get("rate_10y") or {}
    if x["code"] != "JPY" and now.get("yen"):
        bh = 78 if old.get("yen") else 52
        c.setFillColorCMYK(*WHITE)
        c.roundRect(L, y - bh, w, bh, 4, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.rect(L, y - bh, 4, bh, stroke=0, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 9)
        c.drawString(L + 14, y - 15, "日本円にすると")
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 7.5)
        c.drawRightString(R - 10, y - 15, f"{now['date'].replace('-', '/')} 時点")
        c.setFillColorCMYK(*INK)
        big = f"{unit_text(x, now)} ＝ {yen_text(now['yen'])}円"
        bfs_ = 20
        while c.stringWidth(big, FONT_ROUNDED, bfs_) > w - 28 and bfs_ > 9:
            bfs_ -= 0.5
        c.setFont(FONT_ROUNDED, bfs_)
        c.drawString(L + 14, y - 40, big)
        if old.get("yen"):
            ratio = (now["yen"] / now.get("unit", 1)) / (old["yen"] / old.get("unit", 1))
            pct = (ratio - 1) * 100
            c.setFont(FONT_REGULAR, 8.5)
            c.setFillColorCMYK(*SUB)
            ot = f"10年前（{old['date'][:4]}年）は {unit_text(x, old)} ＝ {yen_text(old['yen'])}円"
            ofs = 8.5
            while c.stringWidth(ot, FONT_REGULAR, ofs) > w - 28 and ofs > 7:
                ofs -= 0.25
            c.setFont(FONT_REGULAR, ofs)
            c.drawString(L + 14, y - 58, ot)
            if abs(pct) < 5:
                msg = "この10年で、円との値打ちはほぼ同じです"
            elif pct > 0:
                msg = f"この10年で、この通貨は円に対して約{pct:.0f}%高くなりました（円安）"
            else:
                msg = f"この10年で、この通貨は円に対して約{-pct:.0f}%安くなりました（円高）"
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_BOLD, 8.5)
            c.drawString(L + 14, y - 71, msg)
        y -= bh + 12
    elif x["code"] == "JPY":
        c.setFillColorCMYK(*WHITE)
        c.roundRect(L, y - 40, w, 40, 4, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        c.setFont(FONT_BOLD, 9.5)
        c.drawString(L + 14, y - 24, "この本の為替は、すべて「日本円でいくらか」で示しています。")
        y -= 52
    # 1万円で、いくら？（旅行の目安）
    if x["code"] != "JPY" and now.get("yen"):
        per_yen = now.get("unit", 1) / now["yen"]
        amount = 10000 * per_yen
        amt = f"{amount:,.0f}" if amount >= 100 else f"{amount:,.2f}"
        c.setFillColorCMYK(*tint)
        c.roundRect(L, y - 30, w, 30, 4, stroke=0, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 9)
        c.drawString(L + 12, y - 19, "1万円は")
        c.setFillColorCMYK(*INK)
        t_amt = f"約 {amt} {x['short']}"
        afs = 15
        while c.stringWidth(t_amt, FONT_ROUNDED, afs) > w - 170 and afs > 10:
            afs -= 0.5
        c.setFont(FONT_ROUNDED, afs)
        c.drawString(L + 52, y - 20, t_amt)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 7)
        c.drawRightString(R - 10, y - 19, "両替の手数料は含みません")
        y -= 44
    # 使っている国・地域
    cts = x.get("countries") or {}
    off, unoff = cts.get("official") or [], cts.get("unofficial") or []
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 11.5)
    c.drawString(L, y, "使っている国・地域")
    y -= 15
    c.setFillColorCMYK(*INK)
    text = printable("、".join(off))
    cfs, cg = 8.5, 12
    lines = wrap(c, text, FONT_REGULAR, cfs, w, "list")
    if len(lines) > 3 or tight == 2:  # 国の多い通貨（米ドル・ユーロなど）は字を小さく
        cfs, cg = 7.5, 10
        lines = wrap(c, text, FONT_REGULAR, cfs, w, "list")
    for ln in lines[:6]:
        draw_mix(c, L, y, ln, FONT_REGULAR, cfs)
        y -= cg
    if unoff:
        c.setFillColorCMYK(*SUB)
        t2 = printable("正式ではないが広く使われる: " + "、".join(unoff))
        for ln in wrap(c, t2, FONT_REGULAR, 8, w, "list")[:2]:
            draw_mix(c, L, y, ln, FONT_REGULAR, 8)
            y -= 11
    y -= 6
    # 為替のしくみ・発行する中央銀行
    rg = (x.get("regime") or {}).get("classification", "")
    c.setFillColorCMYK(*NAVY)
    c.setFont(FONT_ROUNDED, 11.5)
    c.drawString(L, y, "為替のしくみ")
    y -= 15
    c.setFillColorCMYK(*col)
    c.roundRect(L, y - 4, c.stringWidth(rg, FONT_BOLD, 9) + 14, 15, 7, stroke=0, fill=1)
    c.setFillColorCMYK(*WHITE)
    c.setFont(FONT_BOLD, 9)
    c.drawString(L + 7, y, rg)
    note = next((v for k, v in REGIME_NOTE.items() if k in rg), "")
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_REGULAR, 8.5)
    nx2 = L + c.stringWidth(rg, FONT_BOLD, 9) + 22
    for ln in wrap_even(c, note, FONT_REGULAR, 8.5, R - nx2, False)[:2]:
        c.drawString(nx2, y, ln)
        y -= 11.5
    y -= 6
    # 10年の動き（1単位の円の値を棒で比べる）
    if x["code"] != "JPY" and now.get("yen") and old.get("yen") and tight < 2:
        v_old = old["yen"] / old.get("unit", 1)
        v_now = now["yen"] / now.get("unit", 1)
        top_v = max(v_old, v_now)
        y -= 4
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_ROUNDED, 11.5)
        c.drawString(L, y, "10年の動き")
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 7)
        c.drawString(L + 70, y + 1, f"1{x['short']}が何円か（棒が長いほど、この通貨が高い）")
        y -= 14
        for lab, v in ((old["date"][:4] + "年", v_old), (now["date"][:4] + "年", v_now)):
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_BOLD, 8.5)
            c.drawString(L, y, lab)
            bw_ = (w - 120) * v / top_v
            c.setFillColorCMYK(*(col if lab.startswith(now["date"][:4]) else (0, 0, 0, 0.25)))
            c.rect(L + 42, y - 1, max(bw_, 1.5), 9, stroke=0, fill=1)
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_REGULAR, 8.5)
            vt = f"{v:,.2f}円" if v >= 0.01 else f"{v:.4f}円"
            c.drawRightString(R, y, vt)
            y -= 13
        y -= 4
    cb = x.get("central_bank", "")
    if cb:
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_REGULAR, 8)
        for ln in wrap(c, printable("発行: " + cb), FONT_REGULAR, 8, w, False)[:2]:
            draw_mix(c, L, y, ln, FONT_REGULAR, 8)
            y -= 11
    # 名前の由来・豆知識（下にそろえる）
    boxes = [("名前の由来", printable(x.get("origin", ""))), ("豆知識", printable(x.get("trivia", "")))]
    bfs, bg = (8.5, 12) if tight == 0 else (8, 11) if tight == 1 else (7.5, 10)
    lays = [(t, wrap_even(c, s, FONT_REGULAR, bfs, w - 24, False)) for t, s in boxes if s]
    need = sum(22 + bg * len(ls) + 6 for _, ls in lays)
    y_box = f.bottom + need
    assert y - 8 >= y_box, (x["code"], y - 8 - y_box)
    yy = y_box
    for title, ls in lays:
        bh = 22 + bg * len(ls)
        c.setFillColorCMYK(*tint)
        c.roundRect(L, yy - bh, w, bh, 3, stroke=0, fill=1)
        c.setFillColorCMYK(*col)
        c.rect(L + 10, yy - 15, 6, 6, stroke=0, fill=1)
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_BOLD, 9)
        c.drawString(L + 21, yy - 15, title)
        c.setFillColorCMYK(*INK)
        for li, ln in enumerate(ls):
            draw_mix(c, L + 12, yy - 29 - li * bg, ln, FONT_REGULAR, bfs)
        yy -= bh + 6
    folio(c, f, label)


# --- 本文 ------------------------------------------------------------------------


def build_pdf(spec: CurrencySpec, output_path: str) -> int:
    cs, meta = load_currencies(spec)
    for x in cs:
        x["short"] = spec.extra.get("short", {}).get(x["code"], x["name"])
    chs = chapters(cs)
    t = kdp_spec.TRIMS[spec.trim]
    c = canvas.Canvas(output_path, pagesize=(t.width_in * inch + BLEED, t.height_in * inch + 2 * BLEED),
                      initialFontName=FONT_REGULAR)
    c.setTitle(spec.title)
    c.setAuthor(spec.publisher)
    c.setCreator(spec.publisher)
    n = 1

    def page() -> Frame:
        return frame(spec, n)

    def turn() -> None:
        nonlocal n
        c.showPage()
        n += 1

    # 1. 表題
    f = page()
    fill_page(c, f, PAPER)
    c.setFillColorCMYK(*NAVY)
    c.rect(0, f.y0 + (f.y1 - f.y0) * 0.45, f.pw, f.ph, stroke=0, fill=1)
    mid = (f.left + f.right) / 2
    outlined_text(c, spec.title, mid, f.top - 150, font=FONT_ROUNDED, size=30,
                  fill=CMYKColor(*WHITE), outline=CMYKColor(*NAVY), outline_width=1)
    c.setFillColorCMYK(*GOLD)
    c.setFont(FONT_BOLD, 10.5)
    c.drawCentredString(mid, f.top - 185, spec.subtitle)
    fw = 40
    codes = ["jp", "us", "eu", "gb", "cn", "kr", "in", "br"]
    x0 = mid - (len(codes) * (fw + 6) - 6) / 2
    for i, fc in enumerate(codes):
        draw_flag(c, fc, x0 + i * (fw + 6), f.y0 + (f.y1 - f.y0) * 0.30, fw)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_BOLD, 11)
    c.drawCentredString(mid, f.bottom + 10, spec.publisher)
    turn()

    # 2〜4. はじめに・見方・為替のしくみ
    for key, title in (("intro", "はじめに"), ("howto", "この本の見方"), ("fx", "為替のしくみ")):
        f = page()
        fill_page(c, f, PAPER)
        y = _heading(c, f, title)
        for text in spec.extra.get(key, []):
            if text.startswith("■"):
                c.setFillColorCMYK(*NAVY)
                c.setFont(FONT_BOLD, 10.5)
                c.drawString(f.left, y, text[1:])
                y -= 17
                continue
            y = _para(c, f, text, y, fs=9.5, gap=15.5) - 6
        assert y >= f.bottom, (title, y - f.bottom)
        folio(c, f)
        turn()

    # 5. 1単位の価値くらべ
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "1単位で、いくら？")
    vals = [(x["rate_now"]["yen"] / x["rate_now"].get("unit", 1), x) for x in cs
            if x["code"] != "JPY" and (x.get("rate_now") or {}).get("yen")]
    vals.sort(key=lambda v: -v[0])
    y = _para(c, f, f"1単位が何円になるか（{cs[1]['rate_now']['date'].replace('-', '/')} 時点）。高い通貨と低い通貨を10ずつ並べました。"
              "低い通貨は、たくさんの数字を使わないと買い物ができません。", y, fs=9, gap=14) - 6
    for title, rows in (("高い通貨", vals[:10]), ("低い通貨", vals[-10:][::-1])):
        c.setFillColorCMYK(*NAVY)
        c.setFont(FONT_ROUNDED, 11.5)
        c.drawString(f.left, y, title)
        y -= 15
        top = max(v for v, _ in rows)
        for v, x in rows:
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_REGULAR, 8.5)
            c.drawString(f.left, y, x["name"])
            c.setFont("LAT", 7.5)
            c.setFillColorCMYK(*SUB)
            c.drawString(f.left + 100, y, x["code"])
            bw = (f.width - 210) * (v / top) if title == "高い通貨" else (f.width - 210) * min(1, (v / top))
            c.setFillColorCMYK(*REGION_COLOR[x["region"]][0])
            c.rect(f.left + 128, y - 1, max(bw, 1.5), 8, stroke=0, fill=1)
            c.setFillColorCMYK(*INK)
            c.setFont(FONT_BOLD, 8.5)
            vt = f"{v:,.2f}円" if v >= 0.01 else f"{v:.4f}円"
            c.drawRightString(f.right, y, vt)
            y -= 12.5
        y -= 10
    assert y >= f.bottom, y
    folio(c, f)
    turn()

    # 6. もくじ
    f = page()
    fill_page(c, f, PAPER)
    y0 = _heading(c, f, "もくじ") + 6
    col_w = (f.width - 16) / 2
    rows = []
    for ci, (r, idx) in enumerate(chs):
        rows.append(("ch", r, chapter_page(cs, ci)))
        rows += [("it", cs[k], item_page(cs, k)) for k in idx]
    half = (len(rows) + 1) // 2
    for hi, part in enumerate((rows[:half], rows[half:])):
        xx = f.left + hi * (col_w + 16)
        y = y0
        for kind, obj, pno in part:
            if kind == "ch":
                y -= 4
                c.setFillColorCMYK(*REGION_COLOR[obj][0])
                c.roundRect(xx, y - 5, col_w, 17, 5, stroke=0, fill=1)
                c.setFillColorCMYK(*WHITE)
                c.setFont(FONT_ROUNDED, 10)
                c.drawString(xx + 7, y, obj)
                c.setFont(FONT_BOLD, 8.5)
                c.drawRightString(xx + col_w - 7, y, str(pno))
                y -= 18
            else:
                c.setFillColorCMYK(*SUB)
                c.setFont("LAT-B", 7.5)
                c.drawString(xx + 4, y, obj["code"])
                c.setFillColorCMYK(*INK)
                nm, tfs = fit_name(c, obj["name"], col_w - 60)
                c.setFont(FONT_REGULAR, tfs)
                c.drawString(xx + 30, y, nm)
                c.setFont(FONT_REGULAR, 8.5)
                c.setFillColorCMYK(*SUB)
                c.drawRightString(xx + col_w - 7, y, str(pno))
                y -= 10.6
        assert y >= f.bottom - 4, (hi, y - f.bottom)
    folio(c, f)
    turn()

    # 7. 章と各通貨
    no = 0
    for ci, (r, idx) in enumerate(chs):
        f = page()
        rc, rt = REGION_COLOR[r]
        fill_page(c, f, rt)
        c.setFillColorCMYK(*rc)
        c.rect(0, f.y1 - 200, f.pw, 200 + BLEED, stroke=0, fill=1)
        c.setFillColorCMYK(*WHITE)
        c.setFont(FONT_ROUNDED, 44)
        c.drawString(f.left, f.y1 - 110, f"第{ci + 1}章")
        c.setFont(FONT_ROUNDED, 28)
        c.drawString(f.left, f.y1 - 160, r)
        # この章の通貨（国旗とコード）
        fw = (f.width - 4 * 8) / 5
        for j, k in enumerate(idx):
            xx = f.left + (j % 5) * (fw + 8)
            yy = f.y1 - 200 - 14 - (j // 5 + 1) * (fw * 0.75 + 27)
            draw_flag(c, cs[k]["flags"][0], xx, yy + 20, fw)
            c.setFillColorCMYK(*INK)
            nm = cs[k]["name"]
            nl = wrap(c, nm, FONT_BOLD, 7, fw, False)[:2]
            c.setFont(FONT_BOLD, 7)
            for li, ln in enumerate(nl):
                c.drawCentredString(xx + fw / 2, yy + 10 + (len(nl) - 1 - li) * 8.5, ln)
            c.setFillColorCMYK(*SUB)
            c.setFont(FONT_REGULAR, 7)
            c.drawCentredString(xx + fw / 2, yy + 1, f"{item_page(cs, k)}ページ")
        turn()
        for k in idx:
            no += 1
            draw_currency(c, page(), cs[k], no, f"第{ci + 1}章　{r}")
            turn()

    # 8. さくいん（通貨コード順）
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "さくいん（通貨コード順）")
    order = sorted(range(len(cs)), key=lambda k: cs[k]["code"])
    col_w = (f.width - 12) / 2
    per = (len(order) + 1) // 2
    row = (y - f.bottom) / per
    for mm, k in enumerate(order):
        x0 = f.left + (mm // per) * (col_w + 12)
        yy = y - (mm % per) * row
        c.setFillColorCMYK(*REGION_COLOR[cs[k]["region"]][0])
        c.circle(x0 + 3, yy + 3, 2.2, stroke=0, fill=1)
        c.setFillColorCMYK(*INK)
        c.setFont("LAT-B", 8)
        c.drawString(x0 + 10, yy, cs[k]["code"])
        nm, tfs = fit_name(c, cs[k]["name"], col_w - 60)
        c.setFont(FONT_REGULAR, tfs)
        c.drawString(x0 + 38, yy, nm)
        c.setFillColorCMYK(*SUB)
        c.setFont(FONT_BOLD, 8.5)
        c.drawRightString(x0 + col_w, yy, str(item_page(cs, k)))
    folio(c, f)
    turn()

    # 9. 参考にした資料
    f = page()
    fill_page(c, f, PAPER)
    y = _heading(c, f, "参考にした資料")
    for text in spec.extra.get("references", []):
        y = _para(c, f, text, y, fs=9, gap=14) - 6
    folio(c, f)
    turn()

    # 10. 奥付
    f = page()
    fill_page(c, f, PAPER)
    y = f.bottom + 150
    c.setStrokeColorCMYK(*NAVY)
    c.setLineWidth(0.8)
    c.line(f.left, y + 18, f.right, y + 18)
    c.setFillColorCMYK(*INK)
    c.setFont(FONT_BOLD, 11)
    c.drawString(f.left, y, spec.title)
    c.setFont(FONT_REGULAR, 9)
    y -= 20
    if spec.edition_date:
        c.drawString(f.left, y, f"{spec.edition_date}　初版発行")
        y -= 15
    c.drawString(f.left, y, f"発行　{spec.publisher}")
    y -= 15
    year = spec.edition_date[:4] if spec.edition_date[:4].isdigit() else ""
    c.setFont("LAT", 9)
    c.drawString(f.left, y, "©")
    c.setFont(FONT_REGULAR, 9)
    c.drawString(f.left + c.stringWidth("© ", "LAT", 9), y, " ".join(t for t in (year, spec.publisher) if t))
    y -= 20
    c.setFont(FONT_REGULAR, 7.5)
    for line in spec.extra.get("credits", []):
        for part in wrap(c, line, FONT_REGULAR, 7.5, f.width, "list"):
            c.drawString(f.left, y, part)
            y -= 11
    c.line(f.left, y + 2, f.right, y + 2)
    turn()
    c.save()
    return n - 1


COVER_FLAGS = ["us", "eu", "jp", "gb", "cn", "ch", "kr", "in", "au", "ca", "br", "mx", "za", "sa", "tr", "th", "sg", "se", "kw", "eg"]


def build_cover(spec: CurrencySpec, output_path: str) -> tuple[float, float]:
    from simple_cover import build_cover as _bc

    cs, _ = load_currencies(spec)
    code_of = {x["flags"][0]: x["code"] for x in cs}

    def visual(c, x, y, w, h):
        cols, rows = 5, 4
        gap = 8
        fw = min((w - gap * (cols - 1)) / cols, ((h - gap * (rows - 1)) / rows - 12) / 0.75)
        x0 = x + (w - (fw * cols + gap * (cols - 1))) / 2
        cell_h = fw * 0.75 + 12
        y0 = y + (h - (cell_h * rows + gap * (rows - 1))) / 2
        for i, fc in enumerate(COVER_FLAGS[: cols * rows]):
            xx = x0 + (i % cols) * (fw + gap)
            yy = y0 + (rows - 1 - i // cols) * (cell_h + gap)
            draw_flag(c, fc, xx, yy + 12, fw)
            c.setFillColorCMYK(*NAVY)
            c.setFont("LAT-B", 8.5)
            c.drawCentredString(xx + fw / 2, yy + 2, code_of.get(fc, ""))

    ex = spec.extra.get("cover", {})
    return _bc(spec, page_count(cs), output_path, visual, ex.get("tagline", ""), ex.get("blurb", []),
               [tuple(e) for e in ex.get("examples", [])], ex.get("for_whom", []), ex.get("contents", []))


def main() -> None:
    parser = argparse.ArgumentParser(description="世界の通貨辞典の本文PDFを作る")
    parser.add_argument("spec")
    args = parser.parse_args()
    spec = CurrencySpec.load(args.spec)
    stem = Path(args.spec).stem
    Path("output").mkdir(exist_ok=True)
    total = build_pdf(spec, f"output/{stem}-interior.pdf")
    print(f"{total}ページ（印刷代 {kdp_spec.print_cost_jpy(total, spec.ink, spec.trim)}円）-> output/{stem}-interior.pdf")
    w, h = build_cover(spec, f"output/{stem}-cover.pdf")
    print(f"表紙 {w:.4f} x {h:.4f} in -> output/{stem}-cover.pdf")


if __name__ == "__main__":
    main()
