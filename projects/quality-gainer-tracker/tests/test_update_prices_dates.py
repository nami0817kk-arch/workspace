"""追跡価格を「どの日から」埋めるかのテスト。

d01 は記録日の翌営業日、と決まっている。ここがずれると、14営業日の追跡が
丸ごと別の期間の値になる。**しかも見た目には何も起きない**（数字は入るので、
後から気づく手がかりが無い）。記録の連続性がこのプロジェクトの価値なので、
基準日の決め方だけは固定しておく。

DB には触らない。接続と価格取得を差し替えて、書き込もうとした値だけを見る。
"""
import pandas as pd
import pytest

from src.db import manager


class _FakeCursor:
    """pyodbc のカーソルの、このテストに必要な部分だけ。"""

    def __init__(self, rows, executed):
        self._rows = rows
        self._executed = executed
        self._last = ""

    def execute(self, sql, params=()):
        self._last = sql
        self._executed.append((sql, params))
        return self

    def fetchall(self):
        return self._rows

    def fetchone(self):
        # 「現在の d カラム」を聞かれたら、全部未記入として返す
        if "SELECT [d01]" in self._last:
            return tuple([None] * 14)
        return None


class _FakeConnection:
    def __init__(self, rows, executed):
        self._rows = rows
        self._executed = executed

    def cursor(self):
        return _FakeCursor(self._rows, self._executed)

    def close(self):
        pass

    def commit(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


@pytest.fixture
def harness(monkeypatch):
    """1レコード（7203 / 記録日 2026-09-01）だけを追跡中にする。"""
    executed: list[tuple] = []
    rows = [(1, "2026-09-01", "7203")]

    monkeypatch.setattr(manager, "_ensure_table", lambda: None)
    monkeypatch.setattr(manager, "_connect", lambda: _FakeConnection(rows, executed))
    return executed


def _prices(dates: list[str], closes: list[float] | None = None) -> pd.DataFrame:
    closes = closes or [100.0 + i for i in range(len(dates))]
    return pd.DataFrame({"Close": closes}, index=pd.to_datetime(dates))


def _updates(executed):
    """UPDATE 文に渡された値を {列名: 値} で返す。"""
    for sql, params in executed:
        if sql.startswith("UPDATE"):
            cols = [part.split("[")[1].split("]")[0] for part in sql.split("=")[:-1] if "[" in part]
            return dict(zip(cols, params))
    return {}


def test_記録日の翌営業日から順に埋める(harness, monkeypatch):
    dates = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"]
    monkeypatch.setattr(manager.yf, "download", lambda *a, **k: _prices(dates))

    manager.update_prices()

    updates = _updates(harness)
    assert updates["d01"] == 101.0   # 2026-09-02 の終値
    assert updates["d02"] == 102.0
    assert updates["d03"] == 103.0
    assert "d04" not in updates      # まだ来ていない日は埋めない


def test_記録日にその銘柄の取引が無ければ直前の営業日を基準にする(harness, monkeypatch):
    # 9/01 は売買が成立せず行が無い。基準は 8/31 で、d01 は 9/02 になる。
    dates = ["2026-08-31", "2026-09-02", "2026-09-03"]
    monkeypatch.setattr(manager.yf, "download", lambda *a, **k: _prices(dates))

    manager.update_prices()

    updates = _updates(harness)
    assert updates["d01"] == 101.0   # 2026-09-02
    assert updates["d02"] == 102.0   # 2026-09-03


def test_記録日より後の価格しか無いときは書き込まない(harness, monkeypatch, capsys):
    """取得範囲が記録日より後から始まる場合、基準日が決められない。

    ここで「いちばん古い行」を d01 にしてしまうと、14営業日ぶん丸ごと
    別の期間の値が入る。数字は埋まるので、後から気づく手がかりが無い。
    """
    dates = ["2026-09-20", "2026-09-21", "2026-09-24"]
    monkeypatch.setattr(manager.yf, "download", lambda *a, **k: _prices(dates))

    manager.update_prices()

    assert _updates(harness) == {}, "基準日が決まらないのに書き込んでいる"
    out = capsys.readouterr().out
    assert "[WARN]" in out and "7203" in out


def test_株式分割があったら知らせる(harness, monkeypatch, capsys):
    """記録時終値は分割前の値のまま。調整済みの終値と比べると成績がずれる。"""
    dates = ["2026-09-01", "2026-09-02", "2026-09-03"]
    df = _prices(dates)
    df["Stock Splits"] = [0.0, 2.0, 0.0]
    monkeypatch.setattr(manager.yf, "download", lambda *a, **k: df)

    manager.update_prices()

    out = capsys.readouterr().out
    assert "分割" in out and "7203" in out
