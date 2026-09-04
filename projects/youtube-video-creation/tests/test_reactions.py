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
