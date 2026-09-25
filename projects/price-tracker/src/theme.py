"""ページの組み立て。実行時にAIは使わず、データからHTMLを組む。"""
import hashlib
import html
import json
import re
from datetime import datetime, timedelta

from .analyze import MIN_DAYS_FOR_LOW
from .store import entry as store_entry

SAFE = re.compile(r"[^a-z0-9]+")
# 先頭に付く宣伝。商品の識別には要らないうえ、検索結果でここだけが見えてしまう。
# 【】で囲まれた断り書き、＼…／の煽り、記号の連なり、期間限定のうたい文句の4種。
# ＼…／ の囲みは飾りそのものが宣伝なので中身を見ずに落とす。
# 【】[] は中身次第で、ブランド名や品目名が入っていることがある。
LEAD_SHOUT = re.compile(r"^\s*(?:＼[^／\\/]{0,60}[／\\/]|《[^》]{0,60}》)\s*")
LEAD_BRACKET = re.compile(r"^\s*[【\[]([^】\]]{0,60})[】\]]\s*")
# 囲みの中が宣伝・配送のうたい文句なら落とす。それ以外は商品の情報として残す
PROMO_HINT = re.compile(
    r"送料無料|送料込|クーポン|ポイント|\d+\s*倍|\d+\s*[%％]|OFF|オフ|還元|エントリー"
    r"|限定|セール|SALE|特価|激安|値下げ|割引|半額|値引|お買い得|ポッキリ|在庫処分"
    r"|お買い物マラソン|買い回り|抽選|プレゼント"
    r"|ゆうパケット|ネコポス|メール便|定形外|宅配便|あす楽|即納|翌日|最短"
    r"|楽天\d+位|ランキング|レビュー|同梱|高評価|大人気|累計|\d{1,2}/\d{1,2}")
LEAD_MARK = re.compile(r"^[\s★☆◆◇■□●○◎▼▲▽△※・!！?？＼\\／/｜|:：、,，\-ー－_＿~〜+＋*＊]+")
LEAD_PROMO = re.compile(
    r"^\s*(?:"
    # 日時は細かい形を先に置く。Python の | は最長ではなく先に当たった方を採るので、
    # 「09/25」だけ食べて「(金)23:59まで」を残す事故が起きる
    r"(?:\d{1,2}/)?\d{1,2}(?:日|\([月火水木金土日]\))\s*\d{1,2}:\d{2}\s*(?:まで|迄)?"
    r"|\d{1,2}/\d{1,2}(?:\s*[〜~ー\-]\s*\d{0,2}/?\d{1,2})?(?:まで|限定|迄)?"
    r"|期間限定|タイムセール|スーパーSALE|お買い物マラソン|楽天スーパーSALE"
    r"|\d+点以上で[^\s]{0,12}(?:OFF|オフ|クーポン)"
    r"|(?:ポイント|P|ポイント最大|最大)\s*\d+(?:\.\d+)?\s*(?:倍|%|％)(?:還元)?"
    r"|最大\s*\d+(?:\.\d+)?\s*(?:%|％)\s*(?:OFF|オフ|P還元|ポイント還元)"
    r"|(?:先着)?\d+(?:,\d{3})?円?\s*(?:OFF|オフ)(?:クーポン)?"
    # 「20%OFFクーポン」「全品5%OFFクーポン配布中」「15％オフ」
    r"|(?:全品)?\s*\d+(?:\.\d+)?\s*[%％]?\s*(?:OFF|オフ|off)(?:クーポン)?(?:配布中)?"
    r"|楽天(?:ランキング|年間)?\s*\d+位(?:獲得|受賞)?(?:[★☆]?\d+連覇)?"
    r"|レビュー(?:投稿)?で[^\s]{0,12}|レビュー特典付き|当店人気No\.?\s*\d+"
    r"|\d+点\d+(?:,\d{3})?円"      # 「1点1280円」
    r"|数量限定(?:早い者勝ち)?|限定\d+(?:枚|[%％]割引)|クーポン(?:配布中)?|セール"
    # 売り手の自賛。「高評価★4.59」「シリーズ累計160万台突破！」
    r"|高評価(?:[★☆]?\s*\d+(?:\.\d+)?|づくし)?"
    r"|(?:シリーズ)?累計(?:販売数)?\s*\d+(?:,\d{3})?\s*(?:万|億)?"
    r"[^\s]{0,3}(?:突破|出荷|販売|以上)?"
    r"|大人気|殿堂入り|満足度\s*\d+(?:\.\d+)?\s*[%％]"
    r"|送料無料|あす楽|即納|新品未開封|正規品保証"
    r")\s*[｜|/／・、,，！!♪★☆\s]*")


