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
        query, missing = emphasize(query, kanas, voice.emphasis)
    query = end_rise(query, TONES[tone].get("end_rise", 0.0) * voice.tone_strength)
    data = engine.synthesize(query, voice.style_id)
    target.write_bytes(data)
    seconds = wav_seconds(data)
    meta.write_text(json.dumps({"text": text, "tone": tone, "seconds": seconds, "missing": missing},
                               ensure_ascii=False), encoding="utf-8")
    return Spoken(target, seconds, missing)


TOGETHER = "二人"       # 2人で声を合わせる行（10-04「しめは二人で声を合わせる」）


def speak_together(engine: Voicevox, text: str, voices: list[Voice], tone: str, readings: dict[str, str],
                   cache_dir: Path) -> Spoken:
    """同じせりふを2人の声で読み、重ねて1本にする。長い方に合わせ、短い方は頭をそろえる。"""
    import array
    parts = [speak(engine, text, v, tone, readings, cache_dir) for v in voices]
    key = hashlib.sha256("|".join(p.wav.stem for p in parts).encode()).hexdigest()[:16]
    target = cache_dir / f"together-{key}.wav"
    if not target.exists():
        samples, params = [], None
        for p in parts:
            with wave.open(str(p.wav)) as w:
                params = params or w.getparams()
                a = array.array("h")
                a.frombytes(w.readframes(w.getnframes()))
                samples.append(a)
        n = max(len(a) for a in samples)
        out = array.array("h", [0] * n)
        for a in samples:
            for i, v in enumerate(a):
                out[i] = max(-32768, min(32767, out[i] + int(v * 0.65)))   # 重ねても割れない大きさ
        with wave.open(str(target), "wb") as w:
            w.setparams(params)
            w.writeframes(out.tobytes())
    with wave.open(str(target)) as w:
        seconds = w.getnframes() / w.getframerate()
    return Spoken(target, seconds, sorted({m for p in parts for m in p.missing_emphasis}))


def speak_line(engine: Voicevox, line, voices: dict[str, Voice], readings: dict[str, str], cache_dir: Path) -> Spoken:
    """1行を、その行の話者の声で。二人の行は語りと聞きの声を重ねる。"""
    if line.speaker == TOGETHER:
        return speak_together(engine, line.text, [voices["語り"], voices["聞き"]], line.tone, readings, cache_dir)
    return speak(engine, line.text, voices[line.speaker], line.tone, readings, cache_dir)
