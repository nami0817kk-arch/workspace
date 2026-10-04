import pytest

from chiso import people, script

CONFIG = {
    "cast": {"語り": {"name": "剣崎雌雄", "style_id": 21}, "聞き": {"name": "春日部つむぎ", "style_id": 8}},
    "roles": {"マリー": {"label": "マリー・アントワネット", "name": "九州そら", "style_id": 16},
              "ロアン": {"label": "ロアン枢機卿", "name": "玄野武宏", "style_id": 11}},
}


def _data(lines):
    return {"title": "t", "sections": [{"title": "一", "lines": lines}]}


def test_role_line_speaker_is_who():
    sc = script.parse(_data([{"語り": "こう言いました。"}, {"人物": "「ごめんなさい」", "who": "マリー"}]))
    assert [l.speaker for l in sc.lines] == ["語り", "マリー"]
    assert sc.roles == ["マリー"]


def test_role_line_needs_who_and_who_only_on_role_lines():
    with pytest.raises(script.ScriptError):
        script.parse(_data([{"人物": "「a」"}]))
    with pytest.raises(script.ScriptError):
        script.parse(_data([{"人物": "「a」", "who": "語り"}]))
    with pytest.raises(script.ScriptError):
        script.parse(_data([{"語り": "a", "who": "マリー"}]))


def test_labels_and_credits_only_used_roles():
    sc = script.parse(_data([{"語り": "a"}, {"人物": "「b」", "who": "マリー"}]))
    assert people.label(CONFIG, "語り") == "剣崎雌雄"
    assert people.label(CONFIG, "マリー") == "マリー・アントワネット"
    assert people.credit_names(CONFIG, sc) == ["剣崎雌雄", "春日部つむぎ", "九州そら"]   # ロアンの声は使っていない
    assert people.unknown_roles(CONFIG, sc) == []
    sc2 = script.parse(_data([{"人物": "「c」", "who": "西太后"}]))
    assert people.unknown_roles(CONFIG, sc2) == ["西太后"]


def test_voices_include_roles():
    from chiso.cli import voices
    vs = voices(CONFIG)
    assert vs["マリー"].style_id == 16 and vs["語り"].style_id == 21
