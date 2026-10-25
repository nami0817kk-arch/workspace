"""事実カード（fact sheet、10-26）：research の結果から、事実1つごとに出どころ・本文の該当箇所・独立した出どころの数・
知らない度・他チャンネルでの既出を持つ YAML を作る。

    python -m chiso.cli research 伊達政宗 --slug masamune --cards \
        --fact "1974年に瑞鳳殿の墓を発掘した::1974 発掘" --fact "隻眼の肖像（土佐光貞筆）::土佐光貞" \
        [--pdf <人が開いた PDF の URL>] [--cards-in agents.yaml] [--yt] [--plan] [--chain]

出力：research/<題>_facts_YYYYMMDD.yaml（と md の「6. 事実カード」）。台本の行は `# fact: masamune-03` でつなぐ（chiso/factcheck.py）。

本文を道具が開くもの（どれも登録・鍵なし）：
- NDL デジタルの公開本（lab.ndl.go.jp の fulltext-json。頁ごとの OCR）。事実の一番長い語で全文を引き、当たった本を開く
- Wikisource の翻刻（API の wikitext）
- 人が開いた PDF の URL（--pdf。全国遺跡報告総覧・J-STAGE の PDF など。**道具は PDF を探しに行かない**：
  J-STAGE は robots.txt が /_pdf を断り、遺跡報告総覧は検索を断る）
- J-STAGE の記事の頁（HTML）は要旨だけ（「要旨」として数え、本文には数えない）
- Internet Archive の全文検索の抜き出し（「抜き出し」。貸出の本は頁を開けない）
「開いた」の段：本文（道具が本文を取って該当箇所を抜いた）／要旨／抜き出し（入口が返した本文の一部）／書誌（題だけ）。

独立した出どころ：本文・抜き出し・要旨で語が近くに出た資料を、題（巻次を除く）でまとめて数える。Wikipedia・まとめは数えない。
1つだけなら single_source: true（台本では「と伝わる」と言うか、もう1つ探す）。
"""
from __future__ import annotations

import datetime as _dt
import io
import json
import re
import subprocess
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import research as R

WINDOW = 150          # 語がこの字数の中に全部出たら「近くに出た」
QUOTE = 70            # 引用の字数（短く）
MAX_BOOKS = 20        # 1回で開く NDL の本の数
MAX_WS = 8            # 1回で開く Wikisource の頁の数
MAX_EVIDENCE = 8      # 1つの事実に並べる出どころの数
OPENED_RANK = {"本文": 0, "抜き出し": 1, "要旨": 2, "書誌": 3}
COUNTED = ("本文", "抜き出し", "要旨")
WS_TEXT = ("https://{lang}.wikisource.org/w/api.php?action=parse&page={q}&prop=wikitext&format=json&formatversion=2")


@dataclass
class FactSpec:
    id: str
    claim: str
    terms: list[str]
    en_terms: list[str] = field(default_factory=list)


@dataclass
class Evidence:
    title: str
    url: str
    entry: str
    tier: str
    opened: str                    # 本文／抜き出し／要旨／書誌
    quote: str = ""
    page: int | str | None = None
    year: int | None = None
    who: str = ""
    by: str = "道具"               # 道具／Agent（WebFetch）／Chrome

    @property
    def work(self) -> str:
        t = R.norm(self.title)
        t = re.sub(r"[:：].*$", "", t)
        return re.sub(r"(第?[0-9０-９一二三四五六七八九十]+[巻卷輯号冊編]?|[上中下]|vol\.?\d+)$", "", t, flags=re.I)


@dataclass
class Card:
    spec: FactSpec
    evidence: list[Evidence] = field(default_factory=list)
    wikipedia: str = ""
    dictionaries: list[str] = field(default_factory=list)
    youtube: dict = field(default_factory=dict)

    @property
    def independent(self) -> int:
        return len({e.work for e in self.evidence if e.opened in COUNTED and e.tier != "まとめ記事"})

    @property
    def opened_body(self) -> bool:
        return any(e.opened == "本文" for e in self.evidence)

    @property
    def unknown(self) -> str:
        if self.wikipedia.startswith("誰でも") or len(self.dictionaries) >= 3:
            return "低"
        if self.wikipedia.startswith("知る人") or self.dictionaries:
            return "中"
        return "高"


