"""そのクラブに日本人選手がいたことがあるかを調べる（2026-09-21）。

**このチャンネルの検索流入は、上位5語のうち4語が日本人選手名**（CLAUDE.md）。
20クラブ紹介はプレミアの話なので、日本語で探す人にとっての入口が無い回が多い。
**過去に誰がいたか**なら、いまいなくても入口になる。

英語版Wikipedia のカテゴリを掛け合わせて探す（1クラブ1リクエスト）。

    python tools/pljapan.py               # 20クラブぶん research/pl_data/japan.json へ
    python tools/pljapan.py --club palace

**いない回に無理やり作らない。**見つからなければ「いない」と書いて終わる。
その回の入口は別で作る（ボーンマスは欧州の相手が久保建英のソシエダだった）。
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research" / "pl_data"
# カテゴリ名は記事名から作れない（Hull City A.F.C. → "Hull City A.F.C. players"）ので書く
CLUBS = {
    "arsenal": "Arsenal F.C.", "bournemouth": "AFC Bournemouth", "brentford": "Brentford F.C.",
    "brighton": "Brighton & Hove Albion F.C.", "chelsea": "Chelsea F.C.",
    "coventry": "Coventry City F.C.", "everton": "Everton F.C.",
    "forest": "Nottingham Forest F.C.", "fulham": "Fulham F.C.", "hull": "Hull City A.F.C.",
    "ipswich": "Ipswich Town F.C.", "leeds": "Leeds United F.C.", "liverpool": "Liverpool F.C.",
    "mancity": "Manchester City F.C.", "manutd": "Manchester United F.C.",
    "newcastle": "Newcastle United F.C.", "palace": "Crystal Palace F.C.",
    "sunderland": "Sunderland A.F.C.", "tottenham": "Tottenham Hotspur F.C.",
    "villa": "Aston Villa F.C.",
}


def _session():
    s = requests.Session()
    s.headers["User-Agent"] = "kaigai-soccer-video/1.0 (nami)"
    return s


def _search(session, query: str, tries: int = 5) -> list[str]:
    """**立て続けに叩くと JSON でないものが返る**（src/crest.py と同じ）。待って試し直す。"""
    for attempt in range(tries):
        try:
            r = session.get("https://en.wikipedia.org/w/api.php", params={
                "action": "query", "list": "search", "srsearch": query,
                "srlimit": 50, "srnamespace": 0, "format": "json"}, timeout=40)
            return [x["title"] for x in r.json().get("query", {}).get("search", [])]
        except Exception:
            if attempt == tries - 1:
                raise
            time.sleep(2.5 * (attempt + 1))
    return []


def look(session, club_page: str) -> list[str]:
    return _search(session, f'incategory:"{club_page} players" '
                           f'incategory:"Japanese men\'s footballers"')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--club", default="", help="1クラブだけ調べる")
    args = ap.parse_args()
    out = DATA / "japan.json"
    found = json.loads(out.read_text(encoding="utf-8")) if out.exists() else {}
    session = _session()
    keys = [args.club] if args.club else list(CLUBS)
    for key in keys:
        names = look(session, CLUBS[key])
        found[key] = names
        print(f"{key:12} {'、'.join(names) if names else '— いません'}")
        time.sleep(1.0)
    out.write_text(json.dumps(found, ensure_ascii=False, indent=1), encoding="utf-8")
    empty = [k for k, v in found.items() if not v]
    print(f"→ {out}（日本人のいないクラブ: {len(empty)} / {len(found)}）")
    if empty:
        print("　 " + "、".join(empty))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
