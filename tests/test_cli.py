import json

import pytest
from fakes import FakeResponse, FakeSession

from ailab import assets, cli
from ailab.connectors.assets_iconify import IconifyAssets
from ailab.connectors.assets_openverse import OpenverseAssets
from ailab.connectors.assets_wikimedia import WikimediaAssets
from ailab.connectors.feed_qiita import QiitaFeed
from ailab.connectors.github import GitHubConnector
from ailab.connectors.images_pollinations import PollinationsImages
from ailab.core.types import Asset

SAMPLE = Asset(
    source="openverse",
    title="Cat",
    image_url="https://example.com/cat.png",
    page_url="https://example.com/page",
    license="BY 4.0",
    creator="Taro",
    width=100,
    height=100,
)


@pytest.fixture
def stub_search(monkeypatch):
    """素材検索を差し替える（openverse だけがヒットする状態にする）。"""
    monkeypatch.setattr(OpenverseAssets, "search_assets", lambda self, q, **kw: [SAMPLE])
    monkeypatch.setattr(WikimediaAssets, "search_assets", lambda self, q, **kw: [])
    monkeypatch.setattr(IconifyAssets, "search_assets", lambda self, q, **kw: [])


# --- connectors / doctor ---------------------------------------------
def test_connectors_lists_every_category(capsys):
    assert cli.main(["connectors"]) == 0
    out = capsys.readouterr().out
    assert "画像生成" in out and "素材取得" in out and "送信先" in out
    assert "local" in out and "openverse" in out and "github" in out


def test_status_is_an_alias_of_connectors(capsys):
    assert cli.main(["status"]) == 0
    assert "画像生成" in capsys.readouterr().out


