"""GitHub 連携（クローンと Issue 起票）。標準ライブラリのみで実装する。

トークンは `GROWTH_TOKEN` → `GITHUB_TOKEN` の順に見る。
他リポジトリへ Issue を起票するには、リポジトリ既定の GITHUB_TOKEN では
権限が足りないため、`GROWTH_TOKEN`（Fine-grained PAT / Issues: write）が要る。
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.github.com"


class GitHubError(RuntimeError):
    pass


def token() -> str | None:
    return os.environ.get("GROWTH_TOKEN") or os.environ.get("GITHUB_TOKEN") or None


def _request(method: str, url: str, payload: dict | None = None) -> dict | list:
    tok = token()
    if not tok:
        raise GitHubError("GROWTH_TOKEN も GITHUB_TOKEN も設定されていません。")
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {tok}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("User-Agent", "ai-lab-growth-loop")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:  # pragma: no cover - ネットワーク依存
        detail = exc.read().decode("utf-8", errors="replace")[:400]
        raise GitHubError(f"{method} {url} -> HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:  # pragma: no cover
        raise GitHubError(f"{method} {url} -> {exc.reason}") from exc
    return json.loads(body) if body else {}


def clone_repo(repo: str, workspace: Path, depth: int = 1) -> Path:
    """浅いクローン。既にあれば fetch で更新する。"""
    workspace.mkdir(parents=True, exist_ok=True)
    target = workspace / repo.split("/")[-1]
    tok = token()
    url = f"https://github.com/{repo}.git"
    if tok:
        url = f"https://x-access-token:{tok}@github.com/{repo}.git"

    if (target / ".git").is_dir():
        cmd = ["git", "-C", str(target), "fetch", "--depth", str(depth), "origin"]
        subprocess.run(cmd, check=True, capture_output=True)
        head = subprocess.run(
            ["git", "-C", str(target), "rev-parse", "FETCH_HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        subprocess.run(
            ["git", "-C", str(target), "reset", "--hard", head],
            check=True, capture_output=True,
        )
        return target

    subprocess.run(
        ["git", "clone", "--depth", str(depth), url, str(target)],
        check=True, capture_output=True,
        env={**os.environ, "GIT_LFS_SKIP_SMUDGE": "1", "GIT_TERMINAL_PROMPT": "0"},
    )
    return target


def find_issue_by_marker(repo: str, marker: str) -> dict | None:
    """マーカー付きの既存 Issue を探す（重複起票の防止）。

    open / closed の両方を見る。閉じられている = 人が「やらない」と判断した、
    と解釈して再起票しない。

    確認できなかった場合は GitHubError を投げる。None（＝存在しない）と
    同じ扱いにすると、確認に失敗しただけで重複起票してしまうため。
    """
    url = f"{API}/repos/{repo}/issues?state=all&per_page=100&labels=growth-loop"
    issues = _request("GET", url)
    if not isinstance(issues, list):
        raise GitHubError(f"想定外の応答形式: {type(issues).__name__}")
    for issue in issues:
        if marker in (issue.get("body") or ""):
            return issue
    return None


def ensure_label(repo: str) -> None:
    """growth-loop ラベルを用意する。既にあれば何もしない。

    ラベルが無くても Issue 自体は立てられるので、ここでの失敗は致命的でない。
    ただし黙って飲み込むと、権限不足なのか単に既存なのか分からなくなるため、
    「既にある」以外は理由を出す。
    """
    try:
        _request(
            "POST",
            f"{API}/repos/{repo}/labels",
            {"name": "growth-loop", "color": "0E8A16", "description": "ai-lab 成長ループの自動提案"},
        )
    except GitHubError as exc:
        if "422" not in str(exc):  # 422 = 既に同名のラベルがある
            print(f"[warn] ラベルを用意できなかった ({repo}): {exc}", file=sys.stderr)


def create_issue(repo: str, title: str, body: str) -> str:
    ensure_label(repo)
    result = _request(
        "POST",
        f"{API}/repos/{repo}/issues",
        {"title": title, "body": body, "labels": ["growth-loop"]},
    )
    return result.get("html_url", "") if isinstance(result, dict) else ""
