import base64

import pytest

from ailab.imagegen import gemini_provider, openai_provider, stability_provider
from ailab.imagegen.base import ProviderError
from ailab.imagegen.stability_provider import closest_aspect_ratio
from fakes import FakeResponse, FakeSession

PNG = b"\x89PNG\r\n\x1a\nfake"
B64 = base64.b64encode(PNG).decode()


def test_openai_decodes_b64_response(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    fake = FakeSession([FakeResponse(json_data={"data": [{"b64_json": B64}]})])
    monkeypatch.setattr(openai_provider, "session", lambda headers=None: fake)

    images = openai_provider.OpenAIProvider().generate("猫", size="512x512")

    assert images[0].data == PNG
    assert images[0].provider == "openai"
    method, url, kwargs = fake.calls[0]
    assert (method, url) == ("POST", openai_provider.API_URL)
    assert kwargs["json"]["prompt"] == "猫"
    assert kwargs["json"]["size"] == "512x512"


def test_openai_downloads_url_response(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    fake = FakeSession(
        [
            FakeResponse(json_data={"data": [{"url": "https://example.com/a.png"}]}),
            FakeResponse(content=PNG),
        ]
    )
    monkeypatch.setattr(openai_provider, "session", lambda headers=None: fake)

    assert openai_provider.OpenAIProvider().generate("犬")[0].data == PNG


def test_openai_raises_without_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    with pytest.raises(ProviderError, match="OPENAI_API_KEY"):
        openai_provider.OpenAIProvider().generate("猫")


def test_openai_reports_api_error(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    fake = FakeSession(
        [FakeResponse(status_code=401, json_data={"error": {"message": "bad key"}})]
    )
    monkeypatch.setattr(openai_provider, "session", lambda headers=None: fake)
    with pytest.raises(ProviderError, match="bad key"):
        openai_provider.OpenAIProvider().generate("猫")


def test_gemini_reads_inline_data(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "g-test")
    body = {
        "candidates": [
            {"content": {"parts": [{"text": "ok"}, {"inlineData": {"mimeType": "image/png", "data": B64}}]}}
        ]
    }
    fake = FakeSession([FakeResponse(json_data=body)])
    monkeypatch.setattr(gemini_provider, "session", lambda headers=None: fake)

    images = gemini_provider.GeminiProvider().generate("桜")

    assert images[0].data == PNG
    assert fake.calls[0][1].endswith(":generateContent")


def test_gemini_uses_predict_for_imagen(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "g-test")
    body = {"predictions": [{"bytesBase64Encoded": B64, "mimeType": "image/png"}]}
    fake = FakeSession([FakeResponse(json_data=body)])
    monkeypatch.setattr(gemini_provider, "session", lambda headers=None: fake)

    images = gemini_provider.GeminiProvider().generate("富士山", model="imagen-4.0-generate-001")

    assert images[0].data == PNG
    assert fake.calls[0][1].endswith(":predict")


def test_gemini_accepts_google_api_key(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.setenv("GOOGLE_API_KEY", "g-test")
    assert gemini_provider.GeminiProvider().is_available()


def test_stability_returns_raw_bytes(monkeypatch):
    monkeypatch.setenv("STABILITY_API_KEY", "st-test")
    fake = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])
    monkeypatch.setattr(stability_provider, "session", lambda headers=None: fake)

    images = stability_provider.StabilityProvider().generate("海", size="1024x576")

    assert images[0].data == PNG
    assert fake.calls[0][2]["data"]["aspect_ratio"] == "16:9"


@pytest.mark.parametrize(
    ("size", "ratio"),
    [("1024x1024", "1:1"), ("1024x576", "16:9"), ("768x1024", "4:5"), ("1200x800", "3:2")],
)
def test_closest_aspect_ratio(size, ratio):
    assert closest_aspect_ratio(size) == ratio


def test_closest_aspect_ratio_falls_back_to_square():
    assert closest_aspect_ratio("invalid") == "1:1"
