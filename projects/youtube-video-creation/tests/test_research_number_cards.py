"""取材メモの段階で、2026-10-07 に足した4つのカード（stats・verdict・calc・versus）の形を見る。

`_check_card` は「書き出しで落ちる条件を draft で先に見る」ための関数。新しい型も同じく、
壊れた形は × にし、正しい形は素通しする。行ごとのカード（判定表で行を光らせる形）も見る。
"""
from PIL import Image

from src.research import (Notes, Section, YARD_STRONG_MARK, _advise_card_telop_overlap,
                          _advise_series_numbers, _check_card)


def make(card=None, line_cards=None, say=None, viewpoint=False):
    say = say or ["a"]
    return Section(id="s", heading="h", tier="報道", telop="t", say=say,
                   sources=["https://example.com/1"], card=card,
                   line_cards=line_cards if line_cards is not None else [None] * len(say),
                   viewpoint=viewpoint)


def _photo(tmp_path, name):
    path = tmp_path / name
    Image.new("RGB", (300, 400), (120, 120, 120)).save(path)
    return str(path)


STATS = {"type": "stats", "title": "メッシの代表", "items": [["208", "試合"], ["126", "点"], ["W杯", "優勝"]]}
VERDICT = {"type": "verdict", "title": "答え合わせ", "rows": [["イサク", "◎", "8試合6点"], ["ヴィルツ", "△", "1点"]]}
CALC = {"type": "calc", "terms": [["125試合"], ["11年193日"], ["年10.8試合"]], "ops": ["÷", "＝"]}


def test_正しい形は素通しする(tmp_path):
    versus = {"type": "versus", "title": "代表125試合",
              "left": {"image": _photo(tmp_path, "a.jpg"), "name": "ケイン", "number": "125試合"},
              "right": {"image": _photo(tmp_path, "b.jpg"), "name": "シルトン", "number": "125試合",
                        "note": "1970〜1990", "top": 0.1}}
    for card in (STATS, VERDICT, CALC, versus,
                 {"type": "verdict", "rows": [["本人の発言", "✓"], ["金額", "✗"]]}):
        assert _check_card(make(card)) == [], card["type"]


def test_知らない鍵は止める():
    found = _check_card(make(dict(STATS, item=[["1", "回"]])))
    assert found and "知らない鍵" in found[0] and "item" in found[0]


def test_数字の板は3つまで():
    four = dict(STATS, items=STATS["items"] + [["1", "回"]])
    assert any("3つまで" in p for p in _check_card(make(four)))
    assert _check_card(make({"type": "stats", "items": []}))
    assert any("focus" in p for p in _check_card(make(dict(STATS, focus=5))))


def test_壊れた判定表は止める():
    assert any("判定『A』" in p for p in _check_card(make(dict(VERDICT, rows=[["イサク", "A", "x"]]))))
    assert _check_card(make(dict(VERDICT, rows=[["イサク", "◎", "x"], ["ヴィルツ", "△"]])))
    assert any("columns" in p for p in _check_card(make(dict(VERDICT, columns=["選手", "判定"]))))
    assert any("highlight_row" in p for p in _check_card(make(dict(VERDICT, highlight_row=2))))


def test_記号の数が合わない式は止める():
    assert any("ops" in p for p in _check_card(make(dict(CALC, ops=["÷"]))))
    assert any("記号" in p for p in _check_card(make(dict(CALC, ops=["÷", "%"]))))
    assert _check_card(make({"type": "calc", "terms": [["125試合"]]}))


def test_左右の比べは写真と名前が要る(tmp_path):
    ok = _photo(tmp_path, "a.jpg")
    missing = {"type": "versus", "left": {"image": ok, "name": "ケイン"},
               "right": {"image": str(tmp_path / "ない.jpg"), "name": "シルトン"}}
    assert any("写真がありません" in p for p in _check_card(make(missing)))
    no_name = {"type": "versus", "left": {"image": ok, "name": ""}, "right": {"image": ok, "name": "b"}}
    assert any("name" in p for p in _check_card(make(no_name)))
    odd = {"type": "versus", "left": {"image": ok, "name": "a", "photo": ok}, "right": {"image": ok, "name": "b"}}
    assert any("photo" in p for p in _check_card(make(odd)))
    assert _check_card(make({"type": "versus", "left": {"image": ok, "name": "a"}}))


def test_行ごとのカードも見る():
    """判定表は行ごとにカードを持たせて話している行を光らせる。その行のカードが壊れていたら止める。"""
    bad = dict(VERDICT, rows=[["イサク", "?", "x"]])
    found = _check_card(make(None, line_cards=[bad, None], say=["a", "b"]))
    assert found and "判定" in found[0]
    # 「card: none」（表を下ろす指定）は見ない
    assert _check_card(make(None, line_cards=["none", None], say=["a", "b"])) == []


def test_判定表も行が多いと長いテロップとぶつかると知らせる():
    rows = [["選手", "◎", "x"]] * 4
    section = make(dict(VERDICT, rows=rows), say=["あ" * 45, "い"])
    notes = Notes(date="2026-10-07", title="t", question="", sections=[section])
    assert _advise_card_telop_overlap(notes)


def test_見立てに計算の式があれば比べの1行が無くても知らせない():
    """計算の式（125試合 ÷ 11年193日 ＝ 年10.8試合）はそれ自体が「この回だけの数字」（⑩の2）。"""
    view = make(CALC, say=["ケインのペースは、歴代でもずば抜けています。", "次はクロアチア戦です。"],
                viewpoint=True)
    notes = Notes(date="2026-10-07", title="t", question="", sections=[view], series="記録")
    assert _advise_series_numbers(notes) == []
    # 引用カードだけなら今までどおり【強め】で知らせる（壊れていないこと）
    view = make({"type": "quote", "text": "見立て"}, say=["ずば抜けています。"], viewpoint=True)
    hints = _advise_series_numbers(Notes(date="2026-10-07", title="t", question="", sections=[view],
                                         series="記録"))
    assert hints and hints[0].startswith(YARD_STRONG_MARK)
