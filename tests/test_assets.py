import json

import pytest

from ailab import assets
from ailab.core.errors import ConfigError
from ailab.core.types import Asset
from fakes import FakeResponse, FakeSession

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
