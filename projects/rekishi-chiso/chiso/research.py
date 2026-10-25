"""題材の出どころを、無料で鍵の要らない入口から集めて1枚の md に並べる（10-25）。

    python -m chiso.cli research 伊達政宗 --kw 瑞鳳殿 --kw 遺言 --phrase 政宗の木像 \
        --fact "1974年に墓を発掘::1974 発掘" --fact "肖像に眼帯が無い::肖像 眼帯"

ユーザー「みんな知っている内容だと興味が惹かれない。知らないような内容も組み込みたい」「ほかにも調べ方を向上させて」。
WebSearch とまとめ記事で止まり、一次史料・論文・発掘報告まで届かないことがあったので、入口を API で直接叩く。
決まりは docs/story-main.md の「0. 題材と知らない事実」、手順はスキル rekishi-research。

叩く入口（10-25 に実際に叩いて確かめた。どれも登録・鍵・課金なし）：
- 国立国会図書館サーチ OpenSearch（本・雑誌記事・デジタル化資料の書誌。from=2015 で新しいものも別に取る）
- 次世代デジタルライブラリー（lab.ndl.go.jp。NDL デジタルコレクションの公開本の全文。**語は1つの句として探す**：
  空白で区切ると 0 件になる。旧字（兩・畫・獨）で書かれた本が多い）
- J-STAGE WebAPI（論文。題名で探す article= と、本文で探す text= の両方。pubyearfrom=2015 も別に取る）
- ジャパンサーチ（絵・木像・公文書・写真。権利表示つき）
- Wikisource 日本語版（翻刻。原本で確かめるまで「翻刻」扱い）
- Wikipedia 日本語版（知らない度の点検と、食い違いの手がかりだけに使う。出どころには数えない）

叩かない入口（md の「手で開く入口」に検索の URL だけ出す）：
- CiNii Research：OpenSearch は appid（登録）が必須と書いてある → 道具からは叩かない。画面は手で開いてよい
- 全国遺跡報告総覧：API が無く、robots.txt が検索結果を拒んでいる → 手で開く（発掘報告の PDF はここ）
- 東京大学史料編纂所 データベース（SHIPS）：公開の API が無い（画面が内部で使う呼び出しは叩かない）→ 手で開く
- Gallica（Cloudflare の bot 判定で 403）・Perseus（503/405）・Europeana（wskey が要る）→ 使わない

出力は research/<題>_sources_YYYYMMDD.md。**URL は入口が実際に返したものだけ**。取れなかった入口は「取れなかった」と書く。
中身（事実）は作らない：ここに並ぶのは候補で、台本に入れる前にページを開いて確かめる。
"""
from __future__ import annotations

import datetime as _dt
import html
import json
import re
import subprocess
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

UA = "chiso-research/0.1 (rekishi-chiso; personal research tool)"
WAIT = 1.0          # 1回ごとに空ける秒数（どの入口にも同じ）
NEW_YEAR = 2015     # これ以降を「新しい」として上に並べる

# 出どころの段（docs/story-main.md の決まり）。最後の「一般書・雑誌」は開いて段を決めるもの
TIERS = ("一次史料", "研究・論文", "公的機関の発表", "報道", "一般書・雑誌", "まとめ記事")

PRIMARY_WORDS = ("史料", "文書", "日記", "覚書", "家譜", "実録", "記録", "書状", "日録", "年譜", "遺文",
                 "治家記録", "古記録", "大日本史料", "藩翰譜", "寛政重修", "書簡", "御用留")
OFFICIAL_WORDS = ("教育委員会", "博物館", "美術館", "資料館", "文化財", "研究所", "史料編纂所", "公文書館",
                  "文化庁", "宮内庁", "国立", "県立", "市立", "図書館", "埋蔵文化財", "記念館", "再建期成会")
NEWS_WORDS = ("新聞", "新報", "通信社", "放送", "NHK", "日報", "タイムス", "ニュース")
ACADEMIC_WORDS = ("大学", "学会", "研究会", "史学", "学報", "紀要", "論集", "研究紀要", "考古学", "学術")

