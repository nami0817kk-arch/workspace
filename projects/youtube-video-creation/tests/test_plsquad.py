"""登録選手と試合結果の読み取り（tools/plsquad.py）。

ラ・リーガの記事で、プレミアの記事では出なかった書き方に3回つまずいた（2026-09-26〜27）。
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

spec = importlib.util.spec_from_file_location("plsquad", ROOT / "tools" / "plsquad.py")
plsquad = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plsquad)


ARTICLE = """==Pre-season and friendlies==
{{Football box collapsible|date=15 July 2026|round=1|score=0–3|team1=[[SD Derio|Derio]]|team2=[[Athletic Bilbao]]|result=W}}
{{Football box collapsible|date=29 July 2026|round=5|score=0–3|team1=[[Racing de Santander|Racing Santander]]|team2=[[Athletic Bilbao]]|result=W}}
==Competitions==
===La Liga===
{{Football box collapsible
|date=22 August 2026
|round=2
|score={{score link|x|1–3}}
|team1=[[Athletic Bilbao]]
|team2=[[Sevilla FC|Sevilla]]
|result=L}}
{{Football box collapsible|date=12 September 2026|round=5|score=1–1|team1=[[Athletic Bilbao]]|team2=[[Elche CF|Elche]]|result=D}}
"""


def test_1行に何項目も書いた試合も読める(monkeypatch):
    monkeypatch.setattr(plsquad, "raw", lambda title: ARTICLE)
    got = plsquad.results("x")
    assert ["12 September 2026", "5", "Athletic Bilbao", "1–1", "Elche"] in got


def test_親善試合の節は読まない(monkeypatch):
    monkeypatch.setattr(plsquad, "raw", lambda title: ARTICLE)
    got = plsquad.results("x")
    assert [g[2] for g in got] == ["Athletic Bilbao", "Athletic Bilbao"]
    assert all("Racing" not in g[2] for g in got)


def test_スコアのひな形から数字を取り出す(monkeypatch):
    monkeypatch.setattr(plsquad, "raw", lambda title: ARTICLE)
    got = plsquad.results("x")
    assert ["22 August 2026", "2", "Athletic Bilbao", "1–3", "Sevilla"] in got


SQUAD_OSASUNA = """==Players==
==Current squad==
===First team squad===
{{Fs start}}
{{Fs player|no=1|nat=ESP|pos=GK|name=[[Sergio Herrera]]}}
{{Fs end}}
===Out on loan===
{{Fs player|no=30|nat=ESP|pos=DF|name=[[Loan Guy]]}}
"""

SQUAD_BETIS = """==Players==
=== First-team ===
{{Fs start}}
{{Fs player|no=13|nat=ESP|pos=GK|name=[[Adrián (footballer)|Adrián]]}}
{{Fs end}}
"""


@pytest.mark.parametrize("text,name", [(SQUAD_OSASUNA, "Sergio Herrera"), (SQUAD_BETIS, "Adrián")])
def test_選手の並びがある見出しから読む(monkeypatch, text, name):
    monkeypatch.setattr(plsquad, "raw", lambda title: text if title == "club" else "")
    monkeypatch.setattr(plsquad, "senior_caps", lambda page: ("", 0))
    got = plsquad.squad("club")
    assert [p["name"] for p in got] == [name]
