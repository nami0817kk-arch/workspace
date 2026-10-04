from chiso import script


def _d(**line):
    return {"title": "t", "sections": [{"title": "見立て", "lines": [dict({"語り": "a"}, **line), {"語り": "b"}]}]}


def test_bubble_and_icon_only_on_that_line():
    sc = script.parse(_d(bubble="ひとこと", icon="crown"))
    assert sc.lines[0].bubble and sc.lines[0].icon == "crown"
    assert sc.lines[1].bubble is None and sc.lines[1].icon is None


def test_compare_is_a_figure_type():
    sc = script.parse(_d(figure={"type": "compare", "people": [["A", "a.jpg"]]}))
    assert "compare" in sc.lines[0].figure
