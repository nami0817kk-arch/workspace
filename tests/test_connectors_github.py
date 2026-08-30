import base64

import pytest

from ailab.connectors.publish_github import API_BASE, GitHubPublish
from ailab.core.errors import AuthError, ConfigError
from fakes import FakeResponse, FakeSession

REPO = "someone/notes"


@pytest.fixture
def png(tmp_path):
    path = tmp_path / "banner.png"
    path.write_bytes(b"\x89PNG\r\n\x1a\nfake")
    return path


def test_dry_run_sends_nothing(png):
    sess = FakeSession()  # 1回でも通信したら AssertionError になる

    result = GitHubPublish(session=sess).publish(png, repo=REPO)

    assert result.dry_run is True
    assert "コミット予定" in result.detail
    assert sess.calls == []


def test_dry_run_works_without_token(png):
    assert GitHubPublish().publish(png, repo=REPO).dry_run


def test_publish_creates_new_file(monkeypatch, png):
    monkeypatch.setenv("GITHUB_TOKEN", "gh-test")
    sess = FakeSession(
        [
            FakeResponse(json_data={"default_branch": "main"}),
            FakeResponse(status_code=404, json_data={"message": "Not Found"}),
            FakeResponse(json_data={"content": {"html_url": "https://github.com/x/y/blob/main/a.png"}}),
        ]
    )

    result = GitHubPublish(session=sess).publish(png, repo=REPO, dry_run=False)

    assert result.url.endswith("a.png")
    assert "追加" in result.detail
    method, url, kwargs = sess.calls[-1]
    assert method == "PUT"
    assert url == f"{API_BASE}/repos/{REPO}/contents/assets/banner.png"
    assert base64.b64decode(kwargs["json"]["content"]) == png.read_bytes()
    assert kwargs["json"]["branch"] == "main"
    assert "sha" not in kwargs["json"]  # 新規なので sha は送らない


def test_publish_overwrites_with_existing_sha(monkeypatch, png):
    monkeypatch.setenv("GITHUB_TOKEN", "gh-test")
    sess = FakeSession(
        [
            FakeResponse(json_data={"sha": "deadbeef"}),
            FakeResponse(json_data={"content": {"html_url": "https://github.com/x/y"}}),
        ]
    )

    result = GitHubPublish(session=sess).publish(
        png, repo=REPO, branch="develop", dest="docs/img/b.png", message="更新", dry_run=False
    )

    assert "更新" in result.detail
    method, url, kwargs = sess.calls[-1]
    assert url == f"{API_BASE}/repos/{REPO}/contents/docs/img/b.png"
    assert kwargs["json"]["sha"] == "deadbeef"
    assert kwargs["json"]["message"] == "更新"
    assert kwargs["json"]["branch"] == "develop"  # ブランチ指定時は既定ブランチを問い合わせない


def test_publish_requires_token(png):
    with pytest.raises(AuthError, match="GITHUB_TOKEN"):
        GitHubPublish().publish(png, repo=REPO, dry_run=False)


def test_publish_uses_default_repo_from_env(monkeypatch, png):
    monkeypatch.setenv("AILAB_GITHUB_REPO", REPO)
    assert REPO in GitHubPublish().publish(png).target


def test_publish_without_repo_is_an_error(png):
    with pytest.raises(ConfigError, match="リポジトリが指定されていません"):
        GitHubPublish().publish(png)


def test_publish_rejects_malformed_repo(png):
    with pytest.raises(ConfigError, match="owner/name"):
        GitHubPublish().publish(png, repo="notes")


def test_publish_rejects_missing_file():
    with pytest.raises(ConfigError, match="見つかりません"):
        GitHubPublish().publish("no/such/file.png", repo=REPO)


def test_publish_rejects_oversized_file(tmp_path, monkeypatch):
    big = tmp_path / "big.bin"
    big.write_bytes(b"0")
    monkeypatch.setattr("ailab.connectors.publish_github.MAX_BYTES", 0)
    with pytest.raises(ConfigError, match="大きすぎます"):
        GitHubPublish().publish(big, repo=REPO)


def test_check_reports_login(monkeypatch):
    monkeypatch.setenv("GITHUB_TOKEN", "gh-test")
    sess = FakeSession([FakeResponse(json_data={"login": "taro"})])

    result = GitHubPublish(session=sess).check()

    assert result.ok and "taro" in result.detail


def test_check_is_skipped_without_token():
    result = GitHubPublish().check()
    assert result.skipped and not result.ok
