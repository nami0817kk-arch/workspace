import json
from pathlib import Path

import pymupdf
import pytest

import build_currency as bc
import build_metals as bmt
import kdp_spec

_ROOT = Path(__file__).resolve().parent.parent
B = kdp_spec.COVER_BLEED_IN * 72


@pytest.fixture(scope="module")
def metals(tmp_path_factory):
    spec = bmt.MetalsSpec.load(_ROOT / "books" / "metals-vol1.json")
    d = tmp_path_factory.mktemp("metals")
    total = bmt.build_pdf(spec, str(d / "i.pdf"))
    bmt.build_cover(spec, str(d / "c.pdf"))
    return spec, d / "i.pdf", d / "c.pdf", total


@pytest.fixture(scope="module")
def currency(tmp_path_factory):
    spec = bc.CurrencySpec.load(_ROOT / "books" / "currency-vol1.json")
    d = tmp_path_factory.mktemp("currency")
    total = bc.build_pdf(spec, str(d / "i.pdf"))
    bc.build_cover(spec, str(d / "c.pdf"))
    return spec, d / "i.pdf", d / "c.pdf", total


def _common(spec, interior, cover, total, n_expected):
    doc = pymupdf.open(str(interior))
    trim = kdp_spec.TRIMS[spec.trim]
    assert len(doc) == total == n_expected
    assert {(round(p.rect.width, 1), round(p.rect.height, 1)) for p in doc} == {
        (round(trim.width_in * 72 + B, 1), round(trim.height_in * 72 + 2 * B, 1))}
    for path in (interior, cover):
        d = pymupdf.open(str(path))
        assert not {f[3] for p in d for f in p.get_fonts() if f[1] == "n/a"}
        assert not [p.number + 1 for p in d if "\x00" in p.get_text() or "�" in p.get_text()]
    return doc


def test_metals_pages_and_photos(metals):
    spec, interior, cover, total = metals
    ms, meta = bmt.load_metals(spec)
    doc = _common(spec, interior, cover, total, bmt.page_count(ms))
    assert len(ms) == 55
    assert not [m["name"] for k, m in enumerate(ms) if m["name"] not in doc[bmt.item_page(ms, k) - 1].get_text()]
    assert not [m["name"] for m in ms if bmt.photo_path(m) is None]
    credits = json.loads((bmt.PHOTO_DIR / "credits.json").read_text(encoding="utf-8"))
    assert len(credits) == 55 and not [c for c in credits if "NC" in c["license"] or "ND" in c["license"]]
    assert not [m["name"] for m in ms if len(set(m["sources"])) < 2]


def test_metal_shares_are_sane():
    ms, _ = bmt.load_metals(bmt.MetalsSpec.load(_ROOT / "books" / "metals-vol1.json"))
    for m in ms:
        top = (m.get("producers") or {}).get("top3") or []
        assert sum(t["share_percent"] for t in top) <= 100.5, m["name"]
        assert [t["share_percent"] for t in top] == sorted((t["share_percent"] for t in top), reverse=True), m["name"]


def test_periodic_table_positions():
    assert bmt.pt_position(1) == (0, 0) and bmt.pt_position(2) == (0, 17)
    assert bmt.pt_position(26) == (3, 7)  # Fe
    assert bmt.pt_position(79) == (5, 10)  # Au
    assert bmt.pt_position(60) == (7, 5)  # Nd（ランタノイドの段）
    assert bmt.pt_position(92) == (8, 5)  # U（アクチノイドの段）


def test_currency_pages_and_rates(currency):
    spec, interior, cover, total = currency
    cs, meta = bc.load_currencies(spec)
    doc = _common(spec, interior, cover, total, bc.page_count(cs))
    assert len(cs) == 60
    assert not [x["code"] for k, x in enumerate(cs) if x["code"] not in doc[bc.item_page(cs, k) - 1].get_text()]
    dates = {x["rate_now"]["date"] for x in cs if x["code"] != "JPY"}
    assert len(dates) == 1
    assert not [x["code"] for x in cs if x["code"] != "JPY" and not x["rate_now"].get("source")]
    assert not [f for x in cs for f in x["flags"] if not (bc.FLAG_DIR / f"{f}.svg").exists()]
    raw = b"".join(d.xref_stream(xx) for d in (doc, pymupdf.open(str(cover))) for p in d for xx in p.get_contents())
    import re
    assert not re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw)  # 国旗も CMYK


def test_covers_keep_barcode_clear(metals, currency):
    for spec, _, cover, _total in (metals, currency):
        trim = kdp_spec.TRIMS[spec.trim]
        page = pymupdf.open(str(cover))[0]
        safe = kdp_spec.COVER_SAFE_IN * 72
        bw, bh = (v * 72 for v in kdp_spec.BARCODE_BOX_IN)
        right, bottom = B + trim.width_in * 72 - safe, B + trim.height_in * 72 - safe
        box = pymupdf.Rect(right - bw, bottom - bh, right, bottom)
        spans = [s for b in page.get_text("dict")["blocks"] for ln in b.get("lines", []) for s in ln["spans"] if s["text"].strip()]
        assert not [s["text"] for s in spans if pymupdf.Rect(s["bbox"]).intersects(box)]
