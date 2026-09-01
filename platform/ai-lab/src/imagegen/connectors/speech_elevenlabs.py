"""ElevenLabs Text to Speech。

日本語を含む多言語モデル（eleven_multilingual_v2）で品質が高い代わりに、
文字あたりの単価も高い。使った分は `imagegen usage` に記録される。
"""

from __future__ import annotations

from ..config import get_env
from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import SynthesizedSpeech, Voice

BASE_URL = "https://api.elevenlabs.io/v1"

#: output_format → MIMEタイプ
FORMATS = {"mp3": "audio/mpeg", "wav": "audio/wav", "pcm": "audio/pcm", "opus": "audio/ogg"}
#: fmt から API の output_format 値へ
OUTPUT_FORMATS = {"mp3": "mp3_44100_128", "wav": "pcm_44100", "pcm": "pcm_44100", "opus": "opus_48000_128"}


@register
class ElevenLabsSpeech(Connector):
    name = "elevenlabs"
    category = "speech"
    summary = "ElevenLabs の音声合成（多言語・高品質）"
    priority = 20
    auth = AuthSpec(env=("ELEVENLABS_API_KEY",), signup_url="https://elevenlabs.io/app/settings/api-keys")
    terms_url = "https://elevenlabs.io/terms-of-use"
    rate_limit = RateLimit(requests=30, per_seconds=60)
    default_model = "eleven_multilingual_v2"
    max_chars = 4500

    def default_headers(self) -> dict[str, str]:
        key = self.api_key()
        return {"xi-api-key": key} if key else {}

    def list_voices(self) -> list[Voice]:
        payload = self.get_json(f"{BASE_URL}/voices", timeout=30)
        return [
            Voice(
                id=str(item.get("voice_id", "")),
                name=str(item.get("name", "")),
                provider=self.name,
                detail=str(item.get("category", "")),
            )
            for item in (payload or {}).get("voices", [])
        ]

    def resolve_voice(self, voice: str | None = None) -> str:
        """使う voice_id を決める。指定が無ければ ELEVENLABS_VOICE_ID、それも無ければ先頭の声。

        既定の voice_id をコードに埋めない。アカウントによって使える声が違ううえ、
        ID は変わりうるため。
        """
        chosen = voice or get_env("ELEVENLABS_VOICE_ID")
        if chosen:
            return chosen
        voices = self.list_voices()
        if not voices:
            raise ConnectorError(
                "elevenlabs: 使える声が1つもありません（ELEVENLABS_VOICE_ID を設定してください）"
            )
        return voices[0].id

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        voices = self.list_voices()
        return CheckResult(self.name, ok=True, detail=f"APIキー有効（声 {len(voices)} 種）")

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
        voice_id = self.resolve_voice(voice)
        key = (fmt or "mp3").lower()
        response = self.request(
            "POST",
            f"{BASE_URL}/text-to-speech/{voice_id}",
            params={"output_format": OUTPUT_FORMATS.get(key, OUTPUT_FORMATS["mp3"])},
            json={
                "text": text,
                "model_id": model,
                "voice_settings": {"stability": 0.5, "similarity_boost": 0.75, "speed": float(speed)},
            },
            timeout=timeout,
        )
        return SynthesizedSpeech(
            data=response.content,
            mime=FORMATS.get(key, "audio/mpeg"),
            provider=self.name,
            model=model,
            voice=voice_id,
            text=text,
            meta={"speed": float(speed)},
        )
