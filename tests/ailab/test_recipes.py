"""レシピ（YAML）実行。"""

import json
from pathlib import Path

import pytest

from ailab import recipes
from ailab.core.errors import ConfigError

CONTEXT = {
    "releases": [{"title": "v1.0", "url": "https://example.com/v1", "meta": {"repo": "a/b"}}],
    "empty": [],
    "vars": {"repo": "owner/name", "count": 3},
    "today": "2026-08-30",
}


# --- 参照の解決 -------------------------------------------------------
def test_lookup_by_index_and_key():
    assert recipes.lookup("releases.0.title", CONTEXT) == "v1.0"
    assert recipes.lookup("releases.0.meta.repo", CONTEXT) == "a/b"
    assert recipes.lookup("vars.repo", CONTEXT) == "owner/name"


def test_lookup_uses_first_item_when_index_is_omitted():
    assert recipes.lookup("releases.title", CONTEXT) == "v1.0"


def test_lookup_reports_missing_key():
    with pytest.raises(ConfigError, match="body がない"):
        recipes.lookup("releases.0.body", CONTEXT)


def test_lookup_reports_empty_result():
    with pytest.raises(ConfigError, match="0件"):
        recipes.lookup("empty.0.title", CONTEXT)


def test_lookup_reports_out_of_range():
    with pytest.raises(ConfigError, match="1件しかありません"):
        recipes.lookup("releases.5.title", CONTEXT)


def test_render_keeps_type_for_whole_expression():
    assert recipes.render("{{ vars.count }}", CONTEXT) == 3  # 文字列化しない
    assert recipes.render("{{ releases.0 }}", CONTEXT) == CONTEXT["releases"][0]


def test_render_interpolates_into_text():
    assert recipes.render("{{ releases.0.title }} を {{ today }} に公開", CONTEXT) == (
        "v1.0 を 2026-08-30 に公開"
    )


def test_render_walks_nested_structures():
    template = {"a": ["{{ vars.repo }}", 1], "b": {"c": "x-{{ today }}"}}
    assert recipes.render(template, CONTEXT) == {
        "a": ["owner/name", 1],
        "b": {"c": "x-2026-08-30"},
    }


# --- 読み込み ---------------------------------------------------------
def test_load_yaml_recipe(tmp_path):
    path = tmp_path / "sample.yaml"
    path.write_text("steps:\n  - gen:\n      prompt: 猫\n", encoding="utf-8")
    recipe = recipes.load_recipe(str(path))
    assert recipe["name"] == "sample"  # 省略時はファイル名
    assert recipe["steps"][0]["gen"]["prompt"] == "猫"


def test_load_json_recipe(tmp_path):
    path = tmp_path / "sample.json"
    path.write_text(json.dumps({"name": "JSONレシピ", "steps": []}), encoding="utf-8")
    assert recipes.load_recipe(str(path))["name"] == "JSONレシピ"


