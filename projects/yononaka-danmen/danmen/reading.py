# -*- coding: utf-8 -*-
"""読み上げる前に、数字を漢数字に直す。**字幕は元のまま。**

AivisSpeech は「175円」を単独なら正しく読むが、**単位のあとに数字が続くと
桁として読めなくなる**（2026-10-08 に実際に起きた）。

    1リットル175円   → イチリットル・イチナナゴエン   ← 誤り
    1リットル、175円  → イチリットル・ヒャクナナジュウゴエン
    1リットル百七十五円 → イチリットル・ヒャクナナジュウゴエン  ← これを使う

読点を入れると間が増えて不自然になるので、**漢数字に直す**。
小数点も「点」にする（「25.1」は「ニジュウゴオテン…」と伸びる）。

    reading(text) … 読み上げ用のテキスト
"""
from __future__ import annotations

import re

KANJI = "〇一二三四五六七八九"
SMALL = ["", "十", "百", "千"]
BIG = ["", "万", "億", "兆", "京"]
NUM = re.compile(r"\d[\d,]*(?:\.\d+)?")


def _under_10000(n: int) -> str:
    """1万未満を漢数字に。「一十」「一百」とは書かない。"""
    if n == 0:
        return ""
    out = ""
    for i, keta in enumerate(reversed(str(n))):
        d = int(keta)
        if d == 0:
            continue
        # 十・百・千の前の「一」は書かない
        head = "" if (d == 1 and i > 0) else KANJI[d]
        out = head + SMALL[i] + out
    return out


def int_to_kanji(n: int) -> str:
    """整数を漢数字に。万・億・兆の区切りを入れる。"""
    if n == 0:
        return "〇"
    out, i = "", 0
    while n > 0:
        n, part = divmod(n, 10000)
        if part:
            out = _under_10000(part) + BIG[i] + out
        i += 1
        if i >= len(BIG):
            break
    return out


def num_to_kanji(s: str) -> str:
    """「175」「1,500」「25.1」を漢数字に。小数点は「点」。"""
    s = s.replace(",", "")
    if "." in s:
        a, b = s.split(".", 1)
        head = int_to_kanji(int(a)) if a else "〇"
        tail = "".join(KANJI[int(c)] for c in b)
        return head + "点" + tail
    return int_to_kanji(int(s))


_READINGS: dict[str, str] | None = None


def readings() -> dict[str, str]:
    """読み替え辞書（readings.yaml）。長い語から順に置き換える。"""
    global _READINGS
    if _READINGS is None:
        from pathlib import Path
        import yaml
        p = Path(__file__).resolve().parents[1] / "readings.yaml"
        data = yaml.safe_load(p.read_text(encoding="utf-8")) if p.exists() else None
        _READINGS = {str(k): str(v) for k, v in (data or {}).items()}
    return _READINGS


def reading(text: str) -> str:
    """読み上げ用のテキスト。**字幕には使わない**（字幕は算用数字のまま）。

    読み替え辞書で語を置き換えてから、数字を漢数字にする。
    """
    for k in sorted(readings(), key=len, reverse=True):
        text = text.replace(k, readings()[k])
    return NUM.sub(lambda m: num_to_kanji(m.group(0)), text)
