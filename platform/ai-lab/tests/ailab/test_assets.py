import json

import pytest
from fakes import FakeResponse, FakeSession

from ailab import assets
from ailab.core.errors import ConfigError
from ailab.core.types import Asset

PNG = b"\x89PNG\r\n\x1a\nfake"


def make_asset(**overrides) -> Asset:
    values = {
        "source": "openverse",
        "title": "Cat drawing",
        "image_url": "https://example.com/cat.png",
        "page_url": "https://example.com/page",
        "license": "BY 4.0",
        "license_url": "https://creativecommons.org/licenses/by/4.0/",
        "creator": "Taro",
        "source_id": "abc",
    }
    values.update(overrides)
    return Asset(**values)


def test_download_saves_file_with_readable_name(tmp_path):
    sess = FakeSession([FakeResponse(content=PNG)])
    path = assets.download(make_asset(), tmp_path, sess=sess)
    assert path.name == "openverse_abc_Cat_drawing.png"
    assert path.read_bytes() == PNG


def test_download_uses_content_type_when_url_has_no_extension(tmp_path):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/webp"})])
    path = assets.download(
        make_asset(image_url="https://example.com/image?id=1"), tmp_path, sess=sess
    )
    assert path.suffix == ".webp"


def test_download_rejects_asset_without_url(tmp_path):
    with pytest.raises(ConfigError):
        assets.download(make_asset(image_url=""), tmp_path)


def test_download_all_writes_credits(tmp_path):
    sess = FakeSession([FakeResponse(content=PNG), FakeResponse(content=PNG)])
    items = [make_asset(), make_asset(source_id="def", title="Dog drawing")]

    saved = assets.download_all(items, tmp_path, sess=sess)

    assert len(saved) == 2
    credits = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert {record["file"] for record in credits} == {path.name for _, path in saved}
    markdown = (tmp_path / "CREDITS.md").read_text(encoding="utf-8")
    assert "Cat drawing" in markdown and "Taro" in markdown
    assert "https://creativecommons.org/licenses/by/4.0/" in markdown
    # ライセンスが許すのは撮影者の著作権だけ、という注意を必ず添える
    assert "肖像権" in markdown and "商標権" in markdown


def test_credits_are_appended_not_overwritten(tmp_path):
    assets.download_all([make_asset()], tmp_path, sess=FakeSession([FakeResponse(content=PNG)]))
    assets.download_all(
        [make_asset(source_id="def", title="Dog")], tmp_path, sess=FakeSession([FakeResponse(content=PNG)])
    )
    credits = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert len(credits) == 2


def test_credits_recover_from_broken_json(tmp_path):
    (tmp_path / "credits.json").write_text("{ broken", encoding="utf-8")
    assets.download_all([make_asset()], tmp_path, sess=FakeSession([FakeResponse(content=PNG)]))
    assert len(json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))) == 1


def test_download_all_of_an_empty_list_does_nothing(tmp_path):
    assert assets.download_all([], tmp_path) == []
    assert not (tmp_path / "CREDITS.md").exists()


def test_download_all_runs_in_parallel_for_multiple_assets(tmp_path, monkeypatch):
    """取得先が別サイトなので並列に落とす（1件ずつだと待ち時間が積み上がる）。"""
    import threading

    started = threading.Barrier(3, timeout=5)

    def fake_download(asset, dest_dir, *, timeout=60, sess=None):
        started.wait()  # 3件が同時に走らないと詰まる
        path = tmp_path / f"{asset.source_id}.png"
        path.write_bytes(PNG)
        return path

    monkeypatch.setattr(assets, "download", fake_download)
    items = [make_asset(source_id=str(i)) for i in range(3)]

    saved = assets.download_all(items, tmp_path)

    assert [asset.source_id for asset, _ in saved] == ["0", "1", "2"]  # 順序は保つ


# --- URL を直接指定して取り込む ------------------------------------------
def test_grab_saves_the_image_and_credits(tmp_path):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])

    asset, path = assets.grab(
        "https://example.com/img/neko.png",
        tmp_path,
        page_url="https://example.com/page",
        license="CC BY 4.0",
        creator="Taro",
        sess=sess,
    )

    assert path.read_bytes() == PNG
    assert path.name == "example.com_neko.png"
    assert asset.source == "example.com"
    credits = (tmp_path / "CREDITS.md").read_text(encoding="utf-8")
    assert "CC BY 4.0" in credits and "Taro" in credits


def test_grab_uses_the_given_title(tmp_path):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])
    _asset, path = assets.grab(
        "https://example.com/a.png", tmp_path, title="猫のイラスト", sess=sess
    )
    assert path.name == "example.com_猫のイラスト.png"


def test_grab_rejects_a_page_url(tmp_path):
    """ページのHTMLを解析して画像を探すことはしない。"""
    sess = FakeSession([FakeResponse(content=b"<html></html>", headers={"Content-Type": "text/html"})])
    with pytest.raises(ConfigError, match="画像そのもののURL"):
        assets.grab("https://example.com/page", tmp_path, sess=sess)


def test_grab_rejects_a_non_url(tmp_path):
    with pytest.raises(ConfigError, match="画像のURL"):
        assets.grab("neko.png", tmp_path)


def test_grab_defaults_to_unknown_license(tmp_path):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])
    asset, _path = assets.grab("https://example.com/a.png", tmp_path, sess=sess)
    assert asset.license == "unknown"
