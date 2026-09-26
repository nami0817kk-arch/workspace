"""ストップ高／ストップ安の記録の保存。

**0件だったのか、取得に失敗したのかを取り違えない**ことが要点。
取れなかった日を0件として記録すると、あとから見たときに
「その日はストップ高が無かった」という嘘になる。取り逃した営業日は二度と取れない。
"""
import pandas as pd
import pytest

import build_site
import fetcher


@pytest.fixture(autouse=True)
def clean_state():
    fetcher.pages_fetched.clear()
    yield
    fetcher.pages_fetched.clear()


def _df(rows):
    return pd.DataFrame(rows)


_ROW = {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
        "change_pct": 44.25, "at_limit": True}


def test_取れた日は行がそのまま入る():
    fetcher.pages_fetched[fetcher.STOP_HIGH_LABEL] = 3
    rows = build_site._stop_rows(_df([_ROW]), fetcher.STOP_HIGH_LABEL)
    assert rows == [_ROW]


def test_ページは取れて0件なら空リスト():
    """相場が穏やかな日は本当に1件も無い。異常ではない。"""
    fetcher.pages_fetched[fetcher.STOP_HIGH_LABEL] = 3
    assert build_site._stop_rows(pd.DataFrame(), fetcher.STOP_HIGH_LABEL) == []


def test_1ページも取れなければNone():
    """0件と区別するため。呼び出し側がキーごと落とす。"""
    fetcher.pages_fetched[fetcher.STOP_HIGH_LABEL] = 0
    assert build_site._stop_rows(pd.DataFrame(), fetcher.STOP_HIGH_LABEL) is None


def test_取得そのものを走らせていなければNone():
    assert build_site._stop_rows(pd.DataFrame(), fetcher.STOP_LOW_LABEL) is None


def test_取れなかったランキングはキーごと保存しない(tmp_path, monkeypatch):
    monkeypatch.setattr(build_site, "_DATA_DIR", tmp_path)
    fetcher.pages_fetched[fetcher.STOP_HIGH_LABEL] = 3
    fetcher.pages_fetched[fetcher.STOP_LOW_LABEL] = 0
    gainers = _df([{"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}",
                    "close": 100.0, "change_pct": 5.0, "metric_value": 1,
                    "rec_date": "2026-09-28"} for i in range(1, 31)])
    empty = _df([])
    build_site._save_today(gainers, empty, empty,
                           _df([{**_ROW, "rec_date": "2026-09-28"}]), empty,
                           skip_checks=True)
    import json
    saved = json.loads((tmp_path / "2026-09-28.json").read_text(encoding="utf-8"))
    assert saved["stop_high"] == [_ROW]
    assert "stop_low" not in saved
