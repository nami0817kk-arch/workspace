"""物語型の本編（横 16:9）の画面の部品（chiso/storymain.py、10-24）。"""
from pathlib import Path

from PIL import Image

from chiso import storymain as M
from chiso import storyshort as S

FONT = "C:/Windows/Fonts/YuGothB.ttc"


def test_blocks_are_the_narration_and_fit_twenty_chars_two_rows():
    text = "1583年4月、最期の夜を迎える北ノ庄城に、ひとりの女がいました。城を囲む兵たちは、驚いたといいます。"
    bl = M.blocks(text)
    joined = "".join(S.screen_plain("".join(u.text for u in b.units)) for b in bl)
    assert joined == text.replace("、", "").replace("。", "")
    for b in bl:
        assert 1 <= len(b.rows) <= 2
        for r in b.rows:
            assert len(S.screen_plain("".join(u.text for u in r))) <= M.ROW_MAX


def test_short_blocks_unchanged_by_row_max_param():
    text = "お市は、信長の死後、柴田勝家と再婚した。"
    assert [b.rows for b in S.blocks_of(text)] == [b.rows for b in S.blocks_of(text, row_max=S.ROW_MAX)]


def test_band_stays_in_top_14_percent_and_title_does_not_touch_bar():
    if not Path(FONT).exists():
        return
    font_of = S.make_font_of({"gothic": FONT})
    lay = Image.new("RGBA", (M.MW, M.MH), (0, 0, 0, 0))
    M.draw_band(lay, {"tag": "お市の方（織田信長の妹）", "title": "なぜ《二度目の落城》で、逃げなかったのか"}, "1583年 北ノ庄城",
                ["1573 小谷", "1583 北ノ庄", "1615 大坂", "1629 天皇家"], 1, font_of)
    assert lay.getbbox()[3] <= M.MH * 0.14
    row = lay.crop((0, 80, M.MW, 130)).convert("L")          # 題とバーの段：字の無い（暗い）所が 100px 以上続く
    cols = [any(row.getpixel((x, y)) > 60 for y in range(0, 50, 2)) for x in range(M.MW)]
    gaps, run = [], 0
    for on in cols[200:M.MW - 200]:
        run = 0 if on else run + 1
        gaps.append(run)
    assert max(gaps) >= 100


def test_imagined_line_gets_tag_and_name():
    class L:
        speaker, imagined = "お市想像", True
    assert M.speaker_tag(L()) == ("想像", M.IMAGINED_COLOR, "お市（想像）")
    L.speaker, L.imagined = "語り", False
    assert M.speaker_tag(L()) is None
