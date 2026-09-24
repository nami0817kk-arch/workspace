"""ページの組み立て。実行時にAIは使わず、データからHTMLを組む。"""
import hashlib
import html
import json
import re
from datetime import datetime

from .analyze import MIN_DAYS_FOR_LOW
from .store import entry as store_entry

SAFE = re.compile(r"[^a-z0-9]+")


def esc(text) -> str:
    return html.escape(str(text if text is not None else ""), quote=True)


def safe_json(value) -> str:
    """JSON-LD に埋める。< > & を潰さないと商品名で </script> を作られる。"""
    return (json.dumps(value, ensure_ascii=False)
            .replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026"))


def slug(item_code: str) -> str:
    """商品コード（例 shop:1001）をURLに使える形にする。

    記号を潰すだけでは別商品が同じ綴りになりうるので、元のコードのハッシュを付ける。
    """
    base = SAFE.sub("-", str(item_code).lower()).strip("-")[:60] or "item"
    digest = hashlib.sha1(str(item_code).encode("utf-8")).hexdigest()[:8]
    return f"{base}-{digest}"


def yen(value) -> str:
    return f"{int(value):,}円"


def pct(value) -> str:
    return f"{value * 100:.1f}%"


def sparkline(tail: list, width: int = 220, height: int = 44) -> str:
    """価格推移の線。色は currentColor にして、明暗どちらのテーマでも読めるようにする。"""
    points = [e[1] for e in map(store_entry, tail) if e[1]]
    if len(points) < 2:
        return '<span class="spark-none">記録が足りません</span>'
    low, high = min(points), max(points)
    span = (high - low) or 1
    step = width / (len(points) - 1)
    coords = " ".join(
        f"{i * step:.1f},{height - 4 - (p - low) / span * (height - 8):.1f}"
        for i, p in enumerate(points))
    last_x = width
    last_y = height - 4 - (points[-1] - low) / span * (height - 8)
    return (f'<svg class="spark" viewBox="0 0 {width} {height}" role="img" '
            f'aria-label="直近{len(points)}日の価格推移">'
            f'<polyline points="{coords}" fill="none" stroke="currentColor" '
            f'stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<circle cx="{last_x:.1f}" cy="{last_y:.1f}" r="3" fill="currentColor"/>'
            f'</svg>')


FAVICON = ("data:image/svg+xml,"
           "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E"
           "%3Crect width='32' height='32' rx='7' fill='%231f6f5c'/%3E"
           "%3Cpath d='M16 7v13m0 0l-6-6m6 6l6-6' stroke='%23fff' stroke-width='3' "
           "fill='none' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E")

AD_NOTICE = ('<p class="ad-notice">本サイトは楽天アフィリエイトを利用しており、'
             'リンク経由の購入により収益を得ています。</p>')

NAV = [("./", "今日の値下がり"), ("points/", "ポイント込み"), ("new-lows/", "最安値更新"),
       ("lows/", "最安値圏"), ("rises/", "値上がり"), ("active/", "よく動く"),
       ("genre/", "ジャンル別"), ("archive/", "日付別"), ("search/", "商品を探す"),
       ("stats/", "記録"),
       ("about/", "このサイトについて")]


def _verification(site: dict) -> str:
    """Search Console の所有権確認タグ。

    pages.dev のサブドメインは自分のドメインではないため DNS 方式が使えない。
    URLプレフィックス方式の HTML タグで確認する（kabu-agari-ranking と同じ）。
    config.json の google_site_verification に値を入れると全ページに入る。
    """
    token = str(site.get("google_site_verification") or "").strip()
    if not token:
        return ""
    return f'\n<meta name="google-site-verification" content="{esc(token)}">'


def head(title: str, description: str, canonical: str, site: dict, prefix: str = "",
         extra: str = "") -> str:
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="canonical" href="{esc(canonical)}">
<meta name="robots" content="index,follow,max-image-preview:large">{_verification(site)}
<meta property="og:type" content="website">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(description)}">
<meta property="og:url" content="{esc(canonical)}">
<meta property="og:site_name" content="{esc(site['name'])}">
<meta name="twitter:card" content="summary_large_image">
<meta property="og:image" content="{esc(site["base_url"].rstrip("/"))}/og.svg">
<link rel="alternate" type="application/rss+xml" title="今日の値下がり" href="{prefix}feed.xml">
<link rel="icon" href="{FAVICON}">
<link rel="stylesheet" href="{prefix}style.css">
{extra}
</head>
<body>
<header class="site-head"><div class="wrap">
  <a class="site-name" href="{prefix or './'}">{esc(site['name'])}</a>
  <nav class="site-nav">{"".join(f'<a href="{prefix}{href}">{esc(label)}</a>' for href, label in NAV)}</nav>
