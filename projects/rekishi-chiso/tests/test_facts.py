"""事実カード・検索の計画・芋づる・他チャンネルの既出・台本との突き合わせ（10-26。ネットに出ない。応答は実際に返った形を縮めたもの）。"""
import datetime as dt
import json
from pathlib import Path

import yaml

from chiso import expand as E
from chiso import facts as F
from chiso import factcheck as FC
from chiso import research as R
from chiso import ytseen as Y

IA_JSON = json.dumps({"response": {"body": {"hits": {"total": 2, "hits": [
    {"fields": {"identifier": "in.ernet.dli.2015.70908", "title": "Transactions The Asiatic Society Of Japan Vol.21 (1893)",
                "creator": ["R. Meiklejohn"], "year": 1893, "page_num": 336, "mediatype": "texts",
                "collection": ["digitallibraryindia"]},
     "highlight": {"text": ["A LETTER FROM {{{DATE MASAMUNE}}} TO THE KING OF SPAIN. The embassy to Rome"]}},
    {"fields": {"identifier": "samuraiofseville0000heal", "title": "Samurai of Seville", "year": 2016, "page_num": 1,
                "mediatype": "texts", "collection": ["internetarchivebooks", "inlibrary"]},
     "highlight": {"text": ["{{{Date Masamune}}}, was known as Dokuganryu"]}},
]}}}})

NAJ_HTML = """<li><h3 id="row-1-title" class="result-header__title">
 <a href="https://www.digital.archives.go.jp/file/4666945" class="x">伊達政宗</a></h3>
 <div>明治17年 1884年</div></li>
<li><h3 id="row-2-title" class="result-header__title"><a href="/item/123">命期集</a></h3></li>"""

KOTO_HTML = """<article class="daijisen"><h2><a href="/dictionary/daijisen/">デジタル大辞泉</a><span>x</span></h2>
<p>幼時に右眼を失明し独眼竜と称された。</p></article>
<article class="nipponica"><h2><a href="/d/">日本大百科全書(ニッポニカ)</a></h2><p>疱瘡で右目を失う。慶長遣欧使節を送る。</p></article>"""

LAB_FULL = json.dumps({"list": [
    {"page": 12, "contents": "仙臺藩祖の事 政宗公は"},
    {"page": 93, "contents": "瑞鳳殿の發掘は昭和四十九年 一九七四年に行はれ 政宗の遺骨を調べた"},
]})

WIKITEXT = """'''伊達 政宗'''、幼名は梵天丸、通称は藤次郎。永禄10年8月3日（1567年9月5日）生まれ。永禄10年8月3日。
『伊達治家記録』によれば…『伊達治家記録』『命期集』
<ref>{{Cite book|和書|author=[[小林清治]]|year=1985|title=伊達政宗|publisher=吉川弘文館}}</ref>
<ref>{{Cite journal|和書|author=中野等|title=豊臣政権の関東・奥羽仕置（続論）|journal=九州文化史研究所紀要|year=2015}}</ref>
* 藩祖伊達政宗公顕彰会『伊達政宗卿伝記史料』
"""

JSTAGE_PAGE = """<meta name="citation_reference" content="1) 『大日本古文書　家わけ第三　伊達家文書』675" />
<meta name="citation_reference" content="3) 津野倫明「豊臣政権における『取次』の機能」（『日本歴史』591号、1997年）" />
<meta name="citation_abstract" content="政宗が1974年の発掘で…" />"""


def test_ia_and_naj_and_kotobank():
    pub, lend = R.parse_ia(IA_JSON)
    assert pub.url == "https://archive.org/details/in.ernet.dli.2015.70908/page/n336" and pub.year == 1893
    assert "KING OF SPAIN" in pub.snippet and "{{{" not in pub.snippet and "公開" in pub.note
    assert "ログイン" in lend.note
    a, b = R.parse_naj(NAJ_HTML)
    assert a.url.endswith("/file/4666945") and a.year == 1884 and a.tier == "一次史料"
    assert b.url == "https://www.digital.archives.go.jp/item/123"
    d = R.parse_kotobank(KOTO_HTML)
    assert list(d) == ["デジタル大辞泉", "日本大百科全書(ニッポニカ)"]
    assert R.dictionary_level(R.Fact("x", ["疱瘡", "右目"]), d) == ["日本大百科全書(ニッポニカ)"]
    assert R.parse_lab_fulltext(LAB_FULL)[1][0] == 93
    assert R.parse_fact("a::b c::eye patch").terms == ["b", "c"]


