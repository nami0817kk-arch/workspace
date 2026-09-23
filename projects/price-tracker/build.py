#!/usr/bin/env python3
"""記録済みのデータから静的サイトを生成する。ネットワークへは一切アクセスしない。"""
import argparse
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
    return f"User-agent: *\nAllow: /\n\nSitemap: {site['base_url'].rstrip('/')}/sitemap.xml\n"


PER_PAGE = 100


def write_listing(out: Path, urls: list, path: str, title: str, lead: str,
                  rows: list, site: dict, base: str, updated: str, empty: str,
                  stats: dict) -> None:
    """一覧をページ送りで書き出す。

    最安値圏は4,000件を超える。1枚に詰めると読めないうえ、100件で打ち切ると
    記録した資産のほとんどを捨てることになる。
    """
    pages = max(1, -(-len(rows) // PER_PAGE))
    for i in range(pages):
        rel = path if i == 0 else f"{path}{i + 1}/"
        prefix = "../" * rel.count("/")
        target = (out / rel / "index.html") if rel else (out / "index.html")
        write(target,
              theme.listing(title, lead, rows[i * PER_PAGE:(i + 1) * PER_PAGE],
                            site, base + "/" + rel, updated, prefix=prefix,
                            empty=empty, stats=stats, page=i + 1, pages=pages,
                            page_prefix=prefix + path, total=len(rows)))
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
    shutil.copy(ROOT / "src" / "style.css", out / "style.css")

    base = site["base_url"].rstrip("/")
    # サイトの規模と記録の厚み。値下がりが数件しかない日でも、
    # 何を持っているサイトなのかが一覧の先頭で伝わるようにする。
    stats = {"items": len(rows),
             "days": len(sorted((data / "snapshots").glob("*.csv.gz"))),
             "updated": updated}
    dropped = analyze.drops(rows)
    low = analyze.lows(rows)

    urls = []
    write_listing(out, urls, "", "今日の値下がり",
                  "毎日記録している楽天市場の価格から、前回より安くなった商品を並べています。",
                  dropped, site, base, updated,
                  "今日の記録では、判定できるほどの値下がりはありませんでした。", stats)

    write_listing(out, urls, "points/", "ポイント込みで安くなった商品",
                  "価格が据え置きでも、ポイント倍率が上がれば実質は安くなります。"
                  "その分を引いた金額で下がったものを並べています。",
                  analyze.effective_drops(rows, site.get("drop_threshold", 0.05)),
                  site, base, updated,
                  "今日の記録では、ポイントを含めても目立った値下がりはありませんでした。", stats)

    write_listing(out, urls, "rises/", "値上がりした商品",
                  "前回の記録より高くなった商品です。買い時ではないことも同じ基準で出しています。",
                  analyze.rises(rows, site.get("drop_threshold", 0.05)),
                  site, base, updated,
                  "今日の記録では、目立った値上がりはありませんでした。", stats)

    write_listing(out, urls, "lows/", "最安値圏の商品",
                  "当サイトが記録している期間の最安値と同じか、それに近い価格の商品です。",
                  low, site, base, updated,
                  "価格の記録日数がまだ足りません。判定には最低7日分が必要です。", stats)

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
                      "このジャンルはまだ記録が始まったばかりです。", stats)
        listed.append({**g, "count": len(hit)})

    write(out / "genre" / "index.html",
          theme.genre_index(listed, site, base + "/genre/", updated, prefix="../"))
    urls.append("/genre/")

    for row in rows:
        s = theme.slug(row["item_code"])
        write(out / "item" / s / "index.html", theme.item_page(row, site, updated))
        urls.append((f"/item/{s}/", row.get("changed_date") or updated))

    # 検索用の索引。数百KBあるので、検索ページで必要になったときだけ読ませる。
    write(out / "search-index.json", json.dumps(
        [[theme.slug(r["item_code"]), r["name"], r["price"]] for r in rows],
        ensure_ascii=False, separators=(",", ":")))
    write(out / "search" / "index.html",
          theme.search_page(site, base + "/search/", updated, stats))
    urls.append("/search/")

    # 共有時の画像・行き先を示す404・値下がりの購読（RSS）。
    write(out / "og.svg", theme.og_image(site, stats))
    write(out / "404.html", theme.not_found(site, updated))
    write(out / "feed.xml", theme.feed(site, dropped, updated))

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
