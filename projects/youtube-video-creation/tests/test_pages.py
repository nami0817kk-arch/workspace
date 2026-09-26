# -*- coding: utf-8 -*-
"""台本ページの尺の出し方（2026-09-24 指示「おおよそ何分の動画になるか記載」）。"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import pages  # noqa: E402

from src.script_model import Line  # noqa: E402


def test_尺の見積りは書き出しと同じ式():
    """ページと書き出しで違う数字を出さない。"""
    text = "ラ・リーガの会長、ハビエル・テバス。記者に囲まれて、こう言い切りました。"
    assert abs(pages.say_seconds(text) - Line(speaker="キャスター", text=text).estimated_duration()) < 1e-9


def test_強調の星印と括弧は字数に数えない():
    """`**` は画面の飾りで、読み上げない。"""
    assert pages.say_seconds("収入は6億7700万ポンド") == pages.say_seconds("収入は**6億7700万ポンド**")


def test_分と秒で出す():
    assert pages.mmss(137.4) == "2分17秒"
    assert pages.mmss(60) == "1分00秒"


def test_ショートだけの行は本編の尺に数えない(tmp_path, monkeypatch):
    """`only: short` の行は本編では読まれない。"""
    date = "20260101"
    d = ROOT / "scripts"
    a = d / f"{date}_zz_test.md"
    a.write_text(
        "---\ntitle: てすと\ncards: {}\nsources: []\n---\n\n## 山場\n"
        "キャスター: ほんぺんではよまないながいながいぜんおきのいちぎょうです。\n"
        "  only: short\n"
        "キャスター: みじかい。\n",
        encoding="utf-8")
    try:
        out = pages.scripts(date)
        html = out.read_text(encoding="utf-8")
        assert "およそ 0分01秒" in html or "およそ 0分02秒" in html, html[html.index("class=\"d\""):][:60]
    finally:
        a.unlink(missing_ok=True)


def test_題材の理由は改行がそのまま改行になる():
    """HTML は書けないので、`why` の改行を <br> にする（2026-09-24）。"""
    assert pages.rich("1行目\n2行目") == "1行目<br>2行目"
    assert pages.rich("**ここ**が太字") == "<b>ここ</b>が太字"
    assert pages.rich("<script>") == "&lt;script&gt;"