def test_plan_aliases_dates_titles_and_queries():
    full = "伊達政宗は、幼名は梵天丸。通称は藤次郎。永禄10年8月3日に生まれ、寛永13年5月24日に没した。永禄10年8月3日。『伊達治家記録』と『命期集』。『伊達治家記録』"
    assert E.aliases_from_text(full)[:2] == ["梵天丸", "藤次郎"]
    assert E.wareki_dates(full)[0] == "永禄10年8月3日"
    assert E.source_titles(full)[0] == "伊達治家記録"
    assert E.old_form("独眼竜") == "獨眼龍"
    ent = json.dumps({"entities": {"Q1": {"labels": {"en": {"value": "Date Masamune"}},
                                          "aliases": {"ja": [{"value": "貞山公"}], "en": [{"value": "One-Eyed Dragon"}]},
                                          "sitelinks": {"enwiki": {"title": "Date Masamune"}}}}})
    en, ja, enwiki = E.parse_entity(ent, "Q1")
    assert en == ["Date Masamune", "One-Eyed Dragon"] and ja == ["貞山公"] and enwiki == "Date Masamune"

    def fake(url):
        if "wbsearchentities" in url:
            return json.dumps({"search": [{"id": "Q1"}]})
        return ent
    plan = E.build_plan("伊達政宗", full, WIKITEXT, fetcher=fake)
    assert plan.qid == "Q1" and "貞山公" in plan.aliases and "梵天丸" in plan.aliases and "小林清治" in plan.scholars
    qs = E.site_queries(plan, ["1974 発掘"])
    assert set(qs) == set(E.KINDS) and any("site:ac.jp" in q for q in qs["学術"])
    assert all(q.startswith('"Date Masamune"') for q in qs["英語圏"])
    assert any("1974 発掘" in q for q in qs["報道"])
    md = E.render_plan(plan, qs)
    assert "Python から検索エンジンは叩かない" in md and "`伊達政宗 site:go.jp`" in md


def test_citations_and_chain_two_levels():
    cites = E.wiki_citations(WIKITEXT)
    titles = [c.title for c in cites]
    assert "伊達政宗" in titles and "豊臣政権の関東・奥羽仕置（続論）" in titles and "伊達政宗卿伝記史料" in titles
    refs = E.jstage_references(JSTAGE_PAGE, "参考文献 u")
    assert refs[0].title.startswith("大日本古文書") and len(refs) == 2
    assert E.jstage_abstract(JSTAGE_PAGE).startswith("政宗が1974年")
    hit = """<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><entry>
      <article_title><ja>豊臣政権の関東・奥羽仕置（続論）</ja></article_title>
      <article_link><ja>https://www.jstage.jst.go.jp/article/x/1/0/1_1/_article/-char/ja/</ja></article_link>
      <pubyear>2015</pubyear></entry></feed>"""
    calls = []

    def fake(url):
        calls.append(url)
        if "searchapi" in url:
            return hit if "%E8%B1%8A%E8%87%A3" in url else "<feed xmlns='http://www.w3.org/2005/Atom'/>"
        if "ndlsearch" in url:
            return "<rss><channel></channel></rss>"
        if "/_pdf" in url:
            raise AssertionError("PDF は叩かない")
        if "/article/x/" in url:                                             # 1段目で当たった論文の頁＝2段目の参考文献
            return '<meta name="citation_reference" content="5) 『仙台藩の成立』1990年" />'
        return JSTAGE_PAGE
    out, found, errors = E.chain(["https://www.jstage.jst.go.jp/article/seed/_article/-char/ja/"], WIKITEXT,
                                 {"伊達政宗"}, "伊達政宗", fetcher=fake)
    assert "伊達政宗" not in [c.title for c in out]                       # 一覧にもうある題は落とす
    assert [c.title for c in out if c.depth == 2] == ["仙台藩の成立"]
    assert found and "芋づる1段" in found[0].note
    assert "## 5. 芋づる" in E.render_chain(out, found, errors)


