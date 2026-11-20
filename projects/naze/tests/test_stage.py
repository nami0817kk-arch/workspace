"""画面の作り(naze/stage.py、2026-11-20)の点検が止めるかの確かめ。python -m pytest tests/test_stage.py"""
import json
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PIL import Image, ImageDraw  # noqa: E402

from naze import stage  # noqa: E402


def _ep(tmp_path, lines, sources=None):
    (tmp_path / "s1").mkdir()
    (tmp_path / "assets" / "stock").mkdir(parents=True)
    (tmp_path / "assets" / "stock" / "a.mp4").write_bytes(b"0")
    if sources is not None:
        (tmp_path / "assets" / "sources.json").write_text(json.dumps(sources), encoding="utf-8")
    return dict(kind="stage", lines=lines, _mod=SimpleNamespace(__file__=str(tmp_path / "s1" / "ep.py")))


def test_good_passes(tmp_path):
    ep = _ep(tmp_path, [dict(id="1", text="海です。", scene=dict(kind="video", src="assets/stock/a.mp4")),
                        dict(id="2", text="雨が降らない。", fx=[dict(k="dim", on="雨")])], {"a.mp4": dict(by="x", site="Pexels")})
    assert stage.lint(ep)[0] == []


def test_line_without_new_picture_fails(tmp_path):
    ep = _ep(tmp_path, [dict(id="1", text="海です。", scene=dict(kind="words", rows=["海"])), dict(id="2", text="雨が降らない。")])
    assert any("絵が替わらない" in x for x in stage.lint(ep)[0])


def test_source_not_noted_fails(tmp_path):
    ep = _ep(tmp_path, [dict(id="1", text="海です。", scene=dict(kind="video", src="assets/stock/a.mp4"))], {})
    assert any("出典" in x for x in stage.lint(ep)[0])


def test_on_word_must_be_in_text(tmp_path):
    ep = _ep(tmp_path, [dict(id="1", text="海です。", scene=dict(kind="words", rows=["海"]), fx=[dict(k="dim", on="雨")])])
    assert any("on「雨」" in x for x in stage.lint(ep)[0])


def test_subtitle_rows_fit_and_no_tiny_rows():
    d = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    f = stage.F("meiryob.ttc", stage.LAY["sub_size"])
    for s in ["1年の雨は、東京なら約1,600ミリ。", "冷えた空気は重く、上の暖かい空気を突き抜けられません。", "次に海辺で霧を見たら、その沖の水の冷たさを思い出してください。"]:
        rows = stage._rows(d, stage.rich(s), f, stage.LAY["sub_maxw"])
        assert all(d.textlength("".join(c for c, _ in r), font=f) <= stage.LAY["sub_maxw"] for r in rows)
        assert all(len(r) >= 3 for r in rows), [("".join(c for c, _ in r)) for r in rows]
