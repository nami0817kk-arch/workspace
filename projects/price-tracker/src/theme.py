"""ページの組み立て。実行時にAIは使わず、データからHTMLを組む。"""
import hashlib
import html
import json
import re
from datetime import datetime

from .analyze import MIN_DAYS_FOR_LOW

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
    points = [p for _, p in tail if p]
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

NAV = [("./", "今日の値下がり"), ("rises/", "値上がり"), ("lows/", "最安値圏"),
       ("genre/", "ジャンル別"), ("search/", "商品を探す"), ("about/", "このサイトについて")]


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
<meta name="twitter:card" content="summary">
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
    points = [p for _, p in (row.get("tail") or []) if p]
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
  input.addEventListener('focus', load);
  input.addEventListener('input', function () { if (index) { render(); } else { load(); } });
})();
"""


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


def listing(title: str, lead: str, rows: list, site: dict, canonical: str,
            updated: str, prefix: str = "", empty: str = "該当する商品がありません。",
            stats: dict | None = None) -> str:
    body = ("".join(card(r, prefix) for r in rows) if rows
            else f'<li class="empty">{esc(empty)}</li>')
    count = f'<span class="count">{len(rows):,}件</span>' if rows else ""
    return (head(f"{title}｜{site['name']}", lead, canonical, site, prefix)
            + f'<h1>{esc(title)}{count}</h1><p class="lead">{esc(lead)}</p>'
            + stats_bar(stats or {})
            + AD_NOTICE
            + f'<ul class="cards">{body}</ul>'
            + foot(site, prefix, updated))


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


def item_page(row: dict, site: dict, updated: str) -> str:
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
    if row.get("prev"):
        rows_html.insert(1, ("前回の価格", yen(row["prev"])))
    table = "".join(f"<tr><th>{esc(k)}</th><td>{v}</td></tr>" for k, v in rows_html)

    # 商品情報の構造化データ。価格は当サイトの取得値であることを本文で明示している。
    ld = safe_json({
        "@context": "https://schema.org", "@type": "Product",
        "name": row["name"], "image": row.get("image") or None,
        "offers": {"@type": "Offer", "price": row["price"], "priceCurrency": "JPY",
                   "url": row.get("url") or canonical},
    })
    extra = f'<script type="application/ld+json">{ld}</script>'

    return (head(f"{title}｜{site['name']}", desc, canonical, site, prefix, extra)
            + f'<article class="item"><h1>{esc(row["name"])}</h1>'
            + AD_NOTICE
            + f'<p class="headline"><strong>{yen(row["price"])}</strong> {badge(row)}</p>'
            + f'<p class="verdict">{esc(verdict_note(row))}</p>'
            + f'<div class="chart">{sparkline(row.get("tail") or [])}</div>'
            + f'<table class="facts">{table}</table>'
            + f'<p class="cta">{buy_link(row)}</p>'
            + f'<p class="shop">販売店: {esc(row.get("shop", ""))}</p>'
            + '</article>'
            + foot(site, prefix, updated))