# ジャパンサーチの権利表示
RIGHTS = {"pdm": "パブリックドメイン", "cc0": "CC0", "ccby": "CC BY", "ccbysa": "CC BY-SA", "ccbynd": "CC BY-ND",
          "ccbync": "CC BY-NC", "ccbyncsa": "CC BY-NC-SA", "ccbyncnd": "CC BY-NC-ND", "incr": "著作権あり",
          "noncom": "非営利なら可", "com": "商用可", "edu": "教育なら可", "nocr_cont": "著作権なし（契約で制限）",
          "undet": "権利不明", "others": "その他（元のページで確かめる）", "uneval": "未評価"}


@dataclass
class Source:
    title: str
    url: str
    entry: str                     # どの入口から来たか
    tier: str = "一般書・雑誌"
    year: int | None = None
    who: str = ""                  # 著者・発行
    where: str = ""                # 載った雑誌・叢書
    snippet: str = ""              # 入口が返した抜き出し（全文検索のハイライトなど）
    note: str = ""                 # 権利・デジタル公開の有無など

    @property
    def is_new(self) -> bool:
        return self.year is not None and self.year >= NEW_YEAR


@dataclass
class EntryResult:
    name: str
    queries: list[str] = field(default_factory=list)
    items: list[Source] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


# --- 通信 ------------------------------------------------------------------------------

def fetch(url: str, timeout: int = 40, retries: int = 2) -> str:
    """GET して本文を返す。429（混みあい）は Retry-After（無ければ5秒・10秒）待って取り直す。
    このPCの Python は証明書で落ちることがあるので、そのときは curl で取り直す。"""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        if e.code in (429, 503) and retries > 0:
            wait = e.headers.get("Retry-After") if e.headers else None
            time.sleep(min(int(wait), 60) if wait and wait.isdigit() else 5 * (3 - retries))
            return fetch(url, timeout, retries - 1)
        raise
    except (urllib.error.URLError, OSError) as e:
        if "CERTIFICATE" not in str(e).upper():
            raise
        out = subprocess.run(["curl", "-s", "-f", "-m", str(timeout), "-A", UA, url],
                             capture_output=True, timeout=timeout + 5)
        if out.returncode != 0:
            raise RuntimeError(f"curl が失敗（{out.returncode}）") from e
        return out.stdout.decode("utf-8", "replace")


# --- 小さな道具 ----------------------------------------------------------------------

def year_of(text: str | int | None) -> int | None:
    """'2013.10'・'19640400'・'1979'・'Wed, 29 Jan 2014' から年を取る。"""
    if text is None:
        return None
    if isinstance(text, int):
        return text
    m = re.search(r"(1[5-9]\d\d|20\d\d)", str(text))
    return int(m.group(1)) if m else None


def strip_tags(s: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s or ""))).strip()


def norm(s: str) -> str:
    """照らし合わせ用：NFKC・空白を消す・旧字を新字に（よく出るものだけ）。"""
    s = unicodedata.normalize("NFKC", s or "")
    s = s.translate(str.maketrans("兩畫獨眞國學當實營氣傳德龍廣澤會舊體", "両画独真国学当実営気伝徳竜広沢会旧体"))
    return re.sub(r"\s+", "", s)


REPORT_WORDS = ("発掘調査", "調査報告", "調査概報", "墓とその遺品", "遺跡", "報告書")


def is_primary_title(title: str) -> bool:
    """題の本体（「 : 」の前）が史料の語で終わるもの（『伊達政宗卿伝記史料』『伊達政宗書状』）。
    「〜史料による結論」「〜記録集」のように途中に出るだけのものは史料ではない。"""
    main = re.split(r"\s*[:：]\s*", title or "")[0].strip(" 　[]［］「」『』")
    main = re.sub(r"[\s　]+\S*[0-9０-９]\S*$", "", main)          # 「 5輯144卷」のような巻次
    main = re.sub(r"[\s　]*[上中下]$", "", main)
    return any(main.endswith(k) for k in PRIMARY_WORDS)


