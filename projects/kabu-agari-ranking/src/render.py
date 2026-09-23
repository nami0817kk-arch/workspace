"""data/*.json を読み込み、Jinja2 テンプレートから output/ に静的HTMLを生成する。"""
import json
import shutil
import sys
from datetime import date
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aggregate
from market_calendar import CalendarOutOfRange, next_business_day

_ROOT = Path(__file__).resolve().parent.parent
_TEMPLATES_DIR = _ROOT / "templates"
_DATA_DIR = _ROOT / "data"
_OUTPUT_DIR = _ROOT / "output"

SITE_URL = "https://kabu-agari-ranking.pages.dev"

# AdSense の審査を通ったら ca-pub-... を入れる。ここが空のあいだは
# 広告のスクリプトも枠も一切出さない。プレースホルダの <ins> を置いたままだと
# 中身の無い点線の箱が全ページに出るだけで、審査にも読者にも損しかない。
ADSENSE_CLIENT = ""

_env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)))
_env.globals["ADSENSE_CLIENT"] = ADSENSE_CLIENT
_env.globals["SITE_URL"] = SITE_URL

_WEEKDAY_JA = "月火水木金土日"

# プライバシーポリシーの文面を最後に直した日。**文面を変えたらここも変える。**
# データの更新日を流用すると、毎日「ポリシーを更新しました」と言うことになる。
POLICY_UPDATED = "2026年9月23日"

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


def format_date_ja(iso: str) -> str:
    """2026-09-18 → 2026年9月18日（金）。"""
    d = date.fromisoformat(iso)
    return f"{d.year}年{d.month}月{d.day}日（{_WEEKDAY_JA[d.weekday()]}）"


def next_update_note(rec_date: str) -> str:
    """「次回更新予定」の一文。休場を挟むときはそれも言う。

    連休中に来た読者が「止まっているサイト」と思って離れるのを防ぐ。
    最終更新日から次の営業日は決まるので、見る時刻によらず正しい。
    """
    d = date.fromisoformat(rec_date)
    try:
        nxt = next_business_day(d)
    except CalendarOutOfRange:
        # 祝日表の範囲外。嘘の予定を出すより黙る。
        return ""
    gap = (nxt - d).days
    note = f"次回更新予定: {format_date_ja(nxt.isoformat())} の16時ごろ"
    if gap > 1:
        note += "（それまでは東証が休場のため、ランキングは更新されません）"
    return note


def day_summary(rows: list[dict], kind: str) -> str:
    """その日のランキングを一文で説明する。

    アーカイブの各日ページは表しか無いと、どの日も同じ見た目の薄いページに
    なってしまう（広告審査でいちばん嫌われる形）。数字から言えることだけを
    書く。ここで相場観や見通しは書かない。
    """
    if not rows:
        return ""
    top = rows[0]
    n = len(rows)

    if kind == "active":
        return (
            f"約定回数が最も多かったのは{top['name']}（{top['code']}）の"
            f"{top['metric_value']:,}回でした。上位{n}銘柄を掲載しています。"
        )

    pct = abs(top["change_pct"])
    verb = "上昇" if kind == "gainers" else "下落"
    big = sum(1 for r in rows if abs(r["change_pct"]) >= 10)
    cheap = sum(1 for r in rows if r["close"] is not None and r["close"] < 1000)

    parts = [f"首位は{top['name']}（{top['code']}）の{pct:.2f}%{verb}。"]
    parts.append(f"上位{n}銘柄のうち{big}銘柄が10%以上{verb}しました。")
    if cheap:
        parts.append(f"終値1,000円未満の低位株が{cheap}銘柄含まれます。")
    return "".join(parts)


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


def group_by_month(dates: list[str]) -> list[dict]:
    """日付を年月ごとにまとめる。営業日が溜まると平坦な一覧では探せなくなる。"""
    months: list[dict] = []
    for iso in dates:
        d = date.fromisoformat(iso)
        label = f"{d.year}年{d.month}月"
        if not months or months[-1]["label"] != label:
            months.append({"label": label, "dates": []})
        months[-1]["dates"].append({"iso": iso, "day": f"{d.month}月{d.day}日（{_WEEKDAY_JA[d.weekday()]}）"})
    return months


def week_summary(week: dict) -> str:
    """週まとめの一文。数えた事実だけを書く。"""
    movers = week["top_movers"]
    if not movers:
        return f"{week['day_count']}営業日ぶんのランキングを掲載しています。"
    top = movers[0]
    repeat = len(week["frequent"])
    parts = [
        f"{week['from']} から {week['to']} までの{week['day_count']}営業日で、"
        f"最も上昇したのは{top['rec_date']}の{top['name']}（{top['code']}）で"
        f"{top['change_pct']:.2f}%でした。"
    ]
    if repeat:
        parts.append(f"この週に2回以上ランキングへ入った銘柄は{repeat}銘柄です。")
    return "".join(parts)