</div></header>
<main class="wrap">"""


def foot(site: dict, prefix: str = "", updated: str = "") -> str:
    stamp = f'<p class="updated">最終更新: {esc(updated)}</p>' if updated else ""
    owner = esc(site.get("owner") or site["name"])
    return f"""</main>
<footer class="site-foot"><div class="wrap">
  {stamp}
  <nav class="foot-nav">
    <a href="{prefix}about/">このサイトについて</a>
    <a href="{prefix}privacy/">プライバシーポリシー</a>
    <a href="{prefix}contact/">お問い合わせ</a>
    <a href="{prefix}stats/">記録の全体像</a>
    <a href="{prefix}feed.xml">RSS</a>
  </nav>
  {AD_NOTICE}
  <p class="disclaimer">価格は当サイトが取得した時点のものです。実際の価格・在庫は
  必ずリンク先の楽天市場でご確認ください。「最安値」は当サイトが記録した期間内での比較であり、
  市場全体の最安値を意味するものではありません。</p>
  <p class="copy">© {datetime.now().year} {owner}</p>
</div></footer>
</body>
</html>"""


def buy_link(row: dict) -> str:
    """アフィリエイトリンク。sponsored を付けるのは検索エンジンへの申告として必須。"""
    if not row.get("url"):
        return ""
    return (f'<a class="buy" href="{esc(row["url"])}" '
            f'rel="sponsored nofollow noopener" target="_blank">楽天市場で見る</a>')


def verdict_note(row: dict) -> str:
    """いまの価格が履歴のどこにあるかを一文で述べる。

    高いときは高いと書く。買い時でないことを言わないサイトは、価格を追う
    道具ではなく売るための導線になってしまう。推奨はせず、事実だけを書く
    （判断の根拠を後から説明できる形を保つ、という analyze.py と同じ方針）。
    """
    days = int(row.get("days") or 0)
    if not row.get("trustworthy"):
        return (f"記録は{days}日分です。最安値かどうかを言うには"
                f"{MIN_DAYS_FOR_LOW}日分必要なため、まだ判断できません。")
    if row.get("at_low"):
        return "記録した中で最も安い価格です。"
    if row.get("near_low"):
        return f'記録した中の最安値 {yen(row["low"])} に近い価格です。'
    if row.get("rise_pct"):
        return f'前回より {pct(row["rise_pct"])} 高くなっています。'
    if row.get("dropped"):
        return (f'前回より {pct(row["drop_pct"])} 安くなりましたが、'
                f'最安値 {yen(row["low"])} には届いていません。')
    return f'記録した中の最安値は {yen(row["low"])}、最高値は {yen(row["high"])} です。'


def point_note(row: dict) -> str:
    """ポイント倍率と、それを引いた実質価格。

    ポイントは現金ではなく、付与は SPU や会員ランクでも変わる。置き換えずに
    価格と併記し、「目安」と明示する。
    """
    rate = int(row.get("point_rate") or 1)
    if rate <= 1 or not row.get("eff_price"):
        return ""
    return (f'<span class="point">ポイント{rate}倍</span>'
            f'<span class="eff">実質 {yen(row["eff_price"])}<small>（目安）</small></span>')


def badge(row: dict) -> str:
    if row["at_low"]:
        cls = "low"
    elif row["near_low"]:
        cls = "near"
    elif row["dropped"]:
        cls = "drop"
    else:
        cls = "flat"
    return f'<span class="badge {cls}">{esc(row["label"])}</span>'


def history_note(row: dict) -> str:
    """その商品を何日ぶん記録できているか。

    「最安値」と言えるかは記録の厚みで決まる（analyze.MIN_DAYS_FOR_LOW）。
    日数を出しておけば、判定が付いていない商品でも理由が読み手に分かる。
    """
    days = int(row.get("days") or 0)
    if days <= 0:
        return ""
    return f'<span class="sep">/</span>記録{days}日'


def card_spark(row: dict) -> str:
    """一覧に出す小さな価格推移。

    このサイトの値打ちは履歴なので、一覧の時点で形が見えるほうがよい。
    点が2つ未満のときは何も出さない（「記録が足りません」を並べても邪魔になる）。
    """
    points = [e[1] for e in map(store_entry, row.get("tail") or []) if e[1]]
    if len(points) < 2:
        return ""
    return f'<div class="card-spark">{sparkline(row.get("tail") or [], width=140, height=30)}</div>'


def card(row: dict, prefix: str = "") -> str:
    href = f'{prefix}item/{slug(row["item_code"])}/'
    change = ""
    if row["dropped"]:
        change = (f'<span class="down">▼{pct(row["drop_pct"])}</span>'
                  f'<span class="was">{yen(row["prev"])} → </span>')
    elif row.get("rise_pct"):
        # 値上がりも同じ形で出す。下がったときだけ変化を見せると、
        # 都合のいい情報だけを並べるサイトになる。
        change = (f'<span class="up">▲{pct(row["rise_pct"])}</span>'
                  f'<span class="was">{yen(row["prev"])} → </span>')
    img = (f'<img src="{esc(row["image"])}" alt="" loading="lazy" width="120" height="120">'
           if row.get("image") else '<span class="noimg"></span>')
    return f"""<li class="card">
  <a class="thumb" href="{href}">{img}</a>
  <div class="body">
    <a class="name" href="{href}">{esc(row["name"])}</a>
    <p class="price">{change}<strong>{yen(row["price"])}</strong> {badge(row)}</p>
    <p class="point-line">{point_note(row)}</p>
    <p class="meta">{esc(row.get("shop", ""))}{history_note(row)}</p>
    {card_spark(row)}
  </div>
