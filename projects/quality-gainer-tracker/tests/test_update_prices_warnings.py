"""追跡価格更新の例外経路が黙らないことのテスト。

update_prices() は1銘柄の失敗で全体を止めない（commit がループ後にあるため、
中断すると他銘柄の更新まで失われる）。継続は意図した仕様だが、握りつぶすと
d カラムが埋まらない原因を追えなくなるので、WARN が出ることを固定する。

DB には触らない。接続まわりは差し替えて、例外経路だけを見る。
"""

import pytest

from src.db import manager


class _FakeCursor:
    def __init__(self, rows):
        self._rows = rows

    def execute(self, *args, **kwargs):
        return self

    def fetchall(self):
        return self._rows


class _FakeConnection:
    """pyodbc の接続の、このテストに必要な部分だけを真似る。"""

    def __init__(self, rows):
        self._rows = rows
        self.committed = False

    def cursor(self):
        return _FakeCursor(self._rows)

    def close(self):
        pass

    def commit(self):
        self.committed = True

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


@pytest.fixture
def fake_db(monkeypatch):
    rows = [(1, "2026-08-01", "7203"), (2, "2026-08-01", "6758")]
    connections = []

    def _connect():
        con = _FakeConnection(rows)
        connections.append(con)
        return con

    monkeypatch.setattr(manager, "_ensure_table", lambda: None)
    monkeypatch.setattr(manager, "_connect", _connect)
    return connections


def test_price_fetch_failure_warns_per_ticker(fake_db, monkeypatch, capsys):
    """1銘柄が落ちても例外を投げず、WARN に銘柄コードと原因が出る。"""

    def boom(*args, **kwargs):
        raise RuntimeError("価格を取得できません")

    monkeypatch.setattr(manager.yf, "download", boom)

    manager.update_prices()

    out = capsys.readouterr().out
    assert out.count("[WARN]") == 2, "銘柄ごとに1件ずつ出ること"
    assert "7203" in out and "6758" in out
    assert "価格を取得できません" in out, "原因が追えるよう例外の内容を残すこと"


def test_failure_does_not_abort_the_batch(fake_db, monkeypatch, capsys):
    """1銘柄目で落ちても2銘柄目を試し、commit まで到達する。"""

    def boom(*args, **kwargs):
        raise RuntimeError("失敗")

    monkeypatch.setattr(manager.yf, "download", boom)

    manager.update_prices()

    # with _connect() で開いた2本目の接続が commit まで進んでいること
    assert fake_db[-1].committed is True
