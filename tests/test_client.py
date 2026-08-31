"""通信まわりの、ネットワークに出ないテスト。"""

import kabutan.client as client


def test_fetch_failure_is_recorded_not_raised(monkeypatch):
    """全リトライ失敗は None を返しつつ fetch_errors に残る。

    利用側はこれで「休場日で0件」と「取得先に拒否されて0件」を区別する。
    """
    monkeypatch.setattr(client.time, "sleep", lambda *_: None)

    def _boom(url, headers=None, timeout=None):
        raise RuntimeError("405 Client Error")

    monkeypatch.setattr(client.requests, "get", _boom)
    client.fetch_errors.clear()

    assert client.fetch_ranking_html("2_1", 1, retries=2) is None
    assert len(client.fetch_errors) == 1
    assert "mode=2_1" in client.fetch_errors[0]


def test_stock_name_falls_back_to_code_on_failure(monkeypatch):
    def _boom(url, headers=None, timeout=None):
        raise RuntimeError("down")

    monkeypatch.setattr(client.requests, "get", _boom)
    assert client.fetch_stock_name("7203") == "7203"
