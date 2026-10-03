import pytest

from chiso import script


def _data(**over):
    d = {
        "title": "t",
        "timeline": {"start": 1755, "end": 1793, "events": [[1755, "誕生"], [1793, "処刑"]]},
        "shorts": {"s1": {"title": "x"}},
        "sections": [
            {"title": "一", "background": {"image": "bg.jpg", "credit": "c"},
             "portrait": "p.jpg", "card": {"head": "1755年"},
             "lines": [
                 {"語り": "こんにちは", "short": "s1"},
                 {"聞き": "はい", "tone": "驚き", "card": None, "year": 1770},
             ]},
            {"title": "二", "lines": [{"語り": "続き"}]},
        ],
    }
    d.update(over)
    return d


def test_sticky_and_reset():
    sc = script.parse(_data())
    a, b, c = sc.lines
    assert a.card.head == "1755年" and b.card is None          # null で消える
    assert a.year == 1755 and b.year == 1770 and c.year == 1770  # 年は続く
    assert c.background.image == "bg.jpg"                       # 背景は節をまたいで続く
    assert c.portrait is None                                   # 肖像は節で消える
    assert [l.speaker for l in sc.lines] == ["語り", "聞き", "語り"]
    assert sc.short_lines("s1") == [a]


def test_unknown_tone_rejected():
    d = _data()
    d["sections"][0]["lines"][0]["tone"] = "怒り狂う"
    with pytest.raises(script.ScriptError):
        script.parse(d)


def test_two_speakers_in_one_line_rejected():
    d = _data()
    d["sections"][0]["lines"][0] = {"語り": "a", "聞き": "b"}
    with pytest.raises(script.ScriptError):
        script.parse(d)


def test_undefined_short_rejected():
    d = _data(shorts={})
    with pytest.raises(script.ScriptError):
        script.parse(d)


def test_memo_stacks_newest_first_and_resets_per_section():
    d = _data()
    d["sections"][0]["lines"].append({"語り": "x", "card": {"head": "B"}})
    d["sections"][0]["lines"].append({"語り": "y", "card": {"head": "C"}})
    d["sections"][0]["lines"].append({"語り": "z", "card": {"head": "D"}})
    sc = script.parse(d)
    sec0 = [l for l in sc.lines if l.section == 0]
    assert [c.head for c in sec0[-1].memo] == ["D", "C", "B"]        # 新しい順に3枚まで
    assert sc.lines[-1].memo == ()                                   # 節が変わると空になる


def test_next_and_thumbnail_and_question():
    d = _data(title="王妃は本当に悪女だったのか｜副題", next={"title": "西太后", "teaser": "t"},
              thumbnail={"main": "悪女？"})
    sc = script.parse(d)
    assert sc.next["title"] == "西太后" and sc.thumbnail["main"] == "悪女？"
    assert sc.question == "王妃は本当に悪女だったのか"
