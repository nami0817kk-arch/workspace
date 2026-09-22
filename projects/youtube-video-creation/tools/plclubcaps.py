"""登録選手の「いまのクラブでの出場数と得点」を控える（2026-09-21）。

ユーザー指示「代表歴以外の情報もほしい」（2026-09-21）。代表歴だけだと
アダム・スミスのように**代表歴が無くてもクラブで350試合**という選手を出せない。

**この数字はリーグ戦だけ**（2026-09-21 に原文で確認。infobox の `capsN`/`goalsN`
はリーグ戦のみで、全公式戦とは違う。フレイザー 183/208、ピットマン 267/301、
アダム・スミス 350/383）。読み上げでは必ず「**リーグ戦で**◯試合」と言う。

    python tools/plclubcaps.py                # 足りないクラブを全部
    python tools/plclubcaps.py --club chelsea

既に `club_caps` が入っている選手は飛ばすので、**途中で止めても続きから走る**。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research" / "pl_data"
KEYS = ("arsenal bournemouth brentford brighton chelsea coventry everton forest "
        "fulham hull ipswich leeds liverpool mancity manutd newcastle palace "
        "sunderland tottenham villa").split()


def _session():
    s = requests.Session()
    s.headers["User-Agent"] = "kaigai-soccer-research/1.0 (nami)"
    return s


def raw(session, title: str, tries: int = 4) -> str:
    for attempt in range(tries):
        try:
            r = session.get("https://en.wikipedia.org/w/index.php",
                            params={"title": title.replace(" ", "_"), "action": "raw"},
                            timeout=40)
            text = r.text
            if text.lstrip().startswith("<"):
                raise ValueError("HTML が返った")
            if text.lower().startswith("#redirect"):
                return raw(session, re.search(r"\[\[([^]|#]*)", text).group(1), tries)
            return text
        except Exception:
            if attempt == tries - 1:
                return ""
            time.sleep(3 * (attempt + 1))
    return ""


def club_record(page: str, club_title: str) -> tuple[int, int]:
    """その選手の infobox から、そのクラブでの**リーグ戦**出場数と得点を足す。

    **在籍が複数回ある選手がいる**（ピットマンは3回。うち1回はレンタル）。
    行が飛び飛びなので、クラブ名で当たった行番号をすべて足す。
    """
    want = re.sub(r"[^a-z0-9]", "", club_title.lower())
    clubs, caps, goals = {}, {}, {}
    for m in re.finditer(r"^\s*\|\s*clubs(\d+)\s*=\s*(.+)$", page, re.M):
        clubs[int(m.group(1))] = m.group(2)
    for m in re.finditer(r"^\s*\|\s*caps(\d+)\s*=\s*(\d+)", page, re.M):
        caps[int(m.group(1))] = int(m.group(2))
    for m in re.finditer(r"^\s*\|\s*goals(\d+)\s*=\s*(\d+)", page, re.M):
        goals[int(m.group(1))] = int(m.group(2))
    total_caps = total_goals = 0
    for n, value in clubs.items():
        flat = re.sub(r"[^a-z0-9]", "", value.lower())
        if want and want in flat:
            total_caps += caps.get(n, 0)
            total_goals += goals.get(n, 0)
    return total_caps, total_goals


def fill(session, key: str) -> tuple[int, int]:
    path = DATA / f"{key}_raw.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    club = data["club_title"]
    done = todo = 0
    for p in data["squad"]:
        if p.get("club_caps") is not None:
            done += 1
            continue
        page = raw(session, p.get("page") or p["name"])
        if not page:
            print(f"  ！ {p['name']} の記事を取れませんでした")
            continue
        c, g = club_record(page, club)
        p["club_caps"], p["club_goals"] = c, g
        todo += 1
        time.sleep(0.4)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return done, todo


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--club", default="")
    args = ap.parse_args()
    session = _session()
    for key in ([args.club] if args.club else KEYS):
        try:
            done, todo = fill(session, key)
        except Exception as e:
            print(f"{key:12} ■ {e}", file=sys.stderr)
            continue
        print(f"{key:12} 新しく調べた {todo}人 / もとからあった {done}人", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
