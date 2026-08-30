"""Cloudflare Workers AI の画像生成。"""

import base64

import pytest
from fakes import FakeResponse, FakeSession

from ailab.connectors.images_cloudflare import API_BASE, CloudflareImages
from ailab.core.errors import AuthError, ConnectorError

PNG = b"\x89PNG\r\n\x1a\nfake"
B64 = base64.b64encode(PNG).decode()
ACCOUNT = "acc123"


@pytest.fixture
def cloudflare_keys(monkeypatch):
    monkeypatch.setenv("CLOUDFLARE_ACCOUNT_ID", ACCOUNT)
    monkeypatch.setenv("CLOUDFLARE_API_TOKEN", "cf-test")


def test_needs_both_account_id_and_token(monkeypatch):
    monkeypatch.setenv("CLOUDFLARE_ACCOUNT_ID", ACCOUNT)
    connector = CloudflareImages()
    assert not connector.is_available()
    assert "CLOUDFLARE_API_TOKEN" in connector.unavailable_reason()
    with pytest.raises(AuthError):
        connector.generate("猫")


def test_reads_base64_from_result_image(cloudflare_keys):
    sess = FakeSession([FakeResponse(json_data={"result": {"image": B64}, "success": True})])

    images = CloudflareImages(session=sess).generate("猫")

    assert images[0].data == PNG
    assert images[0].provider == "cloudflare"
    method, url, kwargs = sess.calls[0]
    assert (method, url) == (
        "POST",
        f"{API_BASE}/{ACCOUNT}/ai/run/@cf/black-forest-labs/flux-1-schnell",
    )
    assert kwargs["json"]["prompt"] == "猫"


def test_reads_openai_compatible_shape(cloudflare_keys):
    sess = FakeSession([FakeResponse(json_data={"result": {"data": [{"b64_json": B64}]}})])
    assert CloudflareImages(session=sess).generate("猫")[0].data == PNG


def test_reads_raw_image_bytes(cloudflare_keys):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])
    images = CloudflareImages(session=sess).generate("猫", model="@cf/stabilityai/stable-diffusion-xl")
    assert images[0].data == PNG
    assert images[0].mime == "image/png"


def test_size_is_sent_only_for_models_that_accept_it(cloudflare_keys):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])
    CloudflareImages(session=sess).generate(
        "猫", size="512x768", model="@cf/stabilityai/stable-diffusion-xl"
    )
    assert sess.calls[0][2]["json"]["width"] == 512

    sess = FakeSession([FakeResponse(json_data={"result": {"image": B64}})])
    CloudflareImages(session=sess).generate("猫", size="512x768")  # flux 系
    assert "width" not in sess.calls[0][2]["json"]


def test_error_body_is_reported(cloudflare_keys):
    sess = FakeSession([FakeResponse(json_data={"success": False, "errors": [{"message": "枠切れ"}]})])
    with pytest.raises(ConnectorError, match="枠切れ"):
        CloudflareImages(session=sess).generate("猫")


def test_one_request_per_image(cloudflare_keys):
    sess = FakeSession([FakeResponse(json_data={"result": {"image": B64}}) for _ in range(2)])
    assert len(CloudflareImages(session=sess).generate("猫", n=2)) == 2
    assert len(sess.calls) == 2


def test_check_uses_the_account_scoped_endpoint(cloudflare_keys):
    sess = FakeSession([FakeResponse(json_data={"result": [{"name": "flux"}]})])
    result = CloudflareImages(session=sess).check()
    assert result.ok
    assert sess.calls[0][1] == f"{API_BASE}/{ACCOUNT}/ai/models/search"


def test_check_is_skipped_without_keys():
    assert CloudflareImages().check().skipped
