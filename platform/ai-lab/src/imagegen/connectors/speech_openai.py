"""OpenAI Text to Speech (gpt-4o-mini-tts)。

画像生成の openai コネクタと同じ OPENAI_API_KEY を使うが、能力が違うので別コネクタ。
"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError
from ..core.registry import register
from ..core.types import SynthesizedSpeech, Voice
from ..utils import extension_for

API_URL = "https://api.openai.com/v1/audio/speech"
MODELS_URL = "https://api.openai.com/v1/models"

#: 選べる声（APIから一覧を引けないので固定。増減は公式ドキュメントを見ること）
VOICES = [
    ("alloy", "中性的で癖がない"),
    ("ash", "低め・落ち着いた"),
    ("ballad", "柔らかい"),
    ("coral", "明るい"),
    ("echo", "落ち着いた男性的"),
    ("fable", "語り口調"),
    ("nova", "明るい女性的"),
    ("onyx", "低く重い"),
    ("sage", "穏やか"),
    ("shimmer", "軽やか"),
]

#: response_format → MIMEタイプ
FORMATS = {
    "mp3": "audio/mpeg",
    "wav": "audio/wav",
    "opus": "audio/opus",
    "aac": "audio/aac",
    "flac": "audio/flac",
    "pcm": "audio/pcm",
}


@register
class OpenAISpeech(Connector):
    name = "openai_tts"
    category = "speech"
    summary = "OpenAI の音声合成 (gpt-4o-mini-tts)"
    priority = 10
    auth = AuthSpec(env=("OPENAI_API_KEY",), signup_url="https://platform.openai.com/api-keys")
    terms_url = "https://openai.com/policies/usage-policies/"
    rate_limit = RateLimit(requests=20, per_seconds=60)
    default_model = "gpt-4o-mini-tts"
    default_voice = "alloy"
    #: API の入力上限（4096文字）より少し手前で切る
    max_chars = 4000

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def list_voices(self) -> list[Voice]:
        return [Voice(id=name, name=name, provider=self.name, detail=note) for name, note in VOICES]

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        self.get_json(MODELS_URL, use_cache=False, timeout=30)
        return CheckResult(self.name, ok=True, detail="APIキー有効")

    def synthesize(
        self,
        text: str,
        *,
        voice: str | None = None,
        model: str | None = None,
        speed: float = 1.0,
        fmt: str | None = None,
        timeout: int = 180,
    ) -> SynthesizedSpeech:
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        model = self.resolve_model(model)
        voice = voice or self.default_voice
        response_format = (fmt or "mp3").lower()
        mime = FORMATS.get(response_format, "audio/mpeg")

        response = self.request(
            "POST",
            API_URL,
            json={
                "model": model,
                "input": text,
                "voice": voice,
                "response_format": response_format,
                "speed": float(speed),
            },
            timeout=timeout,
        )
        return SynthesizedSpeech(
            data=response.content,
            mime=mime,
            provider=self.name,
            model=model,
            voice=voice,
            text=text,
            meta={"format": extension_for(mime, ".mp3").lstrip("."), "speed": float(speed)},
        )
