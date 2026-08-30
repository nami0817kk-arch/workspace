"""テスト用のダミー HTTP レスポンス/セッション。"""

from __future__ import annotations

import json as jsonlib


class FakeResponse:
    def __init__(self, *, status_code=200, json_data=None, content=b"", headers=None):
        self.status_code = status_code
        self._json = json_data
        self.content = content
        self.headers = headers or {}

    @property
    def ok(self) -> bool:
        return 200 <= self.status_code < 300

    @property
    def text(self) -> str:
        if self._json is not None:
            return jsonlib.dumps(self._json)
        return self.content.decode("utf-8", "replace")

    def json(self):
        if self._json is None:
            raise ValueError("no json")
        return self._json


class FakeSession:
    """requests.Session の最小限の差し替え。呼び出し内容を記録する。"""

    def __init__(self, responses=()):
        self._responses = list(responses)
        self.calls: list[tuple[str, str, dict]] = []
        self.headers: dict[str, str] = {}

    def queue(self, *responses) -> FakeSession:
        self._responses.extend(responses)
        return self

    def request(self, method, url, **kwargs):
        self.calls.append((method.upper(), url, kwargs))
        if not self._responses:
            raise AssertionError(f"想定外のリクエスト: {method} {url}")
        return self._responses.pop(0)

    def get(self, url, **kwargs):
        return self.request("GET", url, **kwargs)

    def post(self, url, **kwargs):
        return self.request("POST", url, **kwargs)

    def last_params(self) -> dict:
        return self.calls[-1][2].get("params") or {}
