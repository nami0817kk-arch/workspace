"""検索語を広げる（plan）と、引用をたどる（chain）（10-26、ユーザー「もっとネットから情報集める性能を上げて」）。

plan：題材の名前から、別名・号・幼名・官位・旧字・和暦の日付・関わる史料名・研究者名・英語名を並べ、
      出どころの種類（学術・公的・博物館と寺社・報道・英語圏・地元）ごとに site: 付きの検索語を作る。
      検索エンジンは Python から叩かない。md の検索語を、Claude の WebSearch・WebFetch（種類ごとに Agent を並べる）で回す。
      取るもの：Wikidata（wbgetentities。鍵なし）の別名と英語名／Wikipedia 日本語版の本文の「〇〇と称す」「幼名」「号」「官位」・
      和暦の日付（「永禄10年8月3日」）・『史料名』／言語間リンク（英語版の題）。
chain：見つけた論文（J-STAGE の記事の頁の citation_reference）と Wikipedia の脚注（<ref>・Cite book/journal）から、
      まだ一覧に無い文献を拾う。拾った文献の題で NDL サーチ・J-STAGE を引き、当たった J-STAGE の論文の参考文献をもう1段たどる（2段まで）。
      J-STAGE の PDF（/_pdf）は robots.txt が断るので叩かない。記事の頁（HTML）だけ。
"""
from __future__ import annotations

import json
import re
import time
import urllib.parse
from collections import Counter
from dataclasses import dataclass, field

from . import research as R

WD_SEARCH = "https://www.wikidata.org/w/api.php?action=wbsearchentities&search={q}&language=ja&format=json&limit=1"
WD_GET = ("https://www.wikidata.org/w/api.php?action=wbgetentities&ids={id}"
          "&props=aliases%7Clabels%7Csitelinks&languages=ja%7Cen&format=json")
WP_WIKITEXT = ("https://{lang}.wikipedia.org/w/api.php?action=parse&page={q}&prop=wikitext"
               "&format=json&formatversion=2&redirects=1")

ERAS = ("天文|弘治|永禄|元亀|天正|文禄|慶長|元和|寛永|正保|慶安|承応|明暦|万治|寛文|延宝|天和|貞享|元禄|宝永|正徳|享保|"
        "元文|寛保|延享|寛延|宝暦|明和|安永|天明|寛政|享和|文化|文政|天保|弘化|嘉永|安政|万延|文久|元治|慶応|明治|大正|昭和|"
        "応仁|文明|長享|延徳|明応|文亀|永正|大永|享禄|建武|延元|正平|応永|嘉吉|文安|宝徳|享徳|康正|長禄|寛正|文正|"
        "治承|寿永|元暦|文治|建久|承久|貞永|弘安|正応|永仁|元弘|正慶|大化|天平|延暦|大同|弘仁|承平|天慶|長保|寛弘|保元|平治")
WAREKI = re.compile(rf"(?:{ERAS})(?:元|[0-9０-９一二三四五六七八九十]+)年(?:閏?[0-9０-９一二三四五六七八九十]+月)?(?:[0-9０-９一二三四五六七八九十]+日)?")
ALIAS_PATTERNS = (r"幼名は([^\s、。（）()]{1,8})", r"通称は([^\s、。（）()]{1,8})", r"号は([^\s、。（）()]{1,8})",
                  r"法名は([^\s、。（）()]{1,16})", r"諡は([^\s、。（）()]{1,10})", r"字は([^\s、。（）()]{1,8})",
                  r"(?:官位|官途)は([^\s、。（）()]{1,10})", r"「([^」]{1,8})」と(?:呼ばれ|称さ|渾名|あだ名)")
TITLES = re.compile(r"『([^』]{2,30})』")
OLD = str.maketrans("両画独真国学当実営気伝徳竜広沢会旧体", "兩畫獨眞國學當實營氣傳德龍廣澤會舊體")


@dataclass
class Plan:
    topic: str
    qid: str = ""
    en_names: list[str] = field(default_factory=list)
    aliases: list[str] = field(default_factory=list)       # 別名・号・幼名・官位（Wikidata と本文から）
    old_forms: list[str] = field(default_factory=list)     # 旧字
    wareki: list[str] = field(default_factory=list)        # 本文に出る和暦の日付（多い順）
    source_titles: list[str] = field(default_factory=list) # 本文に出る『史料名』（多い順）
    scholars: list[str] = field(default_factory=list)      # 脚注・J-STAGE の著者（多い順）
    en_title: str = ""
    errors: list[str] = field(default_factory=list)


def _wait(fetcher):
    time.sleep(R.WAIT if fetcher is R.fetch else 0)


