"""chiso/research.py：入口ごとの応答の読み取り・段・知らない度・書き出し（ネットに出ない。応答は 10-25 に実際に返った形を縮めたもの）。"""
import datetime as dt
import json

from chiso import research as R

NDL_XML = """<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcndl="http://ndl.go.jp/dcndl/terms/" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
 xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="2.0">
<channel><title>t</title>
<item>
  <title>瑞鳳殿伊達政宗の墓とその遺品</title>
  <link>https://ndlsearch.ndl.go.jp/books/R100000002-I000001501880</link>
  <author>伊東, 信雄, 1908-1987,伊東信雄 編</author>
  <category>図書</category><category>紙</category>
  <dc:publisher>瑞鳳殿再建期成会</dc:publisher>
  <dcterms:issued>1979.3</dcterms:issued>
  <rdfs:seeAlso rdf:resource="https://dl.ndl.go.jp/pid/12262728"/>
</item>
<item>
  <title>遺骨</title>
  <link>https://ndlsearch.ndl.go.jp/books/R100000136-I1571698599247269120</link>
  <author>鈴木尚</author>
  <category>記事</category><category>紙</category>
  <dcterms:issued>1979</dcterms:issued>
  <dc:description>掲載誌：瑞鳳殿伊達政宗の墓とその遺品 1979</dc:description>
</item>
<item>
  <title>伊達氏史料 5輯144卷</title>
  <link>https://ndlsearch.ndl.go.jp/books/R000000054-I040_50736</link>
  <category>和古書・漢籍</category>
  <dcterms:issued>1888</dcterms:issued>
</item>
<item>
  <title>暴かれた伊達政宗「幕府転覆計画」 : ヴァティカン機密文書館史料による結論</title>
  <link>https://ndlsearch.ndl.go.jp/books/R100000002-I028486353</link>
  <author>大泉光一 著</author><category>図書</category>
  <dc:publisher>文藝春秋</dc:publisher><dcterms:issued>2017.6</dcterms:issued>
</item>
</channel></rss>"""

LAB_JSON = json.dumps({"hit": 2, "list": [
    {"id": "1218608", "title": "郷土誌漫筆", "volume": "", "responsibility": "阿刀田令造 著",
     "publisher": "仙台郷土研究会出版部", "published": "1936", "publishyear": 1936,
     "highlights": ["<em>瑞鳳殿</em>の十字模樣&#x2F;168  (0093.jp2)"]},
    {"id": "1880040", "title": "伊達政宗卿伝記史料", "volume": "", "responsibility": "藩祖伊達政宗公顕彰会 編",
     "publisher": "藩祖伊達政宗公顕彰会", "publishyear": 1938, "highlights": ["大御所於江戶伊達<em>政宗</em>"]},
]})

JSTAGE_XML = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:prism="http://prismstandard.org/namespaces/basic/2.0/" xml:lang="ja">
  <entry>
    <article_title><en/><ja><![CDATA[伊達政宗の絶縁状]]></ja></article_title>
    <article_link><en>https://www.jstage.jst.go.jp/article/kokutand/37/0/37_25/_article</en>
      <ja>https://www.jstage.jst.go.jp/article/kokutand/37/0/37_25/_article/-char/ja/</ja></article_link>
    <author><en/><ja><name><![CDATA[堀越 祐一]]></name></ja></author>
    <material_title><en><![CDATA[Takikawakokubun]]></en><ja><![CDATA[滝川国文]]></ja></material_title>
    <prism:volume>37</prism:volume><prism:startingPage>25</prism:startingPage>
    <pubyear>2021</pubyear><prism:doi>10.24626/kokutand.37.0_25</prism:doi>
    <title><![CDATA[伊達政宗の絶縁状]]></title>
  </entry>
