"""X（旧Twitter）の投稿を扱う。

ここが扱うのは**検索結果から拾った投稿**。タイトルに投稿本文がそのまま
入っているが、長いものは「…Barcel...」で切れる。切れたものは引用に使わない。

投稿URLの数字（Snowflake ID）には**投稿時刻が埋まっている**ので、
ページを開かなくても「いつの投稿か」は分かる。噂の鮮度を測るのに使う。

本文を切れずに取りたいときは xembed.py（認証不要）。
発見まで含めて速さが要るときは xapi.py（有料）。
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from datetime import datetime, timezone

import yaml

from .config import _resolve

# X の ID は「2010-11-04 01:42:54.657 UTC からの経過ミリ秒 << 22」で作られている
EPOCH_MS = 1_288_834_974_657

STATUS_URL = re.compile(r"https?://(?:www\.)?(?:x|twitter)\.com/([^/]+)/status/(\d+)")

# 検索結果のタイトルは「<名前> on X: "<本文>" / X」の形で返ってくる
TITLE = re.compile(r'^(.*?) on X:\s*"(.*)"\s*/\s*X\s*$', re.DOTALL)

# 本文が途中で切れているときの印。ここで切れたものは引用に使わない
TRUNCATED = ("…", "...", "..")


class XPostError(Exception):
    pass


@dataclass
class Post:
    url: str
    handle: str = ""        # URL に入っているアカウント名
    author: str = ""        # 検索結果に出ていた表示名
    text: str = ""
    posted_at: datetime | None = None
    truncated: bool = False

    def hours_ago(self, now: datetime | None = None) -> float | None:
        if self.posted_at is None:
            return None
        now = now or datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        return (now - self.posted_at).total_seconds() / 3600


def parse_url(url: str) -> tuple[str, int]:
    """投稿URLから (アカウント名, 投稿ID) を取り出す。"""
    match = STATUS_URL.search(url or "")
    if not match:
        raise XPostError(f"Xの投稿URLとして読めません: {url}")
    return match.group(1), int(match.group(2))


def posted_at(url_or_id: str | int) -> datetime:
    """投稿URL（かID）から投稿時刻を出す。ページは開かない。"""
    if isinstance(url_or_id, int):
        post_id = url_or_id
    else:
        text = str(url_or_id).strip()
        post_id = int(text) if text.isdigit() else parse_url(text)[1]
    if post_id <= 0:
        raise XPostError(f"IDとして読めません: {url_or_id}")
    return datetime.fromtimestamp(((post_id >> 22) + EPOCH_MS) / 1000, timezone.utc)


def is_post(url: str) -> bool:
    return bool(STATUS_URL.search(url or ""))


def from_search_result(title: str, url: str) -> Post:
    """検索結果の1件（タイトル＋URL）を投稿にする。

    タイトルに本文が入っていないもの（アカウントのトップページなど）もあるので、
    その場合は text を空のまま返す。
    """
    handle = ""
    when = None
    try:
        handle, _ = parse_url(url)
        when = posted_at(url)
    except XPostError:
        pass

    author = ""
    text = ""
    match = TITLE.match((title or "").strip())
    if match:
        author = match.group(1).strip()
        text = match.group(2).strip()

    return Post(
        url=url,
        handle=handle,
        author=author,
        text=text,
        posted_at=when,
        truncated=text.endswith(TRUNCATED),
    )


LEDGER = "research/reporters.yaml"


@dataclass
class Call:
    """記者の投稿を1件、あとで答え合わせするために控えたもの。"""

    handle: str
    url: str
    said: str                    # 何と言っていたか（見出しの範囲で）
    at: datetime
    outcome: str = ""            # 的中 / 外れ / 未判明
    note: str = ""

    def to_dict(self) -> dict:
        return {
            "handle": self.handle,
            "url": self.url,
            "said": self.said,
            "at": self.at.isoformat(timespec="minutes"),
            "outcome": self.outcome or "未判明",
            "note": self.note,
        }


def load_calls(path: str | Path = LEDGER) -> list[Call]:
    target = _resolve(path)
    if not target.exists():
        return []
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    calls: list[Call] = []
    for row in raw.get("calls") or []:
        try:
            calls.append(
                Call(
                    handle=str(row.get("handle", "")).lstrip("@"),
                    url=str(row.get("url", "")),
                    said=str(row.get("said", "")),
                    at=datetime.fromisoformat(str(row.get("at"))),
                    outcome=str(row.get("outcome", "未判明")),
                    note=str(row.get("note", "")),
                )
            )
        except (TypeError, ValueError):
            continue
    return calls


def save_calls(calls: list[Call], path: str | Path = LEDGER) -> Path:
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        "# 記者の投稿の答え合わせ。outcome を 的中 / 外れ に直していく\n"
        + yaml.safe_dump(
            {"calls": [call.to_dict() for call in calls]}, allow_unicode=True, sort_keys=False
        ),
        encoding="utf-8",
    )
    return target


def record_call(url: str, said: str, path: str | Path = LEDGER) -> Call:
    """投稿を控える。判定は後で人が書き込む。"""
    handle, _ = parse_url(url)
    call = Call(handle=handle, url=url, said=said.strip(), at=posted_at(url))

    calls = load_calls(path)
    if not any(existing.url == url for existing in calls):
        calls.append(call)
        save_calls(calls, path)
    return call


def hit_rate(calls: list[Call]) -> dict[str, tuple[int, int, int]]:
    """アカウントごとに (的中, 外れ, 未判明) を数える。"""
    tally: dict[str, list[int]] = {}
    for call in calls:
        row = tally.setdefault(call.handle, [0, 0, 0])
        index = {"的中": 0, "外れ": 1}.get(call.outcome, 2)
        row[index] += 1
    return {handle: tuple(row) for handle, row in tally.items()}


def review_accounts(calls: list[Call], accounts: list[dict]) -> list[str]:
    """実績と、設定に書いた確度が食い違っていないか。"""
    notes: list[str] = []
    for handle, (hit, miss, _) in sorted(hit_rate(calls).items()):
        judged = hit + miss
        if judged < 5:
            continue  # 判定済みが少ないうちは何も言わない
        rate = hit / judged
        entry = trusted(handle, accounts)
        if entry is None:
            notes.append(
                f"@{handle} は accounts に無いのに{judged}件控えています。"
                f"的中 {hit}/{judged}。追うなら登録してください"
            )
        elif rate < 0.5:
            notes.append(
                f"@{handle} の的中は {hit}/{judged}。半分を切っています。"
                "出典に使うのをやめるか、確度を下げてください"
            )
    return notes


def trusted(handle: str, accounts: list[dict]) -> dict | None:
    """設定に登録したアカウントか調べる。大文字小文字は区別しない。"""
    key = (handle or "").lstrip("@").lower()
    for entry in accounts or []:
        if str(entry.get("handle", "")).lstrip("@").lower() == key:
            return dict(entry)
    return None


def review(url: str, accounts: list[dict], stale_hours: int, now=None) -> list[str]:
    """1つの投稿URLについて、気をつける点を並べる。"""
    problems: list[str] = []
    try:
        handle, _ = parse_url(url)
    except XPostError as error:
        return [str(error)]

    entry = trusted(handle, accounts)
    if entry is None:
        problems.append(
            f"@{handle} は登録済みのアカウントではありません。"
            "確度を上げる根拠にはせず、config/sources.yaml の accounts に足すか判断してください"
        )

    age = Post(url=url, posted_at=posted_at(url)).hours_ago(now)
    if age is not None and age > stale_hours:
        problems.append(f"@{handle} の投稿は {age:.0f}時間前のものです（{stale_hours}時間を超過）")
    return problems
