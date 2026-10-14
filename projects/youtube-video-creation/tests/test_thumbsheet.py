"""サムネを並べる道具（2026-09-28）。"""
import importlib.util
from pathlib import Path

from PIL import Image

spec = importlib.util.spec_from_file_location("thumbsheet", Path("tools/thumbsheet.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_サムネを3列で並べて1枚にする(tmp_path):
    thumbs = []
    for i in range(4):
        d = tmp_path / f"2026100{i}_x"
        d.mkdir()
        Image.new("RGB", (1280, 720), (i * 40, 80, 120)).save(d / "thumbnail.png")
        thumbs.append(d / "thumbnail.png")
    out = mod.sheet(thumbs, tmp_path / "sheet.png")
    im = Image.open(out)
    assert im.width == 3 * 650 + 10 and im.height == 2 * 394 + 10


def test_空なら作らない(tmp_path):
    import pytest

    with pytest.raises(ValueError):
        mod.sheet([], tmp_path / "x.png")
