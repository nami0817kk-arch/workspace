"""ショートの投稿まわり（10-04「明日の11時から1時間ごとに予約」「タグは検索されやすいものに」）。

題名・タグ・概要欄は台本の shorts: に書く（yt_title / tags / lead）。台本の tags: は全ショートに足す共通のタグ。
タグは YouTube の検索候補（suggestqueries の ds=yt）に実際に出る言い方を使う
（「マリーアントワネット」は「・」なしのほうが候補の先頭）。関係のない人気語は入れない。
"""
from __future__ import annotations

from datetime import datetime, timedelta

from . import people

TAGS_CHARS = 480        # YouTube のタグは合計500字まで（区切りも数える）。余裕を残す
HASHTAGS = 3            # 概要欄の頭に3つ（題名の上に出るのは最初の3つ）


def tags(sc, sid: str) -> list[str]:
    """そのショートのタグ＋台本の共通タグ。重複を除き、合計の字数で切る。"""
    meta = sc.shorts[sid]
    out: list[str] = []
    for t in list(meta.get("tags") or []) + list(getattr(sc, "tags", []) or []):
        t = str(t).strip()
        if t and t not in out and sum(len(x) + 1 for x in out) + len(t) <= TAGS_CHARS:
            out.append(t)
    return out


def title(sc, sid: str) -> str:
    meta = sc.shorts[sid]
    return str(meta.get("yt_title") or meta.get("title", "").replace("／", " "))[:100]


def description(sc, config: dict, sid: str, main_id: str | None) -> str:
    meta = sc.shorts[sid]
    lines = sc.short_lines(sid)
    out = [str(meta.get("lead", "")).strip()] if meta.get("lead") else []
    if main_id:
        out += ["", f"▶ 本編（約30分・聞き流し）「{sc.question}」", f"https://youtu.be/{main_id}"]
    out += ["", "■ 音声"]
    used = {l.speaker for l in lines}
    names = [config["cast"][k]["name"] for k in config["cast"]]
    for who in used:
        n = people.roles(config).get(who, {}).get("name")
        if n and n not in names:
            names.append(n)
    out += [f"VOICEVOX:{n}" for n in names]
    out += config.get("character_credits", [])
    out += ["絵：著作権の切れた作品（作者と年は本編の概要欄に）"]
    # 題名の上に出る3つ：そのショートの一番の語 → 共通の語（マリーアントワネット・世界史…）
    cand = list(meta.get("tags") or [])[:1] + list(getattr(sc, "tags", []) or [])
    hashtags = list(dict.fromkeys(t for t in cand if " " not in t and "・" not in t))[:HASHTAGS]
    if hashtags:
        out += ["", " ".join("#" + t for t in hashtags)]
    return "\n".join(out).strip()


def schedule(start: str, every_minutes: int, n: int) -> list[str]:
    """'2026-10-05 11:00' から every 分ごとに n 個の時刻（日本時間の文字列）。"""
    t = datetime.strptime(start, "%Y-%m-%d %H:%M")
    return [(t + timedelta(minutes=every_minutes * k)).strftime("%Y-%m-%d %H:%M") for k in range(n)]
