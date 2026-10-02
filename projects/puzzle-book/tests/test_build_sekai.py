import json
import re
from pathlib import Path

import pymupdf
import pytest

import kdp_spec
from build_sekai import LANGS, SekaiSpec, build_cover, build_pdf, item_page, load_items, page_count

_ROOT = Path(__file__).resolve().parent.parent
_SPEC = _ROOT / "books" / "sekai-kotowaza-vol1.json"
B = kdp_spec.COVER_BLEED_IN * 72


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    spec = SekaiSpec.load(_SPEC)
    spec.edition_date = "2026年10月10日"
    d = tmp_path_factory.mktemp("sekai")
    interior, cover = d / "interior.pdf", d / "cover.pdf"
    total = build_pdf(spec, str(interior))
    build_cover(spec, str(cover))
    return spec, interior, cover, total


def _spans(path):
    for page in pymupdf.open(str(path)):
        for b in page.get_text("dict")["blocks"]:
            for ln in b.get("lines", []):
                for s in ln["spans"]:
                    if s["text"].strip():
                        yield page, s


def test_every_phrase_is_verified_with_two_sources():
    spec = SekaiSpec.load(_SPEC)
    ver = json.loads((_ROOT / spec.verified).read_text(encoding="utf-8"))
    assert len(ver) == 50
    for r in ver:
        for k, _ in LANGS:
            assert r[k]["match"] in ("同じ", "近い"), (r["jp"], k)
            assert len(set(r[k]["sources"])) >= 2, (r["jp"], k)
            assert all(u.startswith("http") for u in r[k]["sources"])


def test_fifty_items_in_five_chapters():
    spec = SekaiSpec.load(_SPEC)
    items = load_items(spec)
    assert len(items) == 50 and len({it["src"] for it in items}) == 50
    assert all(len(ch["items"]) == 10 for ch in spec.chapters)
    assert all(re.fullmatch(r"[ぁ-ゖー]+", it["kana"]) for it in items)
    # ひとくち話と意味は日本語の書体で組むので、ハングルを入れない
    assert not [it["jp"] for it in items if re.search(r"[가-힣]", it["story"] + it["mean"])]


def test_page_size_has_bleed(built):
    spec, interior, _, total = built
    doc = pymupdf.open(str(interior))
    trim = kdp_spec.TRIMS[spec.trim]
    assert len(doc) == total == page_count(spec) and total % 2 == 0
    assert {(round(p.rect.width, 1), round(p.rect.height, 1)) for p in doc} == {
        (round(trim.width_in * 72 + B, 1), round(trim.height_in * 72 + 2 * B, 1))
    }


def test_text_inside_safe_area(built):
    spec, interior, _, _ = built
    trim = kdp_spec.TRIMS[spec.trim]
    tw, th, safe = trim.width_in * 72, trim.height_in * 72, 0.375 * 72
    out = []
    for page, s in _spans(interior):
        n = page.number + 1
        x0 = 0 if n % 2 == 1 else B
        x_a, y_a, x_b, y_b = s["bbox"]
        if x_a < x0 + safe - 0.5 or x_b > x0 + tw - safe + 0.5 or y_a < B + safe - 0.5 or y_b > B + th - safe + 0.5:
            out.append((n, s["text"][:10]))
    assert not out, out[:5]


def test_fonts_glyphs_and_sizes(built):
    _, interior, cover, _ = built
    for path in (interior, cover):
        doc = pymupdf.open(str(path))
        assert not {f[3] for p in doc for f in p.get_fonts() if f[1] == "n/a"}
        assert not [p.number + 1 for p in doc if "\x00" in p.get_text() or "�" in p.get_text()]
        assert min(s["size"] for _, s in _spans(path)) >= 6.99
    thin = [(p.number + 1, d["width"]) for p in pymupdf.open(str(interior)) for d in p.get_drawings()
            if d.get("type") in ("s", "fs") and d.get("width") and d["width"] < 0.74]
    assert not thin


def test_phrases_printed_exactly(built):
    spec, interior, _, _ = built
    doc = pymupdf.open(str(interior))
    items = load_items(spec)
    miss = []
    for k, it in enumerate(items):
        page = re.sub(r"\s+", "", doc[item_page(spec, k) - 1].get_text()).replace("近い言い方", "")
        for lang, _ in LANGS:
            if re.sub(r"\s+", "", it[lang]["text"]) not in page:
                miss.append((k + 1, lang))
    assert not miss, miss[:5]


def test_cover_size_and_barcode(built):
    spec, _, cover, total = built
    trim = kdp_spec.TRIMS[spec.trim]
    page = pymupdf.open(str(cover))[0]
    exp_w = (0.25 + 2 * trim.width_in + kdp_spec.spine_width_in(total, "white", spec.ink)) * 72
    assert abs(page.rect.width - exp_w) < 0.1
    bw, bh = (v * 72 for v in kdp_spec.BARCODE_BOX_IN)
    right, bottom = B + trim.width_in * 72 - 18, B + trim.height_in * 72 - 18
    box = pymupdf.Rect(right - bw, bottom - bh, right, bottom)
    assert not [s["text"] for _, s in _spans(cover) if pymupdf.Rect(s["bbox"]).intersects(box)]
    raw = b"".join(pymupdf.open(str(cover)).xref_stream(x) for x in page.get_contents())
    assert not re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw)


def test_colophon_credits(built):
    spec, interior, _, _ = built
    last = pymupdf.open(str(interior))[-1].get_text()
    assert spec.title in last and "Noto Emoji" in last and "Nanum Gothic" in last and "Noto Sans TC" in last


def test_a5_print_cost():
    assert kdp_spec.print_cost_jpy(64, "premium", "a5") == 206 + 4 * 64
    assert kdp_spec.print_cost_jpy(80, "premium", "a4") == 206 + 5 * 80
    assert not kdp_spec.is_large("a5") and kdp_spec.is_large("a4")