def parse_spec(spec: str, slug: str, n: int) -> FactSpec:
    """'主張::語 語' か '主張::語 語::English words'。id は <slug>-NN。"""
    parts = spec.split("::")
    claim = parts[0].strip()
    terms = [t for t in re.split(r"[\s　]+", (parts[1] if len(parts) > 1 else parts[0]).strip()) if t]
    en = [t for t in re.split(r"\s+", parts[2].strip()) if t] if len(parts) > 2 else []
    return FactSpec(f"{slug}-{n:02d}", claim, terms, en)


# --- 本文の中で語を探す ----------------------------------------------------------------------------------------

_KD = str.maketrans("〇一二三四五六七八九", "0123456789")


def mnorm(s: str) -> str:
    """照らし合わせ用：research.norm に加えて、2字以上続く漢数字（一九七四）を算用数字に（OCR の本は漢数字が多い）。"""
    return re.sub(r"[〇一二三四五六七八九]{2,}", lambda m: m.group(0).translate(_KD), R.norm(s))


def find_window(text: str, terms: list[str], width: int = WINDOW) -> int:
    """語が全部 width 字の中に出る位置（最初の語の位置）。無ければ -1。text・terms は norm 済み。"""
    if not terms or not all(t in text for t in terms):
        return -1
    first = min(terms, key=lambda t: text.count(t))
    start = 0
    while True:
        i = text.find(first, start)
        if i < 0:
            return -1
        lo, hi = max(0, i - width), i + len(first) + width
        if all(t in text[lo:hi] for t in terms):
            return i
        start = i + 1


