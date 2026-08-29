"""HTTP まわりの共通処理。"""

from __future__ import annotations

from typing import Any

import requests

from . import USER_AGENT


def session(extra_headers: dict[str, str] | None = None) -> requests.Session:
    """User-Agent 付きの requests.Session を返す。"""
    sess = requests.Session()
    sess.headers.update({"User-Agent": USER_AGENT})
    if extra_headers:
        sess.headers.update(extra_headers)
    return sess


def error_detail(response: requests.Response) -> str:
    """API のエラーレスポンスから読みやすいメッセージを組み立てる。"""
    text = ""
    try:
        payload: Any = response.json()
    except ValueError:
        text = (response.text or "").strip()
    else:
        if isinstance(payload, dict):
            for key in ("error", "message", "detail", "errors"):
                if key in payload:
                    value = payload[key]
                    text = value.get("message", str(value)) if isinstance(value, dict) else str(value)
                    break
        if not text:
            text = str(payload)
    text = text[:500]
    return f"HTTP {response.status_code}: {text}" if text else f"HTTP {response.status_code}"
