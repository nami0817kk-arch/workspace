"""ailab 共通の例外。

外部サービスのエラーは全てここに集約し、CLI が人間向けの日本語で出せるようにする。
"""

from __future__ import annotations


class AilabError(RuntimeError):
    """ailab のエラーの基底。"""


class ConfigError(AilabError):
    """設定・引数の誤り。"""


class ConnectorError(AilabError):
    """外部サービス連携のエラーの基底。"""


class AuthError(ConnectorError):
    """APIキー・トークンが無い / 無効 / 権限不足 (401, 403)。"""


class NotFoundError(ConnectorError):
    """対象が見つからない (404)。"""


class RateLimitError(ConnectorError):
    """レート制限にかかった (429)。"""

    def __init__(self, message: str, retry_after: float | None = None):
        super().__init__(message)
        self.retry_after = retry_after


class NetworkError(ConnectorError):
    """接続できない・タイムアウト。"""
