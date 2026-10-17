# -*- coding: utf-8 -*-
"""その日の題材の候補を出す。

    python scripts/gather.py                 # 集めて選り分けて、番号を振って出す
    python scripts/gather.py --raw           # 選り分けずに、集めたものをそのまま見る
    python scripts/gather.py --no-ai         # Gemini を使わず、言葉の当たりだけで絞る

○× を付けるのはユーザー。ここは番号を振って並べるところまで。
採った題材は research/ledger.json に控え、次から同じものを出さない。
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from danmen import sources            # noqa: E402

LEDGER = Path("research/ledger.json")

# Gemini を使わないときの、ざっくりした当たり
SIGNALS = {
    "異質": (3, ["日本だけ", "世界初", "唯一", "異例", "初めて", "世界一", "日本以外"]),
    "増減": (2, ["過去最多", "過去最少", "過去最高", "過去最低", "急増", "急減", "最多", "最少",
                 "相次ぐ", "激減", "半減", "倍増"]),
    "消える": (2, ["倒産", "廃業", "撤退", "打ち切り", "閉店", "終了", "撤去", "廃止", "休止"]),
    "値動き": (2, ["値上げ", "値下げ", "高騰", "急騰", "暴落", "下落", "最高値", "最安値", "赤字"]),
    "制度": (2, ["改正", "新制度", "義務化", "規制", "控除", "減税", "増税", "給付", "補助金",
                 "解禁", "認可", "基準"]),
    "問い": (3, ["なぜ", "どうして", "背景", "理由", "わけ", "からくり", "仕組み", "のか"]),
}
NG = ["死去", "逝去", "訃報", "容疑者", "逮捕", "殺害", "殺人", "暴行", "強盗", "虐待",
      "不倫", "熱愛", "離婚", "破局", "結婚", "妊娠", "出産", "引退会見",
      "被害者", "遺体", "心肺停止", "炎上", "謝罪会見",
      "死亡", "重体", "重傷", "搬送", "安否", "行方不明", "遭難",
      "熱中症", "感染", "ワクチン", "がん", "認知症", "うつ病", "ダイエット"]


def rough_score(text: str) -> tuple[int, list[str]]:
    if any(ng in text for ng in NG):
        return -1, []
    pts, hits = 0, []
    for kind, (w, words) in SIGNALS.items():
        for word in words:
            if word in text:
                pts += w
                hits.append(f"{kind}:{word}")
                break
    return pts, hits


def load_ledger() -> set[str]:
    if LEDGER.exists():
        return {r["title"] for r in json.loads(LEDGER.read_text(encoding="utf-8"))}
    return set()


def main() -> int:
    ap = argparse.ArgumentParser(description="その日の題材の候補を出す")
    ap.add_argument("--raw", action="store_true", help="選り分けずに、集めたものを見る")
    ap.add_argument("--no-ai", action="store_true", help="Gemini を使わない")
    ap.add_argument("--out", help="控えを書く先（JSON）")
    args = ap.parse_args()

    print("集めています…", file=sys.stderr)
    items = sources.gather_all()
    kinds: dict[str, int] = {}
    for it in items:
        kinds[it.kind] = kinds.get(it.kind, 0) + 1
    print("■ 集めた　%d 件（ニュース %d ／ 検索の疑問 %d ／ YouTube %d ／ はてブ %d）"
          % (len(items), kinds.get("news", 0), kinds.get("suggest", 0),
             kinds.get("yt_suggest", 0), kinds.get("hatena", 0)))
    print()

    if args.raw:
        for it in items[:80]:
            print(f"  [{it.source}] {it.text}")
        return 0

    # まず言葉の当たりで粗く絞る（Gemini に渡す数を減らすため）
    for it in items:
        it.score, it.hits = rough_score(it.text)
    rough = [it for it in items if it.score > 0]
    rough.sort(key=lambda i: -i.score)
    rough = rough[:70]
    print(f"■ 粗く絞った　{len(rough)} 件", file=sys.stderr)

    if args.no_ai:
        for i, it in enumerate(rough[:20], 1):
            print(f"{i:>2}. [{it.source}] {it.text}")
            print(f"     芽: {' / '.join(it.hits)}")
        return 0

    from danmen import judge
    print("Gemini に選り分けさせています…", file=sys.stderr)
    rows = judge.judge(rough)

    done = load_ledger()
    shown = 0
    print(f"■ {date.today():%Y-%m-%d}　題材の候補\n")
    for row in rows:
        if row.get("title") in done:
            continue
        shown += 1
        cond = {1: "理由が語られていない", 2: "誤解されている", 3: "日本だけ異質"}.get(row.get("cond"), "")
        print(f"{shown:>2}. {row.get('title')}")
        print(f"     ★{row.get('score')}　{cond}　…　{row.get('why')}")
        print(f"     原典: {row.get('source')}")
        print(f"     元: [{row.get('source_feed')}] {row.get('original')}")
        print()
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"控え: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
