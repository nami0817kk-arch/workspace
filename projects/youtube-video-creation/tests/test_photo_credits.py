# -*- coding: utf-8 -*-
"""写真を組み直す道具が、**使った写真の出典だけ**を引き継ぐか（2026-10-10）。

2026-10-10 に、マンチェスター・ユナイテッドのユニフォームの回で
**概要欄が 16,769 字**になり、投稿が上限（5000字）で弾かれた。
使った写真は3枚なのに、クレジットが **97件**並んでいた。

元は `tools/pairphoto.py` が、元の写真の置き場の `credits.json` を
**丸ごと写して `file` を全部 `01.jpg` に書き換えていた**こと。
`assets/backgrounds/credits.json` は20クラブぶん109件あるので、
2枚並べる相手にそこの1枚を選んだだけで109件が引き継がれる。

読む側（`src/tts._ledger_lines`）には
「どのフォルダも中身は 01.jpg なので、ファイル名だけで突き合わせない」と
2026-09 に直してあるのに、**書く側**が同じ罠に落ちていた。
"""
import importlib.util
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def _load(name: str):
    spec = importlib.util.spec_from_file_location(f"{name}_tool", ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[f"{name}_tool"] = mod
    spec.loader.exec_module(mod)
    return mod


def _photo(path: Path, size=(900, 1400)) -> None:
    """縦長の写真を1枚置く（`pairphoto` は横長を受け取らない）。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", size, (90, 110, 130)).save(path, quality=80)


def _ledger(folder: Path, rows: list[dict]) -> None:
    (folder / "credits.json").write_text(
        json.dumps(rows, ensure_ascii=False), encoding="utf-8")


def test_2枚並べた帳簿は使った写真の行だけを引き継ぐ(tmp_path):
    # 置き場に109件ぶんの帳簿がある（assets/backgrounds と同じ形）
    many = tmp_path / "backgrounds"
    _photo(many / "stadium_マンチェスターユナイテッド.png")
    _ledger(many, [
        {"file": f"stadium_クラブ{i}.png", "title": f"File:Stadium {i}.jpg",
         "author": f"撮った人{i}", "license": "CC BY-SA 2.0"}
        for i in range(108)
    ] + [
        {"file": "stadium_マンチェスターユナイテッド.png",
         "title": "File:Manchester United Old Trafford.jpg",
         "author": "Arne Müseler", "license": "CC BY-SA 3.0 de"},
    ])

    one = tmp_path / "images" / "fergie"
    _photo(one / "01.jpg")
    _ledger(one, [{"file": "01.jpg", "title": "File:Alex Ferguson 02 (cropped).jpg",
                   "author": "撮った人", "license": "CC BY-SA 2.0"}])

    pairphoto = _load("pairphoto")
    out_dir = tmp_path / "out"
    pairphoto.pair([one / "01.jpg", many / "stadium_マンチェスターユナイテッド.png"], out_dir)

    rows = json.loads((out_dir / "credits.json").read_text(encoding="utf-8"))
    titles = [r["title"] for r in rows]
    # **109件ではなく2件**。使った2枚のぶんだけ
    assert len(rows) == 2, f"使っていない写真まで引き継いでいます（{len(rows)}件）"
    assert "File:Alex Ferguson 02 (cropped).jpg" in titles
    assert "File:Manchester United Old Trafford.jpg" in titles
    assert all(r["file"] == "01.jpg" for r in rows)


def test_16対9に切った帳簿も使った写真の行だけを引き継ぐ(tmp_path):
    """`tools/widecrop.py` も同じ形で丸ごと写していた。"""
    many = tmp_path / "src"
    _photo(many / "02.jpg", (1200, 1800))
    _ledger(many, [
        {"file": "01.jpg", "title": "File:べつの写真.jpg", "license": "CC BY 2.0"},
        {"file": "02.jpg", "title": "File:これを切る.jpg", "license": "CC BY-SA 4.0"},
        {"file": "03.jpg", "title": "File:まだべつの写真.jpg", "license": "CC0"},
    ])

    widecrop = _load("widecrop")
    out_dir = tmp_path / "out"
    widecrop.crop_wide(many / "02.jpg", out_dir, top=0.1)

    rows = json.loads((out_dir / "credits.json").read_text(encoding="utf-8"))
    assert len(rows) == 1, f"切った写真以外まで引き継いでいます（{len(rows)}件）"
    assert rows[0]["title"] == "File:これを切る.jpg"
    assert rows[0]["file"] == "01.jpg", "切った先のファイル名に直っていません"
