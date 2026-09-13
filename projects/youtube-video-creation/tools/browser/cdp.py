"""手元の Chrome（リモートデバッグ 9222）を直に動かす小さな道具。

**Playwright を経由しない。**Chrome 152 に対して Playwright 1.62 の
connect_over_cdp が握手の途中で止まったため（2026-09-13 に実測）。
CDP は HTTP でタブ一覧を取り、WebSocket でコマンドを送るだけなので、
必要なのは websocket-client 1本で足りる。

読むだけでなく**画面を操作する**ので、使うときは必ず何をしたかを控える。
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request

import websocket

BASE = "http://127.0.0.1:9222"


class Cdp:
    def __init__(self, ws_url: str, timeout: float = 30.0):
        # **Origin を送らない。**送ると Chrome が 403 で弾く
        # （--remote-allow-origins を付けずに起動しているため。2026-09-13 に実測）
        self.ws = websocket.create_connection(ws_url, timeout=timeout,
                                              max_size=64 * 1024 * 1024,
                                              suppress_origin=True)
        self.n = 0

    def send(self, method: str, **params):
        self.n += 1
        self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == self.n:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})

    def js(self, expr: str, wait: float = 0.0):
        """ページの中で JavaScript を動かして、返り値を受け取る。"""
        if wait:
            time.sleep(wait)
        r = self.send("Runtime.evaluate", expression=expr,
                      returnByValue=True, awaitPromise=True,
                      userGesture=True)
        if r.get("exceptionDetails"):
            raise RuntimeError(r["exceptionDetails"].get("text", "JS が失敗しました"))
        return r.get("result", {}).get("value")

    def goto(self, url: str, wait: float = 6.0):
        self.send("Page.navigate", url=url)
        time.sleep(wait)

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass


def tabs() -> list[dict]:
    with urllib.request.urlopen(f"{BASE}/json", timeout=10) as r:
        return [t for t in json.load(r) if t.get("type") == "page"]


def new_tab(url: str = "about:blank") -> dict:
    """タブを開く。**自分で開いたものは自分で閉じる**（ユーザーのタブは触らない）。"""
    req = urllib.request.Request(f"{BASE}/json/new?{urllib.parse.quote(url, safe=':/?&=')}",
                                 method="PUT")
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def close_tab(target_id: str) -> None:
    with urllib.request.urlopen(f"{BASE}/json/close/{target_id}", timeout=10):
        pass


def attach(target: dict, timeout: float = 30.0) -> Cdp:
    c = Cdp(target["webSocketDebuggerUrl"], timeout=timeout)
    c.send("Page.enable")
    c.send("Runtime.enable")
    return c
