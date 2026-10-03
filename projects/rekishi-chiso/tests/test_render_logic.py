from types import SimpleNamespace as NS

from chiso import lipsync, video


def test_segments_merge_and_cover_length():
    segs = lipsync.segments([False, True, True, False], [(0.15, 0.3)], 0.4)
    assert abs(sum(d for d, _, _ in segs) - 0.4) < 1e-9
    assert any(e for _, _, e in segs)                  # まばたきが入る
    assert any(m for _, m, _ in segs)                  # 口が開く


def test_blinks_are_stable():
    assert lipsync.blinks(3, 20.0) == lipsync.blinks(3, 20.0)
    assert all(abs((b - a) - lipsync.BLINK_LENGTH) < 1e-9 for a, b in lipsync.blinks(3, 20.0))


def test_runs_switch_background_in_section_gap():
    pa, pb = NS(image="a"), NS(image="b")
    L = lambda pic, sec: NS(background=pic, section=sec)
    cues = [NS(line=L(pa, 0), start=0.3, end=2.0), NS(line=L(pb, 1), start=3.2, end=5.0)]
    runs = video.runs_of(cues, 6.0)
    assert [r.picture for r in runs] == [pa, pb]
    assert runs[1].start == 2.0                        # 前の行の話し終わり（節の頭の間）で替わる
