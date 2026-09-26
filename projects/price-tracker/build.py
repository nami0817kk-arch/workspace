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

from src import analyze, pages, store, theme  # noqa: E402

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
        "Disallow: /search-index.json\n"
        f"\nSitemap: {site['base_url'].rstrip('/')}/sitemap.xml\n")


# 1ページ100件だと携帯で縦24,000px（約31画面分）になり、末尾まで届かない。
PER_PAGE = 50


def write_listing(out: Path, urls: list, path: str, title: str, lead: str,
                  rows: list, site: dict, base: str, updated: str, empty: str,
                  stats: dict, show_score: bool = False,
                  linked: set | None = None) -> None:
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
                            page_prefix=prefix + path, total=len(rows),
                            show_score=show_score))
        urls.append("/" + rel)


def build(root: Path, out: Path) -> dict:
    site = store.load_json(root / "config.json", {})
    data = root / "data"
    items = store.load_json(data / "items.json", {})
    summary = store.load_json(data / "summary.json", {})

    rows = analyze.evaluate_all(summary, items,
                                site.get("drop_threshold", 0.05),
                                site.get("near_low_threshold", 0.02))
    updated = today()

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
    write_listing(out, urls, "", "いま条件がそろっている商品",
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
                  "前回の記録より高くなった商品です。買い時ではないことも同じ基準で出しています。",
                  analyze.rises(rows, site.get("drop_threshold", 0.05)),
                  site, base, updated,
                  "今日の記録では、目立った値上がりはありませんでした。", stats, linked=linked)

    write_listing(out, urls, "lows/", "最安値圏の商品",
                  "当サイトが記録している期間の最安値と同じか、それに近い価格の商品です。",
                  low, site, base, updated,
                  "価格の記録日数がまだ足りません。判定には最低7日分が必要です。", stats, linked=linked)

    latest_day = max((p.name[:10] for p in (data / "snapshots").glob("*.csv.gz")),
                     default=updated)
    write_listing(out, urls, "new-lows/", "今日 最安値を更新した商品",
                  "記録している期間の最安値を、この日に塗り替えた商品です。"
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
        write_listing(out, urls, f"archive/{day}/", f"{day} の値下がり",
                      f"{day} に価格が下がった商品の記録です。",
                      hit, site, base, updated,
                      "この日は記録できる値下がりがありませんでした。", stats, linked=linked)
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
    listed = []
    for genre in site.get("genres") or []:
        g = genre if isinstance(genre, dict) else {"genre_id": str(genre)}
        gid = str(g.get("genre_id") or genre)
        # 名前は config で付ける任意項目。無ければIDをそのまま見出しにする。
        g = {**g, "genre_id": gid, "name": str(g.get("name") or gid)}
        hit = analyze.by_genre(rows, gid)
        write_listing(out, urls, f"genre/{gid}/", f'{g["name"]}の値下がり',
                      f'{g["name"]}の商品を毎日記録し、値下がりの大きい順に並べています。',
                      hit, site, base, updated,
                      "このジャンルはまだ記録が始まったばかりです。", stats, linked=linked)
        listed.append({**g, "count": len(hit)})

    write(out / "genre" / "index.html",
          theme.genre_index(listed, site, base + "/genre/", updated, prefix="../"))
    urls.append("/genre/")

    by_gid = {}
    by_shop = {}
    for r in rows:
        by_gid.setdefault(str(r.get("source_genre") or ""), []).append(r)
        by_shop.setdefault(r.get("shop") or "", []).append(r)

    # 題は全商品をまとめて決める。同じ題が並ばないようにするため（page_titles）
    titles = theme.page_titles(rows)

    for row in rows:
        s = theme.slug(row["item_code"])
        kin = [r for r in by_gid.get(str(row.get("source_genre") or ""), [])
               if r["item_code"] != row["item_code"]][:8]
        seen = {row["item_code"]} | {r["item_code"] for r in kin}
        mates = [r for r in by_shop.get(row.get("shop") or "", [])
                 if r["item_code"] not in seen][:6]
        in_list = row["item_code"] in linked
        write(out / "item" / s / "index.html",
              theme.item_page(row, site, updated, kin, mates,
                              titles.get(row["item_code"], ""), indexable=in_list))
        # 一覧に載らない商品は noindex なので、サイトマップにも載せない
        if in_list:
            urls.append((f"/item/{s}/", row.get("changed_date") or updated))

    # 検索用の索引。数百KBあるので、検索ページで必要になったときだけ読ませる。
    write(out / "search-index.json", json.dumps(
        # 判定は符号1文字で持つ。文字列で持つと索引が数百KB太る。
        # 名前は宣伝を落としてから積む。検索窓で「9/25限定」に当たっても仕方ない
        [[theme.slug(r["item_code"]), theme.clean_name(r["name"]), r["price"],
          r["item_code"],
          3 if r["at_low"] else (2 if r["near_low"] else (1 if r["dropped"] else 0))]
         for r in rows],
        ensure_ascii=False, separators=(",", ":")))
    write(out / "search" / "index.html",
          theme.search_page(site, base + "/search/", updated, stats))
    urls.append("/search/")

    write(out / "watch" / "index.html",
          theme.watch_page(site, base + "/watch/", updated))
    urls.append("/watch/")


    # その日の記録を CSV でも出す。表計算で開いて自分で調べられるようにする。
    csv_rows = ["item_code,name,price,point_rate,effective,low,high,days,shop"]
    for r in rows:
        name = (r["name"] or "").replace('"', "'")
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

    counts = [analyze.change_count(r) for r in rows]
    write(out / "stats" / "index.html", theme.stats_page(
        site, base + "/stats/", updated, stats,
        {"still": sum(1 for n in counts if n == 0),
         "once": sum(1 for n in counts if n == 1),
         "active": sum(1 for n in counts if n >= 2),
         "pointed": sum(1 for r in rows if int(r.get("point_rate") or 1) > 1)},
        listed,
        [(r, analyze.change_count(r)) for r in analyze.active(rows, limit=10)],
        archive_counts[:14]))
    urls.append("/stats/")

    # 共有時の画像・行き先を示す404・値下がりの購読（RSS）。
    write(out / "og.svg", theme.og_image(site, stats))
    write(out / "404.html", theme.not_found(site, updated))
    write(out / "feed.xml", theme.feed(site, dropped, updated))
    write(out / "points" / "feed.xml", theme.feed(
        site, analyze.effective_drops(rows, site.get("drop_threshold", 0.05)),
        updated, "ポイント込みで安くなった商品", "points/"))
    write(out / "new-lows" / "feed.xml", theme.feed(
        site, analyze.new_lows(rows, latest_day), updated,
        "最安値を更新した商品", "new-lows/"))

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
