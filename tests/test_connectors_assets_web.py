"""Phase 1 で足した取得先（Iconify / Unsplash / Pexels）。"""

import pytest
from fakes import FakeResponse, FakeSession

from ailab import assets
from ailab.connectors.assets_iconify import MIN_LIMIT, SVG_URL, IconifyAssets
from ailab.connectors.assets_pexels import PexelsAssets
from ailab.connectors.assets_unsplash import UnsplashAssets
from ailab.core.errors import AuthError

ICONIFY_BODY = {
    "icons": ["mdi:cat", "ph:dog-bold"],
    "collections": {
        "mdi": {
            "name": "Material Design Icons",
            "author": {"name": "Pictogrammers", "url": "https://pictogrammers.com/"},
            "license": {"title": "Apache 2.0", "spdx": "Apache-2.0", "url": "https://example.com/l"},
        }
    },
}

UNSPLASH_BODY = {
    "total": 2,
    "results": [
        {
            "id": "abc",
            "description": None,
            "alt_description": "a cat on a laptop",
            "urls": {"regular": "https://images.unsplash.com/cat", "thumb": "https://images.unsplash.com/t"},
            "links": {
                "html": "https://unsplash.com/photos/abc",
                "download_location": "https://api.unsplash.com/photos/abc/download",
            },
            "user": {"name": "Taro", "links": {"html": "https://unsplash.com/@taro"}},
            "width": 4000,
            "height": 3000,
            "tags": [{"title": "cat"}],
        }
    ],
}

PEXELS_BODY = {
    "total_results": 1,
    "photos": [
        {
            "id": 99,
            "alt": "cat",
            "src": {"large": "https://images.pexels.com/large.jpg", "tiny": "https://images.pexels.com/t.jpg"},
            "url": "https://www.pexels.com/photo/99/",
            "photographer": "Hanako",
            "photographer_url": "https://www.pexels.com/@hanako",
            "width": 1920,
            "height": 1280,
        }
    ],
}


# --- Iconify ----------------------------------------------------------
def test_iconify_builds_svg_and_page_urls():
    sess = FakeSession([FakeResponse(json_data=ICONIFY_BODY)])

    found = IconifyAssets(session=sess).search_assets("cat", limit=1)

    assert len(found) == 1
    icon = found[0]
    assert icon.image_url == SVG_URL.format(prefix="mdi", name="cat")
    assert icon.page_url == "https://icon-sets.iconify.design/mdi/cat/"
    assert icon.source_id == "mdi:cat"


def test_iconify_takes_license_from_the_icon_set():
    sess = FakeSession([FakeResponse(json_data=ICONIFY_BODY)])
    icon = IconifyAssets(session=sess).search_assets("cat", limit=1)[0]
    assert icon.license == "Apache 2.0"
    assert icon.creator == "Pictogrammers"
    assert "Material Design Icons" in icon.title


def test_iconify_unknown_collection_is_not_fatal():
    sess = FakeSession([FakeResponse(json_data={"icons": ["ph:dog-bold"], "collections": {}})])
    icon = IconifyAssets(session=sess).search_assets("dog", limit=1)[0]
    assert icon.license == "unknown"
    assert icon.image_url.endswith("/ph/dog-bold.svg")


def test_iconify_respects_api_minimum_limit():
    sess = FakeSession([FakeResponse(json_data=ICONIFY_BODY)])
    IconifyAssets(session=sess).search_assets("cat", limit=2)
    assert sess.last_params()["limit"] == MIN_LIMIT  # API の下限を下回らない


def test_iconify_needs_no_key():
    assert IconifyAssets().is_available()


# --- Unsplash ---------------------------------------------------------
def test_unsplash_maps_fields(monkeypatch):
    monkeypatch.setenv("UNSPLASH_ACCESS_KEY", "us-test")
    sess = FakeSession([FakeResponse(json_data=UNSPLASH_BODY)])

    photo = UnsplashAssets(session=sess).search_assets("cat", limit=1)[0]

    assert photo.title == "a cat on a laptop"  # description が無ければ alt を使う
    assert photo.image_url == "https://images.unsplash.com/cat"
    assert photo.creator == "Taro"
    assert photo.license == "Unsplash License"
    assert photo.meta["download_location"].endswith("/download")


