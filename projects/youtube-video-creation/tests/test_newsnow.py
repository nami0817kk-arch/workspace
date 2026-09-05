"""NewsNow（英語圏の集約サイト）の読み取り。"""

from datetime import datetime

SAMPLE = """
<div class="hl hl_inv" data-id="1">
   <div class="hl__inner"><a class="hll" href="https://c.newsnow.co.uk/A/1?-8" target="_blank">Digging deeper into Liverpool&#8217;s 2-0 win</a>
   <span class="meta"><span class="src src-part" data-pub="LIVFCNET">Liverpool FC - Official Site<i class="fas"></i></span><span class="time" data-time="1788562227">23:50</span></span>
   <span class="favtags"><a class="fav" href="/h/Sport/Football/Premier+League/Liverpool">Liverpool</a> <a class="fav" href="/h/Sport/Football/Premier+League">Premier League</a> </span></div>
</div>
<div class="hl" data-id="2">
   <div class="hl__inner"><a class="hll" href="https://c.newsnow.co.uk/A/2?-8" target="_blank">Mbapp&#233; misses penalty</a>
   <span class="meta"><span class="src src-part" data-pub="SUN">The Sun<i class="fas"></i></span><span class="time" data-time="1788555000">21:50</span></span>
   <span class="favtags"><a class="fav" href="/h/Sport/Football/La+Liga">La Liga</a> </span></div>
</div>
<div class="hl" data-id="3">
   <div class="hl__inner"><a class="hll" href="https://c.newsnow.co.uk/A/3?-8" target="_blank">Women's match report</a>
   <span class="meta"><span class="src src-part" data-pub="VAVEL">VAVEL.com<i class="fas"></i></span><span class="time" data-time="1788550000">20:26</span></span>
   <span class="favtags"><a class="fav" href="/h/Sport/Football/WSL">WSL</a> </span></div>
</div>
"""

NOW = datetime.fromtimestamp(1788562227) 


def test_見出しと媒体と時刻を読む():
    from src.newsnow import parse

    rows = parse(SAMPLE)

    assert len(rows) == 3
    assert rows[0].publisher == "Liverpool FC - Official Site"
    assert rows[0].posted == datetime.fromtimestamp(1788562227)


def test_リーグのタグからリーグを埋める():
    """**毎回手で埋めていた欄。**タグに出ているものは機械で入る。"""
    from src.newsnow import parse

    rows = parse(SAMPLE)

    assert rows[0].league == "england"
    assert rows[1].league == "spain"
    assert rows[2].league == ""      # WSL は対応表に無い。埋めずに判断を残す


def test_クラブのタグも拾う():
    from src.newsnow import parse

    assert parse(SAMPLE)[0].clubs == ("Liverpool",)


def test_実体参照を戻す():
    from src.newsnow import parse

    rows = parse(SAMPLE)
    assert "\u2019" in rows[0].title and "&#8217;" not in rows[0].title
    assert "Mbappé" in rows[1].title


def test_中継ページから実URLを取り出す():
    """リンクは c.newsnow.co.uk の中継URL。中に本当の行き先が書いてある。"""
    from src.newsnow import OUTBOUND

    page = ('<a href="https://c.newsnow.co.uk/x">back</a>'
            '<a href="https://liverpooloffside.sbnation.com/a/1">記事</a>'
            '<a href="https://www.dec.org.uk/?utm_source=newsnow">寄付</a>')
    assert OUTBOUND.search(page).group(1) == "https://liverpooloffside.sbnation.com/a/1"


def test_metaはリーグと経過時間を持つ():
    from src.newsnow import meta, parse

    found = meta(parse(SAMPLE), now=NOW)
    first = found["https://c.newsnow.co.uk/A/1?-8"]
    assert first["league"] == "england"
    assert first["hours_ago"] == 0.0
