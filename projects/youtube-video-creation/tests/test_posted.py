"""二重投稿の歯止め。

2026-09-07 に、本編8本を上げる処理が走っている最中に2本目を起こして
4本を重複公開した。**人が気をつけるのではなく、投稿する側が控えを見る。**
"""

from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from src import posted


@pytest.fixture
def ledger(tmp_path: Path) -> Path:
    return tmp_path / "posted.json"


def test_控えが無ければ見つからない(ledger: Path) -> None:
    assert posted.find("output/20260907_japan", ledger) is None


def test_控えたら見つかる(ledger: Path) -> None:
    posted.record("output/20260907_japan", "abc123", ledger)
    row = posted.find("output/20260907_japan", ledger)
    assert row is not None
    assert row["video_id"] == "abc123"


def test_出力先の名前だけで照らす(ledger: Path) -> None:
    """呼び出し方が違っても同じ出力先だと分かること。"""
    posted.record("output/20260907_japan", "abc123", ledger)
    assert posted.find("./output/20260907_japan/", ledger) is not None


def test_別の出力先は素通しする(ledger: Path) -> None:
    posted.record("output/20260907_japan", "abc123", ledger)
    assert posted.find("output/20260907_japan_short", ledger) is None


def test_上げ直したら新しい方を返す(ledger: Path) -> None:
    posted.record("output/20260907_japan", "old", ledger)
    posted.record("output/20260907_japan", "new", ledger)
    assert posted.find("output/20260907_japan", ledger)["video_id"] == "new"


def test_壊れた控えでも止まらない(ledger: Path) -> None:
    ledger.write_text("{ これは JSON ではない", encoding="utf-8")
    assert posted.find("output/x", ledger) is None
    posted.record("output/x", "v1", ledger)
    assert posted.find("output/x", ledger)["video_id"] == "v1"


def _at(hours_ago: float, now: datetime) -> datetime:
    return now - timedelta(hours=hours_ago)


def test_直近24時間だけ数える(ledger: Path) -> None:
    now = datetime(2026, 9, 7, 10, 0, tzinfo=timezone.utc)
    posted.record("output/a", "v1", ledger, now=_at(25, now))   # 窓の外
    posted.record("output/b", "v2", ledger, now=_at(23, now))
    posted.record("output/c", "v3", ledger, now=_at(1, now))
    assert posted.in_window(ledger, now) == 2


def test_残りは上限から引いた数(ledger: Path) -> None:
    now = datetime(2026, 9, 7, 10, 0, tzinfo=timezone.utc)
    for i in range(5):
        posted.record(f"output/{i}", f"v{i}", ledger, now=_at(1, now))
    assert posted.left(ledger, now) == posted.WINDOW_MAX - 5


def test_上限まで埋まっていなければ空き待ちは無い(ledger: Path) -> None:
    now = datetime(2026, 9, 7, 10, 0, tzinfo=timezone.utc)
    posted.record("output/a", "v1", ledger, now=_at(1, now))
    assert posted.frees_at(ledger, now) is None


def test_埋まっていたら次に空く時刻が出る(ledger: Path) -> None:
    """**転がる24時間の窓**なので、いちばん古い1本が抜けた時に空く。"""
    now = datetime(2026, 9, 7, 10, 0, tzinfo=timezone.utc)
    oldest = _at(20, now)
    posted.record("output/0", "v0", ledger, now=oldest)
    for i in range(1, posted.WINDOW_MAX):
        posted.record(f"output/{i}", f"v{i}", ledger, now=_at(1, now))
    assert posted.left(ledger, now) == 0
    assert posted.frees_at(ledger, now) == oldest + timedelta(hours=24)
