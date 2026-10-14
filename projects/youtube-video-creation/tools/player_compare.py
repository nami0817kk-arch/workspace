"""有名選手の比較（金曜のシリーズ、10月の案22）の取材メモの雛形。2026-09-28。

    python tools/player_compare.py 342229 418560 --date 2026-10-02   # Transfermarkt の番号を2つ

材料は `player_intro.py` と同じ（Transfermarkt の詳細・市場価値の推移・今季の数字）。
**「どちらが上か」は言い切らない**（CLAUDE.md「10月のシリーズ」）。数字の違いを並べて、見立てで
「何が違うか」を言う。節は「2人の基礎DATA（2列の表）→ 今季の数字（2列、main）→ 市場価値の歩み（2人の
最高額と今）→ 見立て」。顔写真は2枚並べる（`thumbnail.photos`、人が取る）。
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_spec = importlib.util.spec_from_file_location("player_intro", ROOT / "tools" / "player_intro.py")
intro = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(intro)


def data_rows(a: dict, b: dict) -> list[list[str]]:
    """2人の基礎DATAを横に並べる（項目・A・B）。片方でも空の項目は落とす。"""
    def cell(p, key):
        if key == "所属":
            return p["club"]
        if key == "ポジション":
            return p["position"]
        if key == "年齢":
            return f"{p['age']}歳" if p["age"] else ""
        if key == "身長":
            return f"{p['height']}m" if p["height"] else ""
        if key == "利き足":
            return p["foot"]
        if key == "市場価値":
            return intro.compact_value(p["value"]) if p["value"] else ""
        return ""
    rows = []
    for key in ("所属", "ポジション", "年齢", "身長", "利き足", "市場価値"):
        x, y = cell(a, key), cell(b, key)
        if x and y:
            rows.append([key, x, y])
    return rows


def season_rows(a: dict, b: dict) -> list[list[str]]:
    """今季の合計を横に並べる（項目・A・B）。1試合あたりの数字も出す（試合数が違う2人を比べるため）。"""
    ta, tb = intro.totals(a["aggregated"]), intro.totals(b["aggregated"])
    rows = [["試合", str(ta["apps"]), str(tb["apps"])],
            ["得点", str(ta["goals"]), str(tb["goals"])],
            ["アシスト", str(ta["assists"]), str(tb["assists"])],
            ["出場時間", f"{ta['minutes']}分", f"{tb['minutes']}分"]]
    if ta["minutes"] and tb["minutes"]:
        rows.append(["90分あたり得点", f"{ta['goals'] * 90 / ta['minutes']:.2f}", f"{tb['goals'] * 90 / tb['minutes']:.2f}"])
    return rows


def surname(name: str) -> str:
    """サムネに置く短い名前（「・」で区切った最後）。"""
    return name.split("・")[-1] if "・" in name else name


def peak(history: list[dict]) -> tuple[int, int]:
    """市場価値の最高額と、そのときの年齢。"""
    best = max(history, key=lambda e: int((e.get("marketValue") or {}).get("value") or 0), default={})
    return int((best.get("marketValue") or {}).get("value") or 0), int(best.get("age") or 0)


def write_note(a: dict, b: dict, day: datetime.date, path: Path) -> None:
    na, nb = a["ja"] or a["name"], b["ja"] or b["name"]
    urls = ["https://www.transfermarkt.com" + p["url"] for p in (a, b) if p["url"].startswith("/")] or ["https://www.transfermarkt.com/"]
    pa, pb = peak(a["history"]), peak(b["history"])
    ta, tb = intro.totals(a["aggregated"]), intro.totals(b["aggregated"])
    sections = [
        {"id": "data", "heading": "2人の基礎DATA", "tier": "報道", "telop": f"{na}と{nb}", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{na} と {nb}", "columns": ["項目", na, nb], "rows": data_rows(a, b),
                  "source": "Transfermarkt"},
         # 1行は40字まで（6行の表とテロップが重なる）。同じ位置なら1回で言う
         "say": [f"{na}は{a['age']}歳、{a['club']}。", f"{nb}は{b['age']}歳、{b['club']}。"]
                + ([f"2人とも{a['position']}です。"] if a["position"] == b["position"]
                   else [f"位置は{a['position']}と{b['position']}。"])
                + [f"市場価値は{intro.compact_value(a['value'])}と{intro.compact_value(b['value'])}。"],
         "sources": urls},
        {"id": "season", "heading": "今季の数字", "tier": "報道", "main": True, "telop": "今季ここまで", "narrator": "解説",
         "card": {"type": "table", "title": "今季ここまで", "columns": ["項目", na, nb], "rows": season_rows(a, b),
                  "source": "Transfermarkt"},
         "say": [{"text": f"（前置き1行：{na}と{nb}、何を比べるのかを一言で）", "short_only": True},
                 f"{na}は{ta['apps']}試合で{ta['goals']}得点{ta['assists']}アシスト。",
                 f"{nb}は{tb['apps']}試合で{tb['goals']}得点{tb['assists']}アシストです。",
                 "（90分あたりの数字で、試合数の差をならして比べる1行）"],
         "sources": urls},
        {"id": "value", "heading": "市場価値の歩み", "tier": "報道", "telop": "最高額と、いま", "narrator": "解説",
         "card": {"type": "table", "title": "市場価値", "columns": ["", na, nb],
                  "rows": [["最高額", intro.compact_value(pa[0]), intro.compact_value(pb[0])],
                           ["そのときの年齢", f"{pa[1]}歳", f"{pb[1]}歳"],
                           ["いま", intro.compact_value(a["value"]), intro.compact_value(b["value"])]],
                  "source": "Transfermarkt"},
         # 金額は基礎DATAで読んでいるので、ここでは年齢だけ（同じ数字を二度読まない）
         "say": [f"{na}の最高額は{pa[1]}歳のとき。{nb}は{pb[1]}歳のときでした。",
                 "（最高額と今の差を1行。金額は表に任せる）"],
         "sources": urls},
        {"id": "view", "heading": "（何についての見立てか。例：エムバペとの今季の差）", "tier": "背景", "viewpoint": True, "narrator": "解説", "telop": "数字の違いが示すもの",
         "say": [f"（{surname(na)}と{surname(nb)}で何が違うのか。上下は言わず、数字の差を見立てに）"],
         "sources": urls},
    ]
    note = {
        "date": day.strftime("%Y年%m月%d日"),
        "slot": "other_1",
        "format": "news",
        "series": "有名選手の比較",
        "people": [na, nb],
        "theme": {"id": f"compare_{a['id']}_{b['id']}", "league": "england", "kind": "other", "topic": f"{na}と{nb}",
                  "title": f"{na}と{nb}、数字で並べると何が違うのか",
                  "question": f"{na}と{nb}は、数字で並べると何が違うのか",
                  "takeaway": "（2人の数字の違いを1文で。どちらが上かは言わない）"},
        "short_title": f"{na}と{nb}を数字で",
        "thumbnail": {"line1": f"{surname(na)}と{surname(nb)}", "line2": "数字で並べると●●", "tags": [a["club"], b["club"]],
                      "photos": [], "face_link": "VS"},
        "sections": sections,
    }
    head = [f"# {na}（{a['club']}）と{nb}（{b['club']}）の比較。数字は Transfermarkt。",
            "# 顔写真は2枚並べる（thumbnail.photos）。どちらが上かは言い切らない（10月のシリーズの決まり）。"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100),
                    encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    a, b = intro.gather(args.a), intro.gather(args.b)
    path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_compare_{args.a}_{args.b}.yaml"
    write_note(a, b, day, path)
    print(f"取材メモ → {path}")
    for row in data_rows(a, b) + season_rows(a, b):
        print(f"   {row[0]:<10} {row[1]:>16} {row[2]:>16}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
