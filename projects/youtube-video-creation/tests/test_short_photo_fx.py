# -*- coding: utf-8 -*-
"""tools/short_photo_fx.py（ショートの写真の使い方を変える素材）。小さい合成画像で、サイズ・9:16・出典の控えを見る。"""
import importlib.util
import json
from pathlib import Path

import pytest
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("short_photo_fx", ROOT / "tools" / "short_photo_fx.py")
fx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fx)


def _book(folder: Path, **extra):
    row = {"file": "01.jpg", "source": "wikimedia", "page_url": "https://example.org/a",
           "license": "CC BY-SA 4.0", "no_derivatives": False, **extra}
    other = {"file": "99.jpg", "source": "x", "page_url": "https://example.org/other"}
    (folder / "credits.json").write_text(json.dumps([row, other]), encoding="utf-8")


def _photo(folder: Path) -> Path:
    im = Image.new("RGB", (1600, 1800), (40, 90, 40))
    ImageDraw.Draw(im).ellipse((600, 300, 1000, 760), fill=(225, 180, 150))
    p = folder / "01.jpg"
    im.save(p)
    return p


def test_B_縦9対16で出典は元の写真の行だけ増える(tmp_path, monkeypatch):
    src = _photo(tmp_path)
    _book(tmp_path)
    face = (600, 330, 400, 400)
    monkeypatch.setattr("src.faces.find_faces", lambda im, **k: [face])
    monkeypatch.setattr("src.faces.available", lambda: True)
    assert fx.run_b([src], tmp_path, False, False) == 0
    outs = sorted(tmp_path.glob("*_v.jpg"))
    assert len(outs) >= 2
    for o in outs:
        assert Image.open(o).size == (1080, 1920)
    rows = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert len(rows) == 2 + len(outs)                       # 元の2行 + 切り出し分だけ
    assert all(r["page_url"] == "https://example.org/a" for r in rows if r["file"].endswith("_v.jpg"))
    assert not any(r["file"] == "99.jpg" and r is not rows[1] for r in rows)


def test_改変不可の写真は加工しない(tmp_path):
    src = _photo(tmp_path)
    _book(tmp_path, no_derivatives=True)
    assert fx.run_b([src], tmp_path, False, False) == 1
    assert not list(tmp_path.glob("*_v.jpg"))


def test_出典の行が無い写真は止まる(tmp_path):
    src = _photo(tmp_path)
    assert fx.run_b([src], tmp_path, False, False) == 1


def test_G背景は縦9対16(tmp_path):
    bg, _ = fx.gradient_bg(None)
    assert bg.size == (1080, 1920)
    tile = Image.new("RGB", (800, 1000), (200, 50, 50))
    mask = Image.new("L", (800, 1000), 0)
    ImageDraw.Draw(mask).rectangle((200, 100, 600, 1000), fill=255)
    out, _ = fx.place_person(bg, tile, mask)
    assert out.size == (1080, 1920)


def test_番号は既存の次から(tmp_path):
    (tmp_path / "01.jpg").write_bytes(b"x")
    (tmp_path / "03_v.jpg").write_bytes(b"x")
    assert fx.next_numbers(tmp_path, 2) == [4, 5]