def test_recipe_found_by_name_in_recipes_dir(tmp_path, monkeypatch):
    (tmp_path / "recipes").mkdir()
    (tmp_path / "recipes" / "mine.yaml").write_text("steps: []\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    assert recipes.find_recipe("mine").name == "mine.yaml"


def test_missing_recipe_is_reported():
    with pytest.raises(ConfigError, match="見つかりません"):
        recipes.load_recipe("no-such-recipe")


def test_recipe_without_steps_is_rejected(tmp_path):
    path = tmp_path / "bad.yaml"
    path.write_text("name: 手順なし\n", encoding="utf-8")
    with pytest.raises(ConfigError, match="steps"):
        recipes.load_recipe(str(path))


# --- 手順の解析 -------------------------------------------------------
def test_step_needs_exactly_one_verb():
    with pytest.raises(ConfigError, match="動詞を1つだけ"):
        recipes._parse_step({"gen": {}, "feed": {}}, 1)
    with pytest.raises(ConfigError, match="動詞を1つだけ"):
        recipes._parse_step({"id": "x"}, 1)


def test_step_id_defaults_to_position():
    assert recipes._parse_step({"gen": {"prompt": "猫"}}, 3)[0] == "step3"


def test_step_options_must_be_a_mapping():
    with pytest.raises(ConfigError, match="辞書"):
        recipes._parse_step({"gen": "猫"}, 1)


# --- 実行 -------------------------------------------------------------
def test_run_chains_generation_into_publish(tmp_path, monkeypatch):
    published = {}

    def fake_publish(self, path, *, dry_run=True, **options):
        from ailab.core.types import PublishResult

        published.update({"path": str(path), "dry_run": dry_run, **options})
        return PublishResult(target="github:owner/name", detail="コミット予定", dry_run=dry_run)

    from ailab.connectors.github import GitHubConnector

    monkeypatch.setattr(GitHubConnector, "publish", fake_publish)

    recipe = {
        "name": "テスト",
        "vars": {"title": "見出し"},
        "steps": [
            {
                "id": "banner",
                "gen": {
                    "provider": "local",
                    "prompt": "{{ vars.title }}",
                    "size": "64x64",
                    "out": str(tmp_path),
                    "filename": "banner",
                },
            },
            {"publish": {"to": "github", "repo": "owner/name", "dest": "docs/banner.png"}},
        ],
    }

    result = recipes.run(recipe)

    assert (tmp_path / "banner.png").exists()
    assert published["path"] == str(tmp_path / "banner.png")  # 前の手順のファイルが渡る
    assert published["dry_run"] is True  # 既定はドライラン
    assert published["repo"] == "owner/name"
    assert result.files() == [str(tmp_path / "banner.png")]


def test_run_passes_yes_through_to_publish(tmp_path, monkeypatch):
    seen = {}

    def fake_publish(self, path, *, dry_run=True, **options):
        from ailab.core.types import PublishResult

        seen["dry_run"] = dry_run
        return PublishResult(target="github", dry_run=dry_run)

    from ailab.connectors.github import GitHubConnector

    monkeypatch.setattr(GitHubConnector, "publish", fake_publish)
    recipe = {
        "steps": [
            {"gen": {"provider": "local", "prompt": "x", "size": "64x64", "out": str(tmp_path)}},
            {"publish": {"to": "github", "repo": "owner/name"}},
        ]
    }

    recipes.run(recipe, dry_run=False)

    assert seen["dry_run"] is False


def test_run_reports_progress_per_step(tmp_path):
    seen = []
    recipe = {
        "steps": [
            {"id": "a", "gen": {"provider": "local", "prompt": "x", "size": "64x64", "out": str(tmp_path)}}
        ]
    }

    recipes.run(recipe, on_step=lambda i, total, step: seen.append((i, total, step.id)))

    assert seen == [(1, 1, "a")]


def test_run_overrides_variables(tmp_path):
    recipe = {
        "vars": {"prompt": "既定"},
        "steps": [
            {
                "id": "img",
                "gen": {
                    "provider": "local",
                    "prompt": "{{ vars.prompt }}",
                    "size": "64x64",
                    "out": str(tmp_path),
                },
            }
        ],
    }

    result = recipes.run(recipe, variables={"prompt": "差し替え"})

    assert result.steps[0].items[0]["prompt"] == "差し替え"


def test_feed_step_uses_the_connector(monkeypatch):
    from ailab.connectors.feed_qiita import QiitaFeed
    from ailab.core.types import FeedItem

    monkeypatch.setattr(
        QiitaFeed, "fetch_items", lambda self, q, **kw: [FeedItem(source="qiita", title=q)]
    )
    result = recipes.run({"steps": [{"id": "posts", "feed": {"source": "qiita", "query": "claude"}}]})
    assert result.steps[0].items[0]["title"] == "claude"


def test_feed_step_requires_source():
    with pytest.raises(ConfigError, match="source が必要"):
        recipes.run({"steps": [{"feed": {"query": "x"}}]})


def test_gen_step_requires_prompt():
    with pytest.raises(ConfigError, match="prompt が必要"):
        recipes.run({"steps": [{"gen": {"provider": "local"}}]})


def test_publish_step_without_a_file_is_reported():
    with pytest.raises(ConfigError, match="file が必要"):
        recipes.run({"steps": [{"publish": {"to": "github", "repo": "owner/name"}}]})


def test_step_errors_mention_the_position():
    with pytest.raises(ConfigError, match="手順1"):
        recipes.run({"steps": [{"gen": {"provider": "local"}}]})


def test_fetch_step_downloads_and_records_paths(tmp_path, monkeypatch):
    from fakes import FakeResponse

    from ailab import assets as assets_module
    from ailab.core.types import Asset

    asset = Asset(source="openverse", title="Cat", image_url="https://example.com/c.png", source_id="1")
    monkeypatch.setattr(assets_module, "search", lambda *a, **kw: [asset])
    monkeypatch.setattr(assets_module, "request", lambda *a, **kw: FakeResponse(content=b"png"))

    result = recipes.run(
        {"steps": [{"id": "got", "fetch": {"query": "cat", "limit": 1, "out": str(tmp_path)}}]}
    )

    item = result.steps[0].items[0]
    assert item["title"] == "Cat"
    assert item["path"].endswith(".png")
    assert (tmp_path / "CREDITS.md").exists()


def test_search_step_returns_assets(monkeypatch):
    from ailab import assets as assets_module
    from ailab.core.types import Asset

    monkeypatch.setattr(
        assets_module, "search", lambda *a, **kw: [Asset(source="iconify", title="cat", image_url="u")]
    )
    result = recipes.run({"steps": [{"id": "found", "search": {"query": "cat"}}]})
    assert result.steps[0].items[0]["source"] == "iconify"


def test_named_output_files_do_not_overwrite_each_other(tmp_path):
    """filename 指定で複数枚生成しても互いに上書きしない。"""
    recipe = {
        "steps": [
            {
                "id": "banner",
                "gen": {
                    "provider": "local",
                    "prompt": "猫",
                    "size": "64x64",
                    "n": 3,
                    "filename": "banner",
                    "out": str(tmp_path),
                },
            }
        ]
    }

    result = recipes.run(recipe)

    paths = [item["path"] for item in result.steps[0].items]
    assert len(set(paths)) == 3
    assert sorted(p.name for p in tmp_path.glob("*.png")) == [
        "banner_1.png",
        "banner_2.png",
        "banner_3.png",
    ]


def test_single_named_output_keeps_the_plain_name(tmp_path):
    recipes.run(
        {
            "steps": [
                {
                    "gen": {
                        "provider": "local",
                        "prompt": "猫",
                        "size": "64x64",
                        "filename": "banner",
                        "out": str(tmp_path),
                    }
                }
            ]
        }
    )
    assert [p.name for p in tmp_path.glob("*.png")] == ["banner.png"]


# --- foreach ----------------------------------------------------------
def test_foreach_repeats_a_step_for_each_item(tmp_path, monkeypatch):
    recipe = {
        "steps": [
            {"id": "titles", "search": {"query": "x"}},
            {
                "id": "banners",
                "foreach": "titles",
                "gen": {
                    "provider": "local",
                    "prompt": "{{ item.title }} のバナー",
                    "size": "64x64",
                    "filename": "b{{ number }}",
                    "out": str(tmp_path),
                },
            },
        ]
    }
    from ailab import assets as assets_module
    from ailab.core.types import Asset

    monkeypatch.setattr(
        assets_module,
        "search",
        lambda *a, **kw: [
            Asset("openverse", "記事A", "https://x/a"),
            Asset("openverse", "記事B", "https://x/b"),
        ],
    )
    result = recipes.run(recipe)

    banners = result.steps[1]
    assert len(banners.items) == 2
    assert [Path(item["path"]).name for item in banners.items] == ["b1.png", "b2.png"]
    assert "記事A のバナー" in banners.items[0]["prompt"]
    assert "記事B のバナー" in banners.items[1]["prompt"]


def test_foreach_accepts_a_template_reference(tmp_path, monkeypatch):
    from ailab.connectors.feed_qiita import QiitaFeed
    from ailab.core.types import FeedItem

    monkeypatch.setattr(
        QiitaFeed,
        "fetch_items",
        lambda self, q, **kw: [FeedItem(source="qiita", title=f"記事{i}") for i in range(3)],
    )
    recipe = {
        "steps": [
            {"id": "posts", "feed": {"source": "qiita", "query": "claude"}},
            {
                "foreach": "{{ posts }}",
                "gen": {
                    "provider": "local",
                    "prompt": "{{ item.title }}",
                    "size": "64x64",
                    "out": str(tmp_path),
                },
            },
        ]
    }

    assert len(recipes.run(recipe).steps[1].items) == 3


def test_foreach_over_nothing_produces_nothing(tmp_path, monkeypatch):
    from ailab import assets as assets_module

    monkeypatch.setattr(assets_module, "search", lambda *a, **kw: [])
    recipe = {
        "steps": [
            {"id": "found", "search": {"query": "x"}},
            {
                "foreach": "found",
                "gen": {"provider": "local", "prompt": "{{ item.title }}", "out": str(tmp_path)},
            },
        ]
    }

    assert recipes.run(recipe).steps[1].items == []


def test_foreach_needs_a_list():
    recipe = {"steps": [{"foreach": "{{ today }}", "gen": {"provider": "local", "prompt": "x"}}]}
    with pytest.raises(ConfigError, match="リストを指定"):
        recipes.run(recipe)


def test_foreach_with_an_unknown_reference():
    recipe = {"steps": [{"foreach": "存在しない", "gen": {"provider": "local", "prompt": "x"}}]}
    with pytest.raises(ConfigError, match="参照できません"):
        recipes.run(recipe)
