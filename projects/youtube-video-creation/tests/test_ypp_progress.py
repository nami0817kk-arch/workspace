"""収益化までの道のりの計算（2026-09-28）。"""
import datetime
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("ypp_progress", Path("tools/ypp_progress.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_届く日はペースから出す():
    assert mod.eta(1000, 1000, 1.0) == "届いている"
    assert "測れない" in mod.eta(70, 1000, 0.0)
    got = mod.eta(70, 1000, 3.3)
    assert got.startswith("あと約282日")


def _snap(folder, subs, rows):
    folder.mkdir(parents=True)
    (folder / "road.json").write_text(json.dumps({
        "channel": {"subs": subs},
        "videos": [{"id": "m1", "short": False}, {"id": "s1", "short": True}]}), encoding="utf-8")
    (folder / "watch.json").write_text(json.dumps({"rows": rows}), encoding="utf-8")


def test_ペースは前回の控えとの差で測る(tmp_path):
    _snap(tmp_path / "20260901", 40, [["m1", 100, 6000], ["s1", 100, 9000]])
    _snap(tmp_path / "20260911", 70, [["m1", 100, 12000], ["s1", 100, 9000]])
    lines = mod.report(tmp_path / "20260911", tmp_path / "20260901")
    text = "\n".join(lines)
    assert "登録者　　　70人" in text
    assert "本編の視聴時間　200時間" in text          # ショートの 9000分 は数えない
    assert "登録 +3.0人/日、本編 +10.0時間/日" in text