def classify(title: str, who: str = "", where: str = "", default: str = "一般書・雑誌", kind: str = "") -> str:
    """題・著者・発行・雑誌名から段を決める（目安。開いて違えば md の上で直す）。
    kind は NDL の資料種別（記事・図書・和古書・漢籍・文書・図像類）。"""
    t, w = title or "", f"{who} {where}"
    if any(k in w for k in NEWS_WORDS):
        return "報道"
    if "和古書" in kind or "文書・図像" in kind:
        return "一次史料"
    if "記事" not in kind and is_primary_title(t):
        return "一次史料"
    if any(k in t + where for k in REPORT_WORDS):
        return "公的機関の発表"            # 発掘・調査の報告書（中の章も含む）
    if any(k in w for k in ACADEMIC_WORDS):
        return "研究・論文"
    if any(k in w for k in OFFICIAL_WORDS) or re.search(r"(市|県|町|村)(役所|役場)?(\s|$)", who or ""):
        return "公的機関の発表"
    return default


# --- 国立国会図書館サーチ OpenSearch ---------------------------------------------------

NDL_OS = "https://ndlsearch.ndl.go.jp/api/opensearch?any={q}&cnt={n}{extra}"


def ndl_url(query: str, n: int = 20, year_from: int | None = None) -> str:
    extra = f"&from={year_from}" if year_from else ""
    return NDL_OS.format(q=urllib.parse.quote(query), n=n, extra=extra)


def parse_ndl(text: str) -> list[Source]:
    ns = {"dc": "http://purl.org/dc/elements/1.1/", "dcterms": "http://purl.org/dc/terms/",
          "dcndl": "http://ndl.go.jp/dcndl/terms/", "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
          "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#"}
    root = ET.fromstring(text)
    out = []
    for it in root.iter("item"):
        title = (it.findtext("title") or "").strip()
        link = (it.findtext("link") or "").strip()
        if not title or not link:
            continue
        who = it.findtext("author") or it.findtext("dc:creator", namespaces=ns) or ""
        pub = it.findtext("dc:publisher", namespaces=ns) or ""
        issued = it.findtext("dcterms:issued", namespaces=ns) or it.findtext("dc:date", namespaces=ns)
        cats = [c.text or "" for c in it.findall("category")]
        where = ""
        for d in [it.findtext("dc:description", namespaces=ns) or "", strip_tags(it.findtext("description") or "")]:
            m = re.search(r"掲載誌[：:]\s*(.+?)(?:\s+\d{4})?$", d.strip())
            if m:
                where = m.group(1).strip()
                break
        digital = [s.get(f"{{{ns['rdf']}}}resource", "") for s in it.findall("rdfs:seeAlso", ns)]
        digital = [d for d in digital if "dl.ndl.go.jp" in d]
        who_s = " ".join(x for x in (who.strip(), pub.strip()) if x)
        src = Source(title=html.unescape(title), url=link, entry="NDLサーチ", year=year_of(issued),
                     who=who_s, where=where, note=" / ".join(c for c in cats if c))
        if digital:
            src.note = (src.note + " / " if src.note else "") + f"デジタル化あり {digital[0]}"
        if "R100000136" in link:
            src.note = (src.note + " / " if src.note else "") + "CiNii 由来の書誌"
        src.tier = classify(src.title, who_s, where, kind=" ".join(cats))
        out.append(src)
    return out


# --- 次世代デジタルライブラリー（NDL デジタルコレクションの全文） ------------------------

NDL_LAB = "https://lab.ndl.go.jp/dl/api/book/search?keyword={q}&size={n}"


def lab_url(phrase: str, n: int = 10) -> str:
    return NDL_LAB.format(q=urllib.parse.quote(phrase), n=n)


