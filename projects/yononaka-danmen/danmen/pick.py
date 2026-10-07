# -*- coding: utf-8 -*-
"""候補のどれを作るかを決める。勘ではなく、測れるもので点を付ける。

5つの物差しで測る。満点は 23点。

| 物差し | 満点 | 測り方 |
|---|---|---|
| 検索の広さ | 5 | YouTube の補完が何件出るか。多いほど関心が広い |
| 問いの濃さ | 5 | 補完のうち「なぜ・いつ・とは・どうなる」などの疑問が占める割合 |
| 原典の堅さ | 5 | 当たるべき原典が公的機関（go.jp 等）か |
| 30分もつか | 5 | 断面が4つ立つか（Gemini に見出しを出させて数える） |
| 新しさ   | 3 | 今日のニュース由来なら加点。常在の疑問は 0 |

**他人の動画の再生数は見ない。** 見ると、既にある動画の後追いになる（2026-10-06 ユーザー指摘）。
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from danmen import judge, sources

QUESTION_WORDS = ["なぜ", "どうして", "いつ", "とは", "どうなる", "理由", "仕組み",
                  "内訳", "いくら", "どこ", "違い", "方法", "意味", "влия"]
PUBLIC = ["go.jp", "省", "庁", "委員会", "日本銀行", "統計", "白書", "法", "規則", "公正取引"]


@dataclass
class Scored:
    row: dict
    word: str = ""
    suggests: list[str] = field(default_factory=list)
    breadth: int = 0        # 検索の広さ
    depth: int = 0          # 問いの濃さ
    source: int = 0         # 原典の堅さ
    length: int = 0         # 30分もつか
    fresh: int = 0          # 新しさ
    cuts: list[str] = field(default_factory=list)

    @property
    def total(self) -> int:
        return self.breadth + self.depth + self.source + self.length + self.fresh


def candidate_words(row: dict) -> list[str]:
    """検索に使う語の候補。judge が出した queries を使い、無ければタイトルから拾う。"""
    qs = row.get("queries") or ([row["query"]] if row.get("query") else [])
    out = [str(q).strip() for q in qs if str(q).strip()]
    return out or [main_word(row)]


def main_word(row: dict) -> str:
    """タイトルから検索語を拾う（queries が無いときの保険）。"""
    t = str(row.get("title", ""))
    t = re.sub(r"^なぜ|^どうして", "", t)
    t = re.split(r"[？?、。！!]", t)[0]
    # 「日本の家庭電源は100Vな」→ 名詞のかたまりを拾う
    words = re.findall(r"[一-龥ァ-ヶーA-Za-z0-9]{2,12}", t)
    words = [w for w in words if w not in ("日本", "ため", "こと", "もの")]
    return words[0] if words else t[:8]


CUTS_PROMPT = """次の問いで30分の動画を作ります。章立てが成り立つか確かめてください。

問い: {title}

この問いについて、次の4つの断面それぞれに見出しを1つずつ付けてください。
中身が無くて見出しが作れない断面は、空文字にしてください。

1. 一の断面: 何でできているか（数字の内訳）
2. 二の断面: いつ、誰が、なぜそう決めたか（経緯）
3. 三の断面: 誰が払い、誰が受け取っているか（お金や損得の流れ）
4. 四の断面: 世界と比べてどうか

JSON だけを返してください。形は {{"cuts": ["見出し1","見出し2","見出し3","見出し4"]}}
"""


def score(row: dict, ask_ai: bool = True) -> Scored:
    s = Scored(row=row)
    # 1. 検索の広さ。候補の語をそれぞれ引いて、いちばん反応のあったものを採る
    best: tuple[int, str, list[str]] = (0, "", [])
    for w in candidate_words(row)[:3]:
        got = sources.suggest(w, youtube=True)
        if len(got) > best[0]:
            best = (len(got), w, got)
    s.word, s.suggests = best[1], best[2]
    s.breadth = min(len(s.suggests) // 2, 5)

    # 2. 問いの濃さ（補完のうち疑問の形をしているもの）
    if s.suggests:
        q = sum(1 for x in s.suggests if any(w in x for w in QUESTION_WORDS))
        s.depth = min(round(q / len(s.suggests) * 10), 5)

    # 3. 原典の堅さ
    src = str(row.get("source", ""))
    s.source = 5 if any(p in src for p in PUBLIC) else (2 if src else 0)

    # 4. 30分もつか（断面が4つ立つか）
    if ask_ai:
        try:
            text = judge.ask(CUTS_PROMPT.format(title=row.get("title", "")))
            data = judge.as_json(text)
            cuts = []
            if isinstance(data, dict):
                cuts = data.get("cuts", [])
            elif isinstance(data, list):
                if data and isinstance(data[0], dict):
                    cuts = data[0].get("cuts", [])
                else:
                    cuts = data          # 配列がそのまま見出しの並びのことがある
            s.cuts = [str(c) for c in cuts if str(c).strip()]
            s.length = min(len(s.cuts) + 1, 5)
        except SystemExit:
            s.length = 0

    # 5. 新しさ
    feed = str(row.get("source_feed", ""))
    s.fresh = 3 if feed and "サジェスト" not in feed and "YouTube" not in feed else 0
    return s


def rank(rows: list[dict], ask_ai: bool = True) -> list[Scored]:
    out = [score(r, ask_ai=ask_ai) for r in rows]
    return sorted(out, key=lambda s: -s.total)
