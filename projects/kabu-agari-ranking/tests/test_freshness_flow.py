"""鮮度の監視が、実際に main() から働いているか。

**関数を書いただけで配線していなかった**ことがある（2026-09-28）。
ストップ高・ストップ安の欠落を見る関数は定義されていたのに、main() から
呼ばれておらず、テストも関数を直接叩いていたので気づけなかった。
ここは main() を通して見る。
"""
import json
from datetime import date, datetime, timedelta

import pytest

import check_freshness


@pytest.fixture
def data_dir(tmp_path, monkeypatch):
    monkeypatch.setattr(check_freshness, "_DATA_DIR", tmp_path)
    monkeypatch.setattr("sys.argv", ["check_freshness.py", "--after-fetch"])
    return tmp_path


def _write(data_dir, rec_date, **extra):
    (data_dir / "latest.json").write_text(
        json.dumps({"rec_date": rec_date, "gainers": [{}], **extra}, ensure_ascii=False),
        encoding="utf-8")


def _today_business_day():
    """祝日表の範囲にある直近の営業日。"""
    d = date(2026, 9, 28)      # 月曜
    return d


def test_記録が欠けていれば落とす(data_dir, monkeypatch, capsys):
    """ランキングは取れているので鮮度の判定には引っかからない。
    ここで見ないと、当日中に取り直す機会を逃す。"""
    rec = _today_business_day()
    _write(data_dir, rec.isoformat(), stop_low=[])
    monkeypatch.setattr(check_freshness, "datetime", _FrozenDatetime(rec))
    assert check_freshness.main() == 1
    out = capsys.readouterr().out
    assert "ストップ高の一覧が取れていません" in out
    assert "fetch_stop_records" in out


def test_両方そろっていれば通る(data_dir, monkeypatch, capsys):
    rec = _today_business_day()
    _write(data_dir, rec.isoformat(), stop_high=[], stop_low=[])
    monkeypatch.setattr(check_freshness, "datetime", _FrozenDatetime(rec))
    assert check_freshness.main() == 0
    assert "取れていません" not in capsys.readouterr().out


def test_鮮度が古くても記録の欠落まで見る(data_dir, monkeypatch, capsys):
    """古いところで止めると、そのあとの欠落を見ないまま終わる。"""
    rec = _today_business_day()
    _write(data_dir, "2026-09-25")          # 1営業日ぶん古い
    monkeypatch.setattr(check_freshness, "datetime", _FrozenDatetime(rec))
    assert check_freshness.main() == 1
    out = capsys.readouterr().out
    assert "古いままです" in out


class _FrozenDatetime:
    """datetime.now(JST) だけを差し替える。"""

    def __init__(self, day: date):
        self._day = day

    def now(self, tz=None):
        return datetime(self._day.year, self._day.month, self._day.day, 17, 0, tzinfo=tz)

    def __getattr__(self, name):
        return getattr(datetime, name)