def test_find_window_and_match_pages():
    t = R.norm("政宗の遺骨は一九七四年の発掘で見つかった")
    assert F.find_window(t, [R.norm("一九七四"), R.norm("発掘")]) >= 0
    assert F.find_window(t + "x" * 400 + "眼帯", [R.norm("発掘"), R.norm("眼帯")]) == -1     # 離れすぎ
    pages = R.parse_lab_fulltext(LAB_FULL)
    page, q = F.match_pages(pages, ["1974", "發掘"], ["政宗"])
    assert page == 93 and "1974" in q
    assert F.match_pages(pages, ["1974", "発掘"], ["信長"]) is None                         # 主題の名前が無い頁は落とす


def test_parse_spec_and_card_counts(tmp_path):
    sp = F.parse_spec("1974年に墓を発掘::1974 発掘::excavation", "masamune", 3)
    assert sp.id == "masamune-03" and sp.terms == ["1974", "発掘"] and sp.en_terms == ["excavation"]
    src_lab = R.Source("瑞鳳殿伊達政宗の墓とその遺品", "https://dl.ndl.go.jp/pid/12262728", "NDLデジタル全文", tier="公的機関の発表")
    src_lab2 = R.Source("瑞鳳殿伊達政宗の墓とその遺品 2", "https://dl.ndl.go.jp/pid/12262729", "NDLデジタル全文", tier="公的機関の発表")
    src_js = R.Source("瑞鳳殿の発掘と政宗", "https://www.jstage.jst.go.jp/article/a/_article/-char/ja/", "J-STAGE", tier="研究・論文")
    bodies = [F.Body(src_lab, R.parse_lab_fulltext(LAB_FULL), "本文"), F.Body(src_lab2, R.parse_lab_fulltext(LAB_FULL), "本文"),
              F.Body(src_js, [(None, "政宗の墓は1974年に発掘された")], "要旨")]
    ev = F.evidence_for(sp, bodies, [src_lab, src_js], ["政宗"])
    assert ev[0].opened == "本文" and ev[0].url == "https://dl.ndl.go.jp/pid/12262728/1/93" and ev[0].page == 93
    assert len(ev) == 2                                                      # 巻違いは1つ
    card = F.Card(sp, ev)
    assert card.independent == 2 and card.opened_body
    card.wikipedia = "知る人は知る（記事の奥）"
    assert card.unknown == "中"
    lone = F.Card(F.parse_spec("x::土佐光貞", "m", 4), [ev[1]])
    assert lone.independent == 1 and lone.unknown == "高"
    agents = tmp_path / "agents.yaml"
    agents.write_text(yaml.safe_dump({"facts": [
        {"id": "m-04", "sources": [{"title": "仙台市博物館 収蔵品", "url": "https://www.city.sendai.jp/museum/x", "opened": "本文",
                                    "quote": "土佐光貞筆", "tier": "公的機関の発表"}]},
        {"claim": "新しい事実", "terms": ["新"], "sources": [{"title": "t", "url": "u", "opened": "本文"}]}]},
        allow_unicode=True), encoding="utf-8")
    cards = [card, lone]
    log = F.merge_cards_in(cards, agents, "m")
    assert lone.independent == 2 and len(cards) == 3 and "新しいカード m-03" in log[0]
    p = tmp_path / "f.yaml"
    card.youtube = {"verdict": "まだ扱われていない"}
    F.write_yaml("伊達政宗", cards, p, 303, {}, [], dt.date(2026, 10, 26))
    data = yaml.safe_load(p.read_text(encoding="utf-8"))
    assert data["counts"] == {"facts": 3, "opened_body": 3, "two_or_more": 2, "not_on_youtube": 1}
    first = data["facts"][0]
    assert first["id"] == "masamune-03" and first["single_source"] is False and first["sources"][0]["page"] == 93
    assert set(F.load_cards(p)) == {"masamune-03", "m-04", "m-03"}


