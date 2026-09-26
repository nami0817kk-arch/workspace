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

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402

# リーグは CLUB_LEAGUE で切り替える（2026-09-26）
OUT = clubleague.data_dir()


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


YOUTH = re.compile(r"U-?\d|Under-?\d|Youth|B team|Olympic", re.I)
# **地域の代表は A代表に数えない**（2026-09-26 ラ・リーガ版）。FIFA に属さないので、
# 「バスク代表で1試合」を「有名な選手」の物差しにできない。オヤルサバルは
# いちばん下の行がバスク代表で、スペイン代表の61試合が消えていた
REGIONAL = re.compile(r"Basque|Catalonia|Galicia|Andalusia|Canary|Asturias|Aragon|Valencian|Castile", re.I)
MONTHS = {m: i for i, m in enumerate(["january", "february", "march", "april", "may", "june", "july",
                                       "august", "september", "october", "november", "december"], 1)}


def captain_label(other: str) -> str:
    """`other=[[Captain (association football)|vice-captain]]` の**見える字**を返す。"""
    m = re.search(r"\[\[\s*captain[^\]|]*\|([^\]]+)\]\]", other, re.I)
    return m.group(1).strip().lower() if m else ""


def senior_caps(text: str) -> tuple[str, int | None]:
    """A代表の名前と出場数。**年代別（U-21 など）は飛ばし、いちばん下の行を採る。**"""
    teams, caps = {}, {}
    # **1行に何項目も書く記事がある**（2026-09-26。オヤルサバルは
    # `| nationalyears5 = … | nationalteam5 = … | nationalcaps5 = 61` が1行）。
    # 行頭で縛らず、リンクの `|` を先に潰してから項目で切る
    flat = re.sub(r"\[\[[^\]|]*\|([^\]]*)\]\]", r"[[\1]]", text)
    for m in re.finditer(r"\|\s*nationalteam(\d+)\s*=\s*([^|\n]*)", flat):
        name = re.sub(r"[\[\]']", "", m.group(2))
        name = re.sub(r"\{\{[^}]*\}\}", "", name).strip()
        teams[int(m.group(1))] = name
    for m in re.finditer(r"\|\s*nationalcaps(\d+)\s*=\s*(\d+)", flat):
        caps[int(m.group(1))] = int(m.group(2))
    for n in sorted(teams, reverse=True):
        if teams[n] and not YOUTH.search(teams[n]) and not REGIONAL.search(teams[n]):
            return teams[n], caps.get(n)
    return "", None


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
    # **行末で切らない**（2026-09-20）。フラムの主将の行は
    # `{{Fs player|…|other=[[Captain…|captain]]}}<ref>…` と続いていて、
    # 行末の縛りに引っかかって**その選手ごと落ちていた**（主将が誰も居ない回になる）
    for r in re.findall(r"\{\{(?:[Ff]s|[Ff]ootball squad) player\|"
                        r"([^{}]*(?:\{\{[^{}]*\}\}[^{}]*)*)\}\}", block):
        get = lambda k: (re.search(k + r"=\s*([^|}]+)", r) or [None, ""])[1].strip()
        nm = re.search(r"name=\s*(\[\[[^]]*\]\]|[^|]+)", r).group(1)
        link = re.match(r"\[\[([^]|]*)(?:\|([^]]*))?\]\]", nm)
        title = link.group(1) if link else nm.strip()
        name = re.sub(r"\s*\(.*\)", "", (link.group(2) or link.group(1)) if link else nm.strip())
        page = raw(title)
        m = re.search(r"birth[_ ]date(?: and age)?\s*\|(?:\s*df=\w+\s*\|)?(?:\s*mf=\w+\s*\|)?"
                      r"\s*(\d{4})\s*\|\s*(\d{1,2}|[A-Za-z]+)\s*\|\s*(\d{1,2})", page, re.I)
        # **月を英語の名前で書く記事がある**（2026-09-26。オッリ・オスカルソンは
        # `{{Birth date and age|2004|August|29|df=y}}` で、生年月日が空になっていた）
        month = (m.group(2) if m and m.group(2).isdigit()
                 else str(MONTHS.get(m.group(2).lower(), 0)) if m else "0")
        # **`|` で切ってはいけない**（2026-09-20 に根っこが分かった）。
        # 原文は `other=[[Captain (association football)|vice-captain]]` で、
        # `|` の手前だけ見ると副主将が「Captain」に見える。
        # **リヴァプールで4人が「主将」になったのはこれ。**丸ごと取る
        om = re.search(r"other=\s*(\[\[[^\]]*\]\]|[^|}]+)", r)
        other = om.group(1).strip() if om else ""
        team, caps = senior_caps(page)
        players.append({
            "no": get("no"), "pos": get("pos"), "nat": get("nat"), "name": name,
            "page": title,
            "dob": "%s-%02d-%02d" % (m.group(1), int(month), int(m.group(3))) if m and int(month) else "",
            # **副主将を主将に数えない**（2026-09-19 にリヴァプールで4人が「主将」になった）。
            # 原文は `other=[[Captain (association football)|vice-captain]]` のように書く
            # **見出しの字そのもので決める。**原文は
            # `[[Captain (association football)|captain]]` / `|vice-captain]]` /
            # `|3rd captain]]` / `|4th captain]]` と書き分けてある。
            # 「captain」ちょうどの1人だけが主将
            "captain": captain_label(other) == "captain",
            "loan": "loan" in other.lower(),
            # **「有名な選手」は代表の出場数で決める**（2026-09-20 指示
            # 「各ポジの有名選手、キャプテンを紹介」）。好き嫌いで選ばない
            "team": team, "caps": caps,
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
