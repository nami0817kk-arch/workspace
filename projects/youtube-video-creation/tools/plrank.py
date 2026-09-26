"""20クラブを横並びに数える（2026-09-21）。

**数字は、他と比べて初めて意味が出る。**「収容1万2357人」だけでは大きいのか
小さいのか分からないが、「マンチェスター・ユナイテッドの6分の1」なら分かる。
20クラブぶんの板（`<key>.json`）は全部そろっているので、そこから数えるだけでよい。

    python tools/plrank.py            # 数えて research/pl_data/rank.json に書く
    python tools/plrank.py --show     # 何が言えるかを並べる

**板の字から数えている。**`trophies` は 2026-09-21 時点でアーセナルと
ボーンマスにしか入っていないので、そちらは当てにできない（板の字は20クラブぶんある）。
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402

# リーグは CLUB_LEAGUE で切り替える（2026-09-26）
DATA = clubleague.data_dir()
KEYS = ("arsenal bournemouth brentford brighton chelsea coventry everton forest "
        "fulham hull ipswich leeds liverpool mancity manutd newcastle palace "
        "sunderland tottenham villa").split()


def _count(text: str, word: str) -> int:
    m = re.search(word + r"[^\d]{0,8}?(\d+)", text)
    return int(m.group(1)) if m else 0


def collect() -> list[dict]:
    out = []
    for key in KEYS:
        spec = json.loads((DATA / f"{key}.json").read_text(encoding="utf-8"))
        tile = {t[0]: t for t in spec["tiles"]}
        small = tile["タイトル歴"][2]
        row = {
            "key": key,
            "club": spec["title"].replace(" 基礎DATA", ""),
            "cap": int(re.search(r"([\d,]+)", tile["本拠地"][2]).group(1).replace(",", "")),
            "year": int(re.search(r"(\d{4})", tile["クラブ創立"][1]).group(1)),
            "lg": int(re.search(r"(\d+)回", tile["タイトル歴"][1]).group(1)),
            "fa": _count(small, "FA杯"),
            "lc": _count(small, "リーグ杯"),
            # 欧州は「欧州2」「CL1」「欧州杯1・EL1」と書き方が揃っていない
            "eu": max(_count(small, "欧州"), _count(small, "CL"), _count(small, "EL")),
        }
        row["all"] = row["lg"] + row["fa"] + row["lc"] + row["eu"]
        out.append(row)
    return out


def facts(rows: list[dict], key: str) -> dict:
    """そのクラブについて「20クラブの中で」言えること。"""
    me = next(r for r in rows if r["key"] == key)
    by_cap = sorted(rows, key=lambda r: -r["cap"])
    by_old = sorted(rows, key=lambda r: r["year"])
    biggest = by_cap[0]
    return {
        "収容の順位": by_cap.index(me) + 1,
        "一番大きいクラブ": biggest["club"],
        "一番大きいクラブとの倍率": round(biggest["cap"] / me["cap"], 1),
        "古さの順位": by_old.index(me) + 1,
        "優勝ゼロのクラブ数": sum(1 for r in rows if r["all"] == 0),
        "1部優勝ゼロのクラブ数": sum(1 for r in rows if r["lg"] == 0),
        "優勝の合計": me["all"],
        "優勝の合計の順位": sorted(rows, key=lambda r: -r["all"]).index(me) + 1,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--show", action="store_true", help="何が言えるかを並べる")
    ap.add_argument("--club", default="", help="そのクラブについて言えることを出す")
    args = ap.parse_args()
    rows = collect()
    out = DATA / "rank.json"
    out.write_text(json.dumps({"作り方": "各クラブの基礎DATAの板の字から数えた（tools/plrank.py）",
                               "clubs": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    if args.club:
        for k, v in facts(rows, args.club).items():
            print(f"  {k}: {v}")
    elif args.show:
        cap = sorted(rows, key=lambda r: r["cap"])
        old = sorted(rows, key=lambda r: r["year"])
        print(f"収容 最小 {cap[0]['club']} {cap[0]['cap']:,} ／ 最大 {cap[-1]['club']} {cap[-1]['cap']:,}"
              f"（{round(cap[-1]['cap'] / cap[0]['cap'], 1)}倍）")
        print(f"創立 最古 {old[0]['club']} {old[0]['year']} ／ 最新 {old[-1]['club']} {old[-1]['year']}")
        print("優勝が1つも無い: " + "、".join(r["club"] for r in rows if r["all"] == 0))
        print("1部優勝ゼロ: " + str(sum(1 for r in rows if r["lg"] == 0)) + "クラブ")
        print("優勝の合計: " + "、".join(f"{r['club']}{r['all']}"
                                    for r in sorted(rows, key=lambda r: -r["all"])[:5]))
    print(f"→ {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
