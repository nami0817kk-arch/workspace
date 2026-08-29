import pytest

from ailab import illust
from ailab.illust import openverse, pixabay, wikimedia
from ailab.illust.base import SourceError
from fakes import FakeResponse, FakeSession

OPENVERSE_BODY = {
    "results": [
        {
            "id": "abc-123",
            "title": "Cat drawing",
            "url": "https://example.com/cat.png",
            "thumbnail": "https://example.com/cat_thumb.png",
            "foreign_landing_url": "https://example.com/page",
            "license": "by",
            "license_version": "4.0",
            "license_url": "https://creativecommons.org/licenses/by/4.0/",
            "creator": "Taro",
            "creator_url": "https://example.com/taro",
            "width": 800,
            "height": 600,
            "tags": [{"name": "cat"}, {"name": "illustration"}],
        }
    ]
}


def test_openverse_maps_fields_and_filters_licenses(monkeypatch):
    fake = FakeSession([FakeResponse(json_data=OPENVERSE_BODY)])
    monkeypatch.setattr(openverse, "session", lambda headers=None: fake)

    items = openverse.OpenverseSource().search("猫", limit=5)

    item = items[0]
    assert (item.source, item.title, item.license) == ("openverse", "Cat drawing", "BY 4.0")
    assert item.image_url == "https://example.com/cat.png"
    assert item.creator == "Taro"
    assert item.tags == ["cat", "illustration"]
    params = fake.calls[0][2]["params"]
    assert params["license_type"] == "commercial,modification"
    assert params["category"] == "illustration"
    assert params["page_size"] == 5


def test_openverse_reports_http_error(monkeypatch):
    fake = FakeSession([FakeResponse(status_code=429, json_data={"detail": "rate limited"})])
    monkeypatch.setattr(openverse, "session", lambda headers=None: fake)
    with pytest.raises(SourceError, match="rate limited"):
        openverse.OpenverseSource().search("猫")


def test_pixabay_requires_key(monkeypatch):
    monkeypatch.delenv("PIXABAY_API_KEY", raising=False)
    with pytest.raises(SourceError, match="PIXABAY_API_KEY"):
        pixabay.PixabaySource().search("猫")


def test_pixabay_maps_illustration_hits(monkeypatch):
    monkeypatch.setenv("PIXABAY_API_KEY", "px-test")
    body = {
        "hits": [
            {
                "id": 42,
                "tags": "cat, animal",
                "largeImageURL": "https://pixabay.com/large.jpg",
                "previewURL": "https://pixabay.com/prev.jpg",
                "pageURL": "https://pixabay.com/page",
                "user": "hanako",
                "user_id": 7,
                "imageWidth": 1280,
                "imageHeight": 720,
            }
        ]
    }
    fake = FakeSession([FakeResponse(json_data=body)])
    monkeypatch.setattr(pixabay, "session", lambda headers=None: fake)

    item = pixabay.PixabaySource().search("猫", limit=1)[0]

    assert (item.title, item.creator, item.license) == ("cat", "hanako", "Pixabay Content License")
    assert item.tags == ["cat", "animal"]
    assert fake.calls[0][2]["params"]["image_type"] == "illustration"


def test_wikimedia_strips_html_from_metadata(monkeypatch):
    body = {
        "query": {
            "pages": {
                "1": {
                    "pageid": 1,
                    "title": "File:Neko.svg",
                    "imageinfo": [
                        {
                            "url": "https://upload.wikimedia.org/neko.svg",
                            "descriptionurl": "https://commons.wikimedia.org/wiki/File:Neko.svg",
                            "thumburl": "https://upload.wikimedia.org/thumb.png",
                            "width": 512,
                            "height": 512,
                            "extmetadata": {
                                "LicenseShortName": {"value": "CC BY-SA 4.0"},
                                "LicenseUrl": {"value": "https://creativecommons.org/x"},
                                "Artist": {"value": '<a href="/wiki/User:Neko">Neko</a>'},
                            },
                        }
                    ],
                }
            }
        }
    }
    fake = FakeSession([FakeResponse(json_data=body)])
    monkeypatch.setattr(wikimedia, "session", lambda headers=None: fake)

    item = wikimedia.WikimediaSource().search("猫", limit=1)[0]

    assert item.title == "Neko.svg"
    assert item.creator == "Neko"
    assert item.license == "CC BY-SA 4.0"


def test_search_all_skips_sources_without_key(monkeypatch):
    monkeypatch.delenv("PIXABAY_API_KEY", raising=False)
    monkeypatch.setattr(
        openverse, "session", lambda headers=None: FakeSession([FakeResponse(json_data=OPENVERSE_BODY)])
    )
    monkeypatch.setattr(
        wikimedia,
        "session",
        lambda headers=None: FakeSession([FakeResponse(json_data={"query": {"pages": {}}})]),
    )

    items = illust.search("猫", limit=5)

    assert [item.source for item in items] == ["openverse"]


def test_search_raises_when_every_source_fails(monkeypatch):
    monkeypatch.delenv("PIXABAY_API_KEY", raising=False)
    for module in (openverse, wikimedia):
        monkeypatch.setattr(
            module, "session", lambda headers=None: FakeSession([FakeResponse(status_code=500)])
        )
    with pytest.raises(SourceError):
        illust.search("猫")


def test_unknown_source_name():
    with pytest.raises(SourceError, match="未知の素材サイト"):
        illust.get_source("irasutoya")


def test_attribution_line():
    item = illust.IllustItem(
        source="openverse",
        title="Cat",
        image_url="https://example.com/c.png",
        page_url="https://example.com/p",
        license="BY 4.0",
        creator="Taro",
    )
    assert item.attribution == '"Cat" by Taro (https://example.com/p) [BY 4.0]'
