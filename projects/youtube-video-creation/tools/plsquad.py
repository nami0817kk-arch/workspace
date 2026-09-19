"""プレミア20クラブの登録選手を英語版 Wikipedia の原文から抜き出す（2026-09-19）。

クラブ記事の「First-team squad」の {{Fs player}} を読み、各選手の記事から
生年月日を取る。**年齢は記事の「◯歳」ではなく生年月日から計算する**
（CLAUDE.md「年齢は生年月日から計算する」）。今季の結果はシーズン記事から。

    python tools/plsquad.py arsenal "Arsenal_F.C." "2026–27_Arsenal_F.C._season"
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "research" / "pl_data"


def raw(title: str) -> str:
    url = ("https://en.wikipedia.org/w/index.php?title="
           + urllib.parse.quote(title.replace(" ", "_")) + "&action=raw")
    # **続けて叩くと弾かれる**（2026-09-19、マンUの27人ぶん生年月日が空で返った）。
    # HTML が返ったら間をあけて取り直す
    for wait in (0, 3, 10, 30):
        time.sleep(wait)
        text = subprocess.run(["curl", "-sL", "-A", "kaigai-soccer-research/1.0 (nami.0817.kk@gmail.com)", url],
                              capture_output=True).stdout.decode("utf-8", "replace")
        if not text.lstrip().startswith("<"):
            break
    if text.lower().startswith("#redirect"):
        target = re.search(r"\[\[([^]|#]*)", text).group(1)
        return raw(target)
    return text


def squad(club_title: str) -> list[dict]:
    text = raw(club_title)
    # 見出しで探す。本文に同じ言葉があると、そこから読み始めて0人になった
    head = re.search(r"^=+[^\n]*(First[- ]team squad|Current squad)[^\n]*=+\s*$", text, re.M)
    start = head.end() if head else 0
    # 次の見出しで止める（「貸し出し中」「U-21」を混ぜない。リヴァプールで42人になった）
    nxt = re.search(r"^=+[^\n]+=+\s*$", text[start:], re.M)
    end = start + nxt.start() if nxt else start + 20000
    block = text[start:end if end > 0 else start + 20000]
    players = []
    for r in re.findall(r"\{\{(?:[Ff]s|[Ff]ootball squad) player\|(.*?)\}\}\s*$", block, re.M):
        get = lambda k: (re.search(k + r"=\s*([^|}]+)", r) or [None, ""])[1].strip()
        nm = re.search(r"name=\s*(\[\[[^]]*\]\]|[^|]+)", r).group(1)
        link = re.match(r"\[\[([^]|]*)(?:\|([^]]*))?\]\]", nm)
        title = link.group(1) if link else nm.strip()
        name = re.sub(r"\s*\(.*\)", "", (link.group(2) or link.group(1)) if link else nm.strip())
        page = raw(title)
        m = re.search(r"birth[_ ]date(?: and age)?\s*\|(?:\s*df=\w+\s*\|)?(?:\s*mf=\w+\s*\|)?"
                      r"\s*(\d{4})\s*\|\s*(\d{1,2})\s*\|\s*(\d{1,2})", page, re.I)
        other = get("other")
        players.append({
            "no": get("no"), "pos": get("pos"), "nat": get("nat"), "name": name,
            "dob": "%s-%02d-%02d" % (m.group(1), int(m.group(2)), int(m.group(3))) if m else "",
            "captain": "aptain" in other, "loan": "loan" in other.lower(),
        })
    return players


def results(season_title: str) -> list[list[str]]:
    text = raw(season_title)
    games = []
    for box in re.findall(r"\{\{\s*[Ff]ootball ?box(?: collapsible)?(.*?)\n\}\}", text, re.S):
        g = lambda k: re.sub(r"\[\[(?:[^]|]*\|)?([^]]*)\]\]", r"\1",
                             re.sub(r"\{\{[^}]*\}\}", "", (re.search(r"\|\s*" + k + r"\s*=\s*(.*)", box) or [None, ""])[1])).strip()
        games.append([g("date"), g("round"), g("team1"), g("score"), g("team2")])
    return games


def main() -> int:
    key, club_title, season_title = sys.argv[1:4]
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"club_title": club_title, "season_title": season_title,
            "squad": squad(club_title), "results": results(season_title)}
    (OUT / f"{key}_raw.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    missing = [p["name"] for p in data["squad"] if not p["dob"]]
    print(f"{key}: {len(data['squad'])}人 / 生年月日なし {missing} / 試合 {len([r for r in data['results'] if r[3]])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
