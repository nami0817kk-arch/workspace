"""声の候補を同じ3文で聞き比べる見本を作る（out/voice_samples/<話者>_<スタイル>.wav と stats.json）。
使い方: python tools/voice_samples.py   （VOICEVOX エンジンが 127.0.0.1:50021 で動いていること）
既存の chiso/ は読むだけ。速さ 1.18・抑揚 1.2 に固定し、読みは readings.yaml を使う。"""
from __future__ import annotations

import io
import json
import math
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from chiso.tts import Voicevox, final_query, wav_seconds  # noqa: E402
from chiso.voice import Voice, load_readings  # noqa: E402

LINES = ["逃げた女は、二度目、逃げなかった。",
         "だが、お市は断った。三人の娘だけを、城から送り出した。",
         "あなたなら、娘を送り出して、逃げずにいられますか。"]
CANDIDATES = [  # (話者, スタイル, style_id)
    ("剣崎雌雄", "ノーマル(現行)", 21),
    ("青山龍星", "しっとり", 84),
    ("青山龍星", "かなしみ", 85),
    ("玄野武宏", "悲しみ", 41),
    ("No.7", "読み聞かせ", 31),
    ("離途", "シリアス", 101),
    ("猫使アル", "おちつき", 56),
]
GAP = 0.3


def main() -> None:
    out = ROOT / "out" / "voice_samples"
    out.mkdir(parents=True, exist_ok=True)
    eng = Voicevox()
    readings = load_readings(ROOT / "readings.yaml")
    stats = {}
    for who, style, sid in CANDIDATES:
        voice = Voice(style_id=sid, speed=1.18, intonation=1.2, tone_strength=0.75, max_intonation=1.3, max_speed=1.3)
        pcm, params, f0s, lens = b"", None, [], []
        for t in LINES:
            q, _ = final_query(eng, t, voice, "普通", readings)
            data = eng.synthesize(q, sid)
            with wave.open(io.BytesIO(data)) as w:
                params = params or w.getparams()
                pcm += w.readframes(w.getnframes())
                pcm += b"\0" * (int(w.getframerate() * GAP) * 2)
            lens.append(round(wav_seconds(data), 2))
            for ph in q["accent_phrases"]:
                for m in ph["moras"]:
                    if m.get("pitch", 0) > 0 and m.get("vowel") not in ("N", "cl"):
                        f0s.append(math.exp(m["pitch"]))
        pcm = pcm[:-int(params.framerate * GAP) * 2]
        path = out / f"{who}_{style.split('(')[0]}.wav"
        with wave.open(str(path), "wb") as w:
            w.setparams(params)
            w.writeframes(pcm)
        f0s.sort()
        n = len(f0s)
        stats[path.name] = {"id": sid, "秒": round(len(pcm) / 2 / params.framerate, 2), "各文の秒": lens,
                            "f0中央Hz": round(f0s[n // 2]), "f0_10%": round(f0s[n // 10]), "f0_90%": round(f0s[n * 9 // 10]),
                            "文字/秒": round(sum(len(x) for x in LINES) / (sum(lens)), 1)}
        print(path.name, stats[path.name], flush=True)
    (out / "stats.json").write_text(json.dumps(stats, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
