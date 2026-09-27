import json
import re
from pathlib import Path

import pymupdf
import pytest
from fontTools.ttLib import TTFont
from puzzle_generator import validate_record

import kdp_spec
from build_notore import NotoreSpec, build_cover, build_pdf, generate_days, page_count

_ROOT = Path(__file__).resolve().parent.parent
_SPEC = _ROOT / "books" / "notore-vol1.json"


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    spec = NotoreSpec.load(_SPEC)
    spec.edition_date = "2026年10月1日"
    days = generate_days(spec)
    d = tmp_path_factory.mktemp("notore")
    interior, cover = d / "interior.pdf", d / "cover.pdf"
    total = build_pdf(days, str(interior), spec)
    build_cover(spec, days, str(cover))
    return spec, days, interior, cover, total


def _spans(path):
    for page in pymupdf.open(str(path)):
        for b in page.get_text("dict")["blocks"]:
            for ln in b.get("lines", []):
                for s in ln["spans"]:
                    if s["text"].strip():
                        yield page, s


def test_every_puzzle_verified(built):
    _, days, *_ = built
    assert len(days) == 30
    for day in days:
        for key in ("arithmetic", "number", "right", "clock"):
            validate_record(day[key])


def test_levels_rise_every_ten_days(built):
    _, days, *_ = built
    assert [d["difficulty"] for d in days] == ["easy"] * 10 + ["medium"] * 10 + ["hard"] * 10
    assert days[0]["number"]["board"]["size"] < days[29]["number"]["board"]["size"]


def test_page_count_even_and_flat_size(built):
    spec, _, interior, _, total = built
    doc = pymupdf.open(str(interior))
    assert len(doc) == total == page_count(spec) and total % 2 == 0
    trim = kdp_spec.TRIMS[spec.trim]
    assert {(round(p.rect.width, 1), round(p.rect.height, 1)) for p in doc} == {
        (round(trim.width_in * 72, 1), round(trim.height_in * 72, 1))
    }


def test_arithmetic_answers_match_printed_problems(built):
    """紙面の計算問題（左のページ）を読み、答えのページの数と一致するか計算し直す。"""
    _, days, interior, _, _ = built
    doc = pymupdf.open(str(interior))
    for i, day in enumerate(days):
        text = doc[3 + 2 * i].get_text().replace("\n", " ")
        # 2列に並べているので、並び順ではなく（番号）で問題と答えを対応させる
        probs = {int(k): (int(a), op, int(b)) for k, a, op, b in
                 re.findall(r"\((\d+)\)\s*(\d+)\s*([＋－×])\s*(\d+)\s*＝", text)}
        assert sorted(probs) == list(range(1, 11)), (day["day"], probs)
        # ページ上端の「1日目〜2日目」に引っかからないよう、行としての「N日目」から読む
        block = doc[3 + 60 + i // 2].get_text().split(f"\n{day['day']}日目\n")[1].split("時計")[0]
        answers = {int(k): int(v) for k, v in re.findall(r"\((\d+)\)\s*(\d+)", block)}
        for k, (a, op, b) in probs.items():
            want = a + b if op == "＋" else a - b if op == "－" else a * b
            assert answers.get(k) == want, (day["day"], k, a, op, b, answers.get(k))


def test_no_wordsearch_and_mazes_grow(built):
    """ことば探しは別の本があるので入れない（2026-09-27 指示）。奇数日は迷路で、10日ごとに大きくなる。"""
    _, days, interior, _, _ = built
    kinds = [d["right"]["type"] for d in days]
    assert kinds == ["maze", "pair_search"] * 15
    sizes = [d["right"]["board"]["width"] for d in days if d["right"]["type"] == "maze"]
    assert sizes[0] < sizes[5] < sizes[-1]
    text = "".join(p.get_text() for p in pymupdf.open(str(interior)))
    assert "ことば探し" not in text


def test_talks_are_questions_without_sad_topics():
    spec = json.loads(_SPEC.read_text(encoding="utf-8"))
    for d in spec["days"]:
        assert d["talk"].endswith("？")
        assert not re.search(r"死|亡|病|戦争|別れ|認知", d["talk"]), d["talk"]


def test_fonts_embedded_cmyk_cover_and_text_size(built):
    _, _, interior, cover, _ = built
    for path in (interior, cover):
        missing = {f[3] for p in pymupdf.open(str(path)) for f in p.get_fonts() if f[1] == "n/a"}
        assert not missing, (path.name, missing)
        assert min(s["size"] for _, s in _spans(path)) >= 6.99
    doc = pymupdf.open(str(cover))
    raw = b"".join(doc.xref_stream(x) for x in doc[0].get_contents())
    assert not re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw)


def test_min_line_width_and_margins(built):
    _, _, interior, _, _ = built
    doc = pymupdf.open(str(interior))
    thin = [(p.number + 1, round(d["width"], 2)) for p in doc for d in p.get_drawings()
            if d.get("type") in ("s", "fs") and d.get("width") and d["width"] < 0.74]
    assert not thin, thin[:5]
    for page, s in _spans(interior):
        x0, y0, x1, y1 = s["bbox"]
        assert 18 <= x0 and x1 <= page.rect.width - 18 and 18 <= y0 and y1 <= page.rect.height - 18, (page.number + 1, s["text"])


def test_every_character_has_a_glyph(built):
    _, _, interior, cover, _ = built
    cmaps = [TTFont(str(_ROOT / "assets" / "fonts" / n)).getBestCmap() for n in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")]
    text = "".join(p.get_text() for f in (interior, cover) for p in pymupdf.open(str(f)))
    missing = {ch for ch in text if not ch.isspace() and not all(ord(ch) in cm for cm in cmaps)}
    assert not missing, sorted(missing)


def test_cover_size_barcode_and_overlap(built):
    spec, _, _, cover, total = built
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
    _, _, interior, _, _ = built
    last = pymupdf.open(str(interior))[-1].get_text()
    assert "Noto Emoji" in last and "コピーについて" in last and "ゆったり あたまの体操" in last
