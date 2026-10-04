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


def test_figure_sticky_and_cleared():
    d = _data()
    d["sections"][0]["lines"][0]["figure"] = {"type": "pie", "title": "x", "parts": [["a", 1]]}
    d["sections"][0]["lines"][1]["figure"] = None
    sc = script.parse(d)
    assert sc.lines[0].figure and sc.lines[1].figure is None


def test_figure_type_checked():
    d = _data()
    d["sections"][0]["lines"][0]["figure"] = {"type": "video"}
    with pytest.raises(script.ScriptError):
        script.parse(d)


def test_terms_first_appearance_three_lines_and_queue():
    gl = {"枢機卿": "教皇の次の位", "王太子": "王位を継ぐ王子", "王太子妃": "王太子の妻"}
    d = {"title": "t", "terms": {"三部会": "身分ごとの議会"}, "sections": [
        {"title": "一", "lines": [{"語り": "ロアン枢機卿と王太子妃。"}, {"語り": "a"}, {"語り": "王太子と《三部会》"},
                                 {"語り": "b"}, {"語り": "枢機卿ふたたび"}, {"語り": "c"}, {"語り": "d"}]},
        {"title": "二", "lines": [{"語り": "e"}]}]}
    sc = script.parse(d, glossary=gl)
    words = [l.term[0] if l.term else None for l in sc.lines]
    # 1行目は先に出た枢機卿。王太子妃は待ち、3行目で新しい言葉（王太子・三部会）が来たので差し替え。
    # 王太子妃の中の王太子は数えない。2度目の枢機卿は出さない。節が変わると消える
    assert words == ["枢機卿", "枢機卿", "王太子", "王太子", "王太子", "三部会", "三部会", None]


def test_term_note_length_limited():
    with pytest.raises(script.ScriptError):
        script.parse({"title": "t", "terms": {"長": "あ" * 41}, "sections": [{"title": "一", "lines": [{"語り": "長"}]}]})


def test_template_parses():
    """見本の台本は写して使うので、いつも読める状態にしておく（10-04 まで壊れていた）。"""
    from pathlib import Path
    sc = script.load(Path(__file__).resolve().parent.parent / "scripts" / "_template.yaml")
    assert sc.lines


def test_age_at_uses_card_month_and_hides_outside_life():
    from types import SimpleNamespace as NS
    info = {"born": "1755-11-02", "died": "1793-10-16"}
    assert script.age_at(info, 1774, NS(head="1774年5月")) == 18
    assert script.age_at(info, 1793, NS(head="1793年10月16日")) == 37
    assert script.age_at(info, 1770, NS(head="1770年 春")) == 14          # 月が無ければ7月1日とみなす
    assert script.age_at(info, 1770, NS(head="1769年12月")) == 14         # 別の年の札の月は使わない
    assert script.age_at(info, 1755, None) is None                        # 1歳未満は出さない
    assert script.age_at(info, 1794, None) is None                        # 亡くなったあと


def test_person_of_matches_caption_tail():
    from types import SimpleNamespace as NS
    people = {"マリー・アントワネット": {"match": ["マリー・アントワネット", "王妃", "マリア・アントニア"]},
              "マリア・テレジア": {"match": ["マリア・テレジア"]}}
    pic = lambda cap, who="": NS(caption=cap, who=who)
    assert script.person_of(people, pic("処刑に向かう王妃（ダヴィッド）")) == "マリー・アントワネット"
    assert script.person_of(people, pic("嫁ぐ前のマリア・アントニア（1769年）")) == "マリー・アントワネット"
    assert script.person_of(people, pic("マリア・テレジアの家族（マイテンス画）")) is None   # 家族の絵は1人ではない
    assert script.person_of(people, pic("だれか", who="マリア・テレジア")) == "マリア・テレジア"


def test_places_attach_and_ignore_inside_terms():
    d = {"title": "t", "sections": [{"title": "一", "lines": [
        {"語り": "神聖ローマ皇帝の娘"}, {"語り": "ヴァレンヌで捕まる"}, {"語り": "a"}, {"語り": "b"}, {"語り": "c"}]}]}
    sc = script.parse(d, glossary={"神聖ローマ皇帝": "皇帝"}, places={"ローマ": (12.5, 41.9), "ヴァレンヌ": (5.03, 49.23)})
    assert [l.place[0] if l.place else None for l in sc.lines] == [None, "ヴァレンヌ", "ヴァレンヌ", "ヴァレンヌ", None]


def test_card_year_moves_timeline_year():
    sc = script.parse({"title": "t", "timeline": {"start": 1755}, "sections": [{"title": "一", "lines": [
        {"語り": "a"}, {"語り": "b", "card": {"head": "1772年 元日"}}, {"語り": "c"},
        {"語り": "d", "card": {"head": "首飾りの値段"}}, {"語り": "e", "card": {"head": "1783年"}, "year": 1780}]}]})
    assert [l.year for l in sc.lines] == [1755, 1772, 1772, 1772, 1780]   # 年の無い札は動かさない、year: が優先


def test_portrait_age_can_be_hidden():
    from types import SimpleNamespace as NS
    people = {"マリー": {"match": ["マリー"], "born": "1755-11-02", "died": "1793-10-16"}}
    sc = script.parse({"title": "t", "sections": [{"title": "一", "lines": [
        {"語り": "a", "portrait": {"image": "x.jpg", "caption": "マリー", "age": False}}]}]})
    assert sc.lines[0].portrait.age is False
    assert script.person_of(people, sc.lines[0].portrait) is None          # 年齢の札を出さない
    assert script.person_of(people, NS(caption="マリー", who="", age=True)) == "マリー"
