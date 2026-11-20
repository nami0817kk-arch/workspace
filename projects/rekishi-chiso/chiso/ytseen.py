"""他チャンネルでの既出（10-26）：YouTube Data API の検索で、事実の語の上位の本数・再生数を見る。

- 鍵：歴史の地層の OAuth の token（dev/output/rekishi-chiso/secrets/token.json。upload と同じもの）。
  **読み取りだけ**（search.list・videos.list）。token は更新しない（アクセストークンをその場で取り、ファイルには書かない）
- 単位：search.list は1回100、videos.list は50本ごとに1。プロジェクトの枠は1日 10,000（投稿と同じ枠）。
  既定の上限は1回の実行で 1,000 単位（--yt-budget）。使った単位は md と画面に出す
- 判定：上位の動画の題・説明に事実の語が全部出る本数で、3本以上＝すでに多く扱われている／1〜2本＝少し／0本＝まだ扱われていない
- 需要の目安：YouTube の検索候補（suggestqueries、chiso/keywords.py と同じ入口）
"""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

from . import research as R

SEARCH = ("https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults={n}"
          "&regionCode=JP&relevanceLanguage=ja&q={q}")
VIDEOS = "https://www.googleapis.com/youtube/v3/videos?part=statistics&id={ids}"
SUGGEST = "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&hl=ja&q={q}"
SEARCH_UNITS, VIDEOS_UNITS = 100, 1
MANY, FEW = 3, 1


@dataclass
class Seen:
    query: str
    total: int = 0                     # 上位の本数
    matched: int = 0                   # 題・説明に語が全部出る本数
    views: int = 0                     # その本数の再生数の合計
    top: list[tuple[str, str, int]] = field(default_factory=list)   # (題, チャンネル, 再生数)
    error: str = ""

    @property
    def verdict(self) -> str:
        if self.error:
            return "測れなかった"
        if self.matched >= MANY:
            return "すでに多く扱われている"
        if self.matched >= FEW:
            return "少し扱われている"
        return "まだ扱われていない"


class Budget:
    def __init__(self, limit: int):
        self.limit, self.used = limit, 0

    def take(self, n: int) -> bool:
        if self.used + n > self.limit:
            return False
        self.used += n
        return True


def access_token(token_path: Path) -> str:
    """refresh_token からアクセストークンを取る（token.json には書かない。他のセッションの投稿と取り合わない）。"""
    tok = json.loads(token_path.read_text(encoding="utf-8"))
    data = urllib.parse.urlencode({"client_id": tok["client_id"], "client_secret": tok["client_secret"],
                                   "refresh_token": tok["refresh_token"], "grant_type": "refresh_token"}).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", data, timeout=30) as r:
        return json.load(r)["access_token"]


def api_fetcher(token: str):
    def get(url: str) -> str:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "User-Agent": R.UA})
        with urllib.request.urlopen(req, timeout=40) as r:
            return r.read().decode("utf-8")
    return get


def parse_search(text: str) -> list[dict]:
    out = []
    for it in json.loads(text).get("items", []):
        vid = (it.get("id") or {}).get("videoId")
        sn = it.get("snippet") or {}
        if vid:
            out.append({"id": vid, "title": R.html.unescape(sn.get("title", "")),
                        "desc": R.html.unescape(sn.get("description", "")), "channel": sn.get("channelTitle", "")})
    return out


def parse_views(text: str) -> dict[str, int]:
    return {it["id"]: int((it.get("statistics") or {}).get("viewCount", 0)) for it in json.loads(text).get("items", [])}


def seen(query: str, terms: list[str], get, budget: Budget, n: int = 25, cache: dict | None = None) -> Seen:
    """cache（{query: 応答}）にあればそれを使う（同じ日の2回目は単位を使わない）。"""
    s = Seen(query)
    if cache is not None and query in cache:
        return _judge(s, cache[query]["items"], cache[query]["views"], terms)
    if not budget.take(SEARCH_UNITS):
        s.error = "単位の上限（--yt-budget）"
        return s
    try:
        items = parse_search(get(SEARCH.format(n=n, q=urllib.parse.quote(query))))
        views = {}
        if items and budget.take(VIDEOS_UNITS):
            views = parse_views(get(VIDEOS.format(ids=",".join(i["id"] for i in items))))
    except Exception as e:  # noqa: BLE001
        s.error = f"{type(e).__name__} {str(e)[:100]}"
        return s
    if cache is not None:
        cache[query] = {"items": items, "views": views}
    return _judge(s, items, views, terms)


def _judge(s: Seen, items: list[dict], views: dict[str, int], terms: list[str]) -> Seen:
    nt = [R.norm(t) for t in terms]
    s.total = len(items)
    for i in items:
        v = views.get(i["id"], 0)
        if all(t in R.norm(i["title"] + i["desc"]) for t in nt):
            s.matched += 1
            s.views += v
            s.top.append((i["title"], i["channel"], v))
    s.top.sort(key=lambda x: -x[2])
    return s


def load_cache(path: Path, today: str) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data.get("queries", {}) if data.get("date") == today else {}
    except (OSError, ValueError):
        return {}


def save_cache(path: Path, today: str, cache: dict) -> None:
    path.write_text(json.dumps({"date": today, "queries": cache}, ensure_ascii=False), encoding="utf-8")


def suggestions(name: str, fetcher=R.fetch) -> list[str]:
    try:
        data = json.loads(fetcher(SUGGEST.format(q=urllib.parse.quote(name))))
        return [str(x) for x in data[1]]
    except Exception:  # noqa: BLE001
        return []


def demand(topic: str, fetcher=R.fetch) -> dict[str, list[str]]:
    """名前・名前＋空白の検索候補（需要の目安）。"""
    out = {}
    for q in (topic, topic + " "):
        out[q] = suggestions(q, fetcher)
        time.sleep(R.WAIT if fetcher is R.fetch else 0)
    return out