</li>"""


SEARCH_JS = """
(function () {
  var input = document.getElementById('q');
  var out = document.getElementById('results');
  var note = document.getElementById('note');
  var index = null, loading = false, LIMIT = 60, MAX_SCAN = 400;

  function norm(s) { return s.normalize('NFKC').toLowerCase().replace(/\\s+/g, ''); }

  function terms() {
    return input.value.trim().split(/\\s+/).map(norm).filter(Boolean);
  }

  function render() {
    var t = terms();
    if (!t.length) { out.textContent = ''; note.textContent = ''; return; }
    var hits = [];
    for (var i = 0; i < index.length && hits.length < MAX_SCAN; i++) {
      var name = index[i][3], ok = true;
      for (var k = 0; k < t.length; k++) { if (name.indexOf(t[k]) < 0) { ok = false; break; } }
      if (ok) { hits.push(index[i]); }
    }
    note.textContent = hits.length
      ? hits.length + '件' + (hits.length > LIMIT ? '以上（' + LIMIT + '件を表示）' : '')
      : '見つかりませんでした。';
    // 商品名は楽天から来る文字列なので、DOM API で入れる（HTMLとして解釈させない）
    out.textContent = '';
    hits.slice(0, LIMIT).forEach(function (r) {
      var li = document.createElement('li');
      li.className = 'hit';
      var a = document.createElement('a');
      a.href = '../item/' + r[0] + '/';
      a.textContent = r[1];
      var p = document.createElement('span');
      p.className = 'price';
      p.textContent = r[2].toLocaleString() + '円';
      li.appendChild(a);
      li.appendChild(p);
      out.appendChild(li);
    });
  }

  function load() {
    if (index || loading) { return; }
    loading = true;
    note.textContent = '商品一覧を読み込んでいます…';
    fetch('../search-index.json').then(function (r) { return r.json(); }).then(function (data) {
      // 正規化した名前を持たせておく（入力のたびに作り直さない）
      index = data.map(function (r) { return [r[0], r[1], r[2], norm(r[1])]; });
      loading = false;
      render();
    }).catch(function () {
      note.textContent = '一覧を読み込めませんでした。時間をおいて試してください。';
      loading = false;
    });
  }

  // 一覧は数百KBある。検索する人だけが読み込むよう、触られるまで取りに行かない。
  // 検索語を URL に残す。共有・ブックマーク・戻るボタンが効くようになる。
  function syncUrl() {
    var q = input.value.trim();
    history.replaceState(null, '', q ? '?q=' + encodeURIComponent(q) : location.pathname);
  }

  var initial = new URLSearchParams(location.search).get('q');
  if (initial) { input.value = initial; load(); }

  input.addEventListener('focus', load);
  input.addEventListener('input', function () { syncUrl(); if (index) { render(); } else { load(); } });
})();
"""


def stats_page(site: dict, canonical: str, updated: str, stats: dict,
               buckets: dict, genres: list, examples: list | None = None) -> str:
    """このサイトが何を持っているかを数字で出す。

    毎日ためた履歴そのものが値打ちなので、その厚みを一覧の裏側だけでなく
    1ページとして見せる。「動かない商品が大半」という事実も隠さない。
    """
    title = "記録の全体像"
    lead = "当サイトが何をどれだけ記録しているかをまとめています。"
    rows = [("記録している商品", f'{stats["items"]:,} 件'),
            ("記録した日数", f'{stats["days"]} 日'),
            ("価格が一度も動いていない商品", f'{buckets["still"]:,} 件'),
            ("1回動いた商品", f'{buckets["once"]:,} 件'),
            ("2回以上動いた商品", f'{buckets["active"]:,} 件'),
            ("ポイントが通常より高い商品", f'{buckets["pointed"]:,} 件')]
    table = "".join(f"<tr><th>{esc(k)}</th><td>{v}</td></tr>" for k, v in rows)
    per_genre = "".join(
        f'<tr><th><a href="../genre/{esc(str(g["genre_id"]))}/">{esc(g["name"])}</a></th>'
        f'<td>{g["count"]:,} 件</td></tr>' for g in genres)
    return (head(f"{title}｜{site['name']}", lead, canonical, site, "../")
            + breadcrumb(site, title, "../")
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + AD_NOTICE
            + f'<table class="facts">{table}</table>'
            + '<h2>ジャンル別</h2>'
            + f'<table class="facts">{per_genre}</table>'
            + (('<h2>よく動いた商品</h2><ul class="hits">'
                + "".join(
                    f'<li class="hit"><a href="../item/{slug(r["item_code"])}/">'
                    f'{esc(r["name"][:56])}</a><span class="price">{n}回</span></li>'
                    for r, n in examples)
                + '</ul>') if examples else '')
            + '<p class="lead">価格が動かない商品が大半を占めます。'
            + '毎日記録しているのは、動いた瞬間を取り逃さないためです。</p>'
            + foot(site, "../", updated))


def search_page(site: dict, canonical: str, updated: str, stats: dict) -> str:
    """商品名で絞り込む。通信は検索用データの取得だけで、サーバは要らない。"""
    title = "商品を探す"
    lead = "記録している商品を名前で絞り込めます。空白で区切ると、すべてを含むものを探します。"
    return (head(f"{title}｜{site['name']}", lead, canonical, site, "../")
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + stats_bar(stats)
            + AD_NOTICE
            + '<input id="q" type="search" class="q" placeholder="例: モニター 27インチ" '
              'autocomplete="off" aria-label="商品名で検索">'
            + '<p id="note" class="note"></p><ul id="results" class="hits"></ul>'
            + f'<script>{SEARCH_JS}</script>'
            + foot(site, "../", updated))


def stats_bar(stats: dict) -> str:
    """このサイトが何を持っているかを最初に示す。

    価格履歴は後から買えないことが唯一の強みなのに、一覧に並ぶ商品だけを見ても
    それが伝わらない。値下がりが数件しかない日でもページが空疎に見えないよう、
    追跡している規模と記録の厚みを先に出す。
    """
    if not stats:
        return ""
    parts = [f'<strong>{stats["items"]:,}</strong>商品を追跡',
             f'記録<strong>{stats["days"]}</strong>日目']
    if stats.get("updated"):
        parts.append(f'最終更新 {esc(stats["updated"])}')
    return '<p class="stats">' + '<span class="sep">/</span>'.join(parts) + '</p>'


def pager(page: int, pages: int, prefix: str, total: int) -> str:
    """ページ送り。最安値圏は4,000件を超えるので、1枚に収めると読めない。"""
    if pages <= 1:
        return ""
    def href(n):
        return prefix if n == 1 else f"{prefix}{n}/"
    links = []
    if page > 1:
        links.append(f'<a rel="prev" href="{href(page - 1)}">前へ</a>')
    # 近辺のページ番号だけ出す。41ページ分を並べても選べない。
    lo, hi = max(1, page - 2), min(pages, page + 2)
    if lo > 1:
        links.append(f'<a href="{href(1)}">1</a><span class="gap">…</span>')
    for n in range(lo, hi + 1):
        links.append(f'<span class="now">{n}</span>' if n == page
                     else f'<a href="{href(n)}">{n}</a>')
    if hi < pages:
        links.append(f'<span class="gap">…</span><a href="{href(pages)}">{pages}</a>')
    if page < pages:
        links.append(f'<a rel="next" href="{href(page + 1)}">次へ</a>')
    links.append(f'<span class="of">全{total:,}件</span>')
    return f'<nav class="pager">{"".join(links)}</nav>'


def item_list_ld(rows: list, site: dict, prefix: str) -> str:
    """一覧の構造化データ。検索側に「何の一覧か」を伝える。"""
    if not rows:
        return ""
    base = site["base_url"].rstrip("/")
    ld = safe_json({
        "@context": "https://schema.org", "@type": "ItemList",
        "numberOfItems": len(rows),
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": r["name"],
             "url": f'{base}/item/{slug(r["item_code"])}/'}
            for i, r in enumerate(rows[:30])],
    })
    return f'<script type="application/ld+json">{ld}</script>'


def listing(title: str, lead: str, rows: list, site: dict, canonical: str,
            updated: str, prefix: str = "", empty: str = "該当する商品がありません。",
            stats: dict | None = None, page: int = 1, pages: int = 1,
            page_prefix: str = "", total: int | None = None) -> str:
    body = ("".join(card(r, prefix) for r in rows) if rows
            else f'<li class="empty">{esc(empty)}</li>')
    total = len(rows) if total is None else total
    count = f'<span class="count">{total:,}件</span>' if rows else ""
    heading = esc(title) + (f"（{page}ページ目）" if page > 1 else "")
    nav = pager(page, pages, page_prefix, total)
    return (head(f"{heading}｜{site['name']}", lead, canonical, site, prefix,
                 extra=item_list_ld(rows, site, prefix))
            + f'<h1>{heading}{count}</h1><p class="lead">{esc(lead)}</p>'
            + stats_bar(stats or {})
            + AD_NOTICE
            + nav
            + f'<ul class="cards">{body}</ul>'
            + nav
            + foot(site, prefix, updated))


def archive_index(days: list, site: dict, canonical: str, updated: str) -> str:
    """日付別の入口。一覧が増えても、どの日を見られるかが分からないと辿れない。"""
    title = "日付別の値下がり"
    lead = "記録を始めてからの各日について、その日に安くなった商品を残しています。"
    body = "".join(
        f'<li class="hit"><a href="{esc(day)}/">{esc(day)}</a>'
        f'<span class="price">{n:,}件</span></li>' for day, n in days)
    return (head(f"{title}｜{site['name']}", lead, canonical, site, "../")
            + breadcrumb(site, title, "../")
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + AD_NOTICE
            + f'<ul class="hits">{body}</ul>'
            + foot(site, "../", updated))


def genre_index(genres: list[dict], site: dict, canonical: str, updated: str,
                prefix: str = "") -> str:
    """ジャンル別ページへの入口。

    単品ページは価格比較サイトと正面から競合する。ジャンル単位の入口を1枚持って
    内部リンクを集約し、各商品ページへ回遊させる。
    """
    title = "ジャンル別で見る"
    lead = "記録している商品をジャンルごとに、値下がりの大きい順で並べています。"
    links = "".join(
        f'<li class="genre"><a href="{prefix}genre/{esc(str(g["genre_id"]))}/">'
        f'{esc(g["name"])}</a><span class="count">{g["count"]}商品</span></li>'
        for g in genres)
    return (head(f"{title}｜{site['name']}", lead, canonical, site, prefix)
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + f'<ul class="cards">{links}</ul>'
            + foot(site, prefix, updated))


def history_table(row: dict) -> str:
    """直近の価格を日付つきで出す。

    折れ線は形しか分からない。「いつ・いくらだったか」を読めるようにする。
    倍率が付いている日はそれも出す（実質いくらだったかを後から確かめられる）。
    """
    tail = [store_entry(e) for e in (row.get("tail") or [])][-14:]
    if len(tail) < 2:
        return ""
    body = "".join(
        f"<tr><th>{esc(day)}</th><td>{yen(price)}</td>"
        f"<td>{('ポイント' + str(rate) + '倍') if rate > 1 else ''}</td></tr>"
        for day, price, rate in reversed(tail))
    return ('<h2>価格の記録</h2>'
            f'<table class="facts history">{body}</table>')


def og_image(site: dict, stats: dict) -> str:
    """共有時に出る画像。写真素材を持たないので、数字を出す図を自前で描く。"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630">
