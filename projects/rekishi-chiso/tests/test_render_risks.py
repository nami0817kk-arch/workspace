"""書き出す前の画面の点検（check.render_risks）。10-15 に書き出してから見つかった不具合を、前に見つける。"""
import json
from types import SimpleNamespace as NS

from PIL import Image

from chiso import check


def _line(i, figure=None, bg=None, portrait=None, detail=None):
    fig = json.dumps(figure, ensure_ascii=False, sort_keys=True) if figure else None
    return NS(index=i, figure=fig,
              background=NS(image=bg) if bg else None,
              portrait=NS(image=portrait) if portrait else None,
              detail=detail)


def _sc(*lines):
    return NS(lines=list(lines))


def test_stats_order_reversed_is_warned(tmp_path):
    bad = {"type": "stats", "title": "期間", "items": [["約1年", "幽閉の期間", "入城は…"]]}
    ok = {"type": "stats", "title": "期間", "items": [["幽閉の期間", "約1年", "入城は…"]]}
    e, w = check.render_risks(_sc(_line(0, bad)), tmp_path)
    assert not e and any("stats" in x and "逆" in x for x in w)
    e, w = check.render_risks(_sc(_line(0, ok)), tmp_path)
    assert not e and not any("stats" in x for x in w)


def test_numeric_labels_are_errors(tmp_path):
    spec = {"type": "bars", "title": "兵", "bars": [["a", 300]], "labels": [300]}
    e, _ = check.render_risks(_sc(_line(0, spec)), tmp_path)
    assert any("labels" in x for x in e)


def test_comma_truncated_title_is_error(tmp_path):
    spec = {"type": "pie", "title": "遺言の2", "000タエスの内訳": None, "parts": [["a", 1]]}   # {title: 遺言の2,000…} の読まれ方
    e, _ = check.render_risks(_sc(_line(0, spec)), tmp_path)
    assert any("書き方が崩れて" in x for x in e)


def test_person_background_and_wide_background(tmp_path):
    Image.new("RGB", (3000, 1000)).save(tmp_path / "wide.jpg")
    Image.new("RGB", (1000, 1000)).save(tmp_path / "ok.jpg")
    sc = _sc(_line(0, bg="x_portrait_a.jpg", portrait="p.jpg"),
             _line(1, bg="wide.jpg"),
             _line(2, bg="ok.jpg"),
             _line(3, bg="wide.jpg", detail={"box": [0, 0, 1, 1]}))
    _, w = check.render_risks(sc, tmp_path)
    assert any("人物の絵" in x for x in w)
    assert sum("極端に横長" in x for x in w) == 1             # 同じ絵は1回だけ知らせる。detail の行は数えない