def parse_wikidata(search_text: str) -> str:
    hits = json.loads(search_text).get("search") or []
    return hits[0]["id"] if hits else ""


def parse_entity(text: str, qid: str) -> tuple[list[str], list[str], str]:
    """(英語名, 日本語の別名, 英語版 Wikipedia の題)。"""
    e = (json.loads(text).get("entities") or {}).get(qid) or {}
    en = [((e.get("labels") or {}).get("en") or {}).get("value", "")]
    en += [a["value"] for a in (e.get("aliases") or {}).get("en", [])]
    ja = [a["value"] for a in (e.get("aliases") or {}).get("ja", [])]
    enwiki = ((e.get("sitelinks") or {}).get("enwiki") or {}).get("title", "")
    return [x for x in en if x], ja, enwiki


def aliases_from_text(full: str) -> list[str]:
    out = []
    for pat in ALIAS_PATTERNS:
        for m in re.finditer(pat, full or ""):
            w = m.group(1).strip("「」『』")
            if w and w not in out:
                out.append(w)
    return out


def wareki_dates(full: str, limit: int = 15) -> list[str]:
    c = Counter(m.group(0) for m in WAREKI.finditer(full or "") if "月" in m.group(0))
    return [w for w, _ in c.most_common(limit)]


def source_titles(full: str, limit: int = 20) -> list[str]:
    c = Counter(m.group(1) for m in TITLES.finditer(full or ""))
    return [w for w, _ in c.most_common(limit)]


def old_form(word: str) -> str:
    return word.translate(OLD)


def build_plan(topic: str, full: str = "", wikitext: str = "", fetcher=R.fetch) -> Plan:
    plan = Plan(topic)
    try:
        plan.qid = parse_wikidata(fetcher(WD_SEARCH.format(q=urllib.parse.quote(topic))))
        _wait(fetcher)
        if plan.qid:
            en, ja, enwiki = parse_entity(fetcher(WD_GET.format(id=plan.qid)), plan.qid)
            _wait(fetcher)
            plan.en_names, plan.aliases, plan.en_title = en, ja, enwiki
    except Exception as e:  # noqa: BLE001
        plan.errors.append(f"Wikidata: {type(e).__name__} {str(e)[:100]}")
    for a in aliases_from_text(full):
        if a not in plan.aliases and a != topic:
            plan.aliases.append(a)
    for w in [topic] + plan.aliases:
        o = old_form(w)
        if o != w and o not in plan.old_forms:
            plan.old_forms.append(o)
    plan.wareki = wareki_dates(full)
    plan.source_titles = source_titles(full)
    plan.scholars = [a for a, _ in Counter(c.author for c in wiki_citations(wikitext) if c.author).most_common(15)]
    return plan


# --- 出どころの種類ごとの検索語（WebSearch で回す） -----------------------------------------------------------

KINDS = {
    "学術": ["site:ac.jp", "site:jstage.jst.go.jp", "site:irdb.nii.ac.jp", "site:cir.nii.ac.jp", "filetype:pdf 紀要"],
    "公的": ["site:go.jp", "site:lg.jp", "文化財課", "教育委員会 報告書", "site:sitereports.nabunken.go.jp"],
    "博物館・寺社": ["博物館 収蔵品", "美術館 所蔵", "寺 公式 寺宝", "神社 由緒", "企画展 図録"],
    "報道": ["発掘 ニュース", "新発見", "新史料", "企画展 ニュース", "site:kahoku.news"],
    "英語圏": ["site:edu", "museum collection", "translation letter", "archive.org", "jstor"],
    "地元": ["観光協会", "郷土史", "市史", "町史", "史跡 案内板"],
}


def site_queries(plan: Plan, facts: list[str] | None = None) -> dict[str, list[str]]:
    """種類ごとの検索語。名前は「本名」と別名1〜2個、英語圏は英語名。事実の語があれば足す。"""
    names = [plan.topic] + [a for a in plan.aliases if len(a) >= 2][:2]
    en = plan.en_names[0] if plan.en_names else ""
    out: dict[str, list[str]] = {}
    for kind, tails in KINDS.items():
        qs = []
        for t in tails:
            if kind == "英語圏":
                if en:
                    qs.append(f'"{en}" {t}')
                continue
            qs.append(f"{names[0]} {t}")
        for n in names[1:]:
            if kind != "英語圏":
                qs.append(f"{n} {tails[0]}")
        for f in (facts or [])[:4]:
            qs.append((f'"{en}" ' if kind == "英語圏" and en else f"{plan.topic} ") + f + f" {tails[0]}")
        if kind == "学術":
            qs += [f"{plan.topic} {s} {tails[0]}" for s in plan.scholars[:3]]
            qs += [f"{plan.topic} 『{s}』" for s in plan.source_titles[:3]]
        out[kind] = qs
    return out


