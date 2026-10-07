"""再生リストと英語の題名・説明（10-08 ユーザー指示）。

- 再生リスト：台本の `playlists:`（省けば `series:`）に本編を、`shorts_playlists:` にショートを入れる。
  無いリストは作る（公開）。説明は playlists.yaml（無ければ決まった文）。投稿済みは `playlists --sync` で後から。
- 英語：台本の `en: {title, description, chapters}`。日本語を既定の言語にして localizations.en に載せる。
  章の時刻は日本語の概要欄の「■ 目次」から取り、英語の章の題を付ける。クレジットは日本語のまま写す
  （VOICEVOX の規約でクレジットが要る。英語で見る人の概要欄は英語の説明だけになるので）。

API の枠（YouTube Data API は1日 10,000 単位・無料）：
    playlists.insert 50 ／ playlistItems.insert 50 ／ videos.update 50 ／ 一覧（list）は1回 1
    （参考：videos.insert 1,600・captions.insert 400・thumbnails.set 50）
書き込みには youtube か youtube.force-ssl の許可が要る（upload.service(need_manage=True) で確かめる）。
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

COST = {"list": 1, "playlists.insert": 50, "playlistItems.insert": 50, "videos.update": 50}
PRIVACY = "public"
CHANNEL = "歴史の地層"
DEFAULT_DESC = ("「{name}」の回をまとめた再生リストです。\n"
                "歴史の地層｜日本史・世界史を聞き流し（運営：つるはし社）")
CREDIT_HEADS = ("■ 音声", "■ 画面の絵", "■ 絵の出典")
CLOCK = re.compile(r"^((?:\d+:)?\d{1,2}:\d{2})\s")
DESC_MAX = 5000


# --- 計画（API を使わない） ----------------------------------------------

@dataclass
class Plan:
    """どのリストにどの動画を入れるか（入れる順）。"""
    lists: dict[str, list[tuple[str, str]]] = field(default_factory=dict)   # 名前 → [(控えの key, video_id)]

    def add(self, name: str, key: str, vid: str) -> None:
        items = self.lists.setdefault(name, [])
        if vid not in [v for _, v in items]:
            items.append((key, vid))

    def max_units(self, existing: set[str] = frozenset()) -> int:
        """全部を入れたときの最大の単位（入っているものは実際には飛ばす）。"""
        new_lists = sum(1 for n in self.lists if n not in existing)
        items = sum(len(v) for v in self.lists.values())
        return new_lists * COST["playlists.insert"] + items * COST["playlistItems.insert"]


def plan(scripts: dict, posted: list[dict], only: str = "") -> Plan:
    """scripts は 台本の名前（stem）→ Script。posted.json の順（投稿した順）に並べる。"""
    p = Plan()
    for e in posted:
        key = str(e.get("key", ""))
        stem, _, kind = key.partition(":")
        sc = scripts.get(stem)
        if sc is None or (only and stem != only) or not e.get("video_id"):
            continue
        names = sc.playlists if kind == "main" else sc.shorts_playlists if kind.startswith("short:") else []
        for name in names:
            p.add(name, key, str(e["video_id"]))
    # 本編はリストの中で公開の順に（posted.json の publish_at）
    when = {str(e.get("video_id")): str(e.get("publish_at", "")) for e in posted}
    for name, items in p.lists.items():
        items.sort(key=lambda kv: when.get(kv[1], ""))
    return p


def load_descriptions(path: Path) -> dict[str, dict]:
    """playlists.yaml：名前 → {description, privacy}。"""
    if not path.exists():
        return {}
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return {str(k): dict(v or {}) for k, v in data.items()}


def playlist_body(name: str, meta: dict | None = None) -> dict:
    meta = meta or {}
    desc = str(meta.get("description") or DEFAULT_DESC.format(name=name)).strip()
    privacy = str(meta.get("privacy") or PRIVACY)
    if privacy not in ("public", "unlisted", "private"):
        raise ValueError(f"再生リストの公開設定が違います: {name}: {privacy}")
    return {"snippet": {"title": name[:150], "description": desc[:5000], "defaultLanguage": "ja"},
            "status": {"privacyStatus": privacy}}


# --- 再生リスト（API） ----------------------------------------------------

class Budget:
    """1回の実行で使ってよい単位。超えそうなら書き込む前に止める（次の日にもう一度打てば続きから）。"""

    def __init__(self, limit: int):
        self.limit, self.used = limit, 0

    def spend(self, what: str) -> bool:
        cost = COST.get(what, 1)
        if self.used + cost > self.limit:
            return False
        self.used += cost
        return True


def _pages(call, budget: Budget, **kw):
    token = None
    while True:
        budget.used += COST["list"]                # 読むだけ（1単位）は上限に届いても止めない
        got = call(**kw, maxResults=50, **({"pageToken": token} if token else {})).execute()
        yield from got.get("items") or []
        token = got.get("nextPageToken")
        if not token:
            return


def my_playlists(svc, budget: Budget) -> dict[str, str]:
    """自分のチャンネルの再生リスト：題名 → id。"""
    return {it["snippet"]["title"]: it["id"]
            for it in _pages(svc.playlists().list, budget, part="snippet", mine=True)}


def playlist_videos(svc, pid: str, budget: Budget) -> set[str]:
    return {it["snippet"]["resourceId"]["videoId"]
            for it in _pages(svc.playlistItems().list, budget, part="snippet", playlistId=pid)}


def sync(svc, p: Plan, descriptions: dict[str, dict], budget: Budget, log=print) -> dict:
    """計画どおりにリストを作り、入っていない動画を足す。何度打っても同じ（入っているものは飛ばす）。"""
    report = {"created": [], "added": [], "skipped": 0, "stopped": False}
    have = my_playlists(svc, budget)
    for name, items in p.lists.items():
        pid = have.get(name)
        if pid is None:
            if not budget.spend("playlists.insert"):
                report["stopped"] = True
                break
            pid = svc.playlists().insert(part="snippet,status",
                                         body=playlist_body(name, descriptions.get(name))).execute()["id"]
            have[name] = pid
            report["created"].append(name)
            log(f"＋ 再生リストを作りました: {name}（https://www.youtube.com/playlist?list={pid}）")
            inside: set[str] = set()
        else:
            inside = playlist_videos(svc, pid, budget)
        for key, vid in items:
            if vid in inside:
                report["skipped"] += 1
                continue
            if not budget.spend("playlistItems.insert"):
                report["stopped"] = True
                break
            svc.playlistItems().insert(part="snippet", body={"snippet": {
                "playlistId": pid, "resourceId": {"kind": "youtube#video", "videoId": vid}}}).execute()
            inside.add(vid)
            report["added"].append((name, key, vid))
            log(f"  {name} ← {key}（https://youtu.be/{vid}）")
        if report["stopped"]:
            break
    if report["stopped"]:
        log(f"! 今回の上限（{budget.limit} 単位）に届いたので止めました。もう一度打てば続きから入れます")
    return report


# --- 英語の題名と説明 ----------------------------------------------------

def _blocks(text: str) -> list[list[str]]:
    out, cur = [], []
    for line in text.splitlines():
        if line.strip():
            cur.append(line.rstrip())
        elif cur:
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    return out


def chapter_times(ja_description: str) -> list[str]:
    """日本語の概要欄の「■ 目次」の時刻（0:00 から順に）。"""
    for b in _blocks(ja_description):
        if b[0].startswith("■ 目次"):
            return [m.group(1) for m in (CLOCK.match(x) for x in b[1:]) if m]
    return []


def en_description(en: dict, ja_description: str) -> str:
    """英語の説明＋章（時刻は日本語の目次から）＋クレジット（日本語の概要欄から写す）。"""
    out = [en.get("description", "").strip()] if en.get("description") else []
    chapters = en.get("chapters") or []
    if chapters:
        times = chapter_times(ja_description)
        if len(times) != len(chapters):
            raise ValueError(f"日本語の目次の章の数（{len(times)}）と en.chapters（{len(chapters)}）が合いません")
        out += ["", "Chapters"] + [f"{t} {c}" for t, c in zip(times, chapters)]
    credits = [b for b in _blocks(ja_description) if b[0].startswith(CREDIT_HEADS)]
    if credits:
        out += ["", "Credits"]
        for i, b in enumerate(credits):
            out += ([""] if i else []) + b
    op = [x for b in _blocks(ja_description) for x in b if x.startswith("運営：")]
    out += [""] + (op[-1:] if op else []) + [f"{CHANNEL} (Rekishi no Chiso)"]
    text = "\n".join(out).strip() + "\n"
    if len(text) > DESC_MAX:
        raise ValueError(f"英語の説明が {DESC_MAX} 字を超えます（{len(text)}字）。description か画面の絵の欄を短く")
    return text


def localizations(en: dict, ja_description: str) -> dict:
    return {"en": {"title": en["title"][:100], "description": en_description(en, ja_description)}}


_READ_ONLY = ("publishedAt", "channelId", "thumbnails", "channelTitle", "liveBroadcastContent", "localized")


def localized_body(current: dict, loc: dict) -> dict:
    """videos.list の結果から videos.update の body を作る。snippet は全部送り直す
    （送らない欄は消える：説明・タグ・カテゴリ）。既にある他の言語の localizations は残す。"""
    sn = {k: v for k, v in current["snippet"].items() if k not in _READ_ONLY}
    sn["defaultLanguage"] = "ja"
    merged = dict(current.get("localizations") or {})
    merged.update(loc)
    return {"id": current["id"], "snippet": sn, "localizations": merged}


def localize(svc, vid: str, en: dict, dry_run: bool = False, log=print) -> dict:
    """投稿済みの動画に英語の題名と説明を付ける（videos.list 1 ＋ videos.update 50）。"""
    got = svc.videos().list(part="snippet,localizations", id=vid).execute().get("items") or []
    if not got:
        raise ValueError(f"動画が見つかりません: {vid}（自分のチャンネルの動画か、消していないか）")
    current = got[0]
    body = localized_body(current, localizations(en, current["snippet"].get("description", "")))
    if dry_run:
        log("（--dry-run：書き込みません）")
    else:
        svc.videos().update(part="snippet,localizations", body=body).execute()
    return body