<rect width="1200" height="630" fill="#fbfbfa"/>
<rect x="0" y="0" width="1200" height="14" fill="#1f6f5c"/>
<text x="80" y="210" font-family="sans-serif" font-size="64" font-weight="700"
      fill="#23211d">{esc(site["name"])}</text>
<text x="80" y="300" font-family="sans-serif" font-size="34" fill="#6d6a63">
楽天市場の価格を毎日記録し、値下がりと最安値圏を機械的に判定しています。</text>
<text x="80" y="430" font-family="sans-serif" font-size="52" font-weight="700"
      fill="#1f6f5c">{stats.get("items", 0):,} 商品 / {stats.get("days", 0)} 日分の記録</text>
<text x="80" y="500" font-family="sans-serif" font-size="30" fill="#6d6a63">
ポイント倍率を含めた実質価格でも判定します</text>
</svg>"""


def not_found(site: dict, updated: str) -> str:
    """404。5,600ページあり、商品が入れ替われば古いURLも残る。行き先を示す。"""
    return (head(f"ページが見つかりません｜{site['name']}",
                 "お探しのページは見つかりませんでした。", site["base_url"], site)
            + '<h1>ページが見つかりません</h1>'
            + '<p class="lead">記録から外れた商品のページは、時間がたつと無くなります。'
            + '商品名で探すか、一覧から辿ってください。</p>'
            + '<ul class="cards">'
            + '<li class="card"><div class="body"><a class="name" href="search/">商品を探す</a>'
            + '<p class="meta">記録している商品を名前で絞り込めます</p></div></li>'
            + '<li class="card"><div class="body"><a class="name" href="./">今日の値下がり</a>'
            + '<p class="meta">前回より安くなった商品</p></div></li>'
            + '<li class="card"><div class="body"><a class="name" href="lows/">最安値圏</a>'
            + '<p class="meta">記録した中で最も安い価格の商品</p></div></li>'
            + '</ul>'
            + foot(site, "", updated))


def feed(site: dict, rows: list, updated: str, title: str = "今日の値下がり",
         path: str = "") -> str:
    """一覧の RSS。毎日サイトを見に来なくても追える形にする。

    購読したい対象は人によって違う（値下がり・ポイント込み・最安値更新）ので、
    一覧ごとに出す。
    """
    base = site["base_url"].rstrip("/")
    def one(row):
        desc = f'{pct(row["drop_pct"])} 下がって {yen(row["price"])}'
        if int(row.get("point_rate") or 1) > 1:
            desc += f'（ポイント{row["point_rate"]}倍 / 実質 {yen(row["eff_price"])}）'
        return (f"<item><title>{esc(row['name'][:90])}</title>"
                f"<link>{base}/item/{slug(row['item_code'])}/</link>"
                f"<guid isPermaLink=\"false\">{slug(row['item_code'])}-{updated}</guid>"
                f"<description>{esc(desc)}</description></item>")

    items = "".join(one(r) for r in rows[:50])
    return ('<?xml version="1.0" encoding="UTF-8"?>'
            '<rss version="2.0"><channel>'
            f'<title>{esc(site["name"])} - 今日の値下がり</title>'
            f'<link>{base}/</link>'
            f'<description>{esc(site.get("description", ""))}</description>'
            f'<language>ja</language>{items}</channel></rss>')


def breadcrumb(site: dict, name: str, prefix: str) -> str:
    """パンくず。5,600ページあるので、いまどこにいるか分かる道しるべを置く。"""
    base = site["base_url"].rstrip("/")
    ld = safe_json({
        "@context": "https://schema.org", "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": site["name"], "item": base + "/"},
            {"@type": "ListItem", "position": 2, "name": name},
        ],
    })
    return (f'<nav class="crumb"><a href="{prefix}">{esc(site["name"])}</a>'
            f'<span class="sep">/</span>{esc(name)}</nav>'
            f'<script type="application/ld+json">{ld}</script>')


def related(rows: list, site: dict) -> str:
    """同じジャンルの商品へ。5,500ページが互いに孤立していると、
    読み手も検索エンジンも辿れない。"""
    if not rows:
        return ""
    body = "".join(
        f'<li><a href="../{slug(r["item_code"])}/">{esc(r["name"][:56])}</a>'
        f'<span class="price">{yen(r["price"])}</span></li>' for r in rows)
    return f'<h2>同じジャンルの商品</h2><ul class="hits">{body}</ul>'


def item_page(row: dict, site: dict, updated: str, kin: list | None = None) -> str:
    prefix = "../../"
    canonical = f'{site["base_url"].rstrip("/")}/item/{slug(row["item_code"])}/'
    title = f'{row["name"]}の価格推移'
    desc = (f'{row["name"]} の価格を毎日記録しています。'
            f'現在 {yen(row["price"])}、記録した中での最安値は {yen(row["low"])}。')

    rows_html = [("現在の価格", yen(row["price"])),
                 ("記録した中での最安値", f'{yen(row["low"])}（{esc(row.get("low_date") or "-")}）'),
                 ("記録した中での最高値", yen(row["high"])),
                 ("最安値との差", pct(row["vs_low_pct"]) if row["vs_low_pct"] else "最安値と同じ"),
                 ("記録日数", f'{row["days"]}日')]
    if int(row.get("point_rate") or 1) > 1:
        rows_html.insert(1, ("ポイント倍率", f'{row["point_rate"]}倍'))
        rows_html.insert(2, ("ポイント分を引いた実質価格",
                             f'{yen(row["eff_price"])}（目安）'))
    if row.get("prev"):
        rows_html.insert(1, ("前回の価格", yen(row["prev"])))
    table = "".join(f"<tr><th>{esc(k)}</th><td>{v}</td></tr>" for k, v in rows_html)

    # 商品情報の構造化データ。価格は当サイトの取得値であることを本文で明示している。
    ld = safe_json({
        "@context": "https://schema.org", "@type": "Product",
        "name": row["name"], "image": row.get("image") or None,
        "offers": {"@type": "Offer", "price": row["price"], "priceCurrency": "JPY",
                   "url": row.get("url") or canonical,
                   "availability": "https://schema.org/InStock",
                   "seller": {"@type": "Organization",
                              "name": row.get("shop") or ""}},
    })
    extra = f'<script type="application/ld+json">{ld}</script>'

    return (head(f"{title}｜{site['name']}", desc, canonical, site, prefix, extra)
            + breadcrumb(site, "商品の価格推移", prefix)
            + f'<article class="item"><h1>{esc(row["name"])}</h1>'
            + AD_NOTICE
            + f'<p class="headline"><strong>{yen(row["price"])}</strong> {badge(row)}</p>'
            + f'<p class="verdict">{esc(verdict_note(row))}</p>'
            + f'<div class="chart">{sparkline(row.get("tail") or [])}</div>'
            + f'<table class="facts">{table}</table>'
            + history_table(row)
            + f'<p class="cta">{buy_link(row)}</p>'
            + f'<p class="shop">販売店: {esc(row.get("shop", ""))}</p>'
            + related(kin or [], site)
            + '</article>'
            + foot(site, prefix, updated))