def clean_name(name: str) -> str:
    """商品名の頭に積まれた宣伝文句を落とし、商品そのものの名前を先頭に出す。

    楽天の商品名は先頭に「【9/25限定！抽選で最大100%P還元…】」のような
    売り文句が付く。実測（12,593件・2026-09-25）では 1,940件が記号か煽りで
    始まり、うち多数は文言が同一だったため、検索結果に出る28文字が
    商品名ではなく宣伝で埋まり、別商品なのに同じ題になっていた。

    宣伝は日替わりで書き換わるので、落とさないと題が毎日変わることにもなる。
    削りすぎて何の商品か分からなくなるのは避けたいので、3文字を割るときは
    元の名前に戻す。6文字にしていたら「白メダカ」「ミートピア」まで
    宣伝付きの元の名前に戻していた（実測4件、全部が実在の商品名だった）。
    """
    text = original = str(name or "").strip()
    for _ in range(8):  # 「【…】＼…／★」のように積まれるので繰り返す
        before = text
        text = LEAD_SHOUT.sub("", text)
        hit = LEAD_BRACKET.match(text)
        if hit and PROMO_HINT.search(hit.group(1)):
            text = text[hit.end():]
        text = LEAD_PROMO.sub("", text)
        text = LEAD_MARK.sub("", text)
        if text == before:
            break
    text = text.strip()
    return text if len(text) >= 3 else original


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


def short_name(name: str, limit: int = 46) -> str:
    """一覧に出す用の短い商品名。

    楽天の商品名は中央値130文字あり（実測）、送料・クーポン・対応機種などが
    末尾に連なる。そのまま並べると1件で画面が埋まって選べない。
    先頭の宣伝を clean_name で落とし、残りを切り詰める。
    """
    text = clean_name(name)
    return text if len(text) <= limit else text[:limit].rstrip() + "…"


def page_titles(rows: list, limit: int = 28, cap: int = 64) -> dict:
    """商品ページの題を商品コードごとに決める。

    題は検索結果で30文字前後に切られるので既定は28文字だが、それだと
    「同じ商品の容量違い・色違い」が全部同じ題になる（実測で1,580件）。
    区別の付く語はたいてい後ろにあるので、ぶつかったものだけ切る位置を
    後ろへずらす。ずらすのはぶつかった分だけで、大半は28文字のまま。
    """
    out, pending, width = {}, list(rows), limit
    while pending and width <= cap:
        groups = {}
        for row in pending:
            groups.setdefault(short_name(row["name"], width), []).append(row)
        rest = []
        for title, members in groups.items():
            if len(members) == 1 or width + 6 > cap:
                out.update({r["item_code"]: title for r in members})
            else:
                rest.extend(members)
        pending, width = rest, width + 6
    return out


def next_day(value: str) -> str:
    """翌日の日付。構造化データの priceValidUntil に使う。"""
    try:
        base = datetime.strptime(str(value), "%Y-%m-%d")
    except (ValueError, TypeError):
        return str(value or "")
    return (base + timedelta(days=1)).strftime("%Y-%m-%d")


def jp_date(value: str) -> str:
    """2026-09-25 を 9月25日 にする。読み手に見せるのは月日だけで足りる。"""
    parts = str(value or "").split("-")
    return f"{int(parts[1])}月{int(parts[2])}日" if len(parts) == 3 else str(value or "")


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

NAV = [("./", "いま条件がそろう"), ("drops/", "今日の値下がり"), ("points/", "ポイント込み"), ("new-lows/", "最安値更新"),
       ("lows/", "最安値圏"), ("rises/", "値上がり"), ("active/", "よく動く"),
       ("genre/", "ジャンル別"), ("archive/", "日付別"), ("search/", "商品を探す"),
       ("watch/", "見守り"), ("ending/", "期限が近い"), ("stats/", "記録"),
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
         extra: str = "", indexable: bool = True) -> str:
    robots = ("index,follow,max-image-preview:large" if indexable
              else "noindex,follow")
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="canonical" href="{esc(canonical)}">
<meta name="robots" content="{robots}">{_verification(site)}
<meta property="og:type" content="website">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(description)}">
<meta property="og:url" content="{esc(canonical)}">
<meta property="og:site_name" content="{esc(site['name'])}">
<meta name="twitter:card" content="summary">
<meta property="og:image" content="{esc(site["base_url"].rstrip("/"))}/og.svg">
<link rel="alternate" type="application/rss+xml" title="今日の値下がり" href="{prefix}feed.xml">
<link rel="icon" href="{FAVICON}">
<link rel="stylesheet" href="{prefix}{site.get("css", "style.css")}">
{WATCH_JS}
{extra}
</head>
<body>
<a class="skip" href="#main">本文へ</a>
<header class="site-head"><div class="wrap">
  <a class="site-name" href="{prefix or './'}">{esc(site['name'])}</a>
  <nav class="site-nav">{"".join(f'<a href="{(prefix + href).replace("/./", "/")}">{esc(label)}</a>' for href, label in NAV)}</nav>
