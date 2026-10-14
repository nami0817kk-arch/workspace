"""2026-10-01 の指摘を draft で止める（ユーザー「本日の指摘事項を再度指摘されないように」）。"""
from src.research import Notes, Section, _check_20261001


def _sec(heading="基礎DATA", say=None, **kw):
    return Section(id="s", heading=heading, tier="報道", telop="", say=say or ["x"], **kw)


def _notes(**kw):
    base = dict(date="2026-10-01", title="ヤマルってどんな選手？", question="", sections=[_sec()])
    base.update(kw)
    return Notes(**base)


def test_シリーズの回のサムネに札を付けない():
    n = _notes(series="有名選手の紹介", thumbnail={"note_red": "有名選手の紹介 ②"})
    assert any("札" in p for p in _check_20261001(n))


def test_見立ての見出しが見立てだけなら止める():
    assert any("見出し" in p for p in _check_20261001(_notes(sections=[_sec("見立て", viewpoint=True)])))
    assert _check_20261001(_notes(sections=[_sec("エムバペとの今季の差", viewpoint=True)])) == []


def test_選手紹介に通算の表が無ければ止める():
    assert any("通算" in p for p in _check_20261001(_notes(series="有名選手の紹介")))
    # 本文に「通算」が出るだけでは通さない（ハーランドが素通りした）
    loose = _sec("代表", ["代表通算65点。"])
    assert any("通算" in p for p in _check_20261001(_notes(series="有名選手の紹介", sections=[loose])))
    table = _sec("キャリア全体の数字", ["ここまでの通算です。"],
                 line_cards=[{"type": "table", "title": "ラミン・ヤマル 通算（2026年9月末まで）",
                              "columns": ["所属", "試合"], "rows": [["バルサ", "159"]]}])
    assert not any("通算" in p for p in _check_20261001(_notes(series="有名選手の紹介", sections=[table])))


def test_月間まとめは題とサムネで欧州組と分かる():
    n = _notes(series="月間まとめ", title="鎌田大地、9月だけで4点に関与", thumbnail={"line1": "鎌田大地の9月"})
    probs = _check_20261001(n)
    assert any("題" in p for p in probs) and any("サムネの文字" in p for p in probs)
    ok = _notes(series="月間まとめ", title="欧州組9月の成績表。鎌田大地と上田綺世",
                thumbnail={"line1": "欧州の日本人、9月の成績表"})
    assert _check_20261001(ok) == []
