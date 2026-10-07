import json
import re
from pathlib import Path

import pymupdf
import pytest
from fontTools.ttLib import TTFont

import kdp_spec
from build_kaiso import KaisoSpec, build_cover, build_pdf, month_first_page, page_count, topic_page

_ROOT = Path(__file__).resolve().parent.parent
_SPEC = _ROOT / "books" / "kaiso-vol1.json"
SAD = r"死|亡|病|戦争|戦時|疎開|空襲|別れ|認知|介護|葬"


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    spec = KaisoSpec.load(_SPEC)
    spec.edition_date = "2026年10月1日"
    d = tmp_path_factory.mktemp("kaiso")
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


def test_twelve_months_of_eight_topics():
    spec = KaisoSpec.load(_SPEC)
    assert [m["month"] for m in spec.months] == list(range(1, 13))
    assert all(len(m["topics"]) == 8 for m in spec.months)
    assert all(len(t["tane"]) == 3 for t in spec.topics)


def test_questions_and_tane_unique_and_gentle():
    spec = KaisoSpec.load(_SPEC)
    qs = [t["q"] for t in spec.topics]
    tane = [s for t in spec.topics for s in t["tane"]]
    labels = [t["label"] for t in spec.topics]
    assert len(set(qs)) == len(qs) == 96
    assert len(set(tane)) == len(tane) == 288
    assert len(set(labels)) == 96
    assert all(q.endswith(("？", "。")) for q in qs)
    assert all(s.endswith("？") for s in tane)
    bad = [s for s in qs + tane + labels if re.search(SAD, s)]
    assert not bad, bad


def test_not_reusing_talks_from_other_books():
    """ことば探し・あたまの体操の「思い出トーク」と同じ問いを使い回さない。"""
    spec = KaisoSpec.load(_SPEC)
    kotoba = [t["talk"] for t in json.loads((_ROOT / "books" / "kotoba-vol1.json").read_text(encoding="utf-8"))["themes"]]
    notore = [d["talk"] for d in json.loads((_ROOT / "books" / "notore-vol1.json").read_text(encoding="utf-8"))["days"]]
    mine = {t["q"] for t in spec.topics} | {s for t in spec.topics for s in t["tane"]}
    assert not mine & set(kotoba + notore)


def test_icons_exist_and_differ():
    spec = KaisoSpec.load(_SPEC)
    icons = [t["icon"] for t in spec.topics]
    assert len(set(icons)) == 96
    covers = [m["cover_icon"] for m in spec.months]
    assert len(set(covers)) == 12
    missing = [c for c in icons + covers if not (_ROOT / "assets" / "emoji" / f"emoji_u{c}.svg").exists()]
    assert not missing, missing


def test_page_count_even_and_size(built):
    spec, interior, _, total = built
    doc = pymupdf.open(str(interior))
    assert len(doc) == total == page_count(spec) and total % 2 == 0
    trim = kdp_spec.TRIMS[spec.trim]
    assert {(round(p.rect.width, 1), round(p.rect.height, 1)) for p in doc} == {
        (round(trim.width_in * 72, 1), round(trim.height_in * 72, 1))
    }


def test_each_question_printed_on_its_page_and_toc(built):
    spec, interior, _, _ = built
    doc = pymupdf.open(str(interior))
    miss = []
    for mi, month in enumerate(spec.months):
        cover_text = doc[month_first_page(spec, mi) - 1].get_text().replace("\n", "")
        for ti, t in enumerate(month["topics"]):
            text = doc[topic_page(spec, mi, ti) - 1].get_text().replace("\n", "")
            if t["q"] not in text or not all(s in text for s in t["tane"]):
                miss.append(t["label"])
            if f"{topic_page(spec, mi, ti)}ページ" not in cover_text or t["label"] not in cover_text:
                miss.append(("扉", t["label"]))
    toc = doc[3].get_text()
    for mi, month in enumerate(spec.months):
        if not re.search(rf"{month['month']}月[\s\S]*?\n{month_first_page(spec, mi)}\n", toc):
            miss.append(("もくじ", month["month"]))
    assert not miss, miss[:5]


def test_fonts_embedded_cmyk_cover_and_text_size(built):
    _, interior, cover, _ = built
    for path in (interior, cover):
        missing = {f[3] for p in pymupdf.open(str(path)) for f in p.get_fonts() if f[1] == "n/a"}
        assert not missing, (path.name, missing)
        assert min(s["size"] for _, s in _spans(path)) >= 6.99
    doc = pymupdf.open(str(cover))
    raw = b"".join(doc.xref_stream(x) for x in doc[0].get_contents())
    assert not re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw)


def test_min_line_width_and_margins(built):
    _, interior, _, _ = built
    doc = pymupdf.open(str(interior))
    thin = [(p.number + 1, round(d["width"], 2)) for p in doc for d in p.get_drawings()
            if d.get("type") in ("s", "fs") and d.get("width") and d["width"] < 0.74]
    assert not thin, thin[:5]
    for p in doc:
        odd = (p.number + 1) % 2 == 1
        l_, r_ = (27, 18) if odd else (18, 27)
        rects = [pymupdf.Rect(s["bbox"]) for pp, s in _spans(interior) if pp.number == p.number] + [d["rect"] for d in p.get_drawings()]
        out = [r for r in rects if not r.is_empty and (r.x0 < l_ - .5 or r.x1 > p.rect.width - r_ + .5 or r.y0 < 17.5 or r.y1 > p.rect.height - 17.5)]
        assert not out, (p.number + 1, out[:2])


def test_every_character_has_a_glyph(built):
    _, interior, cover, _ = built
    cmaps = [TTFont(str(_ROOT / "assets" / "fonts" / n)).getBestCmap() for n in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")]
    text = "".join(p.get_text() for f in (interior, cover) for p in pymupdf.open(str(f)))
    missing = {ch for ch in text if not ch.isspace() and not all(ord(ch) in cm for cm in cmaps)}
    assert not missing, sorted(missing)


def test_cover_size_barcode_and_overlap(built):
    spec, _, cover, total = built
    trim = kdp_spec.TRIMS[spec.trim]
    page = pymupdf.open(str(cover))[0]
    exp_w = (0.25 + 2 * trim.width_in + kdp_spec.spine_width_in(total, "white", spec.ink)) * 72
    assert abs(page.rect.width - exp_w) < 0.1
    bw, bh = (v * 72 for v in kdp_spec.BARCODE_BOX_IN)
    right = 9 + trim.width_in * 72 - 18
    bottom = 9 + trim.height_in * 72 - 18
    box = pymupdf.Rect(right - bw, bottom - bh, right, bottom)
    boxes = [(pymupdf.Rect(s["bbox"]), s["text"]) for _, s in _spans(cover)]
    assert not [t for r, t in boxes if r.intersects(box)]
    for i, (a, ta) in enumerate(boxes):
        for b, tb in boxes[i + 1:]:
            if ta == tb and all(abs(p - q) < 0.5 for p, q in zip(a, b)):
                continue
            ov = a & b
            assert not (ov.width > 1 and ov.height > 1), (ta, tb)


def test_colophon_credit_and_copy(built):
    _, interior, _, _ = built
    last = pymupdf.open(str(interior))[-1].get_text()
    assert "Noto Emoji" in last and "コピーについて" in last and "ゆったり 思い出ばなし" in last