def test_unsplash_requires_key():
    with pytest.raises(AuthError, match="UNSPLASH_ACCESS_KEY"):
        UnsplashAssets().search_assets("cat")


def test_unsplash_notifies_download(monkeypatch):
    """Unsplash はダウンロード時の通知を規約で求めている。"""
    monkeypatch.setenv("UNSPLASH_ACCESS_KEY", "us-test")
    search = FakeSession([FakeResponse(json_data=UNSPLASH_BODY)])
    photo = UnsplashAssets(session=search).search_assets("cat", limit=1)[0]

    notify = FakeSession([FakeResponse(json_data={"url": "https://images.unsplash.com/cat"})])
    UnsplashAssets(session=notify).notify_download(photo)

    assert notify.calls[0][1] == "https://api.unsplash.com/photos/abc/download"


def test_unsplash_notification_failure_is_swallowed(monkeypatch):
    monkeypatch.setenv("UNSPLASH_ACCESS_KEY", "us-test")
    from ailab.core import http
    from ailab.core.types import Asset

    monkeypatch.setattr(http.time, "sleep", lambda _seconds: None)
    sess = FakeSession([FakeResponse(status_code=500) for _ in range(3)])
    asset = Asset(source="unsplash", title="x", image_url="u", meta={"download_location": "https://x/y"})

    UnsplashAssets(session=sess).notify_download(asset)  # 例外を投げない


def test_unsplash_notification_skipped_without_key():
    from ailab.core.types import Asset

    sess = FakeSession()  # 通信したら AssertionError
    asset = Asset(source="unsplash", title="x", image_url="u", meta={"download_location": "https://x/y"})
    UnsplashAssets(session=sess).notify_download(asset)


def test_download_triggers_source_notification(monkeypatch, tmp_path):
    """assets.download が取得元の通知フックを呼ぶ。"""
    from ailab.core.types import Asset

    called = []
    monkeypatch.setattr(UnsplashAssets, "notify_download", lambda self, asset: called.append(asset))
    asset = Asset(source="unsplash", title="Cat", image_url="https://example.com/c.jpg", source_id="abc")

    assets.download(asset, tmp_path, sess=FakeSession([FakeResponse(content=b"jpegdata")]))

    assert called == [asset]


def test_download_ignores_missing_notification_hook(tmp_path):
    from ailab.core.types import Asset

    asset = Asset(source="openverse", title="Cat", image_url="https://example.com/c.png")
    path = assets.download(asset, tmp_path, sess=FakeSession([FakeResponse(content=b"png")]))
    assert path.exists()


# --- Pexels -----------------------------------------------------------
def test_pexels_maps_fields(monkeypatch):
    monkeypatch.setenv("PEXELS_API_KEY", "px-test")
    sess = FakeSession([FakeResponse(json_data=PEXELS_BODY)])

    photo = PexelsAssets(session=sess).search_assets("cat", limit=1)[0]

    assert photo.image_url == "https://images.pexels.com/large.jpg"
    assert photo.creator == "Hanako"
    assert photo.license == "Pexels License"
    assert (photo.width, photo.height) == (1920, 1280)


def test_pexels_sends_key_in_authorization_header(monkeypatch):
    monkeypatch.setenv("PEXELS_API_KEY", "px-test")
    assert PexelsAssets().default_headers()["Authorization"] == "px-test"


def test_pexels_requires_key():
    with pytest.raises(AuthError, match="PEXELS_API_KEY"):
        PexelsAssets().search_assets("cat")


# --- 横断検索 ---------------------------------------------------------
def test_search_all_includes_iconify(monkeypatch):
    from ailab.core.types import Asset

    monkeypatch.setattr(
        IconifyAssets, "search_assets", lambda self, q, **kw: [Asset("iconify", "cat", "u")]
    )
    for cls in (
        __import__("ailab.connectors.assets_openverse", fromlist=["OpenverseAssets"]).OpenverseAssets,
        __import__("ailab.connectors.assets_wikimedia", fromlist=["WikimediaAssets"]).WikimediaAssets,
    ):
        monkeypatch.setattr(cls, "search_assets", lambda self, q, **kw: [])

    assert [a.source for a in assets.search("cat")] == ["iconify"]
