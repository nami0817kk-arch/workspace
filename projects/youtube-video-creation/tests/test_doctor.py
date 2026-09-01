from datetime import datetime, timedelta

import pytest

from src.doctor import VERIFY_DAYS, diagnose
from src.plan import build_plan
from tests.test_plan import RAW

NOW = datetime(2026, 8, 30, 12, 0)


@pytest.fixture
def plan(tmp_path, monkeypatch):
    from src import doctor

    built = build_plan(RAW)
    built.domains = {"english": ["a.example", "b.example"], "blocked": ["x.example"]}
    built.leagues = {"england": {"name": "プレミアリーグ"}, "spain": {"name": "ラ・リーガ"}}
    built.verified_on = "2026-08-30"
    built.coverage = {"ledger": str(tmp_path / "covered.yaml")}
    built.accounts = []

    # 記録の置き場をテスト用に差し替える
    monkeypatch.setattr(doctor.freshness, "load", lambda path: [])
    monkeypatch.setattr(doctor.queries, "load", lambda: [])
    monkeypatch.setattr(doctor.xposts, "load_calls", lambda: [])
    return built


def _by_label(notes):
    return {note.label: note for note in notes}


def test_a_fresh_network_passes(plan):
    result = _by_label(diagnose(plan, NOW))["情報源の網"]
    assert result.ok
    assert "2サイト" in result.detail        # blocked は数えない


def test_an_old_network_is_flagged(plan):
    plan.verified_on = "2026-01-01"
    result = _by_label(diagnose(plan, NOW))["情報源の網"]
    assert result.ok is False
    assert "確かめ直して" in result.detail


def test_a_missing_verification_date_is_flagged(plan):
    plan.verified_on = ""
    assert _by_label(diagnose(plan, NOW))["情報源の網"].ok is False


def test_a_broken_verification_date_is_flagged(plan):
    plan.verified_on = "きのう"
    assert _by_label(diagnose(plan, NOW))["情報源の網"].ok is False


def test_an_empty_index_ledger_is_flagged(plan):
    assert _by_label(diagnose(plan, NOW))["索引の記録"].ok is False


def test_a_stale_index_ledger_is_flagged(plan, monkeypatch):
    from src import doctor
    from src.freshness import Observation

    old = [Observation("a.example", 100, NOW - timedelta(days=5))]
    monkeypatch.setattr(doctor.freshness, "load", lambda path: old)
    result = _by_label(diagnose(plan, NOW))["索引の記録"]
    assert result.ok is False
    assert "5日更新がありません" in result.detail


def test_a_dead_search_is_flagged(plan, monkeypatch):
    from src import doctor
    from src.queries import Run

    runs = [Run("空振り", NOW - timedelta(days=day), 0) for day in range(6)]
    monkeypatch.setattr(doctor.queries, "load", lambda: runs)
    result = _by_label(diagnose(plan, NOW))["検索の実績"]
    assert result.ok is False
    assert "空振り" in result.detail


def test_untouched_leagues_are_flagged(plan):
    from src import coverage

    coverage.record(plan.coverage["ledger"], "morning", [("k", "h")], NOW, league="england")
    result = _by_label(diagnose(plan, NOW))["追えていないリーグ"]
    assert result.ok is False
    assert "ラ・リーガ" in result.detail


def test_covering_everything_leaves_no_gap_note(plan):
    from src import coverage

    for league in ("england", "spain"):
        coverage.record(plan.coverage["ledger"], "morning", [(league, "h")], NOW, league=league)
    assert "追えていないリーグ" not in _by_label(diagnose(plan, NOW))


def test_a_poor_reporter_is_flagged(plan, monkeypatch):
    from datetime import datetime as dt

    from src import doctor
    from src.xposts import Call

    calls = [Call("A", f"u{i}", "x", dt(2026, 8, 30), "外れ") for i in range(6)]
    monkeypatch.setattr(doctor.xposts, "load_calls", lambda: calls)
    plan.accounts = [{"handle": "A"}]
    assert _by_label(diagnose(plan, NOW))["記者の答え合わせ"].ok is False


def test_unverified_feeds_are_flagged(plan):
    plan.feeds = [{"name": "Sky", "url": "https://x", "verified": False}]
    result = _by_label(diagnose(plan, NOW))["RSSフィード"]
    assert result.ok is False
    assert "fetch --check" in result.detail


def test_verified_feeds_pass(plan):
    plan.feeds = [{"name": "Sky", "url": "https://x", "verified": True}]
    assert _by_label(diagnose(plan, NOW))["RSSフィード"].ok is True


def test_no_feeds_is_not_an_error(plan):
    plan.feeds = []
    assert _by_label(diagnose(plan, NOW))["RSSフィード"].ok is True


# build は VOICEVOX が無いと黙って無音で書き出す。朝の運用でこれに気づかないと
# 無音の動画を3本作ってから気づく。週1の健康診断に声の確認も入れる。


def test_声が出ない状態は健康診断が拾う(monkeypatch):
    from src import cli, tts

    monkeypatch.setattr(tts, "create_backend", lambda config: tts.SilentBackend())
    note = cli._voice_note(None)
    assert not note.ok
    assert "無音" in note.detail


def test_声が出るなら緑(monkeypatch):
    from src import cli, tts

    class Fake:
        name = "engine"

    monkeypatch.setattr(tts, "create_backend", lambda config: Fake())
    assert cli._voice_note(None).ok


def test_バックエンドが作れなくても診断は落ちない(monkeypatch):
    from src import cli, tts

    def boom(config):
        raise tts.TtsError("接続失敗")

    monkeypatch.setattr(tts, "create_backend", boom)
    note = cli._voice_note(None)
    assert not note.ok