def test_youtube_seen_budget_and_cache():
    search = json.dumps({"items": [
        {"id": {"videoId": "a"}, "snippet": {"title": "伊達政宗の遺骨の発掘", "description": "1974年", "channelTitle": "c1"}},
        {"id": {"videoId": "b"}, "snippet": {"title": "伊達政宗 解説", "description": "", "channelTitle": "c2"}}]})
    views = json.dumps({"items": [{"id": "a", "statistics": {"viewCount": "1200"}}, {"id": "b", "statistics": {"viewCount": "5"}}]})
    calls = []

    def get(url):
        calls.append(url)
        return search if "/search?" in url else views
    b, cache = Y.Budget(250), {}
    s = Y.seen("伊達政宗 1974 発掘", ["1974", "発掘"], get, b, cache=cache)
    assert (s.total, s.matched, s.views, s.verdict) == (2, 1, 1200, "少し扱われている") and b.used == 101
    s2 = Y.seen("伊達政宗 1974 発掘", ["1974", "発掘"], get, b, cache=cache)       # 2回目は単位を使わない
    assert b.used == 101 and len(calls) == 2 and s2.matched == 1
    assert Y.seen("伊達政宗 土佐光貞", ["土佐光貞"], get, b).verdict == "まだ扱われていない"
    assert Y.seen("q", [], get, b).error.startswith("単位の上限")                 # 250 を超える
    assert "readonly" not in Y.SEARCH                                              # 検索は読み取りだけの呼び出し


STORY = """title: 伊達政宗｜テスト
story: true
facts: m_facts.yaml
sections:
  - title: 導入
    lines:
      # fact: m-01
      - 語り: 1974年、政宗の墓が開かれました。
      - 語り: 身長は、159センチでした。  # fact: m-02
      - 語り: 肖像には、眼帯がありません。
        # fact: m-03
      - 語り: 次の話です。
      # fact: ?
      - 語り: 謎の話。
      # fact: m-09
      - 語り: 無い ID。
"""


def _cards(tmp_path):
    data = {"facts": [
        {"id": "m-01", "claim": "1974年に発掘", "independent": 2, "opened_body": True, "unknown": "中"},
        {"id": "m-02", "claim": "身長159", "independent": 1, "opened_body": False, "unknown": "高"},
        {"id": "m-03", "claim": "眼帯なし", "independent": 1, "opened_body": False, "unknown": "高"}]}
    (tmp_path / "m_facts.yaml").write_text(yaml.safe_dump(data, allow_unicode=True), encoding="utf-8")


def test_factcheck_rules(tmp_path):
    from chiso import script as S
    _cards(tmp_path)
    sc = S.parse(yaml.safe_load(STORY), tmp_path / "x.yaml")
    links = FC.fact_links(STORY)
    assert links == {0: ["m-01"], 1: ["m-02"], 2: ["m-03"], 4: ["?"], 5: ["m-09"]}
    w = FC.check(sc, STORY, tmp_path)
    assert any("2行目 の m-02 は本文を開いておらず" in x for x in w)
    assert any("3行目 の m-03" in x for x in w)
    assert not any("1行目 の m-01" in x for x in w)                                    # 本文を開いた・出どころ2つ
    assert any("5行目 が事実カードにつながっていません" in x for x in w)
    assert any("6行目 の m-09 がカードにありません" in x for x in w)
    last = [x for x in w if "冒頭3分" in x][0]
    assert "足りない" in last and "4個" in last
    hedged = STORY.replace("身長は、159センチでした。", "身長は、159センチだったと伝わります。")
    sc2 = S.parse(yaml.safe_load(hedged), tmp_path / "x.yaml")
    assert not any("m-02" in x for x in FC.check(sc2, hedged, tmp_path))
    assert FC.summary(sc, STORY, tmp_path)[0].startswith("0:00 1行目 m-01 独立2 本文○")


def test_factcheck_skips_scripts_without_cards():
    text = Path(__file__).resolve().parent.parent.joinpath("scripts", "oichi-story.yaml").read_text(encoding="utf-8")
    from chiso import script as S
    sc = S.parse(yaml.safe_load(text), Path("oichi-story.yaml"))
    assert FC.check(sc, text, Path("nowhere")) == []