def parse_lab(text: str) -> list[Source]:
    data = json.loads(text)
    out = []
    for it in data.get("list", []):
        pid = str(it.get("id", ""))
        hl = [strip_tags(h) for h in it.get("highlights", [])]
        page = None
        for h in it.get("highlights", []):
            m = re.search(r"\((\d{4})\.jp2\)", h)
            if m:
                page = int(m.group(1))
                break
        url = f"https://dl.ndl.go.jp/pid/{pid}" + (f"/1/{page}" if page else "")
        title = it.get("title", "") + (f" {it['volume']}" if it.get("volume") else "")
        who = " ".join(x for x in (it.get("responsibility", ""), it.get("publisher", "")) if x)
        src = Source(title=title, url=url, entry="NDLデジタル全文", year=year_of(it.get("publishyear") or it.get("published")),
                     who=who, snippet=" … ".join(h[:160] for h in hl[:2]), note="公開本の全文（OCR。読み違いあり、画像で確かめる）")
        src.tier = "一次史料" if is_primary_title(title) else classify(title, who, "", default="一般書・雑誌")
        out.append(src)
    return out


def lab_hits(text: str) -> int:
    return int(json.loads(text).get("hit", 0))


# --- J-STAGE WebAPI ------------------------------------------------------------------

JSTAGE = "https://api.jstage.jst.go.jp/searchapi/do?service=3&{field}={q}&count={n}{extra}"


def jstage_url(query: str, n: int = 20, field: str = "article", year_from: int | None = None) -> str:
    extra = f"&pubyearfrom={year_from}" if year_from else ""
    return JSTAGE.format(field=field, q=urllib.parse.quote(query), n=n, extra=extra)


def parse_jstage(text: str) -> list[Source]:
    atom = "{http://www.w3.org/2005/Atom}"
    prism = "{http://prismstandard.org/namespaces/basic/2.0/}"
    root = ET.fromstring(text)
    out = []
    for e in root.iter(f"{atom}entry"):
        def ja(tag: str) -> str:
            node = e.find(f"{atom}{tag}/{atom}ja")
            if node is not None and (node.text or "").strip():
                return node.text.strip()
            node = e.find(f"{atom}{tag}/{atom}en")
            return (node.text or "").strip() if node is not None and node.text else ""
        title = ja("article_title") or (e.findtext(f"{atom}title") or "").strip()
        link = ja("article_link")
        if not link:
            ln = e.find(f"{atom}link")
            link = ln.get("href", "") if ln is not None else ""
        names = [n.text.strip() for n in e.findall(f"{atom}author/{atom}ja/{atom}name") if n.text]
        if not names:
            names = [n.text.strip() for n in e.findall(f"{atom}author/{atom}en/{atom}name") if n.text]
        journal = ja("material_title")
        vol = e.findtext(f"{prism}volume") or ""
        sp = e.findtext(f"{prism}startingPage") or ""
        doi = (e.findtext(f"{prism}doi") or "").strip()
        where = journal + (f" {vol}巻" if vol.strip() else "") + (f" p.{sp}" if sp.strip() else "")
        out.append(Source(title=title, url=link, entry="J-STAGE", tier="研究・論文",
                          year=year_of(e.findtext(f"{atom}pubyear")), who="・".join(names), where=where,
                          note=f"DOI {doi}" if doi else ""))
    return out


# --- ジャパンサーチ ----------------------------------------------------------------------

JPS = "https://jpsearch.go.jp/api/item/search/jps-cross?keyword={q}&size={n}"


def jps_url(query: str, n: int = 20) -> str:
    return JPS.format(q=urllib.parse.quote(query), n=n)


def parse_jps(text: str) -> list[Source]:
    data = json.loads(text)
    out = []
    for it in data.get("list", []):
        c = it.get("common", {})
        url = c.get("linkUrl") or f"https://jpsearch.go.jp/item/{it.get('id', c.get('id', ''))}"
        cats = c.get("category") or []
        rights = c.get("contentsRightsType")
        db = c.get("database", "")
        temporal = c.get("temporal") or []
        year = None
        for t in temporal:
            year = year_of(t)
            if year:
                break
        who = str(c.get("provider") or c.get("ownerOrg") or "")
        title = str(c.get("title", ""))
        if any(k in cats for k in ("cultural", "art", "official")) and not any(k in title for k in ("絵葉書", "写真")):
            tier = "一次史料"                     # 絵・木像・書状・公文書など現物
        else:
            tier = classify(title, who, "", default="一般書・雑誌")
        note = f"権利：{RIGHTS.get(rights, rights)}" if rights else "権利：表示なし（元のページで確かめる）"
        note += f" / {c.get('contentsType')}" if c.get("contentsType") else ""
        out.append(Source(title=title, url=url, entry=f"ジャパンサーチ({db})", tier=tier, year=year, who=who,
                          note=note, snippet=strip_tags(str(c.get("description", "")))[:160]))
    return out


