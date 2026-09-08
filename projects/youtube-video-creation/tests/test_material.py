"""記事本文から材料を抜く（2026-09-08）。"""
from src import material


PAGE = (
    "<html><head><title>久保建英、ベンチの理由 | 例</title></head><body>"
    "<nav><p>メニューのリンクが並ぶところですがこれは本文ではありません</p></nav>"
    "<p>レアル・ソシエダは10人になりながらも1-0で勝った。久保建英は90分ベンチだった。</p>"
    "<p>試合後、監督は「戦術的な判断だ。彼は次の試合で必要になる」と語った。</p>"
    "<p>今季初の出番なし。代わりに入ったオチエンは1ゴール2アシストを記録した。</p>"
    "<p>短い</p>"
    "<script>var x = 1;</script>"
    "</body></html>"
)


def test_本文の段落だけ拾い題名を読む():
    title, paragraphs = material.to_text(PAGE)
    assert title.startswith("久保建英、ベンチの理由")
    assert len(paragraphs) == 3                      # nav と短い段落と script は入らない
    assert paragraphs[0].startswith("レアル・ソシエダ")


def test_発言と数字を分けて抜く():
    _, paragraphs = material.to_text(PAGE)
    quotes, numbers = material.extract(paragraphs)
    assert quotes == ["戦術的な判断だ。彼は次の試合で必要になる"]
    assert any("1-0" in n for n in numbers)
    assert any("1ゴール2アシスト" in n for n in numbers)
    assert not any("戦術的な判断" in n for n in numbers)   # 数字の無い文は数字に入らない


def test_許可サイトだけ読む():
    hosts = material.allowed_hosts({"japanese": ["soccer-king.jp"], "blocked": ["talksport.com"]})
    assert material.is_allowed("https://www.soccer-king.jp/news/1", hosts)
    assert not material.is_allowed("https://talksport.com/x", hosts)
    assert not material.is_allowed("https://example.com/x", hosts)


def test_読めない出典は理由を残して続ける():
    class _Session:
        def get(self, url, **kw):
            raise RuntimeError("timeout")

    hosts = {"soccer-king.jp"}
    items = material.gather(["https://soccer-king.jp/a", "https://example.com/b"], hosts, _Session())
    assert [i.note[:4] for i in items] == ["読めませ", "許可サイ"]
    text = material.render(items, "見出し")
    assert "# 材料: 見出し" in text and "soccer-king.jp" in text


def test_記事の枠があればその中だけ読む():
    """Yahoo は関連記事の見出しも <p> で並べる。久保の記事に他の記事の発言が混ざった。"""
    page = (
        "<html><body><p>関連: 「ほぼヤマルやん」16歳Jリーガーのドリブルにネット騒然という見出し</p>"
        "<article><p>久保建英は今季初めて出番がなかった。チームは3-2で競り勝った。</p>"
        "<p>監督は「戦術的な判断だ」と語った。</p></article>"
        "<p>ランキング1位: 「人質写真みたい」と話題の公式写真について</p></body></html>"
    )
    _, paragraphs = material.to_text(page)
    quotes, numbers = material.extract(paragraphs)
    assert quotes == ["戦術的な判断だ"]
    assert not any("ヤマル" in p or "人質" in p for p in paragraphs)
