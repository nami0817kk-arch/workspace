import json

import pytest

from ailab.illust import downloader as dl
from ailab.illust.base import IllustItem, SourceError
from fakes import FakeResponse, FakeSession

PNG = b"\x89PNG\r\n\x1a\nfake"


def make_item(**overrides) -> IllustItem:
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
    return IllustItem(**values)


def test_download_saves_file_with_readable_name(tmp_path, monkeypatch):
    monkeypatch.setattr(
        dl, "session", lambda headers=None: FakeSession([FakeResponse(content=PNG)])
    )
    path = dl.download(make_item(), tmp_path)
    assert path.name == "openverse_abc_Cat_drawing.png"
    assert path.read_bytes() == PNG


def test_download_uses_content_type_when_url_has_no_extension(tmp_path, monkeypatch):
    monkeypatch.setattr(
        dl,
        "session",
        lambda headers=None: FakeSession(
            [FakeResponse(content=PNG, headers={"Content-Type": "image/webp"})]
        ),
    )
    path = dl.download(make_item(image_url="https://example.com/image?id=1"), tmp_path)
    assert path.suffix == ".webp"


def test_download_rejects_item_without_url(tmp_path):
    with pytest.raises(SourceError):
        dl.download(make_item(image_url=""), tmp_path)


def test_download_all_writes_credits(tmp_path, monkeypatch):
    monkeypatch.setattr(
        dl,
        "session",
        lambda headers=None: FakeSession([FakeResponse(content=PNG), FakeResponse(content=PNG)]),
    )
    items = [make_item(), make_item(source_id="def", title="Dog drawing")]

    saved = dl.download_all(items, tmp_path)

    assert len(saved) == 2
    credits = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert {record["file"] for record in credits} == {path.name for _, path in saved}
    markdown = (tmp_path / "CREDITS.md").read_text(encoding="utf-8")
    assert "Cat drawing" in markdown and "Taro" in markdown
    assert "https://creativecommons.org/licenses/by/4.0/" in markdown


def test_credits_are_appended_not_overwritten(tmp_path, monkeypatch):
    monkeypatch.setattr(
        dl, "session", lambda headers=None: FakeSession([FakeResponse(content=PNG)])
    )
    dl.download_all([make_item()], tmp_path)

    monkeypatch.setattr(
        dl, "session", lambda headers=None: FakeSession([FakeResponse(content=PNG)])
    )
    dl.download_all([make_item(source_id="def", title="Dog")], tmp_path)

    credits = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert len(credits) == 2


def test_credits_recover_from_broken_json(tmp_path, monkeypatch):
    (tmp_path / "credits.json").write_text("{ broken", encoding="utf-8")
    monkeypatch.setattr(
        dl, "session", lambda headers=None: FakeSession([FakeResponse(content=PNG)])
    )
    dl.download_all([make_item()], tmp_path)
    assert len(json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))) == 1