# --- Wikisource / Wikipedia ------------------------------------------------------------

WS = "https://{lang}.wikisource.org/w/api.php?action=query&list=search&srsearch={q}&format=json&srlimit={n}"
WP_INTRO = ("https://{lang}.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1"
            "&redirects=1&format=json&formatversion=2&titles={q}")
WP_FULL = ("https://{lang}.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1"
           "&redirects=1&format=json&formatversion=2&titles={q}")


def ws_url(query: str, n: int = 10, lang: str = "ja") -> str:
    return WS.format(lang=lang, q=urllib.parse.quote(query), n=n)


def parse_ws(text: str, lang: str = "ja") -> list[Source]:
    data = json.loads(text)
    out = []
    for r in data.get("query", {}).get("search", []):
        t = r.get("title", "")
        out.append(Source(title=t, url=f"https://{lang}.wikisource.org/wiki/" + urllib.parse.quote(t.replace(" ", "_")),
                          entry="Wikisource", tier="一次史料", snippet=strip_tags(r.get("snippet", ""))[:160],
                          note="翻刻（誰が起こしたか・底本を原本で確かめる）"))
    return out


def wp_url(title: str, intro: bool, lang: str = "ja") -> str:
    return (WP_INTRO if intro else WP_FULL).format(lang=lang, q=urllib.parse.quote(title))


def parse_wp(text: str) -> tuple[str, str]:
    """(記事の題, 本文) を返す。記事が無ければ ('', '')。"""
    data = json.loads(text)
    pages = data.get("query", {}).get("pages", [])
    if isinstance(pages, dict):
        pages = list(pages.values())
    for p in pages:
        if p.get("missing") is not None or "extract" not in p:
            continue
        return p.get("title", ""), p.get("extract", "")
    return "", ""


# --- 知らない度・食い違い ---------------------------------------------------------------

@dataclass
class Fact:
    label: str
    terms: list[str]


def parse_fact(spec: str) -> Fact:
    """'表示の文::語1 語2' か、空白区切りの語だけ（そのまま表示にも使う）。"""
    if "::" in spec:
        label, terms = spec.split("::", 1)
    else:
        label, terms = spec, spec
    return Fact(label.strip(), [t for t in re.split(r"[\s　]+", terms.strip()) if t])


def known_level(fact: Fact, intro: str, full: str) -> tuple[str, str, str]:
    """(導入部, 本文, 判定)。語が全部出たら「出る」。導入部に出る＝誰でも知っている。"""
    ni, nf = norm(intro), norm(full)
    def where(text: str) -> tuple[bool, list[str]]:
        missing = [t for t in fact.terms if norm(t) not in text]
        return not missing, missing
    in_intro, _ = where(ni)
    in_full, miss = where(nf)
    a = "出る" if in_intro else "出ない"
    b = "出る" if in_full else ("出ない" if len(miss) == len(fact.terms) else f"一部（無い語：{'・'.join(miss)}）")
    if in_intro:
        verdict = "誰でも知っている（冒頭に使わない）"
    elif in_full:
        verdict = "知る人は知る（記事の奥）"
    else:
        verdict = "知らない度：高（記事に無い）"
    return a, b, verdict


DISPUTE_MARKS = ("諸説", "異説", "とする説", "という説", "説がある", "説もある", "定かでない", "不明", "疑問",
                 "異なる", "食い違", "否定", "誤り", "とも言われ", "ともいわれ", "創作", "俗説", "伝承")


