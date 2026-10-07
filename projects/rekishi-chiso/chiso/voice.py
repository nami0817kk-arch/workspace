"""抑揚と間の決まり。掛け合いを「読み上げ」ではなく「会話」に聞かせるための部分。

VOICEVOX の音声は、何も指定しないと1行ごとに同じ調子で平板になる。ここで3つを足す。

1. 調子（tone）: 驚き・疑問・しみじみ など、行ごとの感情で速さ・高さ・抑揚・音量を変える
2. 強調《》: せりふの中の《…》で囲んだ語だけ、高く・ゆっくり・大きくする
3. 間: 話者が替わるとき、問いへの答え、驚きの反応、節の切れ目で、行と行のあいだを変える

読み方の辞書（readings.yaml）もここで当てる。画面に出す文字は変えず、読み上げる文字だけ変える。
"""
from __future__ import annotations

import copy
import re
from dataclasses import dataclass
from pathlib import Path

import yaml

# 調子ごとの補正。pitch は足し算（VOICEVOX の pitchScale、±0.15 が上限の目安）、
# それ以外は話者の基本値への掛け算。
TONES: dict[str, dict[str, float]] = {
    # 2026-10-03「もう少しリアクションや抑揚強め」で全体に強めた
    "普通": {},
    "驚き": {"pitch": 0.09, "intonation": 1.65, "speed": 1.12, "volume": 1.2, "end_rise": 0.35},
    "疑問": {"pitch": 0.04, "intonation": 1.45, "speed": 1.02, "end_rise": 0.25},
    "強調": {"intonation": 1.45, "speed": 0.88, "volume": 1.15},
    "しみじみ": {"pitch": -0.03, "intonation": 0.85, "speed": 0.86, "volume": 0.92},
    "明るい": {"pitch": 0.05, "intonation": 1.4, "speed": 1.07, "volume": 1.05},
    "笑い": {"pitch": 0.06, "intonation": 1.5, "speed": 1.1, "volume": 1.08},
    "重い": {"pitch": -0.06, "intonation": 0.88, "speed": 0.84, "volume": 0.95},
    "ひそひそ": {"intonation": 0.8, "speed": 0.95, "volume": 0.72},
    "納得": {"pitch": -0.01, "intonation": 1.25, "speed": 0.95},
}

# 《》で囲んだ語の強調の強さ
EMPHASIS_PITCH = 0.35        # 音の高さ（VOICEVOX の pitch は 5〜6 前後の対数値）に足す量
EMPHASIS_LENGTH = 1.25       # 母音を伸ばす倍率
EMPHASIS_VOLUME = 1.12

_EMPH = re.compile(r"《(.+?)》")


@dataclass(frozen=True)
class Voice:
    """1人の話者の基本値。

    tone_strength: 調子（驚き・疑問など）の効き方。1.0 で TONES のとおり、0.4 なら変化の幅を4割にする。
    max_intonation / max_speed: 調子を掛けたあとの上限。高すぎる抑揚と早口はキンキンして聞こえる。
    """
    style_id: int
    speed: float = 1.0
    pitch: float = 0.0
    intonation: float = 1.0
    volume: float = 1.0
    tone_strength: float = 1.0
    max_intonation: float = 2.0
    max_speed: float = 2.0
    emphasis: float = 1.0          # 《》の強調の効き（10-05「剣崎が色文字の時におかしな話かたになる」で話者ごとに）


def tone_params(voice: Voice, tone: str) -> dict[str, float]:
    """話者の基本値に調子の補正を掛けた、VOICEVOX の audio_query に入れる値。"""
    if tone not in TONES:
        raise KeyError(f"調子「{tone}」は定義されていません")
    k = voice.tone_strength
    t = TONES[tone]
    mul = lambda key: 1.0 + (t.get(key, 1.0) - 1.0) * k   # 掛け算の補正を k 倍に縮める
    return {
        "speedScale": round(min(voice.max_speed, voice.speed * mul("speed")), 4),
        "pitchScale": round(max(-0.15, min(0.15, voice.pitch + t.get("pitch", 0.0) * k)), 4),
        # VOICEVOX の抑揚は 0〜2 まで。話者ごとの上限でも止める
        "intonationScale": round(min(2.0, voice.max_intonation, voice.intonation * mul("intonation")), 4),
        "volumeScale": round(voice.volume * mul("volume"), 4),
        "prePhonemeLength": 0.05,
        "postPhonemeLength": 0.08,
    }


def split_emphasis(text: str) -> tuple[str, list[str]]:
    """《》を外した文と、強調する語の一覧を返す。"""
    words = [w for w in _EMPH.findall(text) if w.strip()]
    return _EMPH.sub(r"\1", text), words


def display_text(text: str) -> str:
    """画面や字幕に出す文（《》を外す）。"""
    return _EMPH.sub(r"\1", text)


def load_readings(path: str | Path) -> dict[str, str]:
    path = Path(path)
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    return {str(k): str(v) for k, v in data.items()}