</div></header>
<main class="wrap" id="main">"""


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
    <a href="{prefix}data.csv">記録をCSVで取得</a>
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
    until = str(row.get("point_until") or "")[:10]
    mark = (f'<span class="until">{esc(until[5:].replace("-", "/"))}まで</span>'
            if until else "")
    return (f'<span class="point">ポイント{rate}倍</span>{mark}'
            f'<span class="eff">実質 {yen(row["eff_price"])}<small>（目安）</small></span>')


def conditions(row: dict) -> str:
    """送料と在庫。買うかどうかの判断に直結するのに出していなかった。"""
    marks = []
    if row.get("free_shipping"):
        marks.append('<span class="cond free">送料無料</span>')
    if row.get("next_day"):
        marks.append('<span class="cond fast">あす楽</span>')
    if row.get("in_stock") is False:
        marks.append('<span class="cond out">在庫切れ</span>')
    return "".join(marks)


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


def score_bar(row: dict) -> str:
    """条件のそろい具合と、その内訳。

    数字だけ出すと「何点かは分かるが理由が分からない」道具になる。
    満たした条件を名前で並べ、点の根拠を画面から読めるようにする。
    """
    from .analyze import condition_score, score_breakdown
    total = condition_score(row)
    if total <= 0:
        return ""
    parts = [f'{name} {pt}' for name, pt in score_breakdown(row) if pt]
    return (f'<p class="score"><span class="num">{total}</span><span class="max">/100</span>'
            f'<span class="parts">{esc(" ・ ".join(parts))}</span></p>')


def card(row: dict, prefix: str = "", eager: bool = False, show_score: bool = False) -> str:
    href = f'{prefix}item/{slug(row["item_code"])}/'
    change = ""
    if row["dropped"]:
        cut = int(row["prev"]) - int(row["price"])
        change = (f'<span class="down">▼{pct(row["drop_pct"])}'
                  f'<small>（{cut:,}円）</small></span>'
                  f'<span class="was">{yen(row["prev"])} → </span>')
    elif row.get("rise_pct"):
        # 値上がりも同じ形で出す。下がったときだけ変化を見せると、
        # 都合のいい情報だけを並べるサイトになる。
        change = (f'<span class="up">▲{pct(row["rise_pct"])}</span>'
                  f'<span class="was">{yen(row["prev"])} → </span>')
    # 最初の数件は画面に出た時点で見えている。遅延させると自分で表示を遅らせる
    # ことになるので、そこだけ先に読む。alt は短い名前にする（173文字の読み上げを避ける）。
    img = (f'<img src="{esc(row["image"])}" alt="{esc(short_name(row["name"], 40))}" '
           f'loading="{"eager" if eager else "lazy"}" decoding="async" '
           f'width="120" height="120">'
           if row.get("image") else '<span class="noimg"></span>')
    return f"""<li class="card" data-price="{row["price"]}" data-drop="{row.get("drop_pct", 0):.4f}"
    data-days="{row.get("days", 0)}" data-eff="{row.get("eff_price") or row["price"]}"
    data-code="{esc(row["item_code"])}" data-free="{1 if row.get("free_shipping") else 0}"
    data-stock="{0 if row.get("in_stock") is False else 1}">
  <a class="thumb" href="{href}">{img}</a>
  <div class="body">
    <a class="name" href="{href}" title="{esc(row["name"])}">{esc(short_name(row["name"]))}</a>
    <p class="price">{change}<strong>{yen(row["price"])}</strong> {badge(row)}{conditions(row)}</p>
    <p class="point-line">{point_note(row)}</p>
    <p class="meta">{esc(row.get("shop", ""))}{history_note(row)}
      <button class="watch-mini" type="button" data-code="{esc(row["item_code"])}"
              data-price="{row["price"]}" aria-label="この商品を見守る">見守る</button></p>
    {score_bar(row) if show_score else ""}
    {card_spark(row)}
  </div>
