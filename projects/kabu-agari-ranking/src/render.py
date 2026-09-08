"""data/*.json を読み込み、Jinja2 テンプレートから output/ に静的HTMLを生成する。"""
import json
import shutil
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

_ROOT = Path(__file__).resolve().parent.parent
_TEMPLATES_DIR = _ROOT / "templates"
_DATA_DIR = _ROOT / "data"
_OUTPUT_DIR = _ROOT / "output"

SITE_URL = "https://kabu-agari-ranking.pages.dev"

_env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)))

# (json_key, dirname, heading, metric_label, output_filename, intro)
_RANKING_TYPES = [
    (
        "gainers", "gainers", "値上がりランキング", "出来高", "index.html",
        "前営業日終値からの値上がり率が高い順に上位{n}銘柄を掲載しています。"
        "東証プライム・スタンダード・グロース全市場が対象です。",
    ),
    (
        "losers", "losers", "値下がりランキング", "出来高", "losers.html",
        "前営業日終値からの値下がり率が大きい順に上位{n}銘柄を掲載しています。"
        "東証プライム・スタンダード・グロース全市場が対象です。",
    ),
    (
        "active", "active", "活況銘柄ランキング（取引回数）", "約定回数", "active.html",
        "本日の約定回数（取引が成立した回数）が多い順に上位{n}銘柄を掲載しています。"
        "出来高そのものではなく、取引の活発さを示す指標です。",
    ),
]


def canonical_url(rel_path: str) -> str:
    """output/ 内の相対パスから、実際に配信される URL を組み立てる。

    Cloudflare Pages は `/foo.html` を `/foo` へ、`/dir/index.html` を `/dir/` へ
    308 で飛ばす。sitemap や canonical に .html 付きを書くと毎回リダイレクトを
    挟むことになるので、配信される側の形に揃える。
    """
    rel = rel_path.removeprefix("/")
    if rel == "index.html":
        return f"{SITE_URL}/"
    if rel.endswith("/index.html"):
        return f"{SITE_URL}/{rel[: -len('index.html')]}"
    return f"{SITE_URL}/{rel.removesuffix('.html')}"


def _normalize_day(raw: dict) -> dict:
    """旧形式（値上がりランキングのみ・rows/gain_pct/volumeキー）を新形式に変換する。"""
    if "gainers" in raw:
        return raw
    legacy_rows = [
        {
            "rank": r["rank"],
            "code": r["code"],
            "name": r["name"],
            "close": r["close"],
            "change_pct": r["gain_pct"],
            "metric_value": r["volume"],
        }
        for r in raw.get("rows", [])
    ]
    return {"rec_date": raw["rec_date"], "gainers": legacy_rows, "losers": [], "active": []}


# 日付が信用できないため公開しない分。ファイルは data/ に残してある。
#
# 2026-09-07 まで、as-of 日付をページ先頭の <time>（= NYダウの終値日）から
# 採っていたため、平日に取得した分は「前営業日のラベル + 当日のデータ」に
# なっていた（修正は libs/kabutan の extract_asof_date）。どの営業日の
# ランキングなのかを外部から照合する手段が無い（kabutan は過去分を出さない）。
#
# 捨てずに除外にしてあるのは、後から日付を確定できたときに戻せるようにするため。
# 復帰させるならこの集合から外すだけでよい。
UNRELIABLE_DATES = frozenset({"2026-08-24", "2026-08-28", "2026-08-31", "2026-09-01"})


