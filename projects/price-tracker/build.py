#!/usr/bin/env python3
"""記録済みのデータから静的サイトを生成する。ネットワークへは一切アクセスしない。"""
import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import analyze, icon, pages, relate, store, theme  # noqa: E402

JST = timezone(timedelta(hours=9))


def today() -> str:
    return datetime.now(JST).strftime("%Y-%m-%d")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def sitemap(site: dict, urls, updated: str) -> str:
    """urls は "/path" か ("/path", 更新日) を混ぜてよい。

    全ページを毎日「今日更新」と申告すると、実際には変わっていないページまで
    再クロールさせることになる。商品ページは最後に価格が動いた日を出す。
    """
    base = site["base_url"].rstrip("/")
    entries = "".join(
        f"\n  <url><loc>{theme.esc(base + path)}</loc><lastmod>{mod}</lastmod></url>"
        for path, mod in ((u, updated) if isinstance(u, str) else u for u in urls))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            f'{entries}\n</urlset>\n')


def robots(site: dict) -> str:
    """配布用の大きなファイルはクロールさせない。

    history.csv は3MB、search-index.json は1.7MB ある。人が取りに来る分には
    よいが、毎回クロールされても検索結果の役には立たない。
    """
    return (
        "User-agent: *\n"
        "Allow: /\n"
        "Disallow: /history.csv\n"
        "Disallow: /data.csv\n"
        # 索引の名前には中身の指紋が入る（search-index.<8桁>.json）。
        # 前方一致で塞ぐ
        "Disallow: /search-index.\n"
        f"\nSitemap: {site['base_url'].rstrip('/')}/sitemap.xml\n")


# 1ページ100件だと携帯で縦24,000px（約31画面分）になり、末尾まで届かない。
PER_PAGE = 50
# 中分類のページを作る下限。これ未満は面が散らかるだけで役に立たない
MIN_SUB_GENRE = 10