def test_factcheck_missing_yaml_only_warns(tmp_path):
    from chiso import script as S
    sc = S.parse(yaml.safe_load(STORY), tmp_path / "x.yaml")
    w = FC.check(sc, STORY, tmp_path)                                                   # m_facts.yaml を作っていない
    assert w[0].startswith("事実：カードの YAML が見つかりません")


def test_run_offline_with_cards_plan_chain_and_youtube(tmp_path, monkeypatch):
    monkeypatch.setattr(R.time, "sleep", lambda s: None)
    monkeypatch.setattr(F.time, "sleep", lambda s: None)
    monkeypatch.setattr(E.time, "sleep", lambda s: None)
    monkeypatch.setattr(Y.time, "sleep", lambda s: None)
    from tests.test_research import NDL_XML, LAB_JSON, JSTAGE_XML, JPS_JSON, WS_JSON, WP_INTRO, WP_FULL

    def fake(url: str) -> str:
        if "wikidata" in url:
            return json.dumps({"search": [{"id": "Q1"}]}) if "wbsearch" in url else json.dumps(
                {"entities": {"Q1": {"labels": {"en": {"value": "Date Masamune"}}, "aliases": {"ja": [{"value": "貞山公"}]}}}})
        if "action=parse" in url and "wikipedia" in url:
            return json.dumps({"parse": {"wikitext": WIKITEXT}})
        if "wikipedia.org" in url:
            return WP_INTRO if "exintro" in url else WP_FULL
        if "action=parse" in url and "wikisource" in url:
            return json.dumps({"parse": {"wikitext": "政宗の遺骨は1974年に発掘"}})
        if "ndlsearch" in url:
            return NDL_XML
        if "fulltext-json" in url:
            return LAB_FULL
        if "lab.ndl.go.jp" in url:
            return LAB_JSON
        if "searchapi" in url:
            return JSTAGE_XML
        if "jstage.jst.go.jp/article" in url:
            return JSTAGE_PAGE
        if "jpsearch" in url:
            return JPS_JSON
        if "wikisource" in url:
            return WS_JSON
        if "archive.org" in url:
            return IA_JSON
        if "digital.archives.go.jp" in url:
            return NAJ_HTML
        if "kotobank" in url:
            return KOTO_HTML
        if "suggestqueries" in url:
            return json.dumps(["伊達政宗", ["伊達政宗 子孫", "伊達政宗 眼帯"]])
        raise AssertionError(url)

    def yt(url):
        if "/search?" in url:
            return json.dumps({"items": [{"id": {"videoId": "a"}, "snippet": {"title": "伊達政宗", "description": "", "channelTitle": "c"}}]})
        return json.dumps({"items": [{"id": "a", "statistics": {"viewCount": "10"}}]})

    printed = []
    p = R.run("伊達政宗", ["遺骨"], ["政宗の木像"], ["1974年に遺骨を調査::1974 發掘", "隻眼の像::土佐光貞"], tmp_path,
              fetcher=fake, today=dt.date(2026, 10, 26), slug="masamune", cards=True, yt=True, yt_fetcher=yt,
              plan=True, chain=True, log=printed.append)
    md = p.read_text(encoding="utf-8")
    assert "## 6. 事実カード" in md and "## 5. 芋づる" in md and "| Internet Archive（全文） |" in md
    y = yaml.safe_load((tmp_path / "伊達政宗_facts_20261026.yaml").read_text(encoding="utf-8"))
    one, two = y["facts"]
    assert one["id"] == "masamune-01" and one["opened_body"] and one["sources"][0]["page"] == 93
    assert two["youtube"]["verdict"] == "まだ扱われていない" and y["youtube_units"] == 303      # 題材1回＋事実2回
    assert y["demand"]["伊達政宗"] == ["伊達政宗 子孫", "伊達政宗 眼帯"]
    assert (tmp_path / "伊達政宗_plan_20261026.md").exists()
    assert any("YouTube Data API の単位：303" in x for x in printed)
