import pytest
from fakes import FakeResponse, FakeSession

from ailab import assets
from ailab.connectors.assets_iconify import IconifyAssets
from ailab.connectors.assets_openverse import API_URL as OPENVERSE_URL
from ailab.connectors.assets_openverse import OpenverseAssets
from ailab.connectors.assets_pixabay import PixabayAssets
from ailab.connectors.assets_wikimedia import WikimediaAssets
from ailab.core.errors import AuthError, ConnectorError

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


def test_openverse_maps_fields_and_filters_licenses():
    sess = FakeSession([FakeResponse(json_data=OPENVERSE_BODY)])

    found = OpenverseAssets(session=sess).search_assets("猫", limit=5)

    asset = found[0]
    assert (asset.source, asset.title, asset.license) == ("openverse", "Cat drawing", "BY 4.0")
    assert asset.image_url == "https://example.com/cat.png"
    assert asset.creator == "Taro"
    assert asset.tags == ["cat", "illustration"]
    method, url, kwargs = sess.calls[0]
    assert (method, url) == ("GET", OPENVERSE_URL)
    assert kwargs["params"]["license_type"] == "commercial,modification"
    assert kwargs["params"]["category"] == "illustration"
    assert kwargs["params"]["page_size"] == 5


def test_openverse_rate_limit_error_is_readable(monkeypatch):
    from ailab.core import http

    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)  # 再試行の待ちを飛ばす
    sess = FakeSession([FakeResponse(status_code=429, json_data={"detail": "rate limited"})] * 3)
    with pytest.raises(ConnectorError, match="レート制限"):
        OpenverseAssets(session=sess).search_assets("猫")


def test_pixabay_requires_key():
    with pytest.raises(AuthError, match="PIXABAY_API_KEY"):
        PixabayAssets().search_assets("猫")


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
    sess = FakeSession([FakeResponse(json_data=body)])

    asset = PixabayAssets(session=sess).search_assets("猫", limit=1)[0]

    assert (asset.title, asset.creator, asset.license) == ("cat", "hanako", "Pixabay Content License")
    assert asset.tags == ["cat", "animal"]
    assert sess.last_params()["image_type"] == "illustration"


def test_wikimedia_strips_html_from_metadata():
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
    sess = FakeSession([FakeResponse(json_data=body)])

    asset = WikimediaAssets(session=sess).search_assets("猫", limit=1)[0]

    assert asset.title == "Neko.svg"
    assert asset.creator == "Neko"
    assert asset.license == "CC BY-SA 4.0"


def test_search_all_skips_connectors_without_key(monkeypatch):
    monkeypatch.setattr(
        OpenverseAssets, "search_assets", lambda self, q, **kw: [_asset("openverse")]
    )
    _silence(monkeypatch, WikimediaAssets, IconifyAssets)

    found = assets.search("猫", limit=5)

    assert [asset.source for asset in found] == ["openverse"]  # pixabay はキー未設定でスキップ


def test_search_all_survives_one_failing_source(monkeypatch):
    def broken(self, query, **kwargs):
        raise ConnectorError("落ちた")

    monkeypatch.setattr(WikimediaAssets, "search_assets", broken)
    monkeypatch.setattr(
        OpenverseAssets, "search_assets", lambda self, q, **kw: [_asset("openverse")]
    )
    _silence(monkeypatch, IconifyAssets)

    assert len(assets.search("猫")) == 1


def test_search_raises_when_every_source_fails(monkeypatch):
    def broken(self, query, **kwargs):
        raise ConnectorError("落ちた")

    monkeypatch.setattr(OpenverseAssets, "search_assets", broken)
    monkeypatch.setattr(WikimediaAssets, "search_assets", broken)
    monkeypatch.setattr(IconifyAssets, "search_assets", broken)
    with pytest.raises(ConnectorError):
        assets.search("猫")


def test_search_with_unknown_source():
    from ailab.core.errors import ConfigError

    with pytest.raises(ConfigError, match="未知のコネクタ"):
        assets.search("猫", source="irasutoya")


def test_search_rejects_connector_without_capability():
    from ailab.core.errors import ConfigError

    with pytest.raises(ConfigError, match="素材検索に対応していません"):
        assets.search("猫", source="github")


def test_attribution_line():
    from ailab.core.types import Asset

    asset = Asset(
        source="openverse",
        title="Cat",
        image_url="https://example.com/c.png",
        page_url="https://example.com/p",
        license="BY 4.0",
        creator="Taro",
    )
    assert asset.attribution == '"Cat" by Taro (https://example.com/p) [BY 4.0]'


def _silence(monkeypatch, *connector_classes):
    """指定したコネクタを「ヒット0件」にして、横断検索の検証対象から外す。"""
    for cls in connector_classes:
        monkeypatch.setattr(cls, "search_assets", lambda self, q, **kw: [])


def _asset(source: str):
    from ailab.core.types import Asset

    return Asset(source=source, title="Cat", image_url="https://example.com/cat.png")
