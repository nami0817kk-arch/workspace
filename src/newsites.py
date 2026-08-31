"""網に無いサイトを控えて、足す候補を挙げる。

検索は網の外のサイトも返す。今までは「網に無い」と言うだけで捨てていたが、
何度も出てくるサイトは、たいてい足すべきサイトである。
逆に1回きりのサイトを足すと、網が薄まるだけで意味がない。

何回出てきたかを数えておき、繰り返し出るものだけを挙げる。
足すかどうかは人が決める（そのサイトが信用できるかは、機械には分からない）。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import yaml

from .config import _resolve

LEDGER = "research/newsites.yaml"
# これだけ別々の日に出てきたら、足す候補として挙げる
MIN_DAYS = 2
# 例として控えておくURLの数。多くても判断は変わらない
KEEP_EXAMPLES = 3


@dataclass
class Site:
    host: str
    seen: int = 0                                   # 出てきた回数
    days: list[str] = field(default_factory=list)   # 出てきた日（重複なし）
    examples: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "host": self.host,
            "seen": self.seen,
            "days": self.days,
            "examples": self.examples,
        }


def load(path: str | Path = LEDGER) -> list[Site]:
    target = _resolve(path)
    if not target.exists():
        return []
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    found: list[Site] = []
    for row in raw.get("sites") or []:
        host = str((row or {}).get("host", "")).strip()
        if not host:
            continue
        found.append(
            Site(
                host=host,
                seen=int(row.get("seen", 0)),
                days=[str(d) for d in (row.get("days") or [])],
                examples=[str(u) for u in (row.get("examples") or [])],
            )
        )
    return found


def save(sites: list[Site], path: str | Path = LEDGER) -> Path:
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    body = {"sites": [s.to_dict() for s in sorted(sites, key=lambda s: -s.seen)]}
    target.write_text(
        "# 網に無いサイトの控え。collect が自動で足す。\n"
        "# 繰り返し出るものは config/sources.yaml に足す候補。\n"
        "#   python -m src.cli sources --new\n"
        + yaml.safe_dump(body, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return target


def host_of(url: str) -> str:
    """URLのホスト。www. は落として数える。"""
    text = str(url or "").strip()
    text = text.split("//", 1)[-1].split("/", 1)[0].split("?", 1)[0]
    return text[4:] if text.startswith("www.") else text


def unknown(urls: list[str], plan) -> list[str]:
    """網にも blocked にも無いホスト。控える対象。"""
    found: list[str] = []
    for url in urls:
        if not url or plan.group_of(url) or plan.is_blocked(url):
            continue
        host = host_of(url)
        if host and host not in found:
            found.append(host)
    return found


def record(urls: list[str], plan, today: date | None = None,
           path: str | Path = LEDGER) -> list[str]:
    """網に無いホストを控える。控えたホストを返す。"""
    hosts = unknown(urls, plan)
    if not hosts:
        return []

    stamp = (today or date.today()).isoformat()
    sites = {site.host: site for site in load(path)}
    example_of = {host_of(u): u for u in reversed(urls)}

    for host in hosts:
        site = sites.setdefault(host, Site(host=host))
        site.seen += 1
        if stamp not in site.days:
            site.days.append(stamp)
        sample = example_of.get(host, "")
        if sample and sample not in site.examples and len(site.examples) < KEEP_EXAMPLES:
            site.examples.append(sample)

    save(list(sites.values()), path)
    return hosts


def propose(sites: list[Site], min_days: int = MIN_DAYS) -> list[Site]:
    """足す候補。1回きりのサイトは挙げない。

    別々の日に出てきた回数で見る。1日のうちに同じサイトが5回出るのは
    「その日そのサイトが当たっただけ」で、網に足す理由にはならない。
    """
    return sorted(
        (site for site in sites if len(site.days) >= min_days),
        key=lambda site: (-len(site.days), -site.seen, site.host),
    )
