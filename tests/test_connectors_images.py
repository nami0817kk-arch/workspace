import base64
import io

import pytest

from ailab.connectors.images_gemini import BASE_URL, GeminiImages
from ailab.connectors.images_local import LocalImages
from ailab.connectors.images_openai import API_URL, OpenAIImages
from ailab.connectors.images_stability import StabilityImages
from ailab.utils import ASPECT_RATIOS, closest_aspect_ratio
from ailab.core.errors import AuthError, ConnectorError
from fakes import FakeResponse, FakeSession

PNG = b"\x89PNG\r\n\x1a\nfake"
B64 = base64.b64encode(PNG).decode()


# --- local ------------------------------------------------------------
def test_local_generates_png_of_requested_size():
    from PIL import Image

    images = LocalImages().generate("テスト用の画像", size="320x180")

    assert len(images) == 1
    assert images[0].data[:8] == b"\x89PNG\r\n\x1a\n"
    assert Image.open(io.BytesIO(images[0].data)).size == (320, 180)


def test_local_is_deterministic():
    assert LocalImages().generate("同じ入力", size="128x128")[0].data == (
        LocalImages().generate("同じ入力", size="128x128")[0].data
    )


def test_local_varies_by_prompt_and_index():
    images = LocalImages().generate("複数枚", size="128x128", n=3)
    assert len({image.data for image in images}) == 3
    assert images[0].data != LocalImages().generate("別の入力", size="128x128")[0].data


def test_local_needs_no_api_key():
    assert LocalImages().is_available()
    assert LocalImages().check().ok


def test_generated_image_save(tmp_path):
    image = LocalImages().generate("保存テスト", size="64x64")[0]
    path = image.save(tmp_path)
    assert path.exists() and path.suffix == ".png"
    assert path.read_bytes() == image.data


# --- openai -----------------------------------------------------------
def test_openai_decodes_b64_response(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    sess = FakeSession([FakeResponse(json_data={"data": [{"b64_json": B64}]})])

    images = OpenAIImages(session=sess).generate("猫", size="512x512")

    assert images[0].data == PNG
    assert images[0].provider == "openai"
    method, url, kwargs = sess.calls[0]
    assert (method, url) == ("POST", API_URL)
    assert kwargs["json"]["prompt"] == "猫"
    assert kwargs["json"]["size"] == "512x512"


def test_openai_downloads_url_response(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    sess = FakeSession(
        [
            FakeResponse(json_data={"data": [{"url": "https://example.com/a.png"}]}),
            FakeResponse(content=PNG),
        ]
    )
    assert OpenAIImages(session=sess).generate("犬")[0].data == PNG


def test_openai_raises_without_key():
    with pytest.raises(AuthError, match="OPENAI_API_KEY"):
        OpenAIImages().generate("猫")


def test_openai_reports_api_error(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    sess = FakeSession([FakeResponse(status_code=400, json_data={"error": {"message": "bad prompt"}})])
    with pytest.raises(ConnectorError, match="bad prompt"):
        OpenAIImages(session=sess).generate("猫")


def test_openai_empty_response_is_an_error(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    sess = FakeSession([FakeResponse(json_data={"data": []})])
    with pytest.raises(ConnectorError, match="画像が返りませんでした"):
        OpenAIImages(session=sess).generate("猫")


# --- gemini -----------------------------------------------------------
def test_gemini_reads_inline_data(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "g-test")
    body = {
        "candidates": [
            {"content": {"parts": [{"text": "ok"}, {"inlineData": {"mimeType": "image/png", "data": B64}}]}}
        ]
    }
    sess = FakeSession([FakeResponse(json_data=body)])

    images = GeminiImages(session=sess).generate("桜")

    assert images[0].data == PNG
    assert sess.calls[0][1] == f"{BASE_URL}/gemini-2.5-flash-image:generateContent"


def test_gemini_uses_predict_for_imagen(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "g-test")
    sess = FakeSession(
        [FakeResponse(json_data={"predictions": [{"bytesBase64Encoded": B64, "mimeType": "image/png"}]})]
    )

    images = GeminiImages(session=sess).generate("富士山", model="imagen-4.0-generate-001")

    assert images[0].data == PNG
    assert sess.calls[0][1].endswith(":predict")


def test_gemini_accepts_google_api_key(monkeypatch):
    monkeypatch.setenv("GOOGLE_API_KEY", "g-test")
    assert GeminiImages().is_available()


def test_gemini_without_key_explains_both_variables():
    reason = GeminiImages().unavailable_reason()
    assert "GEMINI_API_KEY" in reason and "GOOGLE_API_KEY" in reason


# --- stability --------------------------------------------------------
def test_stability_returns_raw_bytes(monkeypatch):
    monkeypatch.setenv("STABILITY_API_KEY", "st-test")
    sess = FakeSession([FakeResponse(content=PNG, headers={"Content-Type": "image/png"})])

    images = StabilityImages(session=sess).generate("海", size="1024x576")

    assert images[0].data == PNG
    assert sess.calls[0][2]["data"]["aspect_ratio"] == "16:9"


def test_stability_requests_once_per_image(monkeypatch):
    monkeypatch.setenv("STABILITY_API_KEY", "st-test")
    sess = FakeSession([FakeResponse(content=PNG) for _ in range(3)])
    assert len(StabilityImages(session=sess).generate("海", n=3)) == 3
    assert len(sess.calls) == 3


@pytest.mark.parametrize(
    ("size", "ratio"),
    [("1024x1024", "1:1"), ("1024x576", "16:9"), ("768x1024", "4:5"), ("1200x800", "3:2")],
)
def test_closest_aspect_ratio(size, ratio):
    assert closest_aspect_ratio(size) == ratio


def test_closest_aspect_ratio_falls_back_to_square():
    assert closest_aspect_ratio("invalid") in ASPECT_RATIOS
    assert closest_aspect_ratio("invalid") == "1:1"


# --- モデルの決め方 ---------------------------------------------------
def test_model_argument_wins():
    assert OpenAIImages().resolve_model("gpt-image-1.5") == "gpt-image-1.5"


def test_model_falls_back_to_environment(monkeypatch):
    """各社のモデルIDは入れ替わるので .env だけで追随できる。"""
    monkeypatch.setenv("AILAB_OPENAI_MODEL", "gpt-image-3")
    assert OpenAIImages().resolve_model() == "gpt-image-3"
    assert OpenAIImages().resolve_model("gpt-image-2") == "gpt-image-2"  # 引数が優先


def test_model_defaults_to_the_connector_value():
    assert OpenAIImages().resolve_model() == "gpt-image-2"
    assert GeminiImages().resolve_model() == GeminiImages.default_model


def test_environment_model_is_used_when_generating(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    monkeypatch.setenv("AILAB_OPENAI_MODEL", "gpt-image-3")
    sess = FakeSession([FakeResponse(json_data={"data": [{"b64_json": B64}]})])

    images = OpenAIImages(session=sess).generate("猫")

    assert sess.calls[0][2]["json"]["model"] == "gpt-image-3"
    assert images[0].model == "gpt-image-3"