def _build_weekly_pages(days: list[dict]) -> list[dict]:
    """週まとめを書き出し、sitemap 用に slug の一覧を返す。"""
    weeks = aggregate.weekly_summaries(days)
    tmpl = _env.get_template("weekly.html")
    for i, week in enumerate(weeks):
        week["summary"] = week_summary(week)
        _write(
            _OUTPUT_DIR / "weekly" / f"{week['slug']}.html",
            tmpl.render(
                base_url="../",
                canonical=canonical_url(f"weekly/{week['slug']}.html"),
                w=week,
                newer=weeks[i - 1]["slug"] if i > 0 else None,
                older=weeks[i + 1]["slug"] if i + 1 < len(weeks) else None,
            ),
        )
    _write(
        _OUTPUT_DIR / "weekly" / "index.html",
        _env.get_template("weekly_index.html").render(
            base_url="../",
            canonical=canonical_url("weekly/index.html"),
            weeks=weeks,
        ),
    )
    return weeks


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
                rec_date_ja=format_date_ja(latest["rec_date"]),
                next_update=next_update_note(latest["rec_date"]),
                rows=rows,
                heading=heading,
                metric_label=metric_label,
                intro=intro_fmt.format(n=len(rows)),
                summary=day_summary(rows, json_key),
                archive_href=f"archive/{dirname}/index.html",
            ),
        )

        # 新しい順。前後ナビを付けるので、先に対象日を確定させてから描く。
        with_data = [(d["rec_date"], d[json_key]) for d in days if d.get(json_key)]
        dates_with_data = [rec for rec, _ in with_data]

        for i, (rec, day_rows) in enumerate(with_data):
            _write(
                _OUTPUT_DIR / "archive" / dirname / f"{rec}.html",
                day_tmpl.render(
                    base_url="../../",
                    canonical=canonical_url(f"archive/{dirname}/{rec}.html"),
                    rec_date=rec,
                    rec_date_ja=format_date_ja(rec),
                    rows=day_rows,
                    heading=heading,
                    metric_label=metric_label,
                    summary=day_summary(day_rows, json_key),
                    # 一覧に戻らずに日をたどれるようにする。クロールも深くなる。
                    newer=dates_with_data[i - 1] if i > 0 else None,
                    older=dates_with_data[i + 1] if i + 1 < len(with_data) else None,
                    is_latest=(i == 0),
                    today_href=out_name,
                ),
            )

        _write(
            _OUTPUT_DIR / "archive" / dirname / "index.html",
            archive_index_tmpl.render(
                base_url="../../",
                canonical=canonical_url(f"archive/{dirname}/index.html"),
                heading=heading,
                months=group_by_month(dates_with_data),
            ),
        )


_ROBOTS_TXT = f"""User-agent: *
Allow: /

Sitemap: {SITE_URL}/sitemap.xml
"""

_ADS_TXT = """# Google AdSense 審査通過後、下記のコメントを解除し pub-ID を実際の値に置き換える
# google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
"""


def _write_sitemap(days: list[dict], weeks: list[dict]) -> None:
    latest_date = days[0]["rec_date"]
    urls = [
        (canonical_url(name), latest_date)
        for name in (
            "index.html", "losers.html", "active.html",
            "about.html", "privacy.html", "guide.html", "glossary.html",
            "frequent.html", "search.html",
        )
    ]
    urls.append((canonical_url("weekly/index.html"), latest_date))
    for week in weeks:
        urls.append((canonical_url(f"weekly/{week['slug']}.html"), week["to"]))

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
    weeks = _build_weekly_pages(days)

    search_data = aggregate.search_index(days)
    (_OUTPUT_DIR / "search-index.json").write_text(
        json.dumps(search_data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    _write(
        _OUTPUT_DIR / "search.html",
        _env.get_template("search.html").render(
            base_url="",
            canonical=canonical_url("search.html"),
            day_count=min(len(days), aggregate.SEARCH_WINDOW_DAYS),
            period_from=search_data["from"],
            period_to=search_data["to"],
        ),
    )

    _write(
        _OUTPUT_DIR / "frequent.html",
        _env.get_template("frequent.html").render(
            base_url="",
            canonical=canonical_url("frequent.html"),
            day_count=len(days),
            period_from=days[-1]["rec_date"],
            period_to=days[0]["rec_date"],
            gainers=aggregate.frequent(days, "gainers"),
            losers=aggregate.frequent(days, "losers"),
        ),
    )

    # 固定ページにも実データを出す。about の「何日ぶん載っているか」や
    # privacy の最終更新日が実態と違うと、そこだけで信用を落とす。
    fixed_context = {
        "day_count": len(days),
        "period_from": days[-1]["rec_date"],
        "period_to": days[0]["rec_date"],
        # ポリシーの最終更新はデータの日付とは別物。文面を直したときに手で上げる。
        "policy_updated": POLICY_UPDATED,
    }
    for name in ("about.html", "privacy.html", "guide.html", "glossary.html"):
        tmpl = _env.get_template(name)
        _write(
            _OUTPUT_DIR / name,
            tmpl.render(base_url="", canonical=canonical_url(name), **fixed_context),
        )

    # 存在しないURL用。Cloudflare Pages は 404 のときこれを返す。
    # canonical を空にすると base.html 側が noindex を出す（404を検索結果に載せない）。
    _write(_OUTPUT_DIR / "404.html", _env.get_template("404.html").render(base_url="/", canonical=""))

    (_OUTPUT_DIR / "robots.txt").write_text(_ROBOTS_TXT, encoding="utf-8")
    (_OUTPUT_DIR / "ads.txt").write_text(_ADS_TXT, encoding="utf-8")
    _write_sitemap(days, weeks)

    static_dir = _ROOT / "static"
    if static_dir.exists():
        for f in static_dir.iterdir():
            if f.is_file():
                shutil.copy(f, _OUTPUT_DIR / f.name)

    print(f"  output/ を生成しました（{len(days)}日分）")