def apply_readings(text: str, readings: dict[str, str]) -> str:
    """長い語から順に置き換える（「マリー・アントワネット」を「マリー」より先に）。"""
    for word in sorted(readings, key=len, reverse=True):
        text = text.replace(word, readings[word])
    return text


def _moras(query: dict) -> list[dict]:
    out = []
    for phrase in query.get("accent_phrases", []):
        out.extend(phrase.get("moras", []))
    return out


def _kana(moras: list[dict]) -> str:
    return "".join(m.get("text", "") for m in moras)


def emphasize(query: dict, word_kanas: list[str], strength: float = 1.0) -> tuple[dict, list[str]]:
    """audio_query の結果のうち、強調する語の読み（カタカナ）に当たるモーラを持ち上げる。

    語の読みは、その語だけを audio_query にかけて得たモーラ列を渡す（漢字と読みの
    対応が分からないため）。見つからなかった語は2つ目の戻り値で返す。
    strength は効きの強さ（1.0 で EMPHASIS_* のとおり、0.3 なら高さ・伸ばし・音量の変化を3割に）。
    """
    query = copy.deepcopy(query)
    moras = _moras(query)
    full = _kana(moras)
    # 文字位置 → モーラ番号
    owner: list[int] = []
    for i, m in enumerate(moras):
        owner.extend([i] * len(m.get("text", "")))
    missing = []
    for kana in word_kanas:
        if not kana:
            continue
        pos = full.find(kana)
        if pos < 0:
            missing.append(kana)
            continue
        targets = sorted(set(owner[pos:pos + len(kana)]))
        for i in targets:
            m = moras[i]
            if m.get("pitch", 0) > 0:          # 無声化したモーラ（pitch 0）は触らない
                m["pitch"] = round(m["pitch"] + EMPHASIS_PITCH * strength, 4)
            if m.get("vowel_length"):
                m["vowel_length"] = round(m["vowel_length"] * (1 + (EMPHASIS_LENGTH - 1) * strength), 4)
    if word_kanas and len(missing) < len(word_kanas):
        query["volumeScale"] = round(query.get("volumeScale", 1.0) * (1 + (EMPHASIS_VOLUME - 1) * strength), 4)
    return query, missing


def join_n_phrases(accent_phrases: list) -> tuple[list, bool]:
    """「ン」で始まる区切りを、前の言葉につなげる。

    VOICEVOX は「言ってないんですか」を「イッテナイ／ンデスカ」と切り、頭の「ン」をいちばん高く読む。
    「言ってない。ンですか？」と2つに切れて聞こえるので、前の言葉の続きにする（2026-10-04 指摘）。
    間（読点）をはさむ場合はつなげない。つないだら高さは mora_data で計算し直す。
    """
    out: list = []
    changed = False
    for p in accent_phrases:
        moras = p.get("moras") or []
        if out and moras and moras[0].get("text") == "ン" and not out[-1].get("pause_mora"):
            prev = out[-1]
            prev["moras"] = prev["moras"] + copy.deepcopy(moras)
            prev["is_interrogative"] = p.get("is_interrogative", False)
            prev["pause_mora"] = p.get("pause_mora")
            changed = True
        else:
            out.append(copy.deepcopy(p))
    return out, changed


def end_rise(query: dict, amount: float) -> dict:
    """文の最後の言葉（最後のアクセント句）の終わり2モーラを持ち上げて、驚き・問いの尻上がりを強くする。"""
    if amount <= 0 or not query.get("accent_phrases"):
        return query
    query = copy.deepcopy(query)
    moras = [m for m in query["accent_phrases"][-1].get("moras", []) if m.get("pitch", 0) > 0]
    for k, m in enumerate(moras[-2:]):
        m["pitch"] = round(m["pitch"] + amount * (0.5 if k == 0 and len(moras) > 1 else 1.0), 4)
    return query


def kana_of(query: dict) -> str:
    return _kana(_moras(query))


# --- 間 -------------------------------------------------------------------

GAP_SAME_SPEAKER = 0.38      # 同じ人が続けて話す
GAP_TURN = 0.24              # 話者が替わる
GAP_ANSWER = 0.14            # 問い（？で終わる）にすぐ答える
GAP_REACTION = 0.06          # 驚きの反応は、ほぼ間を置かずにかぶせる
GAP_AFTER_HEAVY = 0.7        # 重い・しみじみの後は、余韻を残す
GAP_SECTION = 1.2            # 節の切れ目


def gap_before(prev, line) -> float:
    """prev の行のあと、line を話し始めるまでの間（秒）。"""
    if line.pause is not None:
        return line.pause
    if prev is None:
        return 0.3
    if prev.section != line.section:
        return GAP_SECTION
    if prev.tone in ("重い", "しみじみ"):
        return GAP_AFTER_HEAVY
    if prev.speaker == line.speaker:
        return GAP_SAME_SPEAKER
    if line.tone in ("驚き", "笑い"):
        return GAP_REACTION
    if display_text(prev.text).rstrip().endswith(("？", "?")):
        return GAP_ANSWER
    return GAP_TURN
