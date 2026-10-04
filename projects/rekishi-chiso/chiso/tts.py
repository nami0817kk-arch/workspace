"""VOICEVOX で1行ずつ音声にする。結果は行の中身のハッシュで控えて、変えた行だけ作り直す。"""
from __future__ import annotations

import hashlib
import io
import json
import urllib.parse
import urllib.request
import wave
from dataclasses import dataclass
from pathlib import Path

from .voice import (TONES, Voice, apply_readings, emphasize, end_rise, join_n_phrases, kana_of, split_emphasis,
                    tone_params)


class VoicevoxError(RuntimeError):
    pass


@dataclass
class Voicevox:
    url: str = "http://127.0.0.1:50021"
    timeout: int = 120

    def _post(self, path: str, params: dict, body: bytes | None = None) -> bytes:
        req = urllib.request.Request(
            f"{self.url}{path}?{urllib.parse.urlencode(params)}", data=body, method="POST",
            headers={"Content-Type": "application/json"} if body is not None else {},
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as res:
                return res.read()
        except OSError as e:  # 接続できない・タイムアウト
            raise VoicevoxError(f"VOICEVOX（{self.url}）に繋がりません。エンジンを起動してください: {e}") from e

    def query(self, text: str, style_id: int) -> dict:
        return json.loads(self._post("/audio_query", {"text": text, "speaker": style_id}))

    def mora_data(self, accent_phrases: list, style_id: int) -> list:
        """区切りを変えたあとの高さと長さを、VOICEVOX に計算し直させる。"""
        return json.loads(self._post("/mora_data", {"speaker": style_id},
                                     json.dumps(accent_phrases).encode("utf-8")))

    def synthesize(self, query: dict, style_id: int) -> bytes:
        return self._post("/synthesis", {"speaker": style_id}, json.dumps(query).encode("utf-8"))


@dataclass
class Spoken:
    wav: Path
    seconds: float
    missing_emphasis: list[str]


def line_key(text: str, voice: Voice, tone: str, readings: dict[str, str]) -> str:
    payload = json.dumps([text, voice.__dict__, tone, sorted(readings.items()), "v4"], ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def wav_seconds(data: bytes) -> float:
    with wave.open(io.BytesIO(data)) as w:
        return w.getnframes() / w.getframerate()


def speak(engine: Voicevox, text: str, voice: Voice, tone: str, readings: dict[str, str],
          cache_dir: Path) -> Spoken:
    cache_dir.mkdir(parents=True, exist_ok=True)
    key = line_key(text, voice, tone, readings)
    target = cache_dir / f"{key}.wav"
    meta = cache_dir / f"{key}.json"
    if target.exists() and meta.exists():
        info = json.loads(meta.read_text(encoding="utf-8"))
        return Spoken(target, info["seconds"], info.get("missing", []))

    plain, words = split_emphasis(text)
    spoken_text = apply_readings(plain, readings)
    query = engine.query(spoken_text, voice.style_id)
    phrases, changed = join_n_phrases(query["accent_phrases"])
    if changed:
        query["accent_phrases"] = engine.mora_data(phrases, voice.style_id)
    query.update(tone_params(voice, tone))
    missing: list[str] = []
    if words:
        kanas = [kana_of(engine.query(apply_readings(w, readings), voice.style_id)) for w in words]
        query, missing = emphasize(query, kanas)
    query = end_rise(query, TONES[tone].get("end_rise", 0.0) * voice.tone_strength)
    data = engine.synthesize(query, voice.style_id)
    target.write_bytes(data)
    seconds = wav_seconds(data)
    meta.write_text(json.dumps({"text": text, "tone": tone, "seconds": seconds, "missing": missing},
                               ensure_ascii=False), encoding="utf-8")
    return Spoken(target, seconds, missing)
