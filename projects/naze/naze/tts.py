"""VOICEVOX で行ごとに声を作り、つないで語りの wav と時間割を返す。

行: {id, text(字幕・読みの元), say(読み上げ用に書き換えた文。無ければ text), pause(後ろの間・秒)}
読みは必ず kana で目で確かめる(`kana()` が全行の読みを返す)。違えば say に仮名で書く。
"""
from __future__ import annotations

import io
import json
import re
import urllib.parse
import urllib.request
import wave
from pathlib import Path
from typing import Dict, List

import numpy as np

from .config import VOICEVOX

STYLE = 21          # 剣崎雌雄 ノーマル(2026-10-26 ユーザーが7人から選んだ。クレジットは「VOICEVOX:剣崎雌雄」)
SPEED = 1.1
GAP = 0.3


def _say(line: dict) -> str:
    s = line.get("say") or line["text"]
    s = re.sub(r"[【】|]", "", s).replace("\n", "")
    # 数字のあとの単位は読みを決めておく(VOICEVOX は m を「エム」、km² などを英字で読む)
    s = re.sub(r"(\d)km³", r"\1立方キロメートル", s)
    s = re.sub(r"(\d)km", r"\1キロメートル", s)
    s = re.sub(r"(\d)cm", r"\1センチメートル", s)
    s = re.sub(r"(\d)m(?![a-zA-Z])", r"\1メートル", s)
    return s


def _query(text: str, style: int) -> dict:
    url = f"{VOICEVOX}/audio_query?" + urllib.parse.urlencode(dict(text=text, speaker=style))
    return json.load(urllib.request.urlopen(urllib.request.Request(url, method="POST"), timeout=60))


def kana(lines: List[dict], style: int = STYLE) -> List[str]:
    return [f"{l['id']}: {_query(_say(l), style)['kana']}" for l in lines]


SECTION_GAP = 0.65      # 節の頭(section=True)・問いのあと・結びの前は、ひと呼吸おく


def _gap_after(l: dict) -> float:
    if l.get("style") == "question" or l.get("section_end"):
        return SECTION_GAP
    return GAP


def sync_keys(l: dict) -> List[str]:
    """行の場面のうち on="言葉" を書いた層・パネル・札の言葉(その言葉を言い始めた瞬間に出す)。"""
    keys = list(l.get("marks", []))
    sc = l.get("scene") or {}
    for x in [sc] + list(sc.get("layers", [])) + ([sc["panel"]] if sc.get("panel") else []):
        if isinstance(x, dict) and x.get("on"):
            keys.append(x["on"])
    return [k for k in dict.fromkeys(keys) if k in l["text"]]


def _spoken(q: dict) -> float:
    """audio_query の言い終わりまでの長さ(speedScale 1 のとき、前後の無音は除く)。"""
    t = 0.0
    for ap in q["accent_phrases"]:
        for m in ap["moras"]:
            t += (m.get("consonant_length") or 0.0) + m["vowel_length"]
        if ap.get("pause_mora"):
            t += ap["pause_mora"]["vowel_length"]
    return t


def marks(l: dict, style: int, speed: float) -> Dict[str, float]:
    """行の頭から、その言葉を言い始めるまでの秒。言葉の前までを読ませて長さを測る。"""
    res = {}
    for k in sync_keys(l):
        pre = l["text"][: l["text"].index(k)]
        pre = re.sub(r"[、。,.!?！？\s]+$", "", pre)
        res[k] = 0.05 + (_spoken(_query(_say(dict(text=pre)), style)) / speed if pre else 0.0)
    return res


def synth(lines: List[dict], out: Path, style: int = STYLE, speed: float = SPEED, lead: float = 0.15, tail: float = 1.2) -> Dict:
    """全行を合成して out/narration.wav を書き、行ごとの start/end を足した行の並びと全体の秒数を返す。"""
    out.mkdir(parents=True, exist_ok=True)
    sr = 24000
    t = lead
    chunks = []
    timed = []
    for i, l in enumerate(lines):
        if i and (l.get("section") or l.get("style") in ("end", "cta")):
            t += SECTION_GAP - GAP           # 前の行との間を節の間に広げる
        q = _query(_say(l), style)
        q.update(speedScale=float(l.get("speed", speed)), outputSamplingRate=sr, prePhonemeLength=0.05, postPhonemeLength=0.05)
        req = urllib.request.Request(f"{VOICEVOX}/synthesis?speaker={style}", data=json.dumps(q).encode(),
                                     headers={"Content-Type": "application/json"}, method="POST")
        w = wave.open(io.BytesIO(urllib.request.urlopen(req, timeout=120).read()))
        a = np.frombuffer(w.readframes(w.getnframes()), np.int16)
        keep = {k: v for k, v in l.items() if k not in ("scene", "labels", "profile", "compare", "marks")}   # 時間割には場面の設定を入れない(関数が入っていると保存できない)
        mk = marks(l, style, float(l.get("speed", speed)))
        timed.append(dict(keep, start=round(t, 3), end=round(t + len(a) / sr, 3), **({"marks": mk} if mk else {})))
        chunks.append((t, a))
        t += len(a) / sr + float(l.get("pause", _gap_after(l)))
    total = t + tail
    mix = np.zeros(int(total * sr), np.int16)
    for st, a in chunks:
        i = int(st * sr)
        mix[i:i + len(a)] = a
    with wave.open(str(out / "narration.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(mix.tobytes())
    return dict(lines=timed, total=round(total, 3))