def test_connectors_json_output(capsys):
    assert cli.main(["connectors", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    names = {entry["name"] for entry in payload}
    assert {"local", "openverse", "github"} <= names
    local = next(entry for entry in payload if entry["name"] == "local")
    assert local["available"] is True and local["category"] == "images"


def test_doctor_marks_unset_keys_as_skipped(monkeypatch, capsys):
    from ailab.core.connector import CheckResult

    # キー不要で通信するコネクタは疎通確認を差し替える（テストは通信しない）
    for connector_cls in (OpenverseAssets, WikimediaAssets, IconifyAssets, QiitaFeed, PollinationsImages):
        monkeypatch.setattr(
            connector_cls, "check", lambda self: CheckResult(self.name, ok=True, detail="確認済み")
        )
    assert cli.main(["doctor"]) == 0
    out = capsys.readouterr().out
    assert "--  openai" in out  # キー未設定は未確認扱い
    assert "OK  openverse" in out


def test_doctor_reports_failure(monkeypatch, capsys):
    from ailab.core.errors import ConnectorError

    def boom(self):
        raise ConnectorError("繋がらない")

    monkeypatch.setattr(OpenverseAssets, "check", boom)
    monkeypatch.setattr(WikimediaAssets, "check", boom)
    assert cli.main(["doctor", "openverse"]) == 1
    assert "繋がらない" in capsys.readouterr().out


# --- gen --------------------------------------------------------------
def test_gen_writes_image(tmp_path, capsys):
    assert cli.main(["gen", "テスト", "--provider", "local", "--size", "64x64", "-o", str(tmp_path)]) == 0
    assert len(list(tmp_path.glob("*.png"))) == 1
    assert "保存しました" in capsys.readouterr().out


def test_gen_multiple_images(tmp_path):
    cli.main(["gen", "複数", "--provider", "local", "--size", "64x64", "-n", "2", "-o", str(tmp_path)])
    assert len(list(tmp_path.glob("*.png"))) == 2


def test_gen_auto_prefers_keyless_ai_over_the_placeholder(monkeypatch, tmp_path, capsys):
    """キーが無くても pollinations（本物の生成AI）が選ばれ、local は最後の砦。"""
    from ailab.core.types import GeneratedImage

    monkeypatch.setattr(
        PollinationsImages,
        "generate",
        lambda self, prompt, **kw: [
            GeneratedImage(data=b"\x89PNG\r\n\x1a\n", provider="pollinations", model="flux", prompt=prompt)
        ],
    )
    assert cli.main(["gen", "自動選択", "--size", "64x64", "-o", str(tmp_path)]) == 0
    assert "pollinations/flux" in capsys.readouterr().out


def test_gen_can_still_force_the_local_placeholder(tmp_path, capsys):
    assert cli.main(["gen", "ダミー", "--provider", "local", "--size", "64x64", "-o", str(tmp_path)]) == 0
    assert "local/abstract-v1" in capsys.readouterr().out


def test_gen_reports_missing_api_key(capsys):
    assert cli.main(["gen", "猫", "--provider", "openai"]) == 1
    assert "OPENAI_API_KEY" in capsys.readouterr().err


def test_gen_reports_invalid_size(capsys):
    assert cli.main(["gen", "猫", "--provider", "local", "--size", "おおきい"]) == 1
    assert "サイズの指定が不正" in capsys.readouterr().err


# --- search / fetch ---------------------------------------------------
def test_search_json_output(stub_search, capsys):
    assert cli.main(["search", "猫", "--source", "openverse", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["license"] == "BY 4.0"
    assert payload[0]["attribution"].startswith('"Cat" by Taro')


def test_search_text_output(stub_search, capsys):
    cli.main(["search", "猫"])
    assert "ライセンス: BY 4.0" in capsys.readouterr().out


def test_search_reports_no_results(monkeypatch, capsys):
    monkeypatch.setattr(assets, "search", lambda *a, **kw: [])
    assert cli.main(["search", "存在しない"]) == 0
    assert "見つかりませんでした" in capsys.readouterr().out


def test_fetch_downloads_and_writes_credits(stub_search, monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(
        assets, "request", lambda *a, **kw: FakeResponse(content=b"\x89PNG\r\n\x1a\n")
    )
    assert cli.main(["fetch", "猫", "-l", "1", "-o", str(tmp_path)]) == 0
    assert (tmp_path / "CREDITS.md").exists()
    out = capsys.readouterr().out
    assert "保存しました" in out and "出典" in out


def test_fetch_reports_no_results(monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(assets, "search", lambda *a, **kw: [])
    assert cli.main(["fetch", "存在しない", "-o", str(tmp_path)]) == 1
    assert "見つかりませんでした" in capsys.readouterr().out


def test_no_cache_flag_disables_cache(monkeypatch, capsys):
    seen = {}

    def fake_search(query, *, source="all", limit=10, **kwargs):
        seen.update(kwargs)
        return []

    monkeypatch.setattr(assets, "search", fake_search)
    cli.main(["--no-cache", "search", "猫"])
    assert seen == {"cache_ttl": 0}


# --- publish ----------------------------------------------------------
def test_publish_is_dry_run_by_default(tmp_path, capsys):
    target = tmp_path / "a.png"
    target.write_bytes(b"x")
    assert cli.main(["publish", str(target), "--repo", "someone/notes"]) == 0
    out = capsys.readouterr().out
    assert "[ドライラン]" in out and "--yes" in out


def test_publish_sends_with_yes(monkeypatch, tmp_path, capsys):
    monkeypatch.setenv("GITHUB_TOKEN", "gh-test")
    target = tmp_path / "a.png"
    target.write_bytes(b"x")
    sess = FakeSession(
        [
            FakeResponse(json_data={"default_branch": "main"}),
            FakeResponse(status_code=404, json_data={"message": "Not Found"}),
            FakeResponse(json_data={"content": {"html_url": "https://github.com/x/y/blob/main/a.png"}}),
        ]
    )
    monkeypatch.setattr(GitHubConnector, "session", property(lambda self: sess))

    assert cli.main(["publish", str(target), "--repo", "someone/notes", "--yes"]) == 0
    assert "github.com/x/y" in capsys.readouterr().out


def test_publish_reports_missing_file(capsys):
    assert cli.main(["publish", "no/such.png", "--repo", "someone/notes"]) == 1
    assert "見つかりません" in capsys.readouterr().err


# --- feed -------------------------------------------------------------
FEED_ITEM_KWARGS = {
    "source": "rss",
    "title": "新しい記事",
    "url": "https://example.com/1",
    "published": "2026-08-03T09:00:00Z",
    "summary": "要約の1行目\n2行目",
    "author": "Taro",
}


def test_feed_prints_items(monkeypatch, capsys):
    from ailab.connectors.feed_rss import RssFeed
    from ailab.core.types import FeedItem

    monkeypatch.setattr(
        RssFeed, "fetch_items", lambda self, q, **kw: [FeedItem(**FEED_ITEM_KWARGS)]
    )
    assert cli.main(["feed", "https://example.com/feed", "--source", "rss"]) == 0
    out = capsys.readouterr().out
    assert "新しい記事（2026-08-03）" in out
    assert "要約の1行目" in out and "2行目" not in out  # 1行だけ出す


def test_feed_json_output(monkeypatch, capsys):
    from ailab.connectors.feed_qiita import QiitaFeed
    from ailab.core.types import FeedItem

    monkeypatch.setattr(
        QiitaFeed, "fetch_items", lambda self, q, **kw: [FeedItem(**dict(FEED_ITEM_KWARGS, source="qiita"))]
    )
    assert cli.main(["feed", "claude", "--source", "qiita", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["source"] == "qiita"


def test_feed_reports_no_results(monkeypatch, capsys):
    from ailab.connectors.feed_rss import RssFeed

    monkeypatch.setattr(RssFeed, "fetch_items", lambda self, q, **kw: [])
    assert cli.main(["feed", "https://example.com/feed", "--source", "rss"]) == 0
    assert "見つかりませんでした" in capsys.readouterr().out


def test_feed_requires_source():
    with pytest.raises(SystemExit):  # --source は必須（対象の指定方法が違うため）
        cli.main(["feed", "https://example.com/feed"])


def test_feed_reports_bad_target(capsys):
    assert cli.main(["feed", "キーワード", "--source", "rss"]) == 1
    assert "フィードのURL" in capsys.readouterr().err


# --- run（レシピ） ------------------------------------------------------
def test_run_executes_a_recipe(tmp_path, capsys):
    recipe = tmp_path / "r.yaml"
    recipe.write_text(
        "name: テスト\n"
        "steps:\n"
        "  - id: img\n"
        "    gen:\n"
        "      provider: local\n"
        "      prompt: 猫\n"
        "      size: 64x64\n"
        f"      out: {tmp_path}\n",
        encoding="utf-8",
    )
    assert cli.main(["run", str(recipe)]) == 0
    out = capsys.readouterr().out
    assert "[1/1] gen (img)" in out
    assert "作られたファイル" in out


def test_run_applies_set_variables(tmp_path, capsys):
    recipe = tmp_path / "r.yaml"
    recipe.write_text(
        "vars:\n  prompt: 既定\n"
        "steps:\n"
        "  - gen:\n"
        "      provider: local\n"
        '      prompt: "{{ vars.prompt }}"\n'
        "      size: 64x64\n"
        f"      out: {tmp_path}\n",
        encoding="utf-8",
    )
    assert cli.main(["run", str(recipe), "--set", "prompt=差し替え", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["steps"][0]["items"][0]["prompt"] == "差し替え"


def test_run_rejects_malformed_set(tmp_path, capsys):
    recipe = tmp_path / "r.yaml"
    recipe.write_text("steps: []\n", encoding="utf-8")
    assert cli.main(["run", str(recipe), "--set", "壊れている"]) == 1
    assert "KEY=VALUE" in capsys.readouterr().err


def test_run_reports_missing_recipe(capsys):
    assert cli.main(["run", "no-such-recipe"]) == 1
    assert "見つかりません" in capsys.readouterr().err


def test_bundled_recipes_are_valid():
    """同梱レシピが壊れていないことを確認する（実行はしない）。"""
    from pathlib import Path

    from ailab import recipes as recipes_module

    for path in sorted(Path("recipes").glob("*.yaml")):
        recipe = recipes_module.load_recipe(str(path))
        assert recipe["steps"], f"{path}: 手順が空"
        for index, step in enumerate(recipe["steps"], 1):
            recipes_module._parse_step(step, index)  # 動詞と設定の形を検証


# --- usage -------------------------------------------------------------
def test_usage_reports_nothing_at_first(capsys):
    assert cli.main(["usage"]) == 0
    assert "まだ記録がありません" in capsys.readouterr().out


def test_usage_summarizes_generations(tmp_path, capsys):
    cli.main(["gen", "集計テスト", "--provider", "local", "--size", "64x64", "-o", str(tmp_path)])
    capsys.readouterr()

    assert cli.main(["usage"]) == 0
    out = capsys.readouterr().out
    assert "local" in out and "1" in out


def test_usage_json_output(tmp_path, capsys):
    cli.main(["gen", "集計テスト", "--provider", "local", "--size", "64x64", "-o", str(tmp_path)])
    capsys.readouterr()

    assert cli.main(["usage", "--json", "--days", "7"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["images"] == 1
    assert payload["since_days"] == 7
