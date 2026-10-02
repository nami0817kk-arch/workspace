"""離脱した行の地図（2026-10-03）。作り物の曲線と台本で、計算の部分だけを確かめる。"""
import importlib.util
import sys
from datetime import date, datetime, timezone
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location(
    "dropmap", Path(__file__).resolve().parent.parent / "tools" / "dropmap.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["dropmap"] = mod   # dataclass が自分のモジュールを引くので先に登録する
spec.loader.exec_module(mod)


def _script():
    """10秒の台本。タイトル2秒・語り2秒・数字2秒・節の頭2秒・反応2秒。"""
    return {"scenes": [
        {"title": "オープニング", "lines": [
            {"speaker": "キャスター", "text": "久保建英が結婚を発表。", "start": 0.0, "duration": 2.0},
            {"speaker": "キャスター", "text": "2日の夜に発表しました。", "start": 2.0, "duration": 2.0},
            {"speaker": "キャスター", "text": "今季は7試合で3得点。", "start": 4.0, "duration": 2.0},
        ]},
        {"title": "反応", "lines": [
            {"speaker": "解説", "text": "仲間からも祝福が届きました。", "start": 6.0, "duration": 2.0},
            {"speaker": "久保建英", "text": "支えてくれた人に感謝します", "start": 8.0, "duration": 1.0},
            {"speaker": "ネット民", "text": "おめでとう！", "start": 9.0, "duration": 1.0},
        ]},
    ]}


# 0〜10秒で 100% → 50% に落ちる直線（尺10秒）
LINEAR = [(0.0, 1.0), (1.0, 0.5)]


def test_行への割り当ては秒を尺で割った地点の維持率():
    lines = mod.script_lines(_script())
    drops = mod.map_lines(LINEAR, lines, 10.0)
    assert [round(d.top, 3) for d in drops] == [1.0, 0.9, 0.8, 0.7, 0.6, 0.55]
    assert [round(d.bottom, 3) for d in drops] == [0.9, 0.8, 0.7, 0.6, 0.55, 0.5]


def test_落ち幅と秒あたり():
    drops = mod.map_lines([(0.0, 1.0), (0.2, 0.4), (1.0, 0.4)], mod.script_lines(_script()), 10.0)
    # 0〜2秒で 1.0 → 0.4 に落ち、そのあとは平ら
    assert drops[0].drop == pytest.approx(0.6)
    assert drops[0].per_second == pytest.approx(0.3)
    assert all(d.drop == pytest.approx(0.0) for d in drops[1:])


def test_startが無い行はdurationを積み上げる():
    script = {"scenes": [{"title": "a", "lines": [
        {"speaker": "キャスター", "text": "一", "duration": 3.0},
        {"speaker": "キャスター", "text": "二", "duration": 2.5},
    ]}, {"title": "b", "lines": [{"speaker": "解説", "text": "三", "duration": 1.0}]}]}
    lines = mod.script_lines(script)
    assert [ln.start for ln in lines] == [0.0, 3.0, 5.5]


def test_種類の分類():
    kinds = [mod.classify(ln) for ln in mod.script_lines(_script())]
    assert kinds == ["タイトル", "その他の語り", "数字", "前置き", "代弁", "反応"]


def test_締めと海外の反応():
    script = {"scenes": [
        {"title": "a", "lines": [{"speaker": "キャスター", "text": "題", "duration": 1}]},
        {"title": "b", "lines": [
            {"speaker": "キャスター", "text": "続報が入りました。", "duration": 1},
            {"speaker": "海外のファン", "text": "Kubo!", "duration": 1},
        ]},
        {"title": "c", "lines": [
            {"speaker": "キャスター", "text": "本編はチャンネルから見られます。", "duration": 1},
            {"speaker": "キャスター", "text": "続報をお伝えします。", "duration": 1},
            {"speaker": "キャスター", "text": "チャンネル登録もお願いします。", "duration": 1},
        ]},
    ]}
    kinds = [mod.classify(ln) for ln in mod.script_lines(script)]
    # 途中の節の「続報」は中身の話（締めではない）。最後の節だけ締めに数える
    assert kinds == ["タイトル", "前置き", "反応", "締め", "締め", "締め"]


def test_数字が1つだけの語りは数字の行にしない():
    script = {"scenes": [{"title": "a", "lines": [
        {"speaker": "キャスター", "text": "題", "duration": 1},
        {"speaker": "キャスター", "text": "前置き", "duration": 1},
        {"speaker": "キャスター", "text": "7試合ぶりの出場です。", "duration": 1},
    ]}]}
    assert mod.classify(mod.script_lines(script)[2]) == "その他の語り"


def test_冒頭30秒の落ち幅():
    assert mod.first_drop(LINEAR, 60.0) == pytest.approx(0.25)
    # 30秒より短い動画は最後まで
    assert mod.first_drop(LINEAR, 20.0) == pytest.approx(0.5)


def _posted():
    return [
        {"build": "a", "video_id": "A", "at": "2026-10-01T00:00:00+00:00"},
        {"build": "a_short", "video_id": "As", "at": "2026-10-01T00:00:00+00:00",
         "publish_at": "2026-10-01T03:00:00Z"},
        {"build": "(以前)-X", "video_id": "X", "at": "2026-10-01T00:00:00+00:00"},
        {"build": "b", "video_id": "B", "at": "2026-10-01T00:00:00+00:00", "deleted": True},
        {"build": "c", "video_id": "C", "at": "2026-10-02T00:00:00+00:00"},
        {"build": "old", "video_id": "O", "at": "2026-09-01T00:00:00+00:00"},
    ]


def test_測れなかった本数を理由ごとに数える(tmp_path):
    import json

    for build in ("a", "a_short", "c"):
        (tmp_path / build).mkdir()
        (tmp_path / build / "script.json").write_text(
            json.dumps(_script(), ensure_ascii=False), encoding="utf-8")
    # A と As には曲線があり、C はまだ無い
    fixture = {"A": [[0.0, 1.0], [1.0, 0.5]], "As": [[0.0, 1.0], [1.0, 0.2]]}
    text, summary = mod.run(14, "all", True, fixture, date(2026, 10, 3), tmp_path, _posted())
    assert summary["measured"] == 2
    assert summary["skipped"] == 3
    assert summary["reasons"] == {"台本が手元に無い": 1, "削除済み": 1, "曲線がまだ無い": 1}
    assert summary["calls"] == 0
    assert "測れた 2本 / 測れなかった 3本" in text
    assert summary["groups"]["ショート"]["videos"] == 1
    assert summary["groups"]["本編"]["skipped"] == 3


def test_種類を絞ると反対側は数えない():
    since = datetime(2026, 9, 20, tzinfo=timezone.utc)
    shorts = mod.pick_targets(_posted(), since, "short", lambda b: True)
    assert [t.video_id for t in shorts] == ["As"]
    mains = mod.pick_targets(_posted(), since, "main", lambda b: True)
    assert "As" not in [t.video_id for t in mains] and "O" not in [t.video_id for t in mains]


# ---------------------------------------------------------------- 壊れた例で × になるか

def test_空の曲線は黙って0にしない():
    with pytest.raises(ValueError):
        mod.ratio_at([], 0.5)


def test_尺が0なら止める():
    with pytest.raises(ValueError):
        mod.map_lines(LINEAR, mod.script_lines(_script()), 0.0)


def test_尺を取り違えると割り当てがずれる():
    """尺を倍に間違えると、行の始まりの維持率が変わる。ずれを見逃さない。"""
    lines = mod.script_lines(_script())
    right = mod.map_lines(LINEAR, lines, 10.0)
    wrong = mod.map_lines(LINEAR, lines, 20.0)
    assert [d.top for d in right] != [d.top for d in wrong]


def test_曲線の無い動画を測れた側に数えない(tmp_path):
    """全部の曲線が空なら、測れた本数は0で、レポートにもそう出る。"""
    import json

    (tmp_path / "a").mkdir()
    (tmp_path / "a" / "script.json").write_text(json.dumps(_script()), encoding="utf-8")
    posted = [{"build": "a", "video_id": "A", "at": "2026-10-01T00:00:00+00:00"}]
    text, summary = mod.run(14, "all", True, {}, date(2026, 10, 3), tmp_path, posted)
    assert summary["measured"] == 0 and summary["skipped"] == 1
    assert "測れた 0本 / 測れなかった 1本" in text
    assert "測れた動画なし" in text
