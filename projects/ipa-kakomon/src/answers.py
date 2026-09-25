"""IPA の解答例 PDF から、多肢選択問題の正解表を取り出す。

**筆記試験の問題冊子は文字層を持たないスキャン画像**なので、そちらの問題文は
扱えない（2026-09-24 に令和7年度・令和5年度の応用情報で確認。総文字数 0）。
解答例 PDF は筆記でも CBT でも文字層があり、問番号・正解が素直に取れる。
CBT 方式の問題文は `questions.py` が扱う。

解答表は「問1 エ ア」のような並びが 1 行に 4 問ぶん横に並ぶ。
行を読んで「問<数字> <カタカナ1字>」の組を拾えば、桁を意識せずに済む。
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

# 「問12 エ」= 問番号と正解。末尾の分野記号は問ごとに付くが、付かない年度もある。
_PAIR = re.compile(r"問\s*(\d{1,3})\s*([アイウエオカキク])")

# 正解として認めるのは多肢選択の記号。**アイウエだけにしてはいけない。**
# CBT 方式の科目Bは選択肢が8つあり、「問13 ク」「問15 キ」のような正解が出る。
# 4つに絞っていたときは、その2問が**一言も言わずに一覧から消えていた**
# （令和7年度 SG で実測。15問のはずが13問しか返っていなかった）。
_CHOICES = "アイウエオカキク"


@dataclass(frozen=True)
class Answer:
    """午前問題 1 問ぶんの正解。"""

    number: int
    choice: str

    def __post_init__(self) -> None:
        if not 1 <= self.number <= 100:
            raise ValueError(f"問番号が範囲外です: {self.number}")
        if self.choice not in _CHOICES:
            raise ValueError(f"正解の記号が不正です: {self.choice!r}")


def parse_text(text: str) -> list[Answer]:
    """解答例 PDF から抜いたテキストを、問番号順の正解一覧にする。

    同じ問番号が二度現れたら、PDF の読み違いを疑って例外にする。
    黙って上書きすると、誤った正解を載せたまま公開してしまう。
    """
    found: dict[int, str] = {}
    for raw_number, choice in _PAIR.findall(text):
        number = int(raw_number)
        previous = found.get(number)
        if previous is not None and previous != choice:
            raise ValueError(
                f"問{number} の正解が二通り読めました（{previous} と {choice}）。"
                "PDF の抽出結果を目で確認してください。"
            )
        found[number] = choice
    return [Answer(number=n, choice=found[n]) for n in sorted(found)]


def extract(pdf_path: Path) -> list[Answer]:
    """解答例 PDF を開いて正解一覧を返す。"""
    import pdfplumber  # 重いので呼ばれたときだけ読む

    with pdfplumber.open(pdf_path) as pdf:
        text = "\n".join(page.extract_text() or "" for page in pdf.pages)
    if not text.strip():
        raise ValueError(
            f"{pdf_path.name} から文字が取れませんでした。"
            "問題冊子と同じくスキャン画像の可能性があります。"
        )
    return parse_text(text)


def missing_numbers(answers: list[Answer], expected: int) -> list[int]:
    """期待する問数に対して欠けている問番号。抽出漏れの検知に使う。"""
    have = {a.number for a in answers}
    return [n for n in range(1, expected + 1) if n not in have]