def render_plan(plan: Plan, queries: dict[str, list[str]]) -> str:
    L = [f"# {plan.topic} の検索の計画", "",
         "Python から検索エンジンは叩かない。下の検索語を、種類ごとに Agent を並べて WebSearch・WebFetch で回す（スキル rekishi-research の「並べて集める」）。",
         "結果は事実カードの形（主張・引用・頁・URL・開いたか）で返し、`research --cards-in` で合わせる。", ""]
    L += ["## 名前の広げ方", "",
          f"- Wikidata：{plan.qid or '取れなかった'}　英語名：{'・'.join(plan.en_names) or 'なし'}　英語版 Wikipedia：{plan.en_title or 'なし'}",
          f"- 別名・号・幼名・官位：{'・'.join(plan.aliases) or 'なし'}",
          f"- 旧字：{'・'.join(plan.old_forms) or 'なし'}（NDL デジタル全文の句に使う）",
          f"- 和暦の日付（Wikipedia 本文に多い順）：{'・'.join(plan.wareki) or 'なし'}",
          f"- 関わる史料名（本文の『』に多い順）：{'・'.join(plan.source_titles) or 'なし'}",
          f"- 研究者名（Wikipedia の脚注の著者）：{'・'.join(plan.scholars) or 'なし'}", ""]
    if plan.errors:
        L += [f"取れなかった：{'；'.join(plan.errors)}", ""]
    L += ["## 種類ごとの検索語（WebSearch に1行ずつ）", ""]
    for kind, qs in queries.items():
        L += [f"### {kind}", ""] + [f"- `{q}`" for q in qs] + [""]
    return "\n".join(L)


# --- 引用をたどる ----------------------------------------------------------------------------------------------

@dataclass
class Citation:
    text: str                  # 文献の書き方そのまま（短く）
    title: str = ""            # 題（検索に使う）
    author: str = ""
    year: int | None = None
    origin: str = ""           # どこから拾ったか（Wikipedia の脚注／論文の参考文献 <URL>）
    depth: int = 1


def _cite_field(tpl: str, key: str) -> str:
    m = re.search(rf"\|\s*{key}\s*=\s*([^|}}]*)", tpl)
    return re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", m.group(1)).strip() if m else ""


def wiki_citations(wikitext: str) -> list[Citation]:
    """Wikipedia の脚注と参考文献から、本・論文を拾う（Cite web だけのもの・頁だけの略記は落とす）。"""
    out: list[Citation] = []
    for tpl in re.findall(r"\{\{\s*Cite\s+(?:book|journal)[^{}]*\}\}", wikitext or "", re.I):
        title = re.sub(r"\[https?://\S+\s*\]", "", _cite_field(tpl, "title")).strip()
        if not title:
            continue
        out.append(Citation(text=tpl[:200], title=title, author=_cite_field(tpl, "author").split("、")[0],
                            year=R.year_of(_cite_field(tpl, "year") or _cite_field(tpl, "date")), origin="Wikipedia の脚注"))
    for line in re.findall(r"^\*\s*(.+)$|<ref[^>/]*>(.+?)</ref>", wikitext or "", re.M | re.S):
        s = (line[0] or line[1]).strip()
        if "{{" in s:
            continue
        m = re.search(r"『([^』]{2,40})』", s)
        if not m:
            continue
        a = re.match(r"\[*([^\]『「（(,，、]{2,12})", s)
        out.append(Citation(text=re.sub(r"\s+", " ", s)[:200], title=m.group(1),
                            author=a.group(1).strip("[] ") if a else "", year=R.year_of(s), origin="Wikipedia の脚注"))
    return dedupe_citations(out)


def jstage_references(html_text: str, origin: str) -> list[Citation]:
    """J-STAGE の記事の頁の <meta name="citation_reference">。"""
    out = []
    for m in re.finditer(r'<meta name="citation_reference" content="([^"]+)"', html_text or ""):
        s = R.html.unescape(m.group(1))
        t = re.search(r"[『「]([^』」]{2,50})[』」]", s)
        a = re.match(r"(?:\d+\)\s*)?([^\s『「（(,，、]{2,10})", s)
        out.append(Citation(text=s[:200], title=t.group(1) if t else "", author=a.group(1) if a and t and a.start(1) < t.start() else "",
                            year=R.year_of(s), origin=origin))
    return [c for c in out if c.title]


