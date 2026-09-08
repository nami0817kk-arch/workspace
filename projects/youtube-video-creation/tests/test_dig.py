"""題材から材料まで（2026-09-09）。検索フィードと Google ニュースを分けて使う。"""
from src import dig


def _rss(items):
    body = "".join(
        f"<item><title>{t}</title><link>{u}</link>"
        f"<source url='x'>{o}</source><pubDate>Mon, 08 Sep 2026 12:00:00 GMT</pubDate></item>"
        for t, u, o in items
    )
    return f"<rss version='2.0'><channel>{body}</channel></rss>"


class _Resp:
    def __init__(self, text):
        self.text = text


class _Session:
    """検索フィードは実URL、Google ニュースは google.com のリンクを返す。"""

    def __init__(self):
        self.asked = []

    def get(self, url, **kw):
        self.asked.append(url)
        if "news.google.com" in url:
            return _Resp(_rss([
                ("久保建英、今季初の出番なし", "https://news.google.com/rss/articles/AAA", "時事通信"),
                ("ソシエダ3-2で勝利", "https://news.google.com/rss/articles/BBB", "サッカーキング"),
            ]))
        if "footballchannel" in url:
            return _Resp(_rss([
                ("久保建英のライバルが満点評価", "https://www.footballchannel.jp/2026/09/08/post1/", "fc"),
                ("関係のない記事", "https://www.footballchannel.jp/2026/09/08/post2/", "fc"),
            ]))
        if "ultra-soccer" in url:
            # 許可されていないサイトのリンクが混ざる場合
            return _Resp(_rss([
                ("久保建英、今季初の出番なし", "https://web.ultra-soccer.jp/news/all/1/?utm_source=rss", "us"),
                ("久保建英の記事", "https://example.com/x", "他"),
            ]))
        return _Resp(_rss([]))


HOSTS = {"www.footballchannel.jp", "web.ultra-soccer.jp"}


def test_検索フィードから実URLだけを拾う():
    hits = dig.search("久保建英", HOSTS, _Session())
    urls = [h.url for h in hits]
    assert "https://www.footballchannel.jp/2026/09/08/post1/" in urls
    assert "https://web.ultra-soccer.jp/news/all/1/" in urls      # ?utm_source= は落とす
    assert not any("example.com" in u for u in urls)              # 許可サイト外は捨てる
    assert not any("post2" in u for u in urls)                    # 題材語が無い見出しは捨てる


def test_Googleニュースは媒体の数だけ数える():
    got = dig.coverage("久保建英", "Takefusa Kubo", _Session())
    assert got.total == 4                                          # 日本語2 + 英語2
    assert ("時事通信", 2) in got.outlets
    assert got.headlines[0][0] == "時事通信"


def test_英語の語を渡すと英語でも引く():
    session = _Session()
    dig.coverage("久保建英", "Takefusa Kubo", session)
    assert any("hl=en-GB" in u for u in session.asked)
    assert any("hl=ja" in u for u in session.asked)


def test_材料の1枚に大きさと記事と反応が並ぶ():
    session = _Session()
    got = dig.coverage("久保建英", "", session)
    hits = dig.search("久保建英", HOSTS, session)
    text = dig.render("久保建英", got, hits, "## 発言", "- {voice: ネット民, text: まだ序盤}")
    assert "# 材料: 久保建英" in text
    assert "話の大きさ" in text and "本文を読んだ記事" in text and "## 反応" in text
