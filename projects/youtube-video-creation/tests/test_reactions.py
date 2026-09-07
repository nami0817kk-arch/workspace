"""まとめスレからの書き込みの取り出しと、数え上げ。"""

SAMPLE = """
<div class="article-body">
1:<br>阿弥陀ヶ峰 ★<br>2026/09/03(木) 12:09:02.99 ID:xDr2IcoH9<br>
https://news.yahoo.co.jp/articles/abc<br>
172:<br>名無しさん＠恐縮です<br>2026/09/03(木) 13:12:02.99 ID:Vm65lWHc0<br>
&gt;&gt;1<br>みずほがスポンサーなのにシンガポールでやんの？<br>
190:<br>名無しさん＠恐縮です<br>2026/09/03(木) 13:19:44.52 ID:OK1mgXit0<br>
日本より広告価値有るんだろ<br>
231:<br>名無しさん＠恐縮です<br>2026/09/03(木) 13:44:00.10 ID:AbCdEf00<br>
まだ森保なのかよと思うと萎える<br>
</div>
"""


def test_書き込みを番号つきで取り出す():
    from src.reactions import parse

    posts = parse(SAMPLE)

    assert [p.no for p in posts] == [172, 190, 231]
    assert posts[0].text == "みずほがスポンサーなのにシンガポールでやんの？"


def test_アンカーとURLは落とす():
    from src.reactions import parse

    posts = parse(SAMPLE)

    assert not any(">>" in p.text for p in posts)      # >>1 は消す
    assert not any("http" in p.text for p in posts)    # URLだけの行は捨てる


def test_数えた件数を返す():
    """「多い」と言うための根拠。数えなければ言わない。"""
    from src.reactions import parse, tally

    counts = tally(parse(SAMPLE), {"冷ややか": ("萎え", "意味ない"), "金の話": ("スポンサー", "広告")})

    assert counts["冷ややか"] == 1
    assert counts["金の話"] == 2


def test_同じ本文は1件にまとめる():
    from src.reactions import parse

    doubled = SAMPLE + SAMPLE
    posts = parse(doubled)

    assert len({p.text for p in posts}) == len(posts)


def test_短すぎる書き込みと広告は捨てる():
    from src.reactions import parse

    noisy = SAMPLE.replace("日本より広告価値有るんだろ", "(adsbygoogle = window.adsbygoogle || []).push({});")
    posts = parse(noisy)

    assert all("adsbygoogle" not in p.text for p in posts)


# まとめサイトによってレスの書き方が違う（2026-09-04 実測）。
#   footballnet   「172:」「名無しさん＠恐縮です」「2026/… ID:xxx」
#   football-2ch  「1」「名前：」「ゴアマガラ ★」「：2026/… ID:xxx」
# 番号のうしろのコロンは、あってもなくてもよい。

FOOTBALL_2CH = """
<div>
6<br>名前：<br>名無しさん＠恐縮です<br>：2026/09/04(金) 21:20:00.00 ID:AbC123<br>
意外といけるんだよそれが<br>
8<br>名前：<br>名無しさん＠恐縮です<br>：2026/09/04(金) 21:22:00.00 ID:DeF456<br>
モチベ無くなるからな<br>
</div>
"""


def test_コロンの無い書き方も読める():
    from src.reactions import parse

    posts = parse(FOOTBALL_2CH)

    assert [p.no for p in posts] == [6, 8]
    assert posts[0].text == "意外といけるんだよそれが"


def test_番号とIDの間に空行があっても読める():
    from src.reactions import parse

    spaced = FOOTBALL_2CH.replace("<br>名前：", "<br><br><br>名前：")
    posts = parse(spaced)

    assert [p.no for p in posts] == [6, 8]


# 読み上げに回す反応（2026-09-07）。カードに載せるだけでは画面が変わらない。
# 伸びている3チャンネルは尺の58%を他人の声に使い、1件2〜4秒で刻んでいた。

def test_読み上げに回すのは短いものだけ():
    from src.reactions import Post, say_lines

    posts = [
        Post(no=1, text="完全に別チームだった"),
        Post(no=2, text="あ"),                                   # 短すぎる
        Post(no=3, text="長い" * 40),                            # 長すぎる
        Post(no=4, text="中盤の圧力がすごい"),
    ]
    got = say_lines(posts)
    assert [p.text for p in got] == ["完全に別チームだった", "中盤の圧力がすごい"]


def test_長い書き込みでも一文で収まるなら使う():
    from src.reactions import Post, say_lines

    posts = [Post(no=7, text="これは強い。あとは怪我だけが心配で、"
                             "去年の終盤のように失速しないかどうかだと思う")]
    got = say_lines(posts)
    assert [p.text for p in got] == ["これは強い"]
    assert got[0].no == 7          # レス番号は残す（出典を辿れるように）


def test_件数の上限を守る():
    from src.reactions import Post, say_lines

    posts = [Post(no=i, text=f"反応その{i}です") for i in range(30)]
    assert len(say_lines(posts, want=5)) == 5
