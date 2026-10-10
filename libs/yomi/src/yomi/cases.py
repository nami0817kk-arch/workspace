"""⑤ 見つけた誤読をテストに残す。

1件は「この文は、読み替え辞書で置き換えるとこうなり、エンジンはこう読む」。チャンネルの tests/ に並べて、
CI では置き換えの結果（said）だけ、手元ではエンジンのカナ（kana）まで確かめる。

    CASES = [Case("約12万石の大名", said="万ゴク", kana="マンゴク"), ...]
    def test_cases(): assert check(CASES, readings) == []
    @pytest.mark.voicevox
    def test_cases_kana(): assert check_kana(CASES, readings, lambda t: voicevox_kana(t)) == []

kana が「／」で始まるものは、区切りの頭にその読みが来ること（「勝家」が「〜とか／ついえ」に切れないこと）。
"""
from __future__ import annotations

from dataclasses import dataclass

from .replace import apply_readings


@dataclass(frozen=True)
class Case:
    text: str             # 台本の文（読まない印は外したもの）
    said: str = ""        # 置き換えたあとの文に入っているべきもの
    kana: str = ""        # エンジンのカナに入っているべきもの
    note: str = ""        # どこで見つけたか（「秀長の回 57行目」）


def check(cases, readings: dict[str, str]) -> list[str]:
    """置き換えの結果が said を含まない Case（CI でも回る）。"""
    bad = []
    for c in cases:
        got = apply_readings(c.text, readings)
        if c.said and c.said not in got:
            bad.append(f"{c.note or c.text}：{got}（「{c.said}」が無い）")
    return bad


def check_kana(cases, readings: dict[str, str], kana) -> list[str]:
    """エンジンのカナが kana を含まない Case（kana：置き換えたあとの文 → カナ の関数。手元だけ）。"""
    bad = []
    for c in cases:
        if not c.kana:
            continue
        got = kana(apply_readings(c.text, readings))
        hay = "／" + got if c.kana.startswith("／") else got.replace("／", "")
        if c.kana not in hay:
            bad.append(f"{c.note or c.text}：{got}（「{c.kana}」が無い）")
    return bad
