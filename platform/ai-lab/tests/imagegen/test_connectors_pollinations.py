"""Pollinations（APIキー不要の画像生成）。"""

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.connectors.images_pollinations import BASE_URL, PollinationsImages
from imagegen.core.errors import ConnectorError
from imagegen.core.http import RateLimiter

JPEG = b"\xff\xd8\xff\xe0fake"


def image_response():
    return FakeResponse(content=JPEG, headers={"Content-Type": "image/jpeg"})


def test_generates_without_any_api_key():
    connector = PollinationsImages(session=FakeSession([image_response()]))
    assert connector.is_available()  # キー不要
    images = connector.generate("猫のイラスト", size="512x384")
    assert images[0].data == JPEG
    assert images[0].provider == "pollinations"


def test_prompt_goes_into_the_path_and_size_into_params():
    sess = FakeSession([image_response()])
    PollinationsImages(session=sess).generate("cat on a laptop", size="512x384")

    method, url, kwargs = sess.calls[0]
    assert method == "GET"
    assert url == f"{BASE_URL}/cat%20on%20a%20laptop"
    assert kwargs["params"]["width"] == 512 and kwargs["params"]["height"] == 384
    assert kwargs["params"]["model"] == "sana"


def test_japanese_prompt_is_url_encoded():
    sess = FakeSession([image_response()])
    PollinationsImages(session=sess).generate("猫", size="64x64")
    assert sess.calls[0][1] == f"{BASE_URL}/%E7%8C%AB"


def test_generation_is_private_by_default():
    """公開フィードに載らないようにする。"""
    sess = FakeSession([image_response()])
    PollinationsImages(session=sess).generate("秘密のプロンプト", size="64x64")
    assert sess.calls[0][2]["params"]["private"] == "true"


def test_private_can_be_turned_off():
    sess = FakeSession([image_response()])
    PollinationsImages(session=sess).generate("公開してよい", size="64x64", private=False)
    assert sess.calls[0][2]["params"]["private"] == "false"


def test_seed_advances_per_image():
    sess = FakeSession([image_response(), image_response()])
    PollinationsImages(session=sess).generate("猫", size="64x64", n=2, seed=100)
    assert [call[2]["params"]["seed"] for call in sess.calls] == [100, 101]


def test_watermark_removal_only_with_a_token(monkeypatch):
    sess = FakeSession([image_response()])
    PollinationsImages(session=sess).generate("猫", size="64x64")
    assert "nologo" not in sess.calls[0][2]["params"]

    monkeypatch.setenv("POLLINATIONS_TOKEN", "p-test")
    sess = FakeSession([image_response()])
    connector = PollinationsImages(session=sess)
    connector.generate("猫", size="64x64")
    assert sess.calls[0][2]["params"]["nologo"] == "true"
    assert connector.default_headers()["Authorization"] == "Bearer p-test"


def test_non_image_response_is_an_error():
    sess = FakeSession(
        [FakeResponse(json_data={"error": "busy"}, headers={"Content-Type": "application/json"})]
    )
    with pytest.raises(ConnectorError, match="画像が返りませんでした"):
        PollinationsImages(session=sess).generate("猫", size="64x64")


def test_model_can_be_overridden(monkeypatch):
    monkeypatch.setenv("IMAGEGEN_POLLINATIONS_MODEL", "turbo")
    sess = FakeSession([image_response()])
    PollinationsImages(session=sess).generate("猫", size="64x64")
    assert sess.calls[0][2]["params"]["model"] == "turbo"


def test_rate_limit_waits_instead_of_failing():
    """匿名は15秒に1回。連続生成では例外にせず待つ設定にしてある。"""
    limit = PollinationsImages.rate_limit
    assert limit.max_wait_seconds is not None
    assert limit.max_wait_seconds > limit.per_seconds


def test_rate_limiter_honours_a_custom_max_wait():
    limiter = RateLimiter(1, 15, label="test", max_wait=40)
    assert limiter.max_wait == 40
    assert RateLimiter(1, 15, label="test").max_wait == RateLimiter.MAX_WAIT


def test_check_reports_that_no_token_is_needed():
    result = PollinationsImages(session=FakeSession([image_response()])).check()
    assert result.ok and "トークンなし" in result.detail