def _load_all_days() -> list[dict]:
    """data/YYYY-MM-DD.json を全て読み込み、rec_date 降順（新しい順）で返す。

    UNRELIABLE_DATES は読み飛ばす。日付の当てにならない回を混ぜると、
    アーカイブ全体が「いつのランキングなのか分からないもの」になってしまう。
    """
    days = []
    for path in _DATA_DIR.glob("????-??-??.json"):
        with open(path, encoding="utf-8") as f:
            day = _normalize_day(json.load(f))
        if day["rec_date"] in UNRELIABLE_DATES:
            continue
        days.append(day)
    days.sort(key=lambda d: d["rec_date"], reverse=True)
    return days


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _build_ranking_pages(days: list[dict]) -> None:
    latest = days[0]
    today_tmpl = _env.get_template("ranking_today.html")
    day_tmpl = _env.get_template("ranking_day.html")
    archive_index_tmpl = _env.get_template("ranking_archive_index.html")

    for json_key, dirname, heading, metric_label, out_name, intro_fmt in _RANKING_TYPES:
        rows = latest.get(json_key, [])
        _write(
            _OUTPUT_DIR / out_name,
            today_tmpl.render(
                base_url="",
                canonical=canonical_url(out_name),
                rec_date=latest["rec_date"],
                rows=rows,
                heading=heading,
                metric_label=metric_label,
                intro=intro_fmt.format(n=len(rows)),
                archive_href=f"archive/{dirname}/index.html",
            ),
        )

        dates_with_data = []
        for day in days:
            day_rows = day.get(json_key, [])
            if not day_rows:
                continue
            dates_with_data.append(day["rec_date"])
            _write(
                _OUTPUT_DIR / "archive" / dirname / f"{day['rec_date']}.html",
                day_tmpl.render(
                    base_url="../../",
                    canonical=canonical_url(f"archive/{dirname}/{day['rec_date']}.html"),
                    rec_date=day["rec_date"],
                    rows=day_rows,
                    heading=heading,
                    metric_label=metric_label,
                ),
            )

        _write(
            _OUTPUT_DIR / "archive" / dirname / "index.html",
            archive_index_tmpl.render(
                base_url="../../",
                canonical=canonical_url(f"archive/{dirname}/index.html"),
                heading=heading,
                dates=dates_with_data,
            ),
        )


_ROBOTS_TXT = f"""User-agent: *
Allow: /

Sitemap: {SITE_URL}/sitemap.xml
"""

_ADS_TXT = """# Google AdSense 審査通過後、下記のコメントを解除し pub-ID を実際の値に置き換える
# google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
"""


def _write_sitemap(days: list[dict]) -> None:
    latest_date = days[0]["rec_date"]
    urls = [
        (canonical_url(name), latest_date)
        for name in (
            "index.html", "losers.html", "active.html",
            "about.html", "privacy.html", "guide.html", "glossary.html",
        )
    ]
    for json_key, dirname, *_rest in _RANKING_TYPES:
        urls.append((canonical_url(f"archive/{dirname}/index.html"), latest_date))
        for day in days:
            if day.get(json_key):
                urls.append(
                    (canonical_url(f"archive/{dirname}/{day['rec_date']}.html"), day["rec_date"])
                )

    entries = "\n".join(
        f"  <url><loc>{loc}</loc><lastmod>{lastmod}</lastmod></url>" for loc, lastmod in urls
    )
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}\n"
        "</urlset>\n"
    )
    (_OUTPUT_DIR / "sitemap.xml").write_text(xml, encoding="utf-8")


def build_all() -> None:
    """output/ を作り直し、各種ランキングページ・固定ページを全て生成する。"""
    if _OUTPUT_DIR.exists():
        shutil.rmtree(_OUTPUT_DIR)
    _OUTPUT_DIR.mkdir(parents=True)

    days = _load_all_days()
    if not days:
        raise RuntimeError("data/ にランキングJSONが1件もありません。先に build_site.py でデータを取得してください。")

    gainers_dates = [d["rec_date"] for d in days if d.get("gainers")]
    _env.globals["GAINERS_DATES_JSON"] = json.dumps(gainers_dates)
    _env.globals["GAINERS_DATES_MIN"] = gainers_dates[-1] if gainers_dates else ""
    _env.globals["GAINERS_DATES_MAX"] = gainers_dates[0] if gainers_dates else ""

    _build_ranking_pages(days)

    for name in ("about.html", "privacy.html", "guide.html", "glossary.html"):
        tmpl = _env.get_template(name)
        _write(_OUTPUT_DIR / name, tmpl.render(base_url="", canonical=canonical_url(name)))

    (_OUTPUT_DIR / "robots.txt").write_text(_ROBOTS_TXT, encoding="utf-8")
    (_OUTPUT_DIR / "ads.txt").write_text(_ADS_TXT, encoding="utf-8")
    _write_sitemap(days)

    static_dir = _ROOT / "static"
    if static_dir.exists():
        for f in static_dir.iterdir():
            if f.is_file():
                shutil.copy(f, _OUTPUT_DIR / f.name)

    print(f"  output/ を生成しました（{len(days)}日分）")
