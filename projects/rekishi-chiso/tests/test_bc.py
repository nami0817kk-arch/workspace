"""紀元前（負の年）の扱い（10-09、始皇帝の回）。年表・この時○歳・札の年・話と画面。"""
from types import SimpleNamespace as NS

import pytest
from PIL import ImageFont

from chiso import assign, match, render, script, years


# --- 文字と読み取り ------------------------------------------------------------
def test_labels():
    assert years.label(1785) == "1785年"
    assert years.label(-221) == "紀元前221年"
    assert years.label(-221, short=True) == "前221年"
    assert years.label(-220.6) == "紀元前221年"
    assert years.label(0) == "紀元前1年"                   # 0年は無い（年表の印が紀元前後をまたいで動く途中）
    assert years.tick(1785) == "1785" and years.tick(-259) == "前259"


def test_head_date():
    assert years.head_date("1774年5月") == (1774, 5, None)
    assert years.head_date("紀元前210年7月") == (-210, 7, None)
    assert years.head_date("前221年") == (-221, None, None)
    assert years.head_date("紀元前257年ごろ") == (-257, None, None)
    assert years.head_date("紀元前4年") == (-4, None, None)
    assert years.head_date("1760年代半ば") is None
    assert years.head_date("『史記』秦始皇本紀") is None
    assert years.head_date("13年") is None                  # 紀元後は今までどおり3〜4桁だけ


def test_parse_date_forms():
    assert years.parse_date(-259) == (-259, 1, 1)
    assert years.parse_date("-0259-01-01") == (-259, 1, 1)
    assert years.parse_date("-259-7") == (-259, 7, 1)
    assert years.parse_date(-210, end=True) == (-210, 12, 31)
    assert years.parse_date("1755-11-02") == (1755, 11, 2)
    with pytest.raises(ValueError):
        years.parse_date("紀元前259")


def test_years_in_text():
    assert match.years_in("紀元前221年、秦は統一します") == {-221}
    assert match.years_in("前221年") == {-221}
    assert match.years_in("紀元前230〜221年") == {-230, -221}
    assert match.years_in("2002年、湖南省の井戸から") == {2002}
    assert match.years_in("1582年6月、京都の本能寺") == {1582}
    assert match.years_in("3年前221年") == set()           # 「前」の前に字が続くときは紀元前の印にしない
    assert assign.years("紀元前221年の詔") == {-221}


# --- この時○歳 ------------------------------------------------------------------
def test_age_bc_no_year_zero():
    info = {"born": "-259", "died": "-210"}                 # 年だけ：生まれは1月1日、没は12月31日とみなす
    assert script.age_at(info, -221, NS(head="紀元前221年")) == 38
    assert script.age_at(info, -247, None) == 12
    assert script.age_at(info, -210, NS(head="紀元前210年7月")) == 49
    assert script.age_at(info, -209, None) is None          # 亡くなったあと
    assert script.age_at(info, -259, None) is None          # 1歳未満
    # 紀元前後をまたぐ：紀元前4年生まれは紀元30年に33歳（0年が無い）
    assert script.age_at({"born": "-4", "died": ""}, 30, None) == 33


def test_age_bc_with_month():
    info = {"born": "-0259-03-01", "died": "-0210-07-31"}
    assert script.age_at(info, -221, NS(head="紀元前221年2月")) == 37   # 誕生日の前
    assert script.age_at(info, -221, NS(head="紀元前221年4月")) == 38
    assert script.age_at(info, -210, NS(head="紀元前210年9月")) is None


def test_people_born_forms_parse_and_bad_form_stops():
    base = {"title": "t", "sections": [{"title": "一", "lines": [{"語り": "a"}]}]}
    sc = script.parse(dict(base, people={"始皇帝": {"born": -259, "died": "-0210-07"}}))
    assert script.age_at(sc.people["始皇帝"], -221, None) == 38
    with pytest.raises(script.ScriptError):
        script.parse(dict(base, people={"始皇帝": {"born": "前259年"}}))


