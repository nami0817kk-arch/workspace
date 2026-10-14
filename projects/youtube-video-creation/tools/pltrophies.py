"""優勝回数の板の材料（`trophies`）を、基礎DATAの板の字から起こす（2026-09-21）。

**きっかけは誤り。**ボーンマスを「タイトルは1つもありません」と読み上げていたが、
1983-84 に EFLトロフィー、1986-87 に3部優勝を獲っていた。

**Honours 節を機械で読む案は捨てた。**節の組み方がクラブごとに揃っておらず、
リヴァプール・マンチェスター・ユナイテッド・チェルシー・アーセナル・エヴァートンが
**そろって0回**になった（2026-09-21 に実測）。**間違った数字を板に出すくらいなら、
数えられる範囲だけ出す。**

だから材料は `<key>.json` の「タイトル歴」のタイル（下請けが原文から調べて書いた字。
20クラブぶんそろっていて、板として一度ユーザーに見せている）。
読める4つ——**1部リーグ・FAカップ・リーグカップ・ヨーロッパ**——だけを段にする。

    python tools/pltrophies.py --show
    python tools/pltrophies.py --write

**下部リーグの優勝と EFLトロフィーは、この4つに入っていない。**
足すときは Honours 節を人が見て、`<key>.json` の `trophies` に手で書く
（ボーンマスはそうした）。**「タイトルゼロ」と読み上げてよいのは、
この4つがゼロという意味だけ**で、クラブの優勝が0という意味ではない。
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
# 小さい字は「・」で区切って、**かたまりごとに**どの大会か決める。
# 語で拾うと壊れた（2026-09-21 実測）:
#   「欧州(UEFA杯)1」の中の "FA杯" を FAカップに数えて、イプスウィッチが2回になった
#   「欧州杯1・EL1」は最初の語で打ち切って、ヴィラの欧州が1回になった（正しくは2）
HEADS = (("FAカップ", ("FA杯",)),
         ("リーグカップ", ("リーグ杯",)),
         # **「ヨーロッパ合計」にした**（2026-09-21）。リヴァプールの読み上げは
         # 「チャンピオンズリーグは6回」だが、この段は UEFA杯3回も足した9。
         # 段の名前が「ヨーロッパ」のままだと、板と声が食い違って見える
         ("ヨーロッパ合計", ("欧州", "CL", "EL", "UEFA")))


def _rows_from(small: str) -> dict[str, int]:
    got = {name: 0 for name, _ in HEADS}
    # 「FA杯2。リーグ杯・欧州の優勝は無し」（サンダーランド）は
    # 「。」でも切らないと FA杯2 が落ちる
    for chunk in re.split(r"[・、。]", small):
        chunk = chunk.strip()
        num = re.search(r"(\d+)\s*$", chunk)
        if not num:
            continue                       # 「リーグ杯・欧州の優勝は無し」のような書き方
        for name, heads in HEADS:
            if any(chunk.startswith(h) for h in heads):
                got[name] += int(num.group(1))
                break
    return got


def from_tiles(key: str) -> list[list]:
    spec = json.loads((DATA / f"{key}.json").read_text(encoding="utf-8"))
    tile = next(t for t in spec["tiles"] if str(t[0]).startswith("タイトル歴"))
    rows = [["1部リーグ", int(re.search(r"(\d+)回", tile[1]).group(1))]]
    got = _rows_from(tile[2])
    rows += [[name, got[name]] for name, _ in HEADS]
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--show", action="store_true")
    ap.add_argument("--write", action="store_true", help="trophies が無いクラブにだけ書く")
    ap.add_argument("--force", action="store_true", help="手で直したものも上書きする")
    args = ap.parse_args()
    for key in KEYS:
        path = DATA / f"{key}.json"
        spec = json.loads(path.read_text(encoding="utf-8"))
        rows = from_tiles(key)
        line = "／".join(f"{n}{c}" for n, c in rows)
        # **手で足した段（下部リーグ・EFLトロフィー）は上書きしない**
        if spec.get("trophies") and (not args.force or len(spec["trophies"]) > 4):
            have = "／".join(f"{n}{c}" for n, c in spec["trophies"])
            print(f"{key:12} 既にあり（触らない）: {have}")
            continue
        print(f"{key:12} {line}")
        if args.write:
            spec["trophies"] = rows
            path.write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