def jstage_abstract(html_text: str) -> str:
    m = re.search(r'<meta name="citation_abstract" content="([^"]*)"', html_text or "")
    if m:
        return R.html.unescape(m.group(1))
    m = re.search(r'id="article-overiew-abstract-wrap"(.*?)</div>\s*</div>', html_text or "", re.S)
    return R.strip_tags(m.group(1))[:2000] if m else ""


def dedupe_citations(items: list[Citation]) -> list[Citation]:
    seen, out = set(), []
    for c in items:
        k = R.norm(c.title)
        if k in seen:
            continue
        seen.add(k)
        out.append(c)
    return out


def chain(seed_jstage_urls: list[str], wikitext: str, known_titles: set[str], topic: str,
          fetcher=R.fetch, max_per_depth: int = 12) -> tuple[list[Citation], list[R.Source], list[str]]:
    """2段まで。1段目：Wikipedia の脚注＋見つけた J-STAGE 論文の参考文献。2段目：1段目の題で J-STAGE を引いて当たった論文の参考文献。
    返り値：(拾った文献, 新しく当たった出どころ, 取れなかった)。known_titles（一覧にもうある題）は落とす。"""
    known = {R.norm(t) for t in known_titles}
    cites: list[Citation] = list(wiki_citations(wikitext))
    errors: list[str] = []
    found: list[R.Source] = []
    for url in seed_jstage_urls[:max_per_depth]:
        try:
            cites += jstage_references(fetcher(url), f"参考文献 {url}")
        except Exception as e:  # noqa: BLE001
            errors.append(f"{url}: {type(e).__name__}")
        _wait(fetcher)
    level1 = [c for c in dedupe_citations(cites) if R.norm(c.title) not in known]
    out = list(level1)
    seen = known | {R.norm(c.title) for c in level1}
    next_urls: list[str] = []
    for c in level1[:max_per_depth]:
        q = c.title
        try:
            hits = R.parse_jstage(fetcher(R.jstage_url(q, 3, "article")))
        except Exception as e:  # noqa: BLE001
            errors.append(f"J-STAGE「{q}」: {type(e).__name__}")
            hits = []
        _wait(fetcher)
        for h in hits:
            if R.norm(h.title) == R.norm(q) or (R.norm(q) in R.norm(h.title) and len(q) >= 6):
                h.note = (h.note + " / " if h.note else "") + f"芋づる1段（{c.origin}）"
                found.append(h)
                next_urls.append(h.url)
        try:
            nd = R.parse_ndl(fetcher(R.ndl_url(q, 3)))
        except Exception as e:  # noqa: BLE001
            errors.append(f"NDL「{q}」: {type(e).__name__}")
            nd = []
        _wait(fetcher)
        for h in nd:
            if R.norm(q) in R.norm(h.title):
                h.note = (h.note + " / " if h.note else "") + f"芋づる1段（{c.origin}）"
                found.append(h)
                break
    for url in next_urls[:max_per_depth]:
        try:
            for c in jstage_references(fetcher(url), f"参考文献 {url}"):
                if R.norm(c.title) not in seen:
                    c.depth = 2
                    seen.add(R.norm(c.title))
                    out.append(c)
        except Exception as e:  # noqa: BLE001
            errors.append(f"{url}: {type(e).__name__}")
        _wait(fetcher)
    return out, R.dedupe(found), errors


def render_chain(cites: list[Citation], found: list[R.Source], errors: list[str]) -> str:
    L = ["## 5. 芋づる（脚注・参考文献から、まだ一覧に無い文献）", "",
         f"拾った文献 {len(cites)} 件（1段目 {sum(c.depth == 1 for c in cites)}・2段目 {sum(c.depth == 2 for c in cites)}）、"
         f"そのうち J-STAGE・NDL サーチで当たったもの {len(found)} 件。題だけのものは NDL サーチ・CiNii を手で引く。", ""]
    if found:
        L += ["| 年 | 題 | 誰が・どこに | 入口 | URL | 拾った所 |", "|---|---|---|---|---|---|"]
        for s in found:
            L.append(f"| {s.year or ''} | {R._cell(s.title, 70)} | {R._cell(s.who + ' ' + s.where, 50)} | {s.entry} | {s.url} | {R._cell(s.note, 80)} |")
        L.append("")
    L += ["| 段 | 文献 | 拾った所 |", "|---|---|---|"]
    for c in cites[:80]:
        L.append(f"| {c.depth} | {R._cell(c.text, 120)} | {R._cell(c.origin, 80)} |")
    if errors:
        L += ["", f"取れなかった：{R._cell('；'.join(errors), 400)}"]
    L.append("")
    return "\n".join(L)
