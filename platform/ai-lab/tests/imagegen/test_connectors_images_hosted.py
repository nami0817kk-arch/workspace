"""Replicate / Hugging Face の生成コネクタ。"""

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.connectors import images_replicate
from imagegen.connectors.images_huggingface import DEFAULT_BASE_URL, HuggingFaceImages, base_url
from imagegen.connectors.images_replicate import API_BASE, ReplicateImages
from imagegen.core.errors import AuthError, ConnectorError

PNG = b"\x89PNG\r\n\x1a\nfake"
DONE = {
    "id": "pred1",
    "status": "succeeded",
    "output": ["https://replicate.delivery/out.png"],
    "urls": {"get": "https://api.replicate.com/v1/predictions/pred1"},
}


@pytest.fixture
def replicate_key(monkeypatch):
    monkeypatch.setenv("REPLICATE_API_TOKEN", "r8-test")


@pytest.fixture
def hf_key(monkeypatch):
    monkeypatch.setenv("HF_TOKEN", "hf-test")


# --- Replicate --------------------------------------------------------
def test_replicate_returns_image_when_already_finished(replicate_key):
    sess = FakeSession([FakeResponse(json_data=DONE), FakeResponse(content=PNG)])

    images = ReplicateImages(session=sess).generate("猫", size="1024x576")

    assert images[0].data == PNG
    assert images[0].provider == "replicate"
    method, url, kwargs = sess.calls[0]
    assert (method, url) == ("POST", f"{API_BASE}/models/black-forest-labs/flux-schnell/predictions")
    assert kwargs["headers"]["Prefer"] == "wait"
    assert kwargs["json"]["input"]["aspect_ratio"] == "16:9"


def test_replicate_polls_until_finished(replicate_key, monkeypatch):
    monkeypatch.setattr(images_replicate.time, "sleep", lambda _seconds: None)
    starting = {"id": "pred1", "status": "starting", "urls": {"get": "https://api.replicate.com/v1/predictions/pred1"}}
    sess = FakeSession(
        [FakeResponse(json_data=starting), FakeResponse(json_data=DONE), FakeResponse(content=PNG)]
    )

    assert ReplicateImages(session=sess).generate("猫")[0].data == PNG
    assert sess.calls[1][1] == "https://api.replicate.com/v1/predictions/pred1"


def test_replicate_reports_failed_prediction(replicate_key, monkeypatch):
    monkeypatch.setattr(images_replicate.time, "sleep", lambda _seconds: None)
    failed = {"id": "p", "status": "failed", "error": "NSFW検出", "urls": {}}
    sess = FakeSession([FakeResponse(json_data=failed)])

    with pytest.raises(ConnectorError, match="NSFW検出"):
        ReplicateImages(session=sess).generate("猫")


def test_replicate_gives_up_after_timeout(replicate_key, monkeypatch):
    monkeypatch.setattr(images_replicate.time, "sleep", lambda _seconds: None)
    processing = {"id": "p", "status": "processing", "urls": {"get": "https://x/y"}}
    sess = FakeSession([FakeResponse(json_data=processing)])

    with pytest.raises(ConnectorError, match="完了しませんでした"):
        ReplicateImages(session=sess).generate("猫", timeout=0)


def test_replicate_uses_version_endpoint_for_pinned_model(replicate_key):
    sess = FakeSession([FakeResponse(json_data=DONE), FakeResponse(content=PNG)])

    ReplicateImages(session=sess).generate("猫", model="owner/name:abc123")

    method, url, kwargs = sess.calls[0]
    assert url == f"{API_BASE}/predictions"
    assert kwargs["json"]["version"] == "abc123"


def test_replicate_accepts_single_output_url(replicate_key):
    single = dict(DONE, output="https://replicate.delivery/one.png")
    sess = FakeSession([FakeResponse(json_data=single), FakeResponse(content=PNG)])
    assert len(ReplicateImages(session=sess).generate("猫")) == 1


def test_replicate_empty_output_is_an_error(replicate_key):
    sess = FakeSession([FakeResponse(json_data=dict(DONE, output=[]))])
    with pytest.raises(ConnectorError, match="画像が返りませんでした"):
        ReplicateImages(session=sess).generate("猫")


def test_replicate_requires_token():
    with pytest.raises(AuthError, match="REPLICATE_API_TOKEN"):
        ReplicateImages().generate("猫")


def test_replicate_check_reports_account(replicate_key):
    sess = FakeSession([FakeResponse(json_data={"username": "taro"})])
    assert "taro" in ReplicateImages(session=sess).check().detail


# --- Hugging Face -----------------------------------------------------
def test_huggingface_returns_raw_bytes(hf_key):
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])

    images = HuggingFaceImages(session=sess).generate("猫", size="512x512")

    assert images[0].data == PNG
    method, url, kwargs = sess.calls[0]
    assert url == f"{DEFAULT_BASE_URL}/models/black-forest-labs/FLUX.1-schnell"
    assert kwargs["json"]["inputs"] == "猫"
    assert kwargs["json"]["parameters"] == {"width": 512, "height": 512}


def test_huggingface_json_response_is_an_error(hf_key):
    sess = FakeSession(
        [FakeResponse(json_data={"error": "loading"}, headers={"Content-Type": "application/json"})]
    )
    with pytest.raises(ConnectorError, match="loading"):
        HuggingFaceImages(session=sess).generate("猫")


def test_huggingface_requests_once_per_image(hf_key):
    sess = FakeSession([FakeResponse(content=PNG) for _ in range(2)])
    assert len(HuggingFaceImages(session=sess).generate("猫", n=2)) == 2
    assert len(sess.calls) == 2


def test_huggingface_accepts_either_token_variable(monkeypatch):
    monkeypatch.setenv("HUGGINGFACE_API_KEY", "hf-test")
    assert HuggingFaceImages().is_available()


def test_huggingface_requires_token():
    with pytest.raises(AuthError, match="HF_TOKEN"):
        HuggingFaceImages().generate("猫")


def test_huggingface_endpoint_is_configurable(monkeypatch):
    monkeypatch.setenv("HF_INFERENCE_URL", "https://router.example.com/")
    assert base_url() == "https://router.example.com"