def quote_at(text: str, i: int, n: int = QUOTE) -> str:
    lo = max(0, i - n // 2)
    return ("…" if lo else "") + text[lo: lo + n] + ("…" if lo + n < len(text) else "")


def match_pages(pages: list[tuple[int | None, str]], terms: list[str], anchor: list[str]) -> tuple[int | None, str] | None:
    """頁ごとに語を探す。anchor（主題の名前）が同じ頁に無い当たりは落とす（別人の話を拾わない）。"""
    nt = [mnorm(t) for t in terms]
    na = [mnorm(a) for a in anchor if a]
    for page, text in pages:
        t = mnorm(text)
        if na and not any(a in t for a in na):
            continue
        i = find_window(t, nt)
        if i >= 0:
            return page, quote_at(t, i)
    return None


# --- 本文を取る ------------------------------------------------------------------------------------------------

def pid_of(src: R.Source) -> str:
    for s in (src.url, src.note):
        m = re.search(r"dl\.ndl\.go\.jp/pid/(\d+)", s or "")
        if m:
            return m.group(1)
    return ""


def pdf_pages(data: bytes) -> list[tuple[int, str]]:
    """PDF の頁ごとの文字。pypdf があれば使い、無ければ pdftotext。どちらも無ければ空。"""
    try:
        import pypdf
        rd = pypdf.PdfReader(io.BytesIO(data))
        return [(i + 1, p.extract_text() or "") for i, p in enumerate(rd.pages)]
    except ImportError:
        pass
    try:
        out = subprocess.run(["pdftotext", "-layout", "-", "-"], input=data, capture_output=True, timeout=120)
        return [(i + 1, t) for i, t in enumerate(out.stdout.decode("utf-8", "replace").split("\f"))]
    except (OSError, subprocess.SubprocessError):
        return []


def fetch_bytes(url: str, timeout: int = 60) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": R.UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read()
    except OSError as e:
        if "CERTIFICATE" not in str(e).upper():
            raise
        out = subprocess.run(["curl", "-s", "-f", "-L", "-m", str(timeout), "-A", R.UA, url], capture_output=True)
        if out.returncode:
            raise RuntimeError(f"curl が失敗（{out.returncode}）") from e
        return out.stdout


@dataclass
class Body:
    src: R.Source
    pages: list[tuple[int | None, str]]
    opened: str


def _wait(fetcher):
    time.sleep(R.WAIT if fetcher is R.fetch else 0)


def gather_bodies(sources: list[R.Source], specs: list[FactSpec], topic: str, fetcher=R.fetch,
                  pdfs: list[str] | None = None, byte_fetcher=fetch_bytes, log: list[str] | None = None) -> list[Body]:
    log = log if log is not None else []
    bodies: list[Body] = []
    # NDL デジタルの公開本：事実の一番長い語で全文を引いて本を足す
    lab = [s for s in sources if s.entry == "NDLデジタル全文"]
    for sp in specs:
        word = max(sp.terms, key=len)
        if len(word) < 2:
            continue
        try:
            lab += R.parse_lab(fetcher(R.lab_url(word, 5)))
        except Exception as e:  # noqa: BLE001
            log.append(f"NDLデジタル全文「{word}」: {type(e).__name__}")
        _wait(fetcher)
    lab += [s for s in sources if s.entry == "NDLサーチ" and "デジタル化あり" in s.note]
    seen: set[str] = set()
    for s in lab:
        pid = pid_of(s)
        if not pid or pid in seen or len(seen) >= MAX_BOOKS:
            continue
        seen.add(pid)
        try:
            pages = R.parse_lab_fulltext(fetcher(R.lab_fulltext_url(pid)))
        except Exception as e:  # noqa: BLE001
            log.append(f"NDL 本文 {pid}: {type(e).__name__}")
            pages = []
        _wait(fetcher)
        if pages:
            bodies.append(Body(s, pages, "本文"))
        elif s.snippet:
            bodies.append(Body(s, [(None, s.snippet)], "抜き出し"))
    # Wikisource の翻刻
    for s in [s for s in sources if s.entry.startswith("Wikisource")][:MAX_WS]:
        lang = "en" if "en.wikisource" in s.url else "ja"
        title = urllib.parse.unquote(s.url.rsplit("/wiki/", 1)[-1])
        try:
            text = json.loads(fetcher(WS_TEXT.format(lang=lang, q=urllib.parse.quote(title))))["parse"]["wikitext"]
            bodies.append(Body(s, [(None, text)], "本文"))
        except Exception as e:  # noqa: BLE001
            log.append(f"Wikisource {title}: {type(e).__name__}")
        _wait(fetcher)
    # J-STAGE は記事の頁の要旨だけ（PDF は robots.txt が断る）
    from .expand import jstage_abstract
    for s in [s for s in sources if s.entry == "J-STAGE"][:15]:
        try:
            ab = jstage_abstract(fetcher(s.url))
        except Exception as e:  # noqa: BLE001
            log.append(f"J-STAGE 要旨 {s.url}: {type(e).__name__}")
            ab = ""
        _wait(fetcher)
        if ab:
            bodies.append(Body(s, [(None, s.title + " " + ab)], "要旨"))
    # 抜き出しだけの入口（Internet Archive・ジャパンサーチの説明）
    for s in sources:
        if s.entry in ("Internet Archive",) or s.entry.startswith("ジャパンサーチ"):
            if s.snippet:
                m = re.search(r"/page/n(\d+)", s.url)
                bodies.append(Body(s, [(int(m.group(1)) if m else None, s.snippet)], "抜き出し"))
    # 人が開いた PDF
    for spec in pdfs or []:
        url, _, title = spec.partition("::")
        try:
            pages = pdf_pages(byte_fetcher(url))
        except Exception as e:  # noqa: BLE001
            log.append(f"PDF {url}: {type(e).__name__} {str(e)[:80]}")
            pages = []
        if pages:
            src = R.Source(title=title or url.rsplit("/", 1)[-1], url=url, entry="PDF（人が開いた URL）",
                           tier=R.classify(title or "", "", "", default="公的機関の発表"))
            bodies.append(Body(src, pages, "本文"))
    return bodies


def evidence_for(spec: FactSpec, bodies: list[Body], sources: list[R.Source], anchor: list[str]) -> list[Evidence]:
    ev: list[Evidence] = []
    for b in bodies:
        terms = spec.en_terms if b.src.entry == "Internet Archive" and spec.en_terms else spec.terms
        anc = [] if b.src.entry == "Internet Archive" else anchor
        hit = match_pages(b.pages, terms, anc)
        if hit:
            page, q = hit
            url = b.src.url
            if page and "dl.ndl.go.jp/pid/" in url:
                url = re.sub(r"(/pid/\d+).*$", rf"\1/1/{page}", url)
            ev.append(Evidence(b.src.title, url, b.src.entry, b.src.tier, b.opened, q, page, b.src.year, b.src.who))
    # 書誌だけ（題に語が全部出るもの）
    nt = [mnorm(t) for t in spec.terms]
    for s in sources:
        if all(t in mnorm(s.title + s.where) for t in nt) and not any(e.url == s.url for e in ev):
            ev.append(Evidence(s.title, s.url, s.entry, s.tier, "書誌", "", None, s.year, s.who))
    ev.sort(key=lambda e: (OPENED_RANK.get(e.opened, 9), R.TIERS.index(e.tier) if e.tier in R.TIERS else 9))
    out, works = [], set()
    for e in ev:                                  # 同じ資料（巻違い）は1つに
        if e.work in works:
            continue
        works.add(e.work)
        out.append(e)
    return out[:MAX_EVIDENCE]


def merge_cards_in(cards: list[Card], path: Path, slug: str) -> list[str]:
    """Agent が WebSearch・WebFetch で集めた事実カード（同じ形の YAML）を合わせる。id か主張が同じなら出どころを足し、無ければ新しいカード。"""
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    rows = data.get("facts", data) if isinstance(data, dict) else data
    log = []
    for row in rows or []:
        claim = str(row.get("claim", "")).strip()
        card = next((c for c in cards if c.spec.id == row.get("id") or (claim and c.spec.claim == claim)), None)
        if card is None:
            terms = row.get("terms") or [claim]
            card = Card(FactSpec(f"{slug}-{len(cards) + 1:02d}", claim, [str(t) for t in terms]))
            cards.append(card)
            log.append(f"新しいカード {card.spec.id}：{claim}")
        for s in row.get("sources") or []:
            e = Evidence(str(s.get("title", "")), str(s.get("url", "")), str(s.get("entry", "Web")),
                         str(s.get("tier", "一般書・雑誌")), str(s.get("opened", "書誌")), str(s.get("quote", "")),
                         s.get("page"), R.year_of(s.get("year")), str(s.get("who", "")), str(s.get("by", "Agent（WebFetch）")))
            if e.url and not any(x.url == e.url for x in card.evidence):
                card.evidence.append(e)
    return log


# --- 書き出し --------------------------------------------------------------------------------------------------

def card_dict(c: Card) -> dict:
    return {
        "id": c.spec.id, "claim": c.spec.claim, "terms": c.spec.terms,
        **({"en_terms": c.spec.en_terms} if c.spec.en_terms else {}),
        "independent": c.independent,
        "single_source": c.independent <= 1,
        "opened_body": c.opened_body,
        "unknown": c.unknown,
        "known_check": {"wikipedia": c.wikipedia, "dictionaries": c.dictionaries},
        "youtube": c.youtube,
        "sources": [{k: v for k, v in {"tier": e.tier, "title": e.title, "who": e.who, "year": e.year,
                                        "quote": e.quote, "page": e.page, "url": e.url, "opened": e.opened,
                                        "entry": e.entry, "by": e.by}.items() if v not in ("", None)}
                    for e in c.evidence],
    }


def render_cards_md(cards: list[Card], units: int, demand: dict[str, list[str]]) -> str:
    L = ["## 6. 事実カード（YAML と同じ中身の一覧）", "",
         f"本文を開けた事実 {sum(c.opened_body for c in cards)}／出どころ2つ以上 {sum(c.independent >= 2 for c in cards)}／"
         f"他チャンネル未出 {sum(c.youtube.get('verdict') == 'まだ扱われていない' for c in cards)}／全 {len(cards)}。"
         f"YouTube Data API の単位：{units}", "",
         "| ID | 主張 | 知らない度 | 独立 | 本文 | 他チャンネル | いちばん強い出どころ |", "|---|---|---|---|---|---|---|"]
    for c in cards:
        top = c.evidence[0] if c.evidence else None
        best = f"{top.opened}：{R._cell(top.title, 30)} p.{top.page} {top.url}" if top else "なし（台本に入れない）"
        yt = c.youtube.get("verdict", "測っていない")
        L.append(f"| {c.spec.id} | {R._cell(c.spec.claim, 50)} | {c.unknown} | {c.independent}{'（1つだけ）' if c.independent <= 1 else ''} | "
                 f"{'○' if c.opened_body else ''} | {yt} | {best} |")
    if demand:
        L += ["", "YouTube の検索候補（需要の目安）："]
        for q, xs in demand.items():
            L.append(f"- 「{q}」→ {'、'.join(xs[:10]) or 'なし'}")
    L.append("")
    return "\n".join(L)


def write_yaml(topic: str, cards: list[Card], path: Path, units: int, demand: dict, log: list[str], today: _dt.date) -> None:
    data = {"topic": topic, "made": today.isoformat(), "youtube_units": units, "demand": demand,
            "counts": {"facts": len(cards), "opened_body": sum(c.opened_body for c in cards),
                       "two_or_more": sum(c.independent >= 2 for c in cards),
                       "not_on_youtube": sum(c.youtube.get("verdict") == "まだ扱われていない" for c in cards)},
            "notes": log, "facts": [card_dict(c) for c in cards]}
    path.write_text("# 事実カード（chiso/facts.py）。台本の行は `# fact: <id>` でつなぐ。\n"
                    + yaml.safe_dump(data, allow_unicode=True, sort_keys=False, width=200), encoding="utf-8")


def load_cards(path: Path) -> dict[str, dict]:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    return {str(f["id"]): f for f in data.get("facts", [])}
