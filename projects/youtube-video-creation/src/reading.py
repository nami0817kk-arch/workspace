"""読み上げの読み方をそろえる。

VOICEVOX は漢字を文脈で読む。日付や金額はたいてい外す。
「9月1日」は「くがつついたち」であって「くがつイチにち」ではないし、
「1億5000万」を数字のまま渡すと読み違える。

台本を書くたびに手でひらがなに開いていたが、開き忘れると
音声にしてはじめて気づく。書き換え候補を機械で出す。
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import yaml

from .config import _resolve

DICT_PATH = "config/reading.yaml"

# 日付。1日・8日・10日など、読みが不規則なものが多い
DAYS = {
    1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか",
    6: "むいか", 7: "なのか", 8: "ようか", 9: "ここのか", 10: "とおか",
    14: "じゅうよっか", 20: "はつか", 24: "にじゅうよっか",
}
MONTHS = {
    1: "いちがつ", 2: "にがつ", 3: "さんがつ", 4: "しがつ", 5: "ごがつ", 6: "ろくがつ",
    7: "しちがつ", 8: "はちがつ", 9: "くがつ", 10: "じゅうがつ",
    11: "じゅういちがつ", 12: "じゅうにがつ",
}

DATE = re.compile(r"(\d{1,2})月(\d{1,2})日")
# 勝敗表記の「分」（1勝2分 / 1分3敗 / 6勝3分）。時間の「分」と区別がつかない
# **時間の「45分」と区別する。**前に「勝」があるか、後ろに「敗」が続く形だけ
DRAWS = re.compile(r"[0-9０-９]+勝[0-9０-９]+分(?![けカか])|[0-9０-９]+分(?![けカか])[0-9０-９]+敗")

BIG_MONEY = re.compile(r"(\d+(?:\.\d+)?)\s*(億|兆)")


@dataclass
class Hint:
    """1か所ぶんの書き換え候補。"""

    found: str
    suggest: str
    why: str


def load_dictionary(path: str | Path = DICT_PATH) -> dict[str, str]:
    """人名・クラブ名の読み。無ければ空で動く。"""
    target = _resolve(path)
    if not target.exists():
        return {}
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    return {str(k): str(v) for k, v in (raw.get("readings") or {}).items() if str(v).strip()}


def apply(text: str, dictionary: dict[str, str] | None = None) -> str:
    """読み上げに渡す文を、辞書の読みに置き換える（2026-09-22 指示「日本人選手を読む時に
    読み仮名間違えているから改善して」）。

    それまで辞書は `check` で知らせるだけで、**合成には使っていなかった。**
    VOICEVOX は「冨安健洋」を「トミヤス ケンヨオ」、「鎌田」を「カマタ」と読む
    （`audio_query` の kana で実測）。画面に出す字は変えず、声に渡す文だけ開く。
    長い語から当てる（「鈴木彩艶」と「彩艶」の二重当てを避ける）。
    """
    if dictionary is None:
        dictionary = load_dictionary()
    out = str(text or "")
    for word in sorted(dictionary, key=len, reverse=True):
        if word in out:
            out = out.replace(word, dictionary[word])
    return out


def date_reading(month: int, day: int) -> str:
    """「9月1日」→「くがつついたち」。"""
    return MONTHS.get(month, f"{month}がつ") + DAYS.get(day, f"{day}にち")


def check(text: str, dictionary: dict[str, str] | None = None) -> list[Hint]:
    """読み間違えそうな箇所を拾う。直すかどうかは書き手が決める。"""
    hints: list[Hint] = []

    for match in DATE.finditer(text):
        month, day = int(match.group(1)), int(match.group(2))
        if 1 <= month <= 12 and 1 <= day <= 31:
            hints.append(
                Hint(match.group(0), date_reading(month, day), "日付は読みが不規則")
            )

    # **勝敗表記の「分」は「ふん」と読まれる**（2026-09-13、Gemini に台本を
    # 読ませて見つかった）。「1分3敗」は引き分けの数なのに、合成音声は
    # 時間の「いっぷん」で読む。**聞き返せないので、耳では直せない。**
    # 9/10 のリヴァプール・PSG、9/12 の佐藤、9/13 のヴィラで実際に鳴っていた
    for match in DRAWS.finditer(text):
        hints.append(
            Hint(match.group(0), "",
                 "勝敗の「分」は「ふん」と読まれます（『1分け』『引き分け1』に開く）")
        )

    for match in BIG_MONEY.finditer(text):
        hints.append(
            Hint(match.group(0), "", "大きい数字は読みを開く（例: いちおくごせんまん）")
        )

    # 「鈴木彩艶」と「彩艶」の両方を出すと、同じ場所を二重に指すことになる。
    # 長い語から見て、すでに当たった語に含まれるものは飛ばす
    matched: list[str] = []
    for word in sorted(dictionary or {}, key=len, reverse=True):
        if word not in text:
            continue
        if any(word in longer for longer in matched):
            continue
        matched.append(word)
        hints.append(Hint(word, dictionary[word], "辞書に読みがある"))

    return hints


def apply_dates(text: str) -> str:
    """日付だけを機械的に開く。人名は判断が要るので触らない。"""
    def swap(match: re.Match) -> str:
        month, day = int(match.group(1)), int(match.group(2))
        if 1 <= month <= 12 and 1 <= day <= 31:
            return date_reading(month, day)
        return match.group(0)

    return DATE.sub(swap, text)
