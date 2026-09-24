"""基礎DATAの板（tools/clubdata.py）。

**2026-09-23 に作り直した**（指摘「基礎データの画面があまりにもパクリなので、改変して」）。
形は「左の柱＋9行の一覧」。ここで縛るのは**見た目の決まり**ではなく、
作り直しで壊れやすかったところ（名前が柱からはみ出す・focus で画面が変わらない）。
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

spec = importlib.util.spec_from_file_location("clubdata", ROOT / "tools" / "clubdata.py")
clubdata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clubdata)


def _spec(title: str = "AFCボーンマス 基礎DATA") -> dict:
    return {"title": title, "colors": ["#DA291C", "#000000"],
            "tiles": [[f"見出し{i}", f"大きな字{i}", f"小さな字{i}"] for i in range(9)]}


def test_題からクラブ名と小さな字を分ける():
    assert clubdata._name_and_eyebrow("AFCボーンマス 基礎DATA") == ("AFCボーンマス", "基礎DATA")
    assert clubdata._name_and_eyebrow("フラム") == ("フラム", "基礎DATA")


def test_差し色が黒でも地に沈まない():
    """ボーンマス・ニューカッスルの差し色は黒。そのまま使うと見出しが消える。"""
    assert clubdata._lum(clubdata._readable((0, 0, 0))) >= 150


def test_長いクラブ名でも柱からはみ出さない(tmp_path):
    """柱の内側に収める。はみ出すと差し色の線をまたいで一覧にかかる。"""
    out = clubdata.build(tmp_path / "a.png", _spec("マンチェスター・ユナイテッド 基礎DATA"))
    img = Image.open(out).convert("RGB")
    edge = img.crop((clubdata.RAIL - 22, 0, clubdata.RAIL - 4, clubdata.SIZE[1]))
    assert not any(min(p) > 200 for p in edge.getdata())   # 白い字が縁に届いていない


@pytest.mark.parametrize("focus", [0, 4, 8])
def test_focusで画面が変わる(tmp_path, focus):
    """1枚のまま48秒出すと画面が止まる（2026-09-20）。行ごとに差し替える。"""
    plain = Image.open(clubdata.build(tmp_path / "p.png", _spec())).convert("RGB")
    lit = Image.open(clubdata.build(tmp_path / f"f{focus}.png", _spec(), focus)).convert("RGB")
    assert list(plain.getdata()) != list(lit.getdata())
    # focus の行は明るいまま、ほかの行は落ちる
    h = (clubdata.SIZE[1] - 60) // 9
    def brightness(img, i):
        row = img.crop((clubdata.RAIL + 40, 30 + i * h, clubdata.SIZE[0] - 40, 30 + (i + 1) * h))
        return sum(sum(p) for p in row.getdata())
    other = 0 if focus else 1
    assert brightness(lit, focus) > brightness(lit, other)