def dispute_hints(full: str, limit: int = 12) -> list[str]:
    """Wikipedia の本文から、説が割れていそうな文を拾う（手がかり。出どころを開いて確かめる）。"""
    out = []
    for sent in re.split(r"(?<=[。])", full):
        s = sent.strip()
        if 12 <= len(s) <= 220 and any(k in s for k in DISPUTE_MARKS):
            out.append(s)
        if len(out) >= limit:
            break
    return out


# --- 集める ----------------------------------------------------------------------------

Fetcher = Callable[[str], str]


def _run(entry: EntryResult, url: str, parse, fetcher: Fetcher, label: str) -> list[Source]:
    entry.queries.append(label)
    try:
        got = parse(fetcher(url))
    except Exception as e:  # noqa: BLE001  入口ごとに失敗を控えて先へ進む
        entry.errors.append(f"{label}: {type(e).__name__} {str(e)[:120]}")
        return []
    finally:
        time.sleep(WAIT if fetcher is fetch else 0)
    return got


def collect(topic: str, keywords: list[str], phrases: list[str], fetcher: Fetcher = fetch,
            per: int = 20, world: bool = False) -> list[EntryResult]:
    queries = [topic] + [f"{topic} {k}" for k in keywords]
    res: list[EntryResult] = []

    e = EntryResult("NDLサーチ（OpenSearch）")
    for q in queries:
        e.items += _run(e, ndl_url(q, per), parse_ndl, fetcher, q)
        e.items += _run(e, ndl_url(q, per, NEW_YEAR), parse_ndl, fetcher, f"{q}（{NEW_YEAR}年以降）")
    res.append(e)

    e = EntryResult("NDLデジタル全文（次世代デジタルライブラリー）")
    for p in [topic] + phrases:
        e.items += _run(e, lab_url(p, min(per, 10)), parse_lab, fetcher, p)
    res.append(e)

    e = EntryResult("J-STAGE")
    for q in queries:
        e.items += _run(e, jstage_url(q, per, "article"), parse_jstage, fetcher, f"題名:{q}")
        e.items += _run(e, jstage_url(q, per, "text", NEW_YEAR), parse_jstage, fetcher, f"本文:{q}（{NEW_YEAR}年以降）")
    res.append(e)

    e = EntryResult("ジャパンサーチ")
    for q in queries:
        e.items += _run(e, jps_url(q, per), parse_jps, fetcher, q)
    res.append(e)

    e = EntryResult("Wikisource（日本語）")
    for q in queries:
        e.items += _run(e, ws_url(q, 10), parse_ws, fetcher, q)
    res.append(e)
    if world:
        e = EntryResult("Wikisource（英語）")
        for q in queries:
            e.items += _run(e, ws_url(q, 10, "en"), lambda t: parse_ws(t, "en"), fetcher, q)
        res.append(e)
    for r in res:
        r.items = dedupe(r.items)
    return res


def dedupe(items: list[Source]) -> list[Source]:
    seen, out = set(), []
    for s in items:
        if s.url in seen:
            continue
        seen.add(s.url)
        out.append(s)
    return out


FULLTEXT_ENTRIES = ("Wikisource", "NDLデジタル全文")


def relevant(s: Source, topic: str, keywords: list[str]) -> bool:
    """題・抜き出し・掲載誌に主題の語（4字以上なら前後2字の片方でもよい）が出るもの。
    書誌の入口（NDLサーチ・J-STAGE・ジャパンサーチ）は調べた語が出るだけでもよい。全文検索は主題の語が要る
    （「遺骨」で探すと別人の遺骨の話まで拾うため）。"""
    hay = norm(s.title + s.snippet + s.where)
    keys = [topic]
    if len(topic) >= 4:
        keys += [topic[:2], topic[2:]]
    if not s.entry.startswith(FULLTEXT_ENTRIES):
        keys += keywords
    return any(norm(k) in hay for k in keys if k)


def dedupe_across(items: list[Source]) -> list[Source]:
    """入口をまたいだ同じ資料（ジャパンサーチの bibnl・dignl は NDL の写し）を、題と年で1つに。先に来たものを残す。"""
    seen, out = set(), []
    for s in items:
        key = (norm(s.title), s.year)
        if key in seen:
            continue
        seen.add(key)
        out.append(s)
    return out


