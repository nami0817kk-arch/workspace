"""記事の本文から、台本の材料（発言・数字）を抜き出す（2026-09-08）。

ユーザー「題材は見劣りしないが、中身のボリュームで負けている」。
検索は見出しとURLしか取っておらず、本文・数字・発言は人が開いて読んだ分しか
入っていなかった。今日の18本の中央値は他人の声4件・数字の行7。参考（サッカーラボ
25.5万回）は反応約15件、冒頭30秒に数字4つ。

**許可サイト（config/sources.yaml の domains）の記事しか読まない。**
抜き出すのは「」“”の発言と、数字を含む文。要約はしない。出典URLを必ず添える。
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

import requests

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) youtube-video-creation/1.0"
TIMEOUT = 25
MAX_QUOTES = 12
MAX_NUMBERS = 12
MAX_BYTES = 3_000_000


class MaterialError(RuntimeError):
    pass


@dataclass
class Material:
    url: str
    outlet: str
    title: str = ""
    quotes: list[str] = field(default_factory=list)
    numbers: list[str] = field(default_factory=list)
    lead: list[str] = field(default_factory=list)
    note: str = ""


def allowed_hosts(plan_domains: dict) -> set[str]:
    """domains の群を平らにする。blocked は除く。"""
    hosts: set[str] = set()
    for group, names in (plan_domains or {}).items():
        if group == "blocked" or not isinstance(names, list):
            continue
        hosts.update(str(n).lower() for n in names)
    return hosts


def is_allowed(url: str, hosts: set[str]) -> bool:
    host = urlparse(url).netloc.lower()
    return any(host == h or host.endswith("." + h) for h in hosts)


def fetch_html(url: str, session=None) -> str:
    client = session or requests
    resp = client.get(url, headers={"User-Agent": UA}, timeout=TIMEOUT)
    resp.raise_for_status()
    if resp.encoding in (None, "ISO-8859-1"):
        resp.encoding = resp.apparent_encoding
    return resp.text[:MAX_BYTES]


_TAG = re.compile(r"<[^>]+>")
_DROP = re.compile(r"<(script|style|noscript|svg|nav|footer|header|aside)[^>]*>.*?</\1>",
                   re.S | re.I)
_PARA = re.compile(r"<p[^>]*>(.*?)</p>", re.S | re.I)
_ARTICLE = re.compile(r"<article[^>]*>(.*?)</article>", re.S | re.I)
_TITLE = re.compile(r"<title[^>]*>(.*?)</title>", re.S | re.I)


def to_text(page: str) -> tuple[str, list[str]]:
    """題名と、本文らしい段落の並び。段落は <p> から取る。"""
    title = ""
    found = _TITLE.search(page)
    if found:
        title = html.unescape(_TAG.sub("", found.group(1))).strip()
    body = _DROP.sub(" ", page)
    # **記事の枠があればその中だけ読む。**Yahoo は関連記事の見出しも <p> で並べる
    # ので、ページ全体から拾うと他の記事の発言が混ざる（2026-09-08 実測:
    # 久保の記事に「ほぼヤマルやん」が入った）。<article> が複数あれば <p> の多いもの
    articles = _ARTICLE.findall(body)
    if articles:
        body = max(articles, key=lambda a: len(_PARA.findall(a)))
    paragraphs: list[str] = []
    for chunk in _PARA.findall(body):
        text = html.unescape(_TAG.sub("", chunk))
        text = re.sub(r"\s+", " ", text).strip()
        # 短い段落はメニューや注記。発言1つの段落は短いことがあるので12字から拾う
        if len(text) >= 12:
            paragraphs.append(text)
    return title, paragraphs


_QUOTE = re.compile(r"[「“\"]([^「」“”\"]{6,120})[」”\"]")
_SENT = re.compile(r"[^。．.!?！？]+[。．.!?！？]?")


def extract(paragraphs: list[str]) -> tuple[list[str], list[str]]:
    """発言（かぎ括弧の中）と、数字を含む文。"""
    quotes: list[str] = []
    numbers: list[str] = []
    for para in paragraphs:
        for q in _QUOTE.findall(para):
            q = q.strip()
            if q not in quotes:
                quotes.append(q)
        for sent in _SENT.findall(para):
            sent = sent.strip()
            if len(sent) < 12 or len(sent) > 140:
                continue
            if re.search(r"[0-9０-９]", sent) and sent not in numbers:
                numbers.append(sent)
    return quotes[:MAX_QUOTES], numbers[:MAX_NUMBERS]


def gather(urls: list[str], hosts: set[str], session=None) -> list[Material]:
    """出典の並びから材料を集める。読めないものは note に理由を残して続ける。"""
    out: list[Material] = []
    for url in urls:
        outlet = urlparse(url).netloc
        item = Material(url=url, outlet=outlet)
        if not is_allowed(url, hosts):
            item.note = "許可サイトではありません"
            out.append(item)
            continue
        try:
            page = fetch_html(url, session)
        except Exception as exc:  # noqa: BLE001 - 1本読めなくても他は続ける
            item.note = f"読めません: {str(exc)[:60]}"
            out.append(item)
            continue
        title, paragraphs = to_text(page)
        item.title = title
        item.lead = paragraphs[:3]
        item.quotes, item.numbers = extract(paragraphs)
        if not paragraphs:
            item.note = "本文が取れません（<p> が無い作り）"
        out.append(item)
    return out


def render(items: list[Material], heading: str = "") -> str:
    """取材メモの横に置く材料の Markdown。出典ごとに発言と数字を並べる。"""
    lines: list[str] = []
    if heading:
        lines += [f"# 材料: {heading}", ""]
    lines += ["**引用は出典の確度のまま。**要約ではなく本文の文をそのまま置いている。", ""]
    for item in items:
        lines += [f"## {item.outlet}", f"- {item.url}"]
        if item.title:
            lines.append(f"- 題名: {item.title}")
        if item.note:
            lines += [f"- {item.note}", ""]
            continue
        if item.quotes:
            lines.append("- 発言:")
            lines += [f"  - 「{q}」" for q in item.quotes]
        if item.numbers:
            lines.append("- 数字:")
            lines += [f"  - {n}" for n in item.numbers]
        if item.lead:
            lines.append("- 冒頭:")
            lines += [f"  - {p[:160]}" for p in item.lead]
        lines.append("")
    return "\n".join(lines).replace("\n", chr(10))


def note_sources(note_path: Path) -> tuple[str, list[str]]:
    """取材メモの出典URLを、書いてある順で重複なく返す。"""
    import yaml

    raw = yaml.safe_load(Path(note_path).read_text(encoding="utf-8")) or {}
    seen: list[str] = []
    for section in raw.get("sections") or []:
        for url in (section or {}).get("sources") or []:
            url = str(url).strip()
            if url and url not in seen:
                seen.append(url)
    title = str((raw.get("theme") or {}).get("title") or "")
    return title, seen
