"""投稿の前に動画を見せたかの控え（2026-09-13 ユーザー「今後は投稿する前に動画見して」）。"""

from __future__ import annotations

import json

from src import screening


def _build(tmp_path, name="20260914_doan", body=b"movie"):
    out = tmp_path / name
    out.mkdir()
    (out / "video.mp4").write_bytes(body)
    return out


def test_見せていない動画は通さない(tmp_path):
    out = _build(tmp_path)
    ledger = tmp_path / "screened.json"
    assert not screening.is_screened(out, ledger)
    assert "まだ動画を見せていません" in screening.refusal(out, ledger)


def test_見せたら通る(tmp_path):
    out = _build(tmp_path)
    ledger = tmp_path / "screened.json"
    stamp = screening.screen(out, ledger)
    assert stamp
    assert screening.is_screened(out, ledger)


def test_作り直したら見せ直しになる(tmp_path):
    # **名前だけの控えだと、直したあとに素通りする。**台本の控えで
    # 実際に起きた（伊藤涼太郎の回）ので、こちらは最初から中身まで見る
    out = _build(tmp_path)
    ledger = tmp_path / "screened.json"
    screening.screen(out, ledger)
    (out / "video.mp4").write_bytes(b"movie v2")
    assert not screening.is_screened(out, ledger)
    assert screening.changed_since_screening(out, ledger)
    assert "作り直しています" in screening.refusal(out, ledger)


def test_動画が無ければ印は空(tmp_path):
    out = tmp_path / "20260914_none"
    out.mkdir()
    assert screening.digest_of(out) == ""
    assert not screening.is_screened(out, tmp_path / "screened.json")


def test_控えは名前で引く(tmp_path):
    out = _build(tmp_path)
    ledger = tmp_path / "screened.json"
    screening.screen(out, ledger)
    saved = json.loads(ledger.read_text(encoding="utf-8"))
    assert "20260914_doan" in saved
    assert saved["20260914_doan"]["digest"] == screening.digest_of(out)


def test_印の無い古い控えは通さない(tmp_path):
    # 控えの作りを変えたときに、印を持たない行が残ることがある。
    # 迷ったら聞く側に倒す
    out = _build(tmp_path)
    ledger = tmp_path / "screened.json"
    ledger.write_text(json.dumps({"20260914_doan": {"at": "2026-09-13T20:00:00+09:00"}}),
                      encoding="utf-8")
    assert not screening.is_screened(out, ledger)