</li>"""


SEARCH_JS = r"""
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
      var name = index[i][5], ok = true;
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
      a.textContent = ptShort(r[1], 46);
      a.title = r[1];
      var p = document.createElement('span');
      p.className = 'price';
      p.textContent = r[2].toLocaleString() + '円';
      li.appendChild(a);
      li.appendChild(p);
      var MARK = [null, ['drop', '値下がり'], ['near', '最安値に近い'],
                  ['low', '記録した中で最安']];
      var m = MARK[r[4]];
      if (m) {
        var b = document.createElement('span');
        b.className = 'badge ' + m[0];
        b.textContent = m[1];
        li.appendChild(b);
      }
      out.appendChild(li);
    });
  }

  function load() {
    if (index || loading) { return; }
    loading = true;
    note.textContent = '商品一覧を読み込んでいます…';
    fetch('../search-index.json').then(function (r) { return r.json(); }).then(function (data) {
      // 正規化した名前を持たせておく（入力のたびに作り直さない）
      // 判定(r[4])を残したまま、正規化した名前を末尾に足す。
      // 4要素に詰め直していたため判定が落ち、バッジが出ていなかった。
      index = data.map(function (r) { return [r[0], r[1], r[2], r[3], r[4], norm(r[1])]; });
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
               buckets: dict, genres: list, examples: list | None = None,
               daily: list | None = None) -> str:
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
            + (('<h2>日ごとの値下がり件数</h2>'
                + '<table class="facts">'
                + "".join(f'<tr><th><a href="../archive/{esc(d)}/">{esc(d)}</a></th>'
                          f'<td>{n:,} 件</td></tr>' for d, n in daily)
                + '</table>') if daily else '')
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
    nav = f'<nav class="pager">{"".join(links)}</nav>'
    # 近辺しか出さないと、81ページある一覧の40ページ目まで20回押すことになる。
    # 読み手が奥まで行けないのと同じ理由で、クロールも奥まで届かない。
    # 飛び先は5ページ刻み。近辺が±2なので、この間隔なら取りこぼしが出ない
    # （10刻みにしたら14〜18ページ目だけ1手多くかかった）。
    if pages > 10:
        jumps = "".join(
            f'<a href="{href(n)}">{n}</a>' for n in range(6, pages + 1, 5)
            if n != page)
        nav += f'<nav class="jump"><span>飛ぶ</span>{jumps}</nav>'
    return nav


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


WATCH_MINI_JS = r"""
<script>
// 同じ理由で DOM を待つ。.watch-mini は一覧の中にある。
document.addEventListener('DOMContentLoaded', function () {
  function label(btn, on) {
    btn.textContent = on ? '見守り中' : '見守る';
    btn.classList.toggle('on', on);
  }
  var store = PTWatch.read();
  document.querySelectorAll('.watch-mini').forEach(function (btn) {
    label(btn, !!store[btn.dataset.code]);
    btn.addEventListener('click', function () {
      var s = PTWatch.toggle(btn.dataset.code, parseInt(btn.dataset.price, 10));
      label(btn, !!s[btn.dataset.code]);
    });
  });
});
</script>
"""

LIST_TOOLS = r"""
<div class="tools">
  <label>並び替え <select id="sort">
    <option value="">既定のまま</option>
    <option value="price">価格が安い順</option>
    <option value="-price">価格が高い順</option>
    <option value="-drop">下げ幅が大きい順</option>
    <option value="-eff">実質が高い順</option>
    <option value="eff">実質が安い順</option>
    <option value="-days">記録が長い順</option>
  </select></label>
  <label class="check"><input type="checkbox" id="freeonly"> 送料無料だけ</label>
  <label class="check"><input type="checkbox" id="instock"> 在庫ありだけ</label>
  <label>価格帯 <select id="range">
    <option value="">すべて</option>
    <option value="0-3000">3,000円まで</option>
    <option value="3000-10000">3,000〜10,000円</option>
    <option value="10000-30000">10,000〜30,000円</option>
    <option value="30000-">30,000円以上</option>
  </select></label>
  <button id="reset" type="button" class="reset" hidden>条件を外す</button>
  <span id="shown" class="of"></span>
  <span class="scope">このページに出ている分だけを並べ替えます</span>
</div>
<script>
// この script は一覧より前に置かれる。読み込み時点で .cards はまだ無いので、
// DOM が揃うのを待ってから繋ぐ（待たずに書いたため、並び替えが丸ごと
// 効いていなかった。2026-09-24 に公開サイトで確認）。
document.addEventListener('DOMContentLoaded', function () {
  var list = document.querySelector('.cards');
  if (!list) { return; }
  var all = Array.prototype.slice.call(list.children);
  var sort = document.getElementById('sort');
  var range = document.getElementById('range');
  var shown = document.getElementById('shown');
  var q = new URLSearchParams(location.search);

  function num(li, key) { return parseFloat(li.dataset[key] || '0'); }

  function apply() {
    var r = (range.value || '').split('-');
    var lo = r[0] ? parseFloat(r[0]) : -Infinity;
    var hi = r.length > 1 && r[1] ? parseFloat(r[1]) : Infinity;
    var keep = all.filter(function (li) {
      var p = num(li, 'price');
      if (p < lo || p > hi) { return false; }
      if (freeonly.checked && li.dataset.free !== '1') { return false; }
      if (instock.checked && li.dataset.stock === '0') { return false; }
      return true;
    });
    var key = sort.value;
    if (key) {
      var desc = key.charAt(0) === '-';
      var field = desc ? key.slice(1) : key;
      keep.sort(function (a, b) {
        return (num(a, field) - num(b, field)) * (desc ? -1 : 1);
      });
    }
    list.textContent = '';
    keep.forEach(function (li) { list.appendChild(li); });
    shown.textContent = keep.length === all.length
      ? '' : keep.length + ' / ' + all.length + ' 件を表示';
    reset.hidden = !(sort.value || range.value || freeonly.checked || instock.checked);
    // 並びと価格帯を URL に残す。共有したときに同じ画面が出る。
    var p = new URLSearchParams();
    if (sort.value) { p.set('sort', sort.value); }
    if (range.value) { p.set('range', range.value); }
    if (freeonly.checked) { p.set('free', '1'); }
    if (instock.checked) { p.set('stock', '1'); }
    var s = p.toString();
    history.replaceState(null, '', s ? '?' + s : location.pathname);
  }

  if (q.get('sort')) { sort.value = q.get('sort'); }
  if (q.get('range')) { range.value = q.get('range'); }
  if (q.get('free')) { freeonly.checked = true; }
  if (q.get('stock')) { instock.checked = true; }
  var freeonly = document.getElementById('freeonly');
  var instock = document.getElementById('instock');
  var reset = document.getElementById('reset');
  reset.addEventListener('click', function () {
    sort.value = ''; range.value = '';
    freeonly.checked = false; instock.checked = false; apply();
  });
  sort.addEventListener('change', apply);
  range.addEventListener('change', apply);
  freeonly.addEventListener('change', apply);
  instock.addEventListener('change', apply);
  if (q.get('sort') || q.get('range') || q.get('free') || q.get('stock')) { apply(); }
});
</script>
"""


def listing(title: str, lead: str, rows: list, site: dict, canonical: str,
            updated: str, prefix: str = "", empty: str = "該当する商品がありません。",
            stats: dict | None = None, page: int = 1, pages: int = 1,
            page_prefix: str = "", total: int | None = None,
            show_score: bool = False) -> str:
    body = ("".join(card(r, prefix, eager=i < 3, show_score=show_score)
                    for i, r in enumerate(rows)) if rows
            else ('<li class="empty">' + esc(empty)
                  + f'<span class="go"><a href="{prefix}">いま条件がそろっている商品</a>'
                  + f'<a href="{prefix}lows/">最安値圏</a>'
                  + f'<a href="{prefix}search/">商品を探す</a></span></li>'))
    total = len(rows) if total is None else total
    count = f'<span class="count">{total:,}件</span>' if rows else ""
    # ページ送りの2枚目以降も同じ説明だと、検索結果に同じ文が81枚並ぶ。
    # 何件目を載せた枚かを足して、どれを開けばよいか分かるようにする。
    desc = lead if page == 1 else (
        f'{lead}（{total:,}件のうち'
        f'{(page - 1) * 50 + 1:,}件目から{min(page * 50, total):,}件目）')
    heading = esc(title) + (f"（{page}ページ目）" if page > 1 else "")
    nav = pager(page, pages, page_prefix, total)
    return (head(f"{short_name(heading, 30)}｜{site['name']}", desc, canonical, site, prefix,
                 extra=item_list_ld(rows, site, prefix))
            + f'<h1>{heading}{count}</h1><p class="lead">{esc(lead)}</p>'
            + stats_bar(stats or {})
            + AD_NOTICE
            + nav
            + (f'<p class="thin">この一覧は前回の記録との比較なので、'
               f'動きが少ない日は少なくなります。'
               f'<a href="{prefix}">いま条件がそろっている商品</a>もご覧ください。</p>'
               if 0 < len(rows) < 10 and page == 1 else '')
            + (LIST_TOOLS + WATCH_MINI_JS if rows else "")
            + f'<ul class="cards">{body}</ul>'
            + nav
            + ('<a class="to-top" href="#main">▲ ページの先頭へ</a>' if len(rows) > 10 else '')
            + foot(site, prefix, updated))


def archive_nav(day: str, older: str | None, newer: str | None) -> str:
    """前後の日へ。日付をURLに打ち直させない。"""
    parts = []
    if newer:
        parts.append(f'<a href="../{esc(newer)}/">← {esc(newer)}</a>')
    parts.append('<a href="../">日付の一覧</a>')
    if older:
        parts.append(f'<a href="../{esc(older)}/">{esc(older)} →</a>')
    return f'<nav class="pager">{"".join(parts)}</nav>'


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
        f'{esc(g["name"])}</a><span class="count">{g["count"]:,}商品</span></li>'
        for g in genres)
    return (head(f"{title}｜{site['name']}", lead, canonical, site, prefix)
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + f'<ul class="cards">{links}</ul>'
            + foot(site, prefix, updated))


def chart(tail: list, width: int = 560, height: int = 180) -> str:
    """商品ページの価格推移。日付と価格の目盛りを付ける。

    一覧の小さな線は形が分かればよいが、商品ページでは「いつ・いくら」まで
    読めないと判断に使えない。
    """
    points = [(e[0], e[1]) for e in map(store_entry, tail) if e[1]]
    if len(points) < 2:
        return '<span class="spark-none">記録が足りません</span>'
    prices = [p for _, p in points]
    low, high = min(prices), max(prices)
    span = (high - low) or 1
    # 値が動いていないと線が下端に張り付き、余白だけの図に見える。
    # その場合は中央に引く。
    flat = high == low
    pad_l, pad_b, pad_t = 64, 22, 10
    w = width - pad_l - 8
    h = height - pad_b - pad_t
    step = w / (len(points) - 1)

    def y(v):
        if flat:
            return pad_t + h / 2
        return pad_t + h - (v - low) / span * h

    coords = " ".join(f"{pad_l + i * step:.1f},{y(p):.1f}" for i, p in enumerate(prices))
    grid = "".join(
        f'<line x1="{pad_l}" y1="{y(v):.1f}" x2="{width - 8}" y2="{y(v):.1f}" '
        f'stroke="currentColor" stroke-opacity=".15"/>'
        f'<text x="{pad_l - 8}" y="{y(v) + 4:.1f}" text-anchor="end" '
        f'font-size="11" fill="currentColor" opacity=".65">{v:,}</text>'
        for v in sorted({low, high}, reverse=True))
    labels = "".join(
        f'<text x="{pad_l + i * step:.1f}" y="{height - 6}" text-anchor="middle" '
        f'font-size="11" fill="currentColor" opacity=".65">{points[i][0][5:]}</text>'
        for i in ({0, len(points) - 1} if len(points) > 1 else {0}))
    return (f'<svg class="chart-svg" viewBox="0 0 {width} {height}" role="img" '
            f'aria-label="{len(points)}日分の価格推移。最安 {low:,}円、最高 {high:,}円">'
            f'{grid}{labels}'
            f'<polyline points="{coords}" fill="none" stroke="currentColor" '
            f'stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<circle cx="{pad_l + (len(points) - 1) * step:.1f}" '
            f'cy="{y(prices[-1]):.1f}" r="3.5" fill="currentColor"/></svg>')


def cheaper_days(row: dict) -> str:
    """いまの価格以下だった日が、記録のうち何日あったか。

    「安い」と言われても、過去にどれだけあった水準なのかが分からないと
    判断できない。回数で出す。
    """
    prices = [e[1] for e in map(store_entry, row.get("tail") or []) if e[1]]
    if len(prices) < MIN_DAYS_FOR_LOW:
        return ""
    now = row["price"]
    if len(set(prices)) == 1:
        # 一度も動いていない。「100%」と出しても何も伝わらない
        return f'記録{len(prices)}日のあいだ、価格は{yen(now)}のまま変わっていません。'
    n = sum(1 for p in prices if p <= now)
    if n == 1:
        return f'記録{len(prices)}日のうち、この価格以下だったのは今日だけです。'
    return (f'記録{len(prices)}日のうち、この価格以下だったのは{n}日です'
            f'（{n / len(prices):.0%}）。')


def caption_block(row: dict) -> str:
    """商品説明の冒頭。商品ページが画像と表だけで薄かった。

    全文は中央値1,123文字あり、5,500件ぶん持つと数MBになるので冒頭だけ持つ。
    出典がリンク先であることは必ず書く。
    """
    text = str(row.get("caption") or "").strip()
    if not text:
        return ""
    return ('<h2>商品の説明</h2>'
            f'<p class="caption">{esc(text)}…</p>'
            '<p class="note">楽天市場の掲載内容の冒頭です。全文はリンク先をご確認ください。</p>')


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


def root_prefix(site: dict) -> str:
    """公開URLの根。404 だけはここから絶対パスで書く必要がある。

    404 は存在しないパスすべてに返され、URL は要求されたまま
    （例 /item/存在しない/更に深い/）。相対パスだと CSS もリンクも壊れる。
    一方でサブディレクトリ配信だと "/" 決め打ちも壊れるので、設定から導く。
    """
    from urllib.parse import urlsplit
    path = urlsplit(site.get("base_url", "")).path.rstrip("/")
    return (path or "") + "/"


def not_found(site: dict, updated: str) -> str:
    """404。

    Cloudflare Pages は存在しないパスすべてにこのページを返し、URL は
    要求されたまま（例 /item/存在しない/更に深い/）。相対パスだと CSS も
    リンクも壊れるので、ルートからの絶対パスで書く。
    """
    root = root_prefix(site)
    return (head(f"ページが見つかりません｜{site['name']}",
                 "お探しのページは見つかりませんでした。", site["base_url"], site,
                 prefix=root_prefix(site))
            + '<h1>ページが見つかりません</h1>'
            + '<p class="lead">記録から外れた商品のページは、時間がたつと無くなります。'
            + '商品名で探すか、一覧から辿ってください。</p>'
            + '<ul class="cards">'
            + f'<li class="card"><div class="body"><a class="name" href="{root}search/">商品を探す</a>'
            + '<p class="meta">記録している商品を名前で絞り込めます</p></div></li>'
            + f'<li class="card"><div class="body"><a class="name" href="{root}">今日の値下がり</a>'
            + '<p class="meta">前回より安くなった商品</p></div></li>'
            + f'<li class="card"><div class="body"><a class="name" href="{root}lows/">最安値圏</a>'
            + '<p class="meta">記録した中で最も安い価格の商品</p></div></li>'
            + '</ul>'
            + foot(site, root_prefix(site), updated))


def _rfc822(day: str) -> str:
    """RSS の日付。購読側が並べ替えられるよう、規格どおりの形で出す。"""
    try:
        d = datetime.strptime(day, "%Y-%m-%d")
    except ValueError:
        return ""
    return d.strftime("%a, %d %b %Y 00:00:00 +0900")


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
                f"<description>{esc(desc)}</description>"
                f"<pubDate>{_rfc822(updated)}</pubDate></item>")

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


