"""物語型の本編（横 16:9）の画面と絵の割り当て（chiso/storymain.py、10-24）。"""
from pathlib import Path

import yaml
from PIL import Image

from chiso import script
from chiso import storymain as M
from chiso import storyshort as S

ROOT = Path(__file__).resolve().parent.parent
FONT = "C:/Windows/Fonts/YuGothB.ttc"
LOOK = ROOT / "scripts/story/oichi_main_look.yaml"


def test_blocks_are_the_narration_and_fit_row_max_two_rows():
    text = "1583年4月、最期の夜を迎える北ノ庄城に、ひとりの女がいました。城を囲む兵たちは、驚いたといいます。"
    bl = M.blocks(text)
    joined = "".join(S.screen_plain(M._btext(b)) for b in bl)
    assert joined == text.replace("、", "").replace("。", "")
    for b in bl:
        assert 1 <= len(b.rows) <= 2
        for r in b.rows:
            assert len(S.screen_plain("".join(u.text for u in r))) <= M.ROW_MAX


def test_short_blocks_unchanged_by_row_max_param():
    text = "お市は、信長の死後、柴田勝家と再婚した。"
    assert [b.rows for b in S.blocks_of(text)] == [b.rows for b in S.blocks_of(text, row_max=S.ROW_MAX)]


def test_corner_tag_is_small_top_left():
    if not Path(FONT).exists():
        return
    font_of = S.make_font_of({"gothic": FONT})
    lay = Image.new("RGBA", (M.MW, M.MH), (0, 0, 0, 0))
    M.draw_corner(lay, "1583年4月｜第4章 北ノ庄城の最後の夜", font_of)
    x0, y0, x1, y1 = lay.getbbox()
    assert y1 - y0 <= M.MH * 0.04 and x1 <= M.MW * 0.4          # 全幅の帯ではなく、左上の小さな札


def test_plan_follows_shot_rules():
    look = yaml.safe_load(LOOK.read_text(encoding="utf-8"))
    sc = script.load(ROOT / look["script"])
    pl = M.Plan(look, sc)
    body = [c for c in pl.cuts if c.kind != "end"]
    avg = sum(c.seconds for c in body) / len(body)
    assert 10 <= avg <= 15                                        # 1カットの平均 10〜15秒
    ai = {c.ref for c in pl.cuts if c.kind in ("ai", "end")} | {c.backdrop for c in pl.cuts if c.kind == "frame"}
    assert len(ai) <= 25                                          # AI 絵は25枚まで
    assert set(ai) <= set(look["ai"])
    assert pl.runs() == []                                        # 同じ絵が続けて20秒を超えない
    chapters = [c for c in pl.cuts if c.kind == "chapter"]
    assert len(chapters) == len(sc.sections) - 1 and all(abs(c.seconds - M.CHAPTER_SECONDS) < 1e-6 for c in chapters)
    assert pl.cuts[-1].kind == "end" and abs(pl.cuts[-1].seconds - M.END_SECONDS) < 1e-6
    for a, b in zip(pl.cuts, pl.cuts[1:]):
        assert abs(a.end - b.start) < 1e-6                         # 隙間も重なりもない


def test_corner_tag_follows_spoken_dates_only():
    look = yaml.safe_load(LOOK.read_text(encoding="utf-8"))
    sc = script.load(ROOT / look["script"])
    pl = M.Plan(look, sc)
    assert pl.corner(0) == "1583年4月｜序章 なぜ逃げなかったのか"
    idx = next(i for i, l in enumerate(sc.lines) if "この子たちだけは" in l.text)
    assert pl.corner(idx) == "1573年8月27日夜｜第2章 小谷城の落城"
    kensho = [i for i, l in enumerate(sc.lines) if l.section == 5]
    assert {pl.corner(i) for i in kensho} == {"第5章 なぜ逃げなかったのか"}          # 時間が動かない章は年を出さない
    assert pl.corner(len(sc.lines) - 1) == "" and pl.corner(look["no_tag_from"]) == ""   # 最後の余韻は札なし
    for sec, ch in look["chapters"].items():                     # dates の行は、その章の行で、語りがその年を言っている
        for k, v in (ch.get("dates") or {}).items():
            line = sc.lines[int(k)]
            assert line.section == sec
            year = v.split("年")[0]
            day = v.split("月")[-1].rstrip("夜明け方冬夏") if "日" in v else ""
            assert year in line.text or (day and day in line.text) or "その年" in line.text or "その夜" in line.text, (k, v)


def test_record_lines_use_serif_and_imagined_are_not_records():
    class L:
        speaker, imagined = "お市", False
    assert M.is_record(L())
    L.speaker, L.imagined = "お市想像", True
    assert not M.is_record(L())
    L.speaker, L.imagined = "語り", False
    assert not M.is_record(L())
