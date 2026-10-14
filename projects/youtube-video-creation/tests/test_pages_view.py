"""台本のページの頭に「この動画の見立て」を出す（2026-10-01 ユーザー指示「見立ては何についてかを分かりやすく見れるように」）。"""
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("pages_tool", Path("tools/pages.py"))
pages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pages)


def test_見立ての節と1文を頭の枠に出す():
    meta = {"description": "題\n\n  この動画の見立て: 出場時間は上田271分・ジルー115分\n"}
    sections = [{"heading": "発表", "viewpoint": False}, {"heading": "271分と115分", "viewpoint": True}]
    box, line = pages.view_box(meta, sections)
    assert "何について：271分と115分" in box and "上田271分" in box
    assert "見立て：271分と115分" in line


def test_見立てが無い回は目立たせる():
    box, line = pages.view_box({"description": "題だけ"}, [{"heading": "発表", "viewpoint": False}])
    assert "見立ての節がありません" in box and 'class="view none"' in box
    assert line.endswith("見立て：なし</span>")
