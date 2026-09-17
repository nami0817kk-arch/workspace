"""報道写真の取り込み（2026-09-17 に方針を C まで開けた）。"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def test_出典を控えに残す(tmp_path):
    """**どこから来た写真かを隠さない。**

    許諾は得ていないので権利は晴れないが、記事URL・媒体名・写真の表記を
    控えに残し、概要欄に出す。`tts.image_details` がこの行から作る。
    """
    from tools.pressphoto import record

    folder = tmp_path / "nakamura_press"
    folder.mkdir()
    record(folder, {"file": "01.jpg", "source": "press",
                    "page_url": "https://example.jp/a", "author": "©Koki N/GEKISAKA",
                    "license": "報道写真（許諾は得ていない／出典を明示して使用）",
                    "outlet": "ゲキサカ"})
    rows = json.loads((folder / "credits.json").read_text(encoding="utf-8"))
    assert rows[0]["file"] == "01.jpg"
    assert rows[0]["outlet"] == "ゲキサカ"
    assert "許諾は得ていない" in rows[0]["license"]

    # 同じファイルを取り直しても増えない
    record(folder, dict(rows[0], author="別の表記"))
    rows = json.loads((folder / "credits.json").read_text(encoding="utf-8"))
    assert len(rows) == 1


def test_報道写真のクレジットは概要欄に出る():
    """**表示を落とさない。**CC0 や Pexels のように行ごと消す扱いにしない。"""
    from src.tts import credit_line

    line = credit_line("", "©Koki NAGAHAMA/GEKISAKA",
                       "報道写真（許諾は得ていない／出典を明示して使用）",
                       "https://web.gekisaka.jp/news/x")
    assert line, "報道写真の行が落ちている"
    assert "GEKISAKA" in line
    assert "gekisaka.jp" in line
