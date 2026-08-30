import base64

import pytest

from ailab.connectors.github import API_BASE, GitHubConnector
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

    result = GitHubConnector(session=sess).publish(png, repo=REPO)

    assert result.dry_run is True
    assert "コミット予定" in result.detail
    assert sess.calls == []


def test_dry_run_works_without_token(png):
    assert GitHubConnector().publish(png, repo=REPO).dry_run


def test_publish_creates_new_file(monkeypatch, png):
    monkeypatch.setenv("GITHUB_TOKEN", "gh-test")
    sess = FakeSession(
        [
            FakeResponse(json_data={"default_branch": "main"}),
            FakeResponse(status_code=404, json_data={"message": "Not Found"}),
            FakeResponse(json_data={"content": {"html_url": "https://github.com/x/y/blob/main/a.png"}}),
        ]
    )

    result = GitHubConnector(session=sess).publish(png, repo=REPO, dry_run=False)

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

    result = GitHubConnector(session=sess).publish(
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
        GitHubConnector().publish(png, repo=REPO, dry_run=False)


def test_publish_uses_default_repo_from_env(monkeypatch, png):
    monkeypatch.setenv("AILAB_GITHUB_REPO", REPO)
    assert REPO in GitHubConnector().publish(png).target


def test_publish_without_repo_is_an_error(png):
    with pytest.raises(ConfigError, match="リポジトリが指定されていません"):
        GitHubConnector().publish(png)


def test_publish_rejects_malformed_repo(png):
    with pytest.raises(ConfigError, match="owner/name"):
        GitHubConnector().publish(png, repo="notes")


def test_publish_rejects_missing_file():
    with pytest.raises(ConfigError, match="見つかりません"):
        GitHubConnector().publish("no/such/file.png", repo=REPO)


def test_publish_rejects_oversized_file(tmp_path, monkeypatch):
    big = tmp_path / "big.bin"
    big.write_bytes(b"0")
    monkeypatch.setattr("ailab.connectors.github.MAX_BYTES", 0)
    with pytest.raises(ConfigError, match="大きすぎます"):
        GitHubConnector().publish(big, repo=REPO)


def test_check_reports_login(monkeypatch):
    monkeypatch.setenv("GITHUB_TOKEN", "gh-test")
    sess = FakeSession([FakeResponse(json_data={"login": "taro"})])

    result = GitHubConnector(session=sess).check()

    assert result.ok and "taro" in result.detail


def test_check_is_skipped_without_token():
    result = GitHubConnector().check()
    assert result.skipped and not result.ok


# --- 情報収集（リリース） ---------------------------------------------
RELEASES = [
    {
        "name": "v1.2.0",
        "tag_name": "v1.2.0",
        "html_url": "https://github.com/someone/notes/releases/tag/v1.2.0",
        "published_at": "2026-08-01T10:00:00Z",
        "body": "変更点\r\n- 修正した",
        "author": {"login": "taro"},
        "prerelease": False,
    }
]


def test_fetch_items_maps_releases():
    sess = FakeSession([FakeResponse(json_data=RELEASES)])

    items = GitHubConnector(session=sess).fetch_items(REPO, limit=5)

    item = items[0]
    assert (item.source, item.title, item.author) == ("github", "v1.2.0", "taro")
    assert item.url.endswith("/v1.2.0")
    assert item.published.startswith("2026-08-01")
    assert "修正した" in item.summary
    assert item.meta["repo"] == REPO
    assert sess.last_params()["per_page"] == 5


def test_fetch_items_falls_back_to_tag_name():
    sess = FakeSession([FakeResponse(json_data=[{"tag_name": "v0.1", "html_url": "https://x/y"}])])
    assert GitHubConnector(session=sess).fetch_items(REPO)[0].title == "v0.1"


def test_fetch_items_rejects_bare_repo_name():
    with pytest.raises(ConfigError, match="owner/name"):
        GitHubConnector().fetch_items("notes")


def test_fetch_items_uses_default_repo(monkeypatch):
    monkeypatch.setenv("AILAB_GITHUB_REPO", REPO)
    sess = FakeSession([FakeResponse(json_data=[])])
    assert GitHubConnector(session=sess).fetch_items("") == []


def test_github_has_both_capabilities():
    from ailab.core import capabilities_of

    assert set(capabilities_of(GitHubConnector())) == {"publish", "fetch_items"}