def same_shop(rows: list, shop: str) -> str:
    """同じ店の商品。店ごとにポイント倍率や送料の条件が揃うことが多い。"""
    if not rows or not shop:
        return ""
    body = "".join(
        f'<li><a href="../{slug(r["item_code"])}/" title="{esc(r["name"])}">'
        f'{esc(short_name(r["name"]))}</a>'
        f'<span class="price">{yen(r["price"])}</span></li>' for r in rows)
    return f'<h2>{esc(shop)} の他の商品</h2><ul class="hits">{body}</ul>'


def related(rows: list, site: dict) -> str:
    """同じジャンルの商品へ。5,500ページが互いに孤立していると、
    読み手も検索エンジンも辿れない。"""
    if not rows:
        return ""
    body = "".join(
        f'<li><a href="../{slug(r["item_code"])}/" title="{esc(r["name"])}">'
        f'{esc(short_name(r["name"]))}</a>'
        f'<span class="price">{yen(r["price"])}</span></li>' for r in rows)
    return f'<h2>同じジャンルの商品</h2><ul class="hits">{body}</ul>'


# 見守りの保存は端末の中だけ。登録した時の価格も控えて、次に来たときに
# 「自分が見始めてから下がったか」を出せるようにする。
WATCH_JS = r"""
<script>
function ptShort(name, limit) {
  // 索引に積む時点で宣伝は落としてある（build.py の clean_name）ので、
  // ここは切り詰めるだけ。同じ規則を二か所に書くと必ずずれる。
  var t = String(name || '');
  return t.length <= limit ? t : t.slice(0, limit).replace(/\s+$/, '') + '…';
}

var PTWatch = (function () {
  var KEY = 'pt-watch';
  function read() {
    try {
      var v = JSON.parse(localStorage.getItem(KEY) || '{}');
      // 旧い形（コードの配列）も読めるようにする
      if (Array.isArray(v)) {
        var o = {};
        v.forEach(function (c) { o[c] = {p: 0, d: ''}; });
        return o;
      }
      return v || {};
    } catch (e) { return {}; }
  }
  function save(o) { try { localStorage.setItem(KEY, JSON.stringify(o)); } catch (e) {} }
  function toggle(code, price) {
    var o = read();
    if (o[code]) { delete o[code]; }
    else { o[code] = {p: price || 0, d: new Date().toISOString().slice(0, 10)}; }
    save(o);
    return o;
  }
  function setTarget(code, target) {
    var o = read();
    if (!o[code]) { return o; }
    if (target > 0) { o[code].t = target; } else { delete o[code].t; }
    save(o);
    return o;
  }
  function count() { return Object.keys(read()).length; }
  document.addEventListener('DOMContentLoaded', function () {
    // ナビに件数を出す。何件見守っているか分からないと戻る動機にならない。
    var n = count();
    if (!n) { return; }
    document.querySelectorAll('.site-nav a[href$="watch/"]').forEach(function (a) {
      a.textContent = '見守り ' + n;
    });
  });
  return {read: read, toggle: toggle, count: count, setTarget: setTarget};
})();
</script>
"""

