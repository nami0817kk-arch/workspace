# -*- coding: utf-8 -*-
"""見せる前の手の点検は CLAUDE.md の表から読む（2026-09-27）。

HAND_CHECKS が8つで止まっていて、表に足した決まりが一覧に出てこなかった。
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import preshow  # noqa: E402

DOC = """# 決まり

### 題材を見せるとき

| 決まり | 言われた日 | 誰が見るか |
|---|---|---|
| 女子は出さない | 09-16 | 手 |

### 台本を見せるとき

| 決まり | 言われた日 | 誰が見るか |
|---|---|---|
| **反応は題の中身だけ** | 09-27 | 手 |
| 重複は8字 | 09-22 | 機械 |

| 言われたこと | 何が悪かったか | いま |
|---|---|---|
| 左がグレー | 手で直した | 手 |
"""


def test_表の手の行だけを拾う(tmp_path):
    doc = tmp_path / "CLAUDE.md"
    doc.write_text(DOC, encoding="utf-8")
    assert preshow.table_hand_rules(doc) == [("反応は題の中身だけ", "09-27")]


def test_本物の表に今日の決まりが入っている():
    rules = [rule for rule, _ in preshow.table_hand_rules()]
    assert any("反応は題の中身そのもの" in r for r in rules)
    assert any("ショートは書き出したら" in r for r in rules)
