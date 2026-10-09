# -*- coding: utf-8 -*-
"""Google トレンドの「急上昇」から、このチャンネル向けの題材の芽を拾う。

    python scripts/trending.py            # 手順を出す（ブラウザで読む）
    python scripts/trending.py --parse <貼り付けたJSON>   # 読んだものを整形して保存

**RSS（`https://trends.google.co.jp/trending/rss?geo=JP`）では足りない。**
2026-10-09 に比べたところ、RSS は9件・検索数は100〜500どまりだったが、
ページ（`/trending`）は**1,209件、50万+まで**出て、カテゴリと期間で絞れる。

**ページの取り口（batchexecute の RPC `g4kJzf`）は直に叩けなかった。**
引数の形が分からず、空の応答が返る。ブラウザで開いて DOM から読むのが確実。

このチャンネルに効くカテゴリ（`category=` の番号）:

| 番号 | 名前 | 2026-10-09 の件数 |
|---|---|---|
| 3 | ビジネス、金融 | 109 |
| 7 | その他（制度・社会） | 159 |
| 15 | 科学 | 17 |
| 17 | 自動車、乗り物 | 24 |

**健康（11件）は使わない。** 「医療・健康の助言はしない」という決まりに触れる。

ブラウザで読む手順（Claude がやる）:

1. `https://trends.google.co.jp/trending?geo=JP&hours=168&sort=search-volume&category=<番号>` を開く
2. 下の JS で表を読む（1ページ25件。`1ページあたりの行数` を変えればもっと）
3. 出た JSON を `--parse` に渡す

```js
[...document.querySelectorAll('tr')].slice(1).map(tr => {
  const td = [...tr.querySelectorAll('td')].map(x => x.innerText.replace(/\\s+/g,' ').trim());
  return {word: td[0], volume: td[1], when: td[2], related: td[3] || ''};
}).filter(r => r.word)
```
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

OUT_DIR = Path("research/trending")
CATEGORIES = {3: "ビジネス、金融", 7: "その他", 15: "科学", 17: "自動車、乗り物"}
BASE = "https://trends.google.co.jp/trending?geo=JP&hours=168&sort=search-volume&category={}"
READ_JS = (
    "[...document.querySelectorAll('tr')].slice(1).map(tr => {"
    "const td = [...tr.querySelectorAll('td')].map(x => x.innerText.replace(/\\s+/g,' ').trim());"
    "return {word: td[0], volume: td[1], when: td[2], related: td[3] || ''};"
    "}).filter(r => r.word)"
)
# 扱わないもの（CLAUDE.md の決まり）。ここで落とす
NG = ["容疑", "逮捕", "死去", "訃報", "死亡", "殺", "暴行", "虐待", "炎上", "不倫",
      "熱愛", "離婚", "結婚", "妊娠", "出産", "引退", "病院", "感染", "ワクチン",
      "がん", "ダイエット", "被害者", "遺体", "行方不明"]


def volume_of(text: str) -> int:
    """「5万+」「2,000+」を数に。並べ替えに使う。"""
    t = str(text).replace(",", "")
    m = re.search(r"([\d.]+)\s*万", t)
    if m:
        return int(float(m.group(1)) * 10000)
    m = re.search(r"(\d+)", t)
    return int(m.group(1)) if m else 0


def clean(rows: list[dict]) -> list[dict]:
    out = []
    for r in rows:
        w = str(r.get("word", "")).strip()
        rel = str(r.get("related", ""))
        if not w or any(ng in w or ng in rel for ng in NG):
            continue
        out.append({
            "word": w,
            "volume": volume_of(r.get("volume", "")),
            "volume_text": str(r.get("volume", "")).split(" ")[0],
            "when": str(r.get("when", "")).split(" trending")[0].strip(),
            "related": [x for x in re.split(r"\s{2,}|\s\+\s\d+\s件", rel) if x.strip()][:4],
        })
    out.sort(key=lambda r: -r["volume"])
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Google トレンドの急上昇から題材の芽を拾う")
    ap.add_argument("--parse", help="ブラウザで読んだ JSON（ファイルか、そのままの文字列）")
    ap.add_argument("--category", type=int, default=3, help="／".join(
        "{}={}".format(k, v) for k, v in CATEGORIES.items()))
    args = ap.parse_args()

    if not args.parse:
        print("ブラウザで開くところ:")
        for num, name in CATEGORIES.items():
            print("  {:>2} {:10s} {}".format(num, name, BASE.format(num)))
        print()
        print("表を読む JS:")
        print("  " + READ_JS)
        print()
        print("読んだら: python scripts/trending.py --parse <JSONのファイル> --category <番号>")
        return 0

    p = Path(args.parse)
    raw = p.read_text(encoding="utf-8") if p.exists() else args.parse
    rows = clean(json.loads(raw))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "{}-cat{}.json".format(date.today().isoformat(), args.category)
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print("{} 件（{}）→ {}".format(len(rows), CATEGORIES.get(args.category, "?"), out))
    for r in rows[:15]:
        print("  {:>8}  {:14s} {}".format(r["volume_text"], r["word"][:14],
                                          "／".join(r["related"])[:44]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