def sort_sources(items: list[Source]) -> list[Source]:
    """2015年以降を上に、その中は新しい順。年の無いものは最後。"""
    return sorted(items, key=lambda s: (0 if s.is_new else 1, -(s.year or 0)))


# --- 書き出し ----------------------------------------------------------------------------

def _cell(s: str, n: int = 120) -> str:
    s = (s or "").replace("|", "／").replace("\n", " ")
    return s if len(s) <= n else s[: n - 1] + "…"


def manual_links(topic: str, keywords: list[str]) -> list[tuple[str, str, str]]:
    q = urllib.parse.quote(topic)
    q2 = urllib.parse.quote(" ".join([topic] + keywords[:1]))
    return [
        ("東京大学史料編纂所 SHIPS（大日本史料・古記録）", f"https://wwwap.hi.u-tokyo.ac.jp/ships/cross/search?keyword={q}",
         "公開 API なし。画面で開く。大日本史料の綱文・古記録の全文"),
        ("全国遺跡報告総覧（発掘報告書）", f"https://sitereports.nabunken.go.jp/ja/search?all={q2}",
         "API なし・robots.txt が検索を拒むので道具は叩かない。報告書 PDF の全文検索"),
        ("CiNii Research（論文・博士論文）", f"https://cir.nii.ac.jp/all?q={q2}",
         "API は appid の登録が必須 → 道具は叩かない。画面は登録なしで使える"),
        ("NDLデジタルコレクション（全文・送信資料）", f"https://dl.ndl.go.jp/search/searchResult?keyword={q2}",
         "画面の全文検索。『図書館・個人送信』は個人送信の登録が要る（登録はユーザーが決める）"),
    ]


