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


def test_枠が戻る時刻は日本時間の16時(ledger: Path) -> None:
    """**上限の本数は分からない。**確かなのは戻る時刻だけ。"""
    now = datetime(2026, 9, 7, 3, 41, tzinfo=timezone.utc)   # 12:41 JST
    back = posted.frees_at(ledger, now).astimezone(timezone(timedelta(hours=9)))
    assert (back.month, back.day, back.hour) == (9, 7, 16)


def test_戻る時刻は上げた本数に左右されない(ledger: Path) -> None:
    now = datetime(2026, 9, 7, 3, 41, tzinfo=timezone.utc)
    empty = posted.frees_at(ledger, now)
    for i in range(40):
        posted.record(f"output/{i}", f"v{i}", ledger, now=now)
    assert posted.frees_at(ledger, now) == empty


def test_枠が戻ってからの本数を数える(ledger: Path) -> None:
    now = datetime(2026, 9, 7, 3, 41, tzinfo=timezone.utc)      # 12:41 JST
    before = datetime(2026, 9, 6, 6, 0, tzinfo=timezone.utc)    # 15:00 JST 前日
    after = datetime(2026, 9, 6, 8, 0, tzinfo=timezone.utc)     # 17:00 JST 前日
    posted.record("output/a", "v1", ledger, now=before)         # 戻る前なので数えない
    posted.record("output/b", "v2", ledger, now=after)
    posted.record("output/c", "v3", ledger, now=now)
    assert posted.today(ledger, now) == 2


def test_転がる24時間の窓ではない(ledger: Path) -> None:
    """2026-09-07 に、弾かれてから2時間後も弾かれたままだった。

    24時間の窓なら数本ぶん空いていたはずで、そうならなかった。
    **同じ日のうちは、何本抜けても戻らない。**
    """
    hit = datetime(2026, 9, 7, 1, 36, tzinfo=timezone.utc)      # 10:36 JST 弾かれた
    later = datetime(2026, 9, 7, 3, 41, tzinfo=timezone.utc)    # 12:41 JST まだ弾かれる
    old = datetime(2026, 9, 6, 8, 0, tzinfo=timezone.utc)       # 25時間以上前ではない
    posted.record("output/a", "v1", ledger, now=old)
    assert posted.today(ledger, hit) == posted.today(ledger, later)