# --- 札の年・年表 -----------------------------------------------------------------
def _bc_script():
    return script.parse({"title": "t", "timeline": {"start": -259, "end": -210, "events": [
        [-259, "誕生"], [-257, "父が逃げる"], [-247, "13歳で王"], [-238, "嫪毐の乱"], [-237, "呂不韋を退ける"],
        [-221, "統一"], [-219, "封禅"], [-213, "焚書"], [-212, "坑儒"], [-210, "沙丘"]]},
        "people": {"始皇帝": {"born": -259, "died": -210}},
        "sections": [{"title": "紀元前259年 邯鄲", "lines": [
            {"語り": "a", "card": {"head": "紀元前259年", "body": "誕生"}},
            {"語り": "b", "card": {"head": "前247年", "body": "王に"}},
            {"語り": "c", "card": {"head": "『史記』", "body": "x"}},
            {"語り": "d", "year": -221}]}]})


def test_card_year_bc_moves_timeline():
    sc = _bc_script()
    assert sc.timeline_start == -259 and sc.timeline_end == -210
    assert [l.year for l in sc.lines] == [-259, -247, -247, -221]


class _Rec:
    """ImageDraw の代わりに、描いた文字と線を控える。"""
    def __init__(self):
        self.texts, self.lines = [], []

    def text(self, xy, txt, **k):
        self.texts.append((xy[0], txt))

    def line(self, pts, **k):
        self.lines.append(pts[0])

    def rectangle(self, *a, **k): pass
    def polygon(self, *a, **k): pass
    def rounded_rectangle(self, *a, **k): pass


class _Painter(render.Painter):
    def __init__(self, sc):
        self.script, self.H, self.W = sc, 1080, 1920

    def font(self, kind, size, bold=False):
        return ImageFont.load_default(size)


def test_timeline_bc_labels_order_and_thinning():
    sc = _bc_script()
    rec = _Rec()
    _Painter(sc)._timeline(rec, 470, 1450, 770, -221)
    xs = rec.lines                                            # 印の線は events の順（古い順）
    assert xs == sorted(xs) and xs[0] == 470 and xs[-1] == 1450   # 古い方が左
    texts = [t for _, t in rec.texts]
    assert "紀元前221年" in texts                            # 印の上の札
    assert "前221" in texts and "前259" in texts             # 目盛りの数字
    assert not any(t.startswith("-") for t in texts)          # 「-221」は出さない
    nums = sorted((x, t) for x, t in rec.texts if t.startswith("前") and not t.endswith("年"))
    assert "前238" not in [t for _, t in nums] or "前237" not in [t for _, t in nums]   # 重なる目盛りは間引く


def test_timeline_ad_unchanged():
    sc = script.parse({"title": "t", "timeline": {"start": 1755, "end": 1793, "events": [[1755, "誕生"], [1793, "処刑"]]},
                       "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})
    rec = _Rec()
    _Painter(sc)._timeline(rec, 470, 1450, 770, 1774)
    texts = [t for _, t in rec.texts]
    assert "1755" in texts and "1774年" in texts


# --- 話と画面 ---------------------------------------------------------------------
def test_match_bc_year_against_section_title():
    def sc(title, said):
        return script.parse({"title": "t", "timeline": {"start": -259, "end": -210},
                             "sections": [{"title": title, "lines": [{"語り": said}]}]}, places={"邯鄲": (114.5, 36.6)})
    ok = sc("紀元前228年 邯鄲を落とす", "紀元前228年、邯鄲が落ちました。")
    assert match.line_notes(ok, {}, ["邯鄲"]) == []
    far = sc("紀元前259年 邯鄲に生まれる", "紀元前228年、邯鄲が落ちました。")
    notes = match.line_notes(far, {}, ["邯鄲"])
    assert len(notes) == 1 and "紀元前228年" in notes[0][1] and "紀元前259年" in notes[0][1]
    # 「2002年の井戸」は年表（紀元前）の外＝後の時代の話なので、場面の年にしない
    later = sc("紀元前219年 巡行", "2002年、湖南省の井戸から竹簡が出ました。")
    assert match.line_notes(later, {}, ["邯鄲"]) == []
