"""GitHub リポジトリへファイルをコミットして公開する。"""

from __future__ import annotations

import base64
from pathlib import Path

from ..config import get_env
from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConfigError, NotFoundError
from ..core.registry import register
from ..core.types import PublishResult

API_BASE = "https://api.github.com"
#: Contents API は大きなファイルに向かない。これを超えたら Release や LFS を使う
MAX_BYTES = 25 * 1024 * 1024


@register
class GitHubPublish(Connector):
    name = "github"
    category = "publish"
    summary = "生成物をリポジトリへコミットする"
    auth = AuthSpec(
        env=("GITHUB_TOKEN", "GH_TOKEN"),
        any_of=True,
        signup_url="https://github.com/settings/tokens",
        note="contents:write 権限のある Fine-grained token / PAT",
    )
    terms_url = "https://docs.github.com/site-policy/github-terms/github-terms-of-service"
    rate_limit = RateLimit(requests=5000, per_seconds=3600)

    def default_headers(self) -> dict[str, str]:
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        key = self.api_key()
        if key:
            headers["Authorization"] = f"Bearer {key}"
        return headers

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(f"{API_BASE}/user", use_cache=False, timeout=30)
        repo = default_repo()
        detail = f"{body.get('login', '')} として認証"
        return CheckResult(self.name, ok=True, detail=f"{detail}（既定リポジトリ: {repo or '未設定'}）")

    # --- 内部ヘルパ ---------------------------------------------------
    def _default_branch(self, repo: str) -> str:
        return self.get_json(f"{API_BASE}/repos/{repo}", use_cache=False, timeout=30).get(
            "default_branch", "main"
        )

    def _existing_sha(self, repo: str, dest: str, branch: str) -> str | None:
        """既存ファイルの sha（上書きに必要）。無ければ None。"""
        try:
            body = self.get_json(
                f"{API_BASE}/repos/{repo}/contents/{dest}",
                params={"ref": branch},
                use_cache=False,
                timeout=30,
            )
        except NotFoundError:
            return None
        return body.get("sha") if isinstance(body, dict) else None

    # --- 送信 ---------------------------------------------------------
    def publish(
        self,
        path: str | Path,
        *,
        repo: str | None = None,
        dest: str | None = None,
        branch: str | None = None,
        message: str | None = None,
        dry_run: bool = True,
        timeout: int = 60,
    ) -> PublishResult:
        """ファイルを1つコミットする。dry_run=True（既定）では送信しない。"""
        source = Path(path)
        if not source.is_file():
            raise ConfigError(f"ファイルが見つかりません: {source}")

        size = source.stat().st_size
        if size > MAX_BYTES:
            raise ConfigError(
                f"{source.name} は {size / 1024 / 1024:.1f}MB です。"
                "Contents API では大きすぎます（Release への添付を検討してください）"
            )

        repo = repo or default_repo()
        if not repo:
            raise ConfigError(
                "リポジトリが指定されていません（--repo owner/name か AILAB_GITHUB_REPO）"
            )
        if repo.count("/") != 1 or not all(repo.split("/")):
            raise ConfigError(f"リポジトリの指定が不正です: {repo}（owner/name の形式）")

        dest = (dest or f"assets/{source.name}").lstrip("/")
        message = message or f"Add {dest} via ailab"

        if dry_run:
            return PublishResult(
                target=f"github:{repo}",
                detail=f"{branch or '既定ブランチ'} の {dest} へ {size:,} バイトをコミット予定",
                dry_run=True,
            )

        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        branch = branch or self._default_branch(repo)
        payload = {
            "message": message,
            "content": base64.b64encode(source.read_bytes()).decode("ascii"),
            "branch": branch,
        }
        sha = self._existing_sha(repo, dest, branch)
        if sha:
            payload["sha"] = sha  # 既存ファイルの上書きには sha が要る

        body = self.request(
            "PUT", f"{API_BASE}/repos/{repo}/contents/{dest}", json=payload, timeout=timeout
        ).json()

        content = body.get("content") or {}
        return PublishResult(
            target=f"github:{repo}",
            url=content.get("html_url", ""),
            detail=f"{branch} に {'更新' if sha else '追加'}: {dest}",
        )


def default_repo() -> str | None:
    """既定の送信先リポジトリ（AILAB_GITHUB_REPO）。"""
    return get_env("AILAB_GITHUB_REPO")