</feed>"""

JPS_JSON = json.dumps({"hit": 2, "list": [
    {"id": "cobas-1", "common": {"title": "伊達政宗消息", "linkUrl": "https://colbase.nich.go.jp/collection_items/kyohaku/B%E7%94%B239",
                                 "category": ["cultural", "art"], "contentsRightsType": "ccby", "database": "cobas",
                                 "provider": "京都国立博物館 Kyoto National Museum", "temporal": ["桃山時代・17世紀"],
                                 "contentsType": "image", "description": "土井利勝に宛てた消息。"}},
    {"id": "fcm-1", "common": {"title": "絵葉書｢国史に輝く英傑肖像集｣伊達政宗", "linkUrl": "https://jmapps.ne.jp/fukuokacity/det.html?data_id=65048",
                               "category": ["cultural"], "contentsRightsType": "uneval", "database": "fcm_db"}},
]})

WS_JSON = json.dumps({"query": {"search": [
    {"title": "命期集", "snippet": "仙台藩祖・<span class=\"searchmatch\">伊達政宗</span>の晩年の言行録"}]}})

WP_INTRO = json.dumps({"query": {"pages": [{"title": "伊達政宗",
                                            "extract": "伊達政宗は、出羽国と陸奥国の武将・戦国大名。仙台藩の初代藩主。"}]}})
WP_FULL = json.dumps({"query": {"pages": [{"title": "伊達政宗", "extract":
    "伊達政宗は、出羽国と陸奥国の武将・戦国大名。仙台藩の初代藩主。幼いころ疱瘡を患い右目を失明した。"
    "1974年に政宗の遺骨を調査したときに骨折跡が確認されている。生誕地は館山城であるが米沢城とする学説もある。"}]}})


def test_ndl_reads_items_digital_and_journal():
    got = R.parse_ndl(NDL_XML)
    assert [s.title for s in got][:2] == ["瑞鳳殿伊達政宗の墓とその遺品", "遺骨"]
    report, chapter, kosho, book = got
    assert report.year == 1979 and "瑞鳳殿再建期成会" in report.who
    assert "https://dl.ndl.go.jp/pid/12262728" in report.note
    assert report.tier == "公的機関の発表"                # 発掘の報告書
    assert chapter.where == "瑞鳳殿伊達政宗の墓とその遺品"   # 掲載誌（報告書の中の章）
    assert chapter.tier == "公的機関の発表" and "CiNii" in chapter.note
    assert kosho.tier == "一次史料"                        # 和古書
    assert book.tier != "一次史料"                         # 「史料による結論」は史料ではない
    assert book.is_new and not report.is_new


def test_ndl_urls_build():
    assert "from=2015" in R.ndl_url("伊達政宗 遺言", 5, 2015)
    assert "%E4%BC%8A%E9%81%94" in R.ndl_url("伊達", 5)


def test_lab_reads_page_links_and_tiers():
    got = R.parse_lab(LAB_JSON)
    assert got[0].url == "https://dl.ndl.go.jp/pid/1218608/1/93"     # ハイライトの頁へ
    assert got[0].snippet.startswith("瑞鳳殿の十字模樣")
    assert got[1].url == "https://dl.ndl.go.jp/pid/1880040" and got[1].tier == "一次史料"
    assert R.lab_hits(LAB_JSON) == 2


def test_jstage_reads_entry():
    (s,) = R.parse_jstage(JSTAGE_XML)
    assert s.title == "伊達政宗の絶縁状" and s.year == 2021 and s.who == "堀越 祐一"
    assert s.url.endswith("/-char/ja/") and "DOI 10.24626" in s.note and s.tier == "研究・論文"
    assert "滝川国文 37巻 p.25" == s.where
    assert "article=" in R.jstage_url("伊達政宗") and "pubyearfrom=2015" in R.jstage_url("x", field="text", year_from=2015)


def test_japansearch_rights_and_tiers():
    letter, card = R.parse_jps(JPS_JSON)
    assert letter.tier == "一次史料" and "CC BY" in letter.note and letter.year is None
    assert letter.url.startswith("https://colbase.nich.go.jp/")
    assert card.tier != "一次史料" and "未評価" in card.note        # 絵葉書は現物の史料ではない


def test_wikisource_and_wikipedia():
    (s,) = R.parse_ws(WS_JSON)
    assert s.url == "https://ja.wikisource.org/wiki/%E5%91%BD%E6%9C%9F%E9%9B%86" and "晩年の言行録" in s.snippet
    assert R.parse_wp(WP_INTRO)[0] == "伊達政宗"
    assert R.parse_wp(json.dumps({"query": {"pages": [{"title": "x", "missing": True}]}})) == ("", "")


def test_known_level():
    _, intro = R.parse_wp(WP_INTRO)
    _, full = R.parse_wp(WP_FULL)
    a = R.known_level(R.parse_fact("仙台藩の初代藩主"), intro, full)
    assert a[0] == "出る" and a[2].startswith("誰でも知っている")
    b = R.known_level(R.parse_fact("1974年に遺骨を調査::1974 遺骨"), intro, full)
    assert b[:2] == ("出ない", "出る") and "記事の奥" in b[2]
    c = R.known_level(R.parse_fact("肖像に眼帯は無い::肖像 眼帯"), intro, full)
    assert c[1] == "出ない" and "高" in c[2]
    d = R.known_level(R.parse_fact("x::疱瘡 眼帯"), intro, full)
    assert d[1].startswith("一部") and "眼帯" in d[1]


def test_old_kanji_matches():
    assert R.norm("兩眼") == R.norm("両眼")


def test_dispute_hints():
    _, full = R.parse_wp(WP_FULL)
    assert any("米沢城とする学説" in h for h in R.dispute_hints(full))


def test_sort_new_first():
    items = [R.Source("a", "u1", "x", year=1979), R.Source("b", "u2", "x"), R.Source("c", "u3", "x", year=2017),
             R.Source("d", "u4", "x", year=2024), R.Source("e", "u5", "x", year=2001)]
    assert [s.title for s in R.sort_sources(items)] == ["d", "c", "e", "a", "b"]


def test_primary_title():
    assert R.is_primary_title("伊達政宗卿伝記史料")
    assert R.is_primary_title("伊達氏史料 5輯144卷")
    assert not R.is_primary_title("伊達政宗と時代劇メディア : 時代考証学会第4回フォーラムin仙台記録集")


def test_run_offline_writes_md_only_with_returned_urls(tmp_path, monkeypatch):
    monkeypatch.setattr(R.time, "sleep", lambda s: None)

    def fake(url: str) -> str:
        if "wikipedia.org" in url:
            return WP_INTRO if "exintro" in url else WP_FULL
        if "ndlsearch" in url:
            return NDL_XML
        if "lab.ndl.go.jp" in url:
            return LAB_JSON
        if "jstage" in url:
            raise OSError("つながらない")                    # 取れなかった入口
        if "jpsearch" in url:
            return JPS_JSON
        if "wikisource" in url:
            return WS_JSON
        raise AssertionError(url)

    p = R.run("伊達政宗", ["遺骨"], ["政宗の木像"], ["1974年に遺骨を調査::1974 遺骨"], tmp_path,
              fetcher=fake, today=dt.date(2026, 10, 25))
    assert p.name == "伊達政宗_sources_20261025.md"
    md = p.read_text(encoding="utf-8")
    assert "| J-STAGE |" in md and "OSError つながらない" in md
    assert "記事の奥" in md
    assert "★2017" in md
    assert "https://dl.ndl.go.jp/pid/1880040" in md
    assert "https://dl.ndl.go.jp/pid/1218608/1/93" not in md            # 全文検索で主題の語が無いものは落とす
    assert "米沢城とする学説" in md                                     # 食い違いの手がかり
    assert "jstage.jst.go.jp/article" not in md                         # 取れなかった入口の URL は出さない
    assert md.count("| 瑞鳳殿伊達政宗の墓とその遺品 |") == 1              # 入口をまたいだ重複は1つ