def write_listing(out: Path, urls: list, path: str, title: str, lead: str,
                  rows: list, site: dict, base: str, updated: str, empty: str,
                  stats: dict, show_score: bool = False,
                  linked: set | None = None,
                  parent: tuple | None = None,
                  terms: list | None = None, subs: list | None = None) -> None:
    """一覧をページ送りで書き出す。

    最安値圏は4,000件を超える。1枚に詰めると読めないうえ、100件で打ち切ると
    記録した資産のほとんどを捨てることになる。

    linked には載せた商品コードを控える。どの一覧にも載らない商品は、
    検索結果にだけ出る行き止まりのページになるので索引に載せない。
    """
    if linked is not None:
        linked.update(r["item_code"] for r in rows)
    pages = max(1, -(-len(rows) // PER_PAGE))
    for i in range(pages):
        rel = path if i == 0 else f"{path}{i + 1}/"
        prefix = "../" * rel.count("/")
        target = (out / rel / "index.html") if rel else (out / "index.html")
        write(target,
              theme.listing(title, lead, rows[i * PER_PAGE:(i + 1) * PER_PAGE],
                            site, base + "/" + rel, updated, prefix=prefix,
                            empty=empty, stats=stats, page=i + 1, pages=pages,
                            parent=parent,
                            page_prefix=prefix + path, total=len(rows),
                            show_score=show_score, terms=terms, subs=subs))
        urls.append("/" + rel)


def build(root: Path, out: Path) -> dict:
    site = store.load_json(root / "config.json", {})
    data = root / "data"
    items = store.load_json(data / "items.json", {})
    summary = store.load_json(data / "summary.json", {})

    rows = analyze.evaluate_all(summary, items,
                                site.get("drop_threshold", 0.05),
                                site.get("near_low_threshold", 0.02))
    # 「最終更新」は価格を記録した日にする。ビルドした日を出すと、取得が
    # 失敗した朝でも「最終更新 今日」と表示され、前日の価格を今日の価格として
    # 見せることになる（2026-09-26 に実際にそうなっていた）。
    # 記録が1日も無いときだけ、今日の日付で組む。
    latest_day = max((p.name[:10] for p in (data / "snapshots").glob("*.csv.gz")),
                     default="")
    updated = latest_day or today()
    latest_day = latest_day or updated   # 最安値更新の判定日。記録が無い日は今日

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    # スタイルは中身の指紋を名前に入れる。style.css のままだと、直しても
    # Cloudflare のエッジキャッシュ（実測4時間）が切れるまで読み手に届かない。
    # 名前が変われば即座に新しい方を読みに来るので、逆に長く持たせてよい。
    css_text = (ROOT / "src" / "style.css").read_text(encoding="utf-8")
    css_name = f"style.{hashlib.sha1(css_text.encode('utf-8')).hexdigest()[:8]}.css"
    write(out / css_name, css_text)
    site["css"] = css_name

    # JavaScript も同じ扱い。以前は全ページに直書きしていたため、
    # 同じ本文を12,658枚ぶん配っていて、ページを移るたび読み直させていた。
    # 外に出すと1回読めば使い回せる（指紋付きなので長く持たせられる）。
    for key, text in (("app_js", theme.WATCH_JS), ("list_js", theme.LIST_JS)):
        stem = key.split("_")[0]
        name = f"{stem}.{hashlib.sha1(text.encode('utf-8')).hexdigest()[:8]}.js"
        write(out / name, text)
        site[key] = name
    # 配信時のヘッダ。Cloudflare Pages は dist/ 直下の _headers を読む。
    shutil.copy(ROOT / "src" / "_headers", out / "_headers")

    base = site["base_url"].rstrip("/")
    # サイトの規模と記録の厚み。値下がりが数件しかない日でも、
    # 何を持っているサイトなのかが一覧の先頭で伝わるようにする。
    stats = {"items": len(rows),
             "days": len(sorted((data / "snapshots").glob("*.csv.gz"))),
             "updated": updated}
    dropped = analyze.drops(rows)
    low = analyze.lows(rows)

    urls = []
    # 一覧に載せた商品。ここに入らないものは検索結果にだけ出る行き止まり
    linked = set()
    write_listing(out, urls, "now/", "いま条件がそろっている商品",
                  "最安値への近さ・ポイント込みの下げ幅・価格の下げ幅・送料・"
                  "値動きの多さを、それぞれ上限を決めて足した順に並べています。"
                  "買うべきかは決めません。どの条件がいくつ満たされたかを出すだけです。",
                  analyze.well_stocked(rows, limit=600), site, base, updated,
                  "条件がそろった商品はまだありません。記録が7日分たまってからになります。",
                  stats, show_score=True, linked=linked)

    write_listing(out, urls, "drops/", "今日の値下がり",
                  "毎日記録している楽天市場の価格から、前回より安くなった商品を並べています。",
                  dropped, site, base, updated,
                  "今日の記録では、判定できるほどの値下がりはありませんでした。", stats, linked=linked)

    write_listing(out, urls, "points/", "ポイント込みで安くなった商品",
                  "価格が据え置きでも、ポイント倍率が上がれば実質は安くなります。"
                  "その分を引いた金額で下がったものを並べています。",
                  analyze.effective_drops(rows, site.get("drop_threshold", 0.05)),
                  site, base, updated,
                  "今日の記録では、ポイントを含めても目立った値下がりはありませんでした。", stats,
                  linked=linked)

    write_listing(out, urls, "rises/", "値上がりした商品",
                  "前回の記録より高くなった商品です。ポイント倍率が下がって"
                  "実質価格が上がったものも含みます。"
                  "買い時ではないことも同じ基準で出しています。",
                  analyze.rises(rows, site.get("drop_threshold", 0.05)),
                  site, base, updated,
                  "今日の記録では、目立った値上がりはありませんでした。", stats, linked=linked)

    write_listing(out, urls, "lows/", "最安値圏の商品",
                  "一度は値下がりしたうえで、当サイトが記録している期間の最安値と"
                  "同じか、それに近い価格にある商品です。"
                  "ポイントを含めた実質価格が記録した中でいちばん安い商品も含みます"
                  "（楽天の値引きは価格ではなくポイント倍率で動くことが多いため）。"
                  "価格も倍率も一度も動いていない商品は含みません"
                  "（動いていなければ、その値段が自動的に最安値になるだけのため）。",
                  low, site, base, updated,
                  "価格の記録日数がまだ足りません。判定には最低7日分が必要です。", stats, linked=linked)

    write_listing(out, urls, "new-lows/", "今日 最安値を更新した商品",
                  "記録している期間の最安値を、この日に塗り替えた商品です。"
                  "ポイントを含めた実質価格で塗り替えたものも含みます。"
                  "近い価格を含む最安値圏とは別に、更新した当日だけを出しています。",
                  analyze.new_lows(rows, latest_day), site, base, updated,
                  "この日に最安値を更新した商品はありませんでした。", stats, linked=linked)

    write_listing(out, urls, "ending/", "ポイントの期限が近い商品",
                  "ポイント倍率には終わりの日時があります。3日以内に終わるものを、"
                  "終わりが早い順に並べています。待つか今かの判断に使ってください。",
                  analyze.ending_soon(rows, updated), site, base, updated,
                  "3日以内に終わるポイント倍率の商品はありませんでした。", stats, linked=linked)

    write_listing(out, urls, "active/", "よく動く商品",
                  "記録している期間に価格が何度も変わった商品です。"
                  "動かない商品が大半のなかで、追う値打ちがあるのはここに出るものです。",
                  analyze.active(rows), site, base, updated,
                  "価格が複数回動いた商品はまだありません。", stats, linked=linked)

    # 日付別アーカイブ。過ぎた日の値下がりを残す。ためた履歴がそのまま増える。
    archive_days = sorted((p.name[:10] for p in (data / "snapshots").glob("*.csv.gz")),
                          reverse=True)[:60]
    archive_counts = []
    for day in archive_days:
        hit = analyze.drops_on(rows, day, site.get("drop_threshold", 0.05))
        write_listing(out, urls, f"archive/{day}/", f"{day} に安くなった商品",
                      f"{day} に安くなった商品の記録です。"
                      f"価格が下がったものと、ポイント倍率が上がって"
                      f"実質価格が下がったものを含みます。",
                      hit, site, base, updated,
                      "この日は記録できる値下がりがありませんでした。", stats,
                      linked=linked, parent=("日付別 安くなった商品", "archive/"))
        archive_counts.append((day, len(hit)))
        pos = archive_days.index(day)
        newer = archive_days[pos - 1] if pos > 0 else None
        older = archive_days[pos + 1] if pos + 1 < len(archive_days) else None
        path = out / "archive" / day / "index.html"
        path.write_text(
            path.read_text(encoding="utf-8").replace(
                '<ul class="cards">', theme.archive_nav(day, older, newer)
                + '<ul class="cards">', 1),
            encoding="utf-8")

    write(out / "archive" / "index.html",
          theme.archive_index(archive_counts, site, base + "/archive/", updated))
    urls.append("/archive/")

    for page in pages.PAGES:
        write(out / page["slug"] / "index.html", pages.render(page, site, updated))
        urls.append(f'/{page["slug"]}/')

    # ジャンル別の入口。単品ページで価格比較サイトと正面から競合するより、
    # ジャンル単位のページを持って内部リンクを集約するほうが取りに行ける。
    # ジャンルの下に置く「そのジャンルらしい語」。価格.com のトップはカテゴリの
    # 下にサブ項目を2行置いていて、それが「ここに何があるか」を伝えている。
    # うちは楽天のジャンルを8つしか取っておらず下の階層を持たないので、
    # 商品名から出す（0.3秒）。
    names_by_genre = {}
    for r in rows:
        gid_ = str(r.get("source_genre") or "")
        if gid_:
            # 生の名前には先頭の宣伝が付く（日替わりで変わる）。落としてから数える。
            names_by_genre.setdefault(gid_, []).append(
                theme.clean_name(str(r.get("name") or "")))
    terms_by_genre = relate.genre_terms(names_by_genre)

    # 楽天は商品ごとに末端のジャンルIDを返す（1,054種類）。名前と階層は
    # ジャンル検索APIで一度引いて data/genres.json に控えてある
    # （`python fetch_genres.py`。通信するのはここだけ）。
    # 価格.com のカテゴリページは下位カテゴリを件数つきで並べていて、
    # 2,973製品の中から1手で奥へ入れる。末端のままだと大ジャンル1つに
    # 57〜202種類あって多すぎるので、**level 2 でまとめる**
    # （家電 → 季節・空調家電608 / 美容・健康家電479 / キッチン家電427…）。
    genre_names = store.load_json(data / "genres.json", {})

    def mid_genre(row):
        """その商品が属する中分類（level 2）。無ければ末端そのもの。"""
        info = genre_names.get(str(row.get("genre_id") or ""))
        if not info:
            return None
        for a in info.get("ancestors") or []:
            if int(a.get("level") or 0) == 2:
                return (str(a["id"]), str(a["name"]))
        return (str(row.get("genre_id")), str(info.get("name") or ""))

    subs_by_genre = {}
    for r in rows:
        src = str(r.get("source_genre") or "")
        mid = mid_genre(r)
        if src and mid:
            subs_by_genre.setdefault(src, {}).setdefault(mid, []).append(r)

    listed = []
    for genre in site.get("genres") or []:
        g = genre if isinstance(genre, dict) else {"genre_id": str(genre)}
        gid = str(g.get("genre_id") or genre)
        # 名前は config で付ける任意項目。無ければIDをそのまま見出しにする。
        g = {**g, "genre_id": gid, "name": str(g.get("name") or gid)}
        hit = analyze.by_genre(rows, gid)
        # 題は中身に合わせる。「◯◯の値下がり」で全商品を出していたため、
        # 実測（2026-09-28）ではパソコン・周辺機器1,528件のうち値下がりは3件
        # しか無いのに、題は「値下がり」と名乗っていた。
        # 中身を値下がりだけに絞ると13,000ページへの導線が消えて索引から
        # 落ちるので、絞るのではなく題のほうを直す。
        # 価格.com のカテゴリページは「注目スペック」を件数つきで並べていて、
        # 1,500件の中から1手で奥へ入れる。うちはページ送りしか無かった。
        # 中分類は件数の多い順。1件しか無いものまで並べると面が散らかる
        # （家電は「電卓・デジタル文具1」「その他2」まで出ていた）。
        # 10件に満たないものはページも作らない。そこにある商品は大ジャンルの
        # 一覧に出ているので、辿れなくなるわけではない。
        order = {r["item_code"]: i for i, r in enumerate(hit)}
        sub_pairs = sorted(
            ((key, sorted(members, key=lambda r: order.get(r["item_code"], 1 << 30)))
             for key, members in (subs_by_genre.get(gid) or {}).items()
             if len(members) >= MIN_SUB_GENRE),
            key=lambda kv: -len(kv[1]))
        sub_chips = [(name, len(members), f"genre/{gid}/{mid}/")
                     for (mid, name), members in sub_pairs]

        words = terms_by_genre.get(gid, [])
        counted = [(w, sum(1 for r in hit
                           if w in theme.clean_name(str(r.get("name") or "")).lower()))
                   for w in words]
        write_listing(out, urls, f"genre/{gid}/", f'{g["name"]}の価格記録',
                      f'{g["name"]}の商品を毎日記録しています。'
                      f'値下がりの大きい順に並べていますが、'
                      f'値下がりしていない商品も含みます。',
                      hit, site, base, updated,
                      "このジャンルはまだ記録が始まったばかりです。", stats,
                      linked=linked, parent=("ジャンル別で見る", "genre/"),
                      terms=counted, subs=sub_chips)
        listed.append({**g, "count": len(hit),
                       "terms": terms_by_genre.get(gid, []),
                       "subs": sub_chips})

        # 中分類のページ。ここが価格.com の「カテゴリの下のカテゴリ」に当たる。
        for (mid_id, mid_name), members in sub_pairs:
            write_listing(out, urls, f"genre/{gid}/{mid_id}/",
                          f"{mid_name}の価格記録",
                          f'{g["name"]}のうち{mid_name}の商品を毎日記録しています。'
                          f'値下がりの大きい順に並べていますが、'
                          f'値下がりしていない商品も含みます。',
                          members, site, base, updated,
                          "このジャンルはまだ記録が始まったばかりです。", stats,
                          linked=linked,
                          parent=(g["name"], f"genre/{gid}/"))

    write(out / "genre" / "index.html",
          theme.genre_index(listed, site, base + "/genre/", updated, prefix="../"))
    urls.append("/genre/")

    by_gid = {}
    by_shop = {}
    for r in rows:
        by_gid.setdefault(str(r.get("source_genre") or ""), []).append(r)
        by_shop.setdefault(r.get("shop") or "", []).append(r)

    # 同じ中分類の中で、その値段がどのあたりか。
    # 実測（2026-10-03）で、記録している13,544商品のうち**9,700件（71.6%）は
    # 価格も実質価格も一度も動いていない**。その商品ページには「ずっと同じ値段」
    # という情報しか無かった。同じ分類の中での位置は、13,544商品ぶんの価格を
    # 毎日持っているからこそ出せる。
    sub_stats = {}
    for src, groups in subs_by_genre.items():
        for (mid, name), members in groups.items():
            if len(members) < MIN_SUB_GENRE:
                continue
            prices = sorted(int(r.get("price") or 0) for r in members)
            lo, hi = prices[0], prices[-1]
            middle = prices[len(prices) // 2]
            # 同じ値段は同じ順位にする。並べ替えの偶然で「9番目」「10番目」
            # 「11番目」と散ると、順位が何も意味しなくなる（実測で、同じ
            # 2,980円の商品3件に別々の順位が付いていた）。
            rank_of = {}
            for i, pz in enumerate(prices, 1):
                rank_of.setdefault(pz, i)
            for r in members:
                sub_stats[r["item_code"]] = {
                    "sub_name": name,
                    "sub_rank": rank_of[int(r.get("price") or 0)],
                    "sub_count": len(members),
                    "sub_low": lo, "sub_mid": middle, "sub_high": hi,
                    "sub_path": f"genre/{src}/{mid}/"}

    # 題は全商品をまとめて決める。同じ題が並ばないようにするため（page_titles）
    titles = theme.page_titles(rows)

    # 似た商品は名前の近さで選ぶ。同じジャンルの先頭から取っていたときは、
    # 60ページを調べて33商品・5通りしか出ていなかった。読み手には関係のない
    # 商品が並び、商品ページどうしのリンクもひと握りに集中していた。
    akin = relate.related(rows, lambda r: theme.clean_name(r["name"]))

    for row in rows:
        s = theme.slug(row["item_code"])
        kin = akin.get(row["item_code"]) or [
            r for r in by_gid.get(str(row.get("source_genre") or ""), [])
            if r["item_code"] != row["item_code"]][:8]
        seen = {row["item_code"]} | {r["item_code"] for r in kin}
        mates = [r for r in by_shop.get(row.get("shop") or "", [])
                 if r["item_code"] not in seen][:6]
        in_list = row["item_code"] in linked
        write(out / "item" / s / "index.html",
              theme.item_page({**row, **sub_stats.get(row["item_code"], {})},
                              site, updated, kin, mates,
                              titles.get(row["item_code"], ""), indexable=in_list))
        # 一覧に載らない商品は noindex なので、サイトマップにも載せない
        if in_list:
            urls.append((f"/item/{s}/", row.get("changed_date") or updated))

    # 検索用の索引。数百KBあるので、検索ページで必要になったときだけ読ませる。
    index_text = json.dumps(
        # 判定は符号1文字で持つ。文字列で持つと索引が数百KB太る。
        # 名前は宣伝を落としてから積む。検索窓で「9/25限定」に当たっても仕方ない
        [[theme.slug(r["item_code"]), theme.clean_name(r["name"]), r["price"],
          r["item_code"],
          3 if r["at_low"] else (2 if r["near_low"] else (1 if r["dropped"] else 0))]
         for r in rows],
        ensure_ascii=False, separators=(",", ":"))
    # 索引は 3.9MB（圧縮後 1.1MB）ある。名前が固定だと毎回取り直しになるので
    # 中身の指紋を付けて長く持たせる。中身が変われば名前も変わるので、
    # 翌日の更新はきちんと届く（スタイルや JS と同じ扱い）。
    index_name = (f"search-index.{hashlib.sha1(index_text.encode('utf-8')).hexdigest()[:8]}"
                  ".json")
    write(out / index_name, index_text)
    site["search_index"] = index_name
    write(out / "search" / "index.html",
          theme.search_page(site, base + "/search/", updated, stats))
    urls.append("/search/")

    write(out / "watch" / "index.html",
          theme.watch_page(site, base + "/watch/", updated))
    # 見守りは noindex（中身が端末の中にしか無い）。sitemap にも載せない。


    # その日の記録を CSV でも出す。表計算で開いて自分で調べられるようにする。
    csv_rows = ["item_code,name,price,point_rate,effective,low,high,days,shop"]
    for r in rows:
        # サイトに出す名前と同じものを配る。生の名前は先頭の宣伝が日替わりで
        # 書き換わるため、同じ商品なのに日によって別の文字列になる。
        name = theme.clean_name(r["name"] or "").replace('"', "'")
        shop = (r.get("shop") or "").replace('"', "'")
        csv_rows.append(
            f'{r["item_code"]},"{name}",{r["price"]},{r.get("point_rate", 1)},'
            f'{r.get("eff_price", r["price"])},{r["low"]},{r["high"]},{r["days"]},"{shop}"')
    write(out / "data.csv", "\n".join(csv_rows) + "\n")

    hist = ["date,item_code,price,point_rate"]
    for code, rec in summary.items():
        for e in (store.entry(x) for x in rec.get("tail") or []):
            hist.append(f"{e[0]},{code},{e[1]},{e[2]}")
    write(out / "history.csv", "\n".join(hist) + "\n")

    # 「動いたか」は商品ページと同じ数え方（ポイント込みの実質価格）にそろえる。
    # 価格だけで数えていたため、記録ページだけ 11,172件が「一度も動いていない」
    # と出ていた。実質で見ると動いたのは2,252件で、同じサイトで数え方が
    # 2つある状態になっていた。
    counts = [analyze.change_count(r) for r in rows]
    eff_counts = [analyze.effective_change_count(r) for r in rows]
    write(out / "stats" / "index.html", theme.stats_page(
        site, base + "/stats/", updated, stats,
        {"still": sum(1 for n in eff_counts if n == 0),
         "price_moved": sum(1 for n in counts if n >= 1),
         "eff_moved": sum(1 for n in eff_counts if n >= 1),
         "active": sum(1 for n in eff_counts if n >= 2),
         "pointed": sum(1 for r in rows if int(r.get("point_rate") or 1) > 1)},
        listed,
        [(r, analyze.change_count(r)) for r in analyze.active(rows, limit=10)],
        archive_counts[:14]))
    urls.append("/stats/")

    # 共有時の画像・行き先を示す404・値下がりの購読（RSS）。
    # 共有したときに出る絵。X も Facebook も LINE も og:image の SVG を
    # 描かないので PNG も出す。og.svg は残す（中身は数字入りで、
    # ページに埋め込んで見せるぶんには SVG のほうが軽い）。
    write(out / "og.svg", theme.og_image(site, stats))
    (out / "og.png").write_bytes(icon.og_png())
    write(out / "404.html", theme.not_found(site, updated))
    write(out / "feed.xml", theme.feed(site, dropped, updated))
    write(out / "points" / "feed.xml", theme.feed(
        site, analyze.effective_drops(rows, site.get("drop_threshold", 0.05)),
        updated, "ポイント込みで安くなった商品", "points/"))
    write(out / "new-lows" / "feed.xml", theme.feed(
        site, analyze.new_lows(rows, latest_day), updated,
        "最安値を更新した商品", "new-lows/"))

    # どの一覧を見ればよいかの索引。件数が全部そろうのは最後なので、
    # トップを書くのは他の一覧を全部書き終えてから。
    views = [
        ("now/", "いま条件がそろっている商品", len(analyze.well_stocked(rows, limit=600)),
         "最安値への近さ・ポイント・送料などを点にして足した順"),
        ("drops/", "今日の値下がり", len(dropped), "前回の記録より安くなったもの"),
        ("points/", "ポイント込み", len(analyze.effective_drops(
            rows, site.get("drop_threshold", 0.05))), "ポイント分を引くと安いもの"),
        ("new-lows/", "最安値更新", len(analyze.new_lows(rows, latest_day)),
         "記録した最安値をこの日に塗り替えたもの"),
        ("lows/", "最安値圏", len(low), "一度下がって、記録した最安値と同じか近いもの"),
        ("rises/", "値上がり", len(analyze.rises(
            rows, site.get("drop_threshold", 0.05))), "前回より高くなったもの"),
        ("active/", "よく動く", len(analyze.active(rows)),
         "記録のあいだに価格が何度も変わったもの"),
        ("ending/", "期限が近い", len(analyze.ending_soon(rows, updated)),
         "ポイント倍率が3日以内に終わるもの"),
        ("genre/", "ジャンル別", len(listed), "ジャンルごとの価格記録（値下がりの大きい順）"),
        ("archive/", "日付別", len(archive_counts), "過ぎた日に安くなった商品の記録"),
    ]
    # トップは商品を並べず、入口だけを置く（2026-09-26 ユーザー指示）。
    write(out / "index.html",
          theme.home_page(site, base + "/", updated, stats, views, listed))
    urls.append("/")

    # 検索結果に出る印。ブラウザは指定が無くても /favicon.ico を取りに来るので
    # 両方置く（実測でその404が出ていた）。
    (out / "icon.png").write_bytes(icon.png())
    (out / "favicon.ico").write_bytes(icon.ico())

    write(out / "sitemap.xml", sitemap(site, urls, updated))
    write(out / "robots.txt", robots(site))

    return {"items": len(rows), "drops": len(dropped), "lows": len(low),
            "pages": len(urls), "updated": updated}


def warnings(root: Path) -> list[str]:
    site = store.load_json(root / "config.json", {})
    out = []
    missing = [k for k in ("owner", "contact_email") if not site.get(k)]
    if missing:
        out.append(f"config.json の未設定: {', '.join(missing)}"
                   "（アフィリエイトを行うサイトには運営者情報の表示が必要です）")
    if not site.get("genres"):
        out.append("config.json の genres が空です。explore.py で対象ジャンルを決めてください。")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="記録済みデータから静的サイトを生成する")
    ap.add_argument("--out", default=str(ROOT / "dist"))
    args = ap.parse_args()

    stats = build(ROOT, Path(args.out))
    print(f"生成しました: 商品{stats['items']}件 / 値下がり{stats['drops']}件 / "
          f"最安値圏{stats['lows']}件 / 全{stats['pages']}ページ（{stats['updated']}）")
    for w in warnings(ROOT):
        print(f"  警告: {w}")
    if stats["items"] == 0:
        print("  警告: 商品データがありません。先に fetch.py を実行してください。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
