"""コネクタ（外部サービス連携）の共通契約。

連携先はサービスごとに1クラス。能力（検索できる/生成できる/送信できる）は
継承ではなくプロトコルで表し、1つのコネクタが複数持ってよい。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol, runtime_checkable

import requests

from ..config import get_env
from . import cache as cache_module
from . import http
from .types import Asset, FeedItem, GeneratedImage, PublishResult, SynthesizedSpeech, Voice

#: レート制限はコネクタ名で共有する。
#: registry.get() は毎回新しいインスタンスを作るため、インスタンス変数に持たせると
#: 呼び出しのたびに枠が回復したことになり、MCPサーバのような常駐プロセスで枠を守れない。
_LIMITERS: dict[str, http.RateLimiter] = {}


def reset_limiters() -> None:
    """共有しているレート制限の状態を捨てる（主にテスト用）。"""
    _LIMITERS.clear()


@dataclass(frozen=True)
class AuthSpec:
    """このコネクタを使うのに必要な認証情報。"""

    #: 必要な環境変数名
    env: tuple[str, ...] = ()
    #: True なら env のいずれか1つが揃っていればよい
    any_of: bool = False
    #: True ならキーが無くても動く（あれば枠が広がる、など）
    optional: bool = False
    #: キーの取得先URL（doctor で案内する）
    signup_url: str = ""
    note: str = ""

    def resolved(self) -> str | None:
        """設定済みの値を1つ返す（未設定なら None）。値はログに出さないこと。"""
        for name in self.env:
            value = get_env(name)
            if value:
                return value
        return None

    def missing(self) -> list[str]:
        """未設定の環境変数名（optional なら常に空）。"""
        if not self.env or self.optional:
            return []
        if self.any_of:
            return [] if self.resolved() else list(self.env)
        return [name for name in self.env if not get_env(name)]

    def is_satisfied(self) -> bool:
        return not self.missing()


@dataclass(frozen=True)
class RateLimit:
    """無料枠の宣言。"""

    requests: int
    per_seconds: float
    #: 枠が回復するまで待ってよい秒数（None なら RateLimiter の既定値）
    max_wait_seconds: float | None = None


@dataclass
class CheckResult:
    """疎通確認（imagegen doctor）の結果。"""

    name: str
    ok: bool
    detail: str = ""
    skipped: bool = False


class Connector:
    """外部サービス連携の基底クラス。

    抽象メソッドは持たない。「何ができるか」は継承ではなく、
    下の能力プロトコル（メソッドの有無）で判定する。
    """

    name: str = "base"
    #: assets（素材取得） / images（画像生成） / speech（音声合成） / publish（送信） / feed（情報収集）
    category: str = "misc"
    #: 人が読む1行説明
    summary: str = ""
    auth: AuthSpec = AuthSpec()
    terms_url: str = ""
    license_note: str = ""
    rate_limit: RateLimit | None = None
    #: 自動選択の優先順位（小さいほど先に選ばれる）
    priority: int = 50
    #: 既定のモデル名（生成コネクタのみ）
    default_model: str = ""

    def __init__(self, *, session: requests.Session | None = None, cache_ttl: int | None = None):
        self._session = session
        self.cache_ttl = cache_module.default_ttl() if cache_ttl is None else cache_ttl

    # --- 認証・可用性 -------------------------------------------------
    def api_key(self) -> str | None:
        return self.auth.resolved()

    def is_available(self) -> bool:
        """今すぐ使えるか（必要なキーが揃っているか）。"""
        return self.auth.is_satisfied()

    def unavailable_reason(self) -> str:
        missing = self.auth.missing()
        if not missing:
            return ""
        joiner = " または " if self.auth.any_of else ", "
        reason = f"環境変数 {joiner.join(missing)} が未設定です"
        return f"{reason}（取得: {self.auth.signup_url}）" if self.auth.signup_url else reason

    def resolve_model(self, model: str | None = None) -> str:
        """使うモデル名を決める。

        優先順位は 引数 > 環境変数 IMAGEGEN_<名前>_MODEL > コネクタの既定値。
        各社のモデルIDは短い周期で入れ替わるので、コードを直さなくても
        .env だけで追随できるようにしてある。
        """
        from ..config import get_env

        return model or get_env(f"IMAGEGEN_{self.name.upper()}_MODEL") or self.default_model

    # --- 通信 ---------------------------------------------------------
    def default_headers(self) -> dict[str, str]:
        """このコネクタが常に付けるヘッダ（認証ヘッダなど）。"""
        return {}

    @property
    def session(self) -> requests.Session:
        if self._session is None:
            self._session = http.session(self.default_headers())
        return self._session

    @property
    def limiter(self) -> http.RateLimiter | None:
        """このコネクタのレート制限。同じ連携先なら全インスタンスで共有する。"""
        if self.rate_limit is None:
            return None
        limiter = _LIMITERS.get(self.name)
        if limiter is None:
            limiter = http.RateLimiter(
                self.rate_limit.requests,
                self.rate_limit.per_seconds,
                label=self.name,
                max_wait=self.rate_limit.max_wait_seconds,
            )
            _LIMITERS[self.name] = limiter
        return limiter

    def request(self, method: str, url: str, **kwargs):
        return http.request(
            method, url, sess=self.session, label=self.name, limiter=self.limiter, **kwargs
        )

    def get_json(self, url: str, *, params: dict | None = None, use_cache: bool = True, **kwargs) -> Any:
        return http.get_json(
            url,
            params=params,
            cache_ttl=self.cache_ttl if use_cache else 0,
            sess=self.session,
            label=self.name,
            limiter=self.limiter,
            **kwargs,
        )

    # --- 疎通確認 -----------------------------------------------------
    def check(self) -> CheckResult:
        """実際に叩けるか確かめる。既定はキーの有無だけを見る。

        API を1回呼んで確かめられるコネクタは override すること。
        """
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        return CheckResult(self.name, ok=True, detail="設定あり（未通信）")


# --- 能力プロトコル ---------------------------------------------------
@runtime_checkable
class SearchAssets(Protocol):
    """素材を検索できる。"""

    def search_assets(self, query: str, *, limit: int = 10) -> list[Asset]: ...


@runtime_checkable
class GenerateImage(Protocol):
    """画像を生成できる。"""

    def generate(
        self, prompt: str, *, size: str = "1024x1024", n: int = 1, model: str | None = None
    ) -> list[GeneratedImage]: ...


@runtime_checkable
class SynthesizeSpeech(Protocol):
    """文章を読み上げた音声を作れる。"""

    def synthesize(
        self,
        text: str,
        *,
        voice: str | None = None,
        model: str | None = None,
        speed: float = 1.0,
        fmt: str | None = None,
    ) -> SynthesizedSpeech: ...

    def list_voices(self) -> list[Voice]: ...


@runtime_checkable
class PublishFile(Protocol):
    """ファイルを外部サービスへ送り出せる。"""

    def publish(self, path, *, dry_run: bool = True, **options) -> PublishResult: ...


@runtime_checkable
class ReadFeed(Protocol):
    """記事・リリースなどの一覧を取得できる。"""

    def fetch_items(self, query: str, *, limit: int = 10) -> list[FeedItem]: ...


CAPABILITIES: dict[str, type] = {
    "search_assets": SearchAssets,
    "generate": GenerateImage,
    "synthesize": SynthesizeSpeech,
    "publish": PublishFile,
    "fetch_items": ReadFeed,
}

#: 表示用の能力名
CAPABILITY_LABELS = {
    "generate": "画像生成",
    "synthesize": "音声合成",
    "search_assets": "素材取得",
    "publish": "送信先",
    "fetch_items": "情報収集",
}


def capabilities_of(connector: Connector) -> list[str]:
    """そのコネクタが持つ能力の名前。"""
    return [name for name, protocol in CAPABILITIES.items() if isinstance(connector, protocol)]