def render_md(topic: str, results: list[EntryResult], facts: list[Fact], wp_title: str, intro: str, full: str,
              keywords: list[str], today: _dt.date, wp_error: str = "") -> str:
    L: list[str] = []
    L.append(f"# {topic} の出どころ（{today.isoformat()}）")
    L.append("")
    L.append("`python -m chiso.cli research` が入口を直接叩いて集めた候補。**ここの URL は入口が実際に返したものだけ**。"
             "台本に入れる前にページ（PDF なら該当ページ）を開いて確かめる。確かめられないものは台本に入れない。")
    L.append("")
    L.append("## 入口ごとの件数")
    L.append("")
    L.append("| 入口 | 叩いた語 | 返った件数（重複を除く） | 取れなかった |")
    L.append("|---|---|---|---|")
    for r in results:
        L.append(f"| {r.name} | {_cell('、'.join(r.queries), 200)} | {len(r.items)} | "
                 f"{_cell('；'.join(r.errors), 200) if r.errors else 'なし'} |")
    L.append("")

    # 1. 知らない度
    L.append(f"## 1. 知らない度の点検（Wikipedia 日本語版「{wp_title or topic}」）")
    L.append("")
    if wp_error or not full:
        L.append(f"取れなかった：{wp_error or '記事が見つからない'}")
    else:
        L.append("導入部（冒頭）に出る＝誰でも知っている。語が全部出たら「出る」。言い換えで書かれていると拾えないので、「出ない」は記事を目で見て確かめる。")
        L.append("")
        if facts:
            L.append("| 事実の候補 | 照らした語 | 導入部 | 本文 | 判定 |")
            L.append("|---|---|---|---|---|")
            for f in facts:
                a, b, v = known_level(f, intro, full)
                L.append(f"| {_cell(f.label)} | {'・'.join(f.terms)} | {a} | {b} | {v} |")
        else:
            L.append("（--fact で事実の候補を渡すと、ここに表が出る）")
        L.append("")
        L.append(f"導入部の要約（{len(intro)}字）：{_cell(intro, 400)}")
    L.append("")

    # 2. 出どころ
    every = [s for r in results for s in r.items]
    rel = dedupe_across([s for s in every if relevant(s, topic, keywords)])
    L.append("## 2. 出どころの候補（段ごと・★＝2015年以降を上に）")
    L.append("")
    L.append(f"全 {len(every)} 件のうち、題か抜き出しに主題・調べた語が出る {len(rel)} 件（入口をまたいだ重複は1つに）。"
             "段は題・資料の種別・発行元からの目安で、開いて違えば直す。")
    L.append("")
    for tier in TIERS[:-1]:
        rows = sort_sources([s for s in rel if s.tier == tier])
        L.append(f"### {tier}（{len(rows)}件、うち2015年以降 {sum(s.is_new for s in rows)}件）")
        L.append("")
        if not rows:
            L.append("なし")
            L.append("")
            continue
        L.append("| 年 | 題 | 誰が・どこに | 入口 | URL | 抜き出し・備考 |")
        L.append("|---|---|---|---|---|---|")
        for s in rows:
            y = f"★{s.year}" if s.is_new else (str(s.year) if s.year else "")
            extra = " ／ ".join(x for x in (s.snippet, s.note) if x)
            L.append(f"| {y} | {_cell(s.title, 80)} | {_cell(' '.join(x for x in (s.who, s.where) if x), 60)} | "
                     f"{s.entry} | {s.url} | {_cell(extra, 200)} |")
        L.append("")
    L.append("### まとめ記事")
    L.append("")
    if wp_title:
        L.append(f"- Wikipedia「{wp_title}」 https://ja.wikipedia.org/wiki/{urllib.parse.quote(wp_title)} — "
                 "手がかりだけ。出どころには数えない（記事の注にある本・論文を上の入口で探す）")
    L.append("")

    # 3. 食い違い
    L.append("## 3. 食い違い（同じ出来事で記録や説が割れているもの。1本に1〜3回並べる）")
    L.append("")
    L.append("| 出来事 | 記録A（誰が・いつ・何に） | 記録B（誰が・いつ・何に） | どう違う | 確かめた URL |")
    L.append("|---|---|---|---|---|")
    L.append("|  |  |  |  |  |")
    L.append("")
    hints = dispute_hints(full) if full else []
    if hints:
        L.append("手がかり（Wikipedia の本文で説が割れていそうな文。出どころを開くまで台本に使わない）：")
        L.append("")
        for h in hints:
            L.append(f"- {_cell(h, 220)}")
        L.append("")

    # 4. 手で開く入口
    L.append("## 4. 手で開く入口（道具は叩いていない。検索の URL だけ）")
    L.append("")
    L.append("| 入口 | 検索の URL | なぜ手で |")
    L.append("|---|---|---|")
    for name, url, why in manual_links(topic, keywords):
        L.append(f"| {name} | {url} | {why} |")
    L.append("")
    L.append("使わない入口：Gallica（Cloudflare の bot 判定で 403）・Perseus（503/405）・Europeana（wskey の登録が要る）。"
             "課金・ログインの要る DB（JapanKnowledge・新聞の有料 DB など）は使わない。")
    L.append("")
    return "\n".join(L)


def run(topic: str, keywords: list[str], phrases: list[str], facts: list[str], out_dir: Path,
        name: str = "", wiki_title: str = "", world: bool = False, fetcher: Fetcher = fetch,
        today: _dt.date | None = None) -> Path:
    today = today or _dt.date.today()
    title, intro, full, err = "", "", "", ""
    try:                                   # Wikipedia を先に（Wikisource を続けて叩いたあとだと 429 になった）
        title, intro = parse_wp(fetcher(wp_url(wiki_title or topic, intro=True)))
        if title:
            time.sleep(WAIT if fetcher is fetch else 0)
            _, full = parse_wp(fetcher(wp_url(title, intro=False)))
    except Exception as e:  # noqa: BLE001
        err = f"{type(e).__name__} {str(e)[:120]}"
    results = collect(topic, keywords, phrases, fetcher=fetcher, world=world)
    md = render_md(topic, results, [parse_fact(f) for f in facts], title, intro, full, keywords, today, err)
    out_dir.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r'[\\/:*?"<>|\s]+', "_", name or topic)
    path = out_dir / f"{safe}_sources_{today.strftime('%Y%m%d')}.md"
    path.write_text(md, encoding="utf-8")
    return path
