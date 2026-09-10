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


def test_解除はエラーから24時間(ledger: Path, tmp_path: Path) -> None:
    """**固定時刻でも、1本ずつ空く方式でもない。**

    2026-09-07、10:36 に弾かれてから 12:41 も 16:02 も弾かれたままだった。
    「転がる24時間の窓」「日本時間16時リセット」と2回書いて2回とも外した。
    """
    blocks = tmp_path / "blocked.json"
    hit = datetime(2026, 9, 7, 1, 36, tzinfo=timezone.utc)      # 10:36 JST
    posted.block(blocks, now=hit)
    later = datetime(2026, 9, 7, 7, 2, tzinfo=timezone.utc)     # 16:02 JST 同じ日
    assert posted.blocked_until(blocks, now=later) == hit + timedelta(hours=24)


def test_24時間たてば解除待ちは消える(ledger: Path, tmp_path: Path) -> None:
    blocks = tmp_path / "blocked.json"
    hit = datetime(2026, 9, 7, 1, 36, tzinfo=timezone.utc)
    posted.block(blocks, now=hit)
    assert posted.blocked_until(blocks, now=hit + timedelta(hours=25)) is None


def test_弾かれた記録が無ければ解除待ちも無い(tmp_path: Path) -> None:
    assert posted.blocked_until(tmp_path / "blocked.json") is None


def test_直近24時間の本数を数える(ledger: Path) -> None:
    now = datetime(2026, 9, 7, 3, 41, tzinfo=timezone.utc)
    posted.record("output/a", "v1", ledger, now=now - timedelta(hours=25))
    posted.record("output/b", "v2", ledger, now=now - timedelta(hours=23))
    posted.record("output/c", "v3", ledger, now=now)
    assert posted.recent(ledger, now) == 2


def test_消した動画も本数に数える(ledger: Path) -> None:
    """**上げた時点で枠は消費されていて、消しても戻らない。**"""
    now = datetime(2026, 9, 7, 3, 41, tzinfo=timezone.utc)
    posted.record("output/a", "v1", ledger, now=now)
    import json
    rows = json.loads(ledger.read_text(encoding="utf-8"))
    rows[0]["deleted"] = True
    ledger.write_text(json.dumps(rows), encoding="utf-8")
    assert posted.recent(ledger, now) == 1


def test_消した動画は二重投稿の判定に出さない(ledger: Path) -> None:
    """消えたURLを出して止めても紛らわしい。上げ直したくて消したのかもしれない。"""
    import json
    posted.record("output/a", "v1", ledger)
    rows = json.loads(ledger.read_text(encoding="utf-8"))
    rows[0]["deleted"] = True
    ledger.write_text(json.dumps(rows), encoding="utf-8")
    assert posted.find("output/a", ledger) is None

# 投稿を時間で散らす（2026-09-07）。参考チャンネルは1時間に1本ずつ、
# こちらは13時間前に4本と固めて出していた。

def test_前の投稿からの間隔が分かる(tmp_path):
    from datetime import datetime, timedelta, timezone

    from src import posted

    book = tmp_path / "posted.json"
    now = datetime(2026, 9, 8, 12, 0, tzinfo=timezone.utc)
    assert posted.since_last(book, now) is None          # 控えが無ければ None
    posted.record("out/a", "abc123", book, now=now - timedelta(minutes=20))
    assert round(posted.since_last(book, now)) == 20


def test_目安は30分():
    from src import posted

    assert posted.SPREAD_MINUTES == 30


def test_動画IDから出力先を引ける(tmp_path):
    """**控えは `output/` を含まない名前で持っている**（2026-09-10）。

    そのまま `comment` に渡すと「出力先が分かりません」になり、
    公開済み7本ぶん手で `output/` を足して回した。引く側に置いておく。
    """
    import json

    from src import posted

    book = tmp_path / "posted.json"
    book.write_text(json.dumps([
        {"build": "20260910_haaland", "video_id": "abc123", "at": "2026-09-10T00:00:00+00:00"},
    ]), encoding="utf-8")
    got = posted.folder_of("abc123", root=tmp_path / "output", path=book)
    assert got is not None and got.name == "20260910_haaland"
    assert posted.folder_of("ない", root=tmp_path / "output", path=book) is None