WATCH_BUTTON = r"""
<p class="watch"><button id="watch" type="button" data-code="{code}" data-price="{price}">見守る</button>
<span class="note">端末に保存します。<a href="{prefix}watch/">見守り中の一覧</a></span></p>
<p class="target" id="targetbox" hidden>
  <label>この値段以下になったら知りたい
    <input id="target" type="number" inputmode="numeric" min="0" step="100"
           placeholder="例 {price}"></label>
  <span class="note">次に見守り一覧を開いたとき、達したものを先頭に出します。</span>
</p>
<script>
(function () {
  var btn = document.getElementById('watch');
  function draw(store) {
    var on = !!store[btn.dataset.code];
    btn.textContent = on ? '見守りを外す' : '見守る';
    btn.classList.toggle('on', on);
  }
  var box = document.getElementById('targetbox');
  var input = document.getElementById('target');
  function sync(store) {
    draw(store);
    var on = !!store[btn.dataset.code];
    box.hidden = !on;
    if (on && store[btn.dataset.code].t) { input.value = store[btn.dataset.code].t; }
  }
  sync(PTWatch.read());
  btn.addEventListener('click', function () {
    sync(PTWatch.toggle(btn.dataset.code, parseInt(btn.dataset.price, 10)));
  });
  input.addEventListener('change', function () {
    PTWatch.setTarget(btn.dataset.code, parseInt(input.value, 10) || 0);
  });
})();
</script>
"""


