"""物語完結型ショート（chiso/storyshort.py）。声・絵の生成は使わない部分だけ。"""
from pathlib import Path

from PIL import Image

from chiso import storyshort as S

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "story" / "oichi_s1.yaml"


def test_oichi_script_passes_checks():
    assert S.problems(S.load(SCRIPT)) == []


def test_phrase_plain_marks_yellow():
    plain, mask = S.phrase_plain("兄と夫が《敵》に")
    assert plain == "兄と夫が敵に" and mask == [False] * 4 + [True, False]


def test_plan_splits_cuts_in_a_line_by_length_and_fits_60s():
    lines = S.lines_of(S.load(SCRIPT))
    voice, segs, total = S.plan(lines, [5.0] * len(lines))
    assert segs[0].start == 0 and abs(segs[-1].end - total) < 1e-6
    assert all(b.start == a.end for a, b in zip(segs, segs[1:]))
    assert total == voice[-1][1] + S.END_HOLD


def test_crop_vertical_is_9_16_and_trims_white_bars():
    im = Image.new("RGB", (1024, 1024), (255, 255, 255))
    im.paste(Image.new("RGB", (1024, 940), (40, 30, 20)), (0, 42))
    out = S.crop_vertical(im)
    assert out.size == (S.W, S.H)
    assert out.getpixel((540, 10)) != (255, 255, 255)


def test_phrase_layout_big_and_within_width():
    from PIL import ImageFont
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    if not Path(fonts["gothic"]).exists():
        return
    font_of = S.make_font_of(fonts)
    size, rows = S.phrase_layout("三人の《それぞれの道》", font_of)
    assert len(rows) == 2 and size >= 128
    assert all(font_of(size).getlength(r) <= S.PHRASE_WIDTH for r, _ in rows)
