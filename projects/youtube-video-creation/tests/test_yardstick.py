"""数字に比べる物差しを添えているか（2026-10-05「動画の質を上げる仕組み ⑧」）。"""
from src.research import (YARD_STRONG_MARK, Notes, Section, _advise_yardstick,
                          _bare_numbers)


def _notes(say, voices=None, main=False, viewpoint=False, heading="今季の数字", series=""):
    sec = Section(id="s", heading=heading, tier="報道", telop="", say=say,
                  voices=voices or [], main=main, viewpoint=viewpoint)
    return Notes(date="2026-10-05", title="t", question="", sections=[sec], series=series)


BARE = ["今季は勝ち点16です。", "得点は12、失点は9。", "シュートは0本でした。"]


def test_物差しの無い数字が並ぶ節は知らせる():
    hints = _advise_yardstick(_notes(BARE))
    assert len(hints) == 1 and "3行" in hints[0]
    assert not hints[0].startswith(YARD_STRONG_MARK)


def test_山場で3つ以上なら強めに知らせる():
    hints = _advise_yardstick(_notes(BARE, main=True))
    assert hints and hints[0].startswith(YARD_STRONG_MARK)
    hints = _advise_yardstick(_notes(BARE, viewpoint=True))
    assert hints and hints[0].startswith(YARD_STRONG_MARK)


def test_山場は1行でも知らせる_ほかの節は2行から():
    one = ["9月からの3試合で、シュートは0本でした。", "それでも決勝は、ゴールに迫れる展開になると見ています。"]
    assert _advise_yardstick(_notes(one, main=True))
    assert _advise_yardstick(_notes(one)) == []


def test_同じ行に物差しがあれば知らせない():
    say = ["今季は勝ち点16。昨季の同じ時点より4多い。",
           "シュートは12本。リーグで3位です。",
           "成功率は82%でした。"]
    assert _advise_yardstick(_notes(say, main=True)) == []


def test_次の行の物差しも効く():
    say = ["シュートは0本でした。", "2025年秋の4試合では6本打っていました。以来、減っています。"]
    assert _advise_yardstick(_notes(say, main=True)) == []


def test_同じ単位の数字を前後の行で並べれば比べになる():
    # 堂安の回の見立て。比べの言葉は無いが、時期ごとの本数を並べている
    say = ["その秋の4試合で打ったシュートは、合わせて6本。", "今年3月から5月の3試合は2本。",
           "ワールドカップでも4試合を戦い、シュートは1本でした。"]
    assert _advise_yardstick(_notes(say, viewpoint=True)) == []


def test_年号や日付や時刻やスコアは数えない():
    say = ["2026年10月5日、夜7時半から国立競技場で決勝です。",
           "試合は2対1の勝ち。後半30分に背番号10が決めました。",
           "第7節は19時30分キックオフ。4-3-3で臨みます。"]
    for line in say:
        assert _bare_numbers(line) == [], line
    assert _advise_yardstick(_notes(say, main=True)) == []


def test_本人の言葉と反応は数えない():
    say = ["シュート数が10本も減ってるんで", "3試合で0本はさすがに少ない"]
    assert _advise_yardstick(_notes(say, voices=["堂安律", "ネット民"], main=True)) == []


def test_本人の言葉の物差しは語りの物差しにならない():
    say = ["9月からの3試合で、シュートは0本でした。", "去年よりシュート数が減ってるんで"]
    assert _advise_yardstick(_notes(say, voices=["", "堂安律"], main=True))


def test_紹介の回の基礎DATAは見ない():
    n = _notes(BARE, heading="基礎DATA", series="有名選手の紹介")
    assert _advise_yardstick(n) == []
    # 紹介の回でなければ、同じ見出しでも見る
    assert _advise_yardstick(_notes(BARE, heading="基礎DATA"))