def watch_page(site: dict, canonical: str, updated: str) -> str:
    """見守り中の商品。

    保存先はその端末の中だけで、こちらには送らない。見始めた時の価格も控えて
    あるので、「自分が見始めてから下がったか」を出せる。それが無いと、
    ただの並び替えにくいブックマークにしかならない。
    """
    title = "見守り中の商品"
    lead = ("商品ページで「見守る」を押した商品を、見始めた時からの差が大きい順に並べます。"
            "保存先はお使いの端末の中だけです。")
    return (head(f"{title}｜{site['name']}", lead, canonical, site, "../")
            + breadcrumb(site, title, "../")
            + f'<h1>{esc(title)}</h1><p class="lead">{esc(lead)}</p>'
            + AD_NOTICE
            + '<p id="note" class="note"></p><ul id="results" class="hits"></ul>'
            + """<script>
(function () {
  var out = document.getElementById('results');
  var note = document.getElementById('note');
  var store = PTWatch.read();
  var codes = Object.keys(store);
  if (!codes.length) {
    note.textContent = 'まだありません。商品ページの「見守る」を押すとここに並びます。';
    return;
  }
  note.textContent = '読み込んでいます…';
  fetch('../search-index.json').then(function (r) { return r.json(); }).then(function (data) {
    var hits = data.filter(function (r) { return store[r[3]]; }).map(function (r) {
      var e = store[r[3]];
      var was = e.p || 0;
      return {slug: r[0], name: r[1], now: r[2], was: was, target: e.t || 0,
              hit: e.t ? r[2] <= e.t : false,
              diff: was ? (was - r[2]) / was : 0, since: e.d || ''};
    });
    // 目標に達したものを先に。次が下げ幅の大きい順。
    hits.sort(function (a, b) { return (b.hit - a.hit) || (b.diff - a.diff); });
    var reached = hits.filter(function (h) { return h.hit; }).length;
    note.textContent = reached
      ? hits.length + '件のうち ' + reached + '件が目標の値段に達しています'
      : hits.length + '件';
    out.textContent = '';
    hits.forEach(function (h) {
      var li = document.createElement('li');
      li.className = 'hit';
      var a = document.createElement('a');
      a.href = '../item/' + h.slug + '/';
      a.textContent = ptShort(h.name, 46);
      a.title = h.name;
      li.appendChild(a);
      var p = document.createElement('span');
      p.className = 'price';
      if (h.was && h.diff > 0) {
        p.innerHTML = '';
        var d = document.createElement('span');
        d.className = 'down';
        d.textContent = '▼' + (h.diff * 100).toFixed(1) + '%';
        p.appendChild(d);
        p.appendChild(document.createTextNode(' ' + h.now.toLocaleString() + '円'));
      } else if (h.was && h.diff < 0) {
        var u = document.createElement('span');
        u.className = 'up';
        u.textContent = '▲' + (-h.diff * 100).toFixed(1) + '%';
        p.appendChild(u);
        p.appendChild(document.createTextNode(' ' + h.now.toLocaleString() + '円'));
      } else {
        p.textContent = h.now.toLocaleString() + '円';
      }
      li.appendChild(p);
      if (h.hit) {
        li.classList.add('reached');
        var t = document.createElement('span');
        t.className = 'badge low';
        t.textContent = '目標 ' + h.target.toLocaleString() + '円 に到達';
        li.appendChild(t);
      }
      if (h.since) {
        var s = document.createElement('span');
        s.className = 'since';
        s.textContent = h.since + 'から';
        li.appendChild(s);
      }
      out.appendChild(li);
    });
  }).catch(function () { note.textContent = '一覧を読み込めませんでした。'; });
})();
</script>"""
            + foot(site, "../", updated))


def item_page(row: dict, site: dict, updated: str, kin: list | None = None,
              shopmates: list | None = None, title_name: str = "",
              indexable: bool = True) -> str:
    prefix = "../../"
    canonical = f'{site["base_url"].rstrip("/")}/item/{slug(row["item_code"])}/'
    # 検索結果でタイトルは30文字前後、説明は120文字前後で切られる。
    # 商品名をそのまま入れると204文字になり、要点が全部切り落とされる。
    title = f'{title_name or short_name(row["name"], 28)}の価格推移・最安値'
    # 説明には値と日付を入れる。商品名を繰り返しても、検索結果に並んだとき
    # 他のページと見分けが付かない。
    state = ("いまが記録上の最安値" if row.get("at_low") else
             "最安値に近い" if row.get("near_low") else
             "前回より値下がり" if row.get("dropped") else
             f'最安値より{pct(row["vs_low_pct"])}高い' if row.get("vs_low_pct") else
             "価格は横ばい")
    desc = (f'{short_name(row["name"], 26)} の価格推移。'
            f'{jp_date(updated)}時点 {yen(row["price"])}、'
            f'記録した中での最安値は {yen(row["low"])}'
            f'（{jp_date(row.get("low_date") or "")}）。'
            + ('記録を始めたばかりで、まだ値動きを比べられません。'
               if int(row.get("days") or 0) < 2
               else f'{row["days"]}日分の記録では{state}です。'))

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
        "name": clean_name(row["name"]), "image": row.get("image") or None,
        "description": (row.get("caption") or "")[:200] or None,
        "sku": row.get("item_code") or None,
        "offers": {"@type": "Offer", "price": row["price"], "priceCurrency": "JPY",
                   "url": row.get("url") or canonical,
                   # 在庫は取得している。InStock と書き切ると、売り切れの商品まで
                   # 「在庫あり」として検索結果に出てしまう
                   "availability": ("https://schema.org/InStock"
                                    if row.get("in_stock", True)
                                    else "https://schema.org/OutOfStock"),
                   # 毎日取り直すので、この値段が言えるのは次の取得までとする
                   "priceValidUntil": next_day(updated),
                   "seller": {"@type": "Organization",
                              "name": row.get("shop") or ""}},
    })
    extra = f'<script type="application/ld+json">{ld}</script>'

    # indexable はどの一覧からも辿れるかで build が決める（実測で270件が該当なし）。
    # 辿れない商品は検索結果にだけ出る行き止まりになるので索引に載せない。
    # ページ自体は残す。見守りや外からのリンクの行き先になっている。
    return (head(f"{title}｜{site['name']}", desc, canonical, site, prefix, extra,
                 indexable=indexable)
            + breadcrumb(site, "商品の価格推移", prefix)
            + '<p class="back"><a href="../../">今日の値下がりへ</a><span class="sep">/</span><a href="../../lows/">最安値圏へ</a><span class="sep">/</span><a href="../../search/">商品を探す</a></p>'
            + f'<article class="item"><h1 title="{esc(row["name"])}">'
              f'{esc(short_name(row["name"], 70))}</h1>'
            + (f'<p class="fullname">{esc(row["name"])}</p>'
               if len(row["name"]) > 70 else '')
            + (f'<p class="hero"><img src="{esc(row["image"])}" '
               f'alt="{esc(short_name(row["name"], 40))}" width="300" height="300" '
               f'decoding="async"></p>' if row.get("image") else '')
            + AD_NOTICE
            + f'<p class="headline"><strong>{yen(row["price"])}</strong> {badge(row)}</p>'
            + f'<p class="verdict">{esc(verdict_note(row))}</p>'
            + f'<div class="chart">{chart(row.get("tail") or [])}</div>'
            + (f'<p class="note">{esc(cheaper_days(row))}</p>' if cheaper_days(row) else '')
            + f'<table class="facts">{table}</table>'
            + caption_block(row)
            + history_table(row)
            + (WATCH_BUTTON.replace("{code}", esc(row["item_code"]))
               .replace("{price}", str(row["price"]))
               .replace("{prefix}", prefix))
            + f'<p class="cta">{buy_link(row)}</p>'
            + f'<p class="shop">販売店: {esc(row.get("shop", ""))}</p>'
            + related(kin or [], site)
            + same_shop(shopmates or [], row.get("shop", ""))
            + '</article>'
            + foot(site, prefix, updated))
