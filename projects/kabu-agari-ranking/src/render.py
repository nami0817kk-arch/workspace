"""data/*.json を読み込み、Jinja2 テンプレートから output/ に静的HTMLを生成する。"""
import json
import shutil
import sys
from datetime import date, timedelta
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aggregate
import charts
import feed
import price_limit
import site_config
from market_calendar import CalendarOutOfRange, is_business_day, next_business_day

_ROOT = Path(__file__).resolve().parent.parent
_TEMPLATES_DIR = _ROOT / "templates"
_DATA_DIR = _ROOT / "data"
_OUTPUT_DIR = _ROOT / "output"

# 公開先は site_config が持つ（ドメインを変えるときはそこだけ触る）
SITE_URL = site_config.SITE_URL

# AdSense の審査を通ったら ca-pub-... を入れる。ここが空のあいだは
# 広告のスクリプトも枠も一切出さない。プレースホルダの <ins> を置いたままだと
# 中身の無い点線の箱が全ページに出るだけで、審査にも読者にも損しかない。
ADSENSE_CLIENT = ""

_env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)))
_env.globals["ADSENSE_CLIENT"] = ADSENSE_CLIENT
_env.globals["SITE_URL"] = SITE_URL
_env.globals["SEARCH_CONSOLE_TOKEN"] = site_config.SEARCH_CONSOLE_TOKEN
_env.globals["OWNER"] = site_config.OWNER
_env.globals["CONTACT_EMAIL"] = site_config.CONTACT_EMAIL

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


def format_date_short_ja(iso: str) -> str:
    """2026-09-18 → 9月18日（金）。同じ年の日付を並べるときに使う。"""
    d = date.fromisoformat(iso)
    return f"{d.month}月{d.day}日（{_WEEKDAY_JA[d.weekday()]}）"


def updated_line(rec_date: str) -> str:
    """更新のひとこと。スマホで2行に折り返していたので短くする。

    「いつのデータか」と「次はいつか」だけ残す。休場を挟むときは、
    連休中に来た人が止まったサイトだと思わないよう理由を添える。
    """
    line = f"更新: {format_date_ja(rec_date)}"
    d = date.fromisoformat(rec_date)
    try:
        nxt = next_business_day(d)
    except CalendarOutOfRange:
        return line
    line += f" ／ 次回: {format_date_short_ja(nxt.isoformat())} 16時ごろ"
    if (nxt - d).days > 1:
        line += "（東証が休場のため）"
    return line


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


def missing_business_days(days: list[dict]) -> list[str]:
    """掲載期間のうち、データが無い営業日。

    黙って抜けていると「そういう日は無かった」ように見える。取得に失敗した日が
    あることは書いておく（kabutan は当日分しか出さないので後から埋められない）。
    """
    if len(days) < 2:
        return []
    have = {d["rec_date"] for d in days}
    start, end = date.fromisoformat(days[-1]["rec_date"]), date.fromisoformat(days[0]["rec_date"])
    out, cur = [], start
    try:
        while cur < end:
            cur += timedelta(days=1)
            if is_business_day(cur) and cur.isoformat() not in have:
                out.append(cur.isoformat())
    except CalendarOutOfRange:
        return out
    return out


def annotate_rows(rows: list[dict], stock_pages: set[str] | None = None) -> list[dict]:
    """各行に、制限値幅から見た値動きの性質（ストップ高など）を付ける。

    「何%動いたか」だけでは、上限まで買われたのか途中で止まったのかが
    分からない。前日終値と制限値幅から機械的に決まるので、ここで付ける。
    """
    stock_pages = stock_pages or set()
    out = []
    for row in rows:
        flag = price_limit.classify(row.get("close"), row.get("change_pct"))
        out.append({
            **row,
            "flag": flag,
            "flag_label": price_limit.LABELS.get(flag, ""),
            # 銘柄ページがある銘柄だけリンクにする（無い先へ飛ばさない）
            "has_page": row["code"] in stock_pages,
        })
    return out


def flag_notes(rows: list[dict]) -> list[dict]:
    """その表に出てくる印の説明だけを返す（出ていない印は説明しない）。"""
    seen = []
    for key in (price_limit.STOP_HIGH, price_limit.STOP_LOW, price_limit.OVER_LIMIT):
        if any(r.get("flag") == key for r in rows):
            seen.append({"label": price_limit.LABELS[key], "text": price_limit.DESCRIPTIONS[key]})
    return seen


def highlights(days: list[dict], stock_pages: set[str]) -> list[dict]:
    """トップに出す「今日のハイライト」。

    表の数字だけでは、その日が普通の日なのか特別な日なのかが分からない。
    数えれば言えることだけを、リンク付きで3つまで並べる。
    """
    if not days:
        return []
    today = days[0]
    rows = today.get("gainers", [])
    out = []

    stops = [
        r for r in rows
        if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_HIGH
    ]
    if stops:
        out.append({
            "label": "ストップ高",
            "value": f"{len(stops)}銘柄",
            "note": "、".join(r["name"] for r in stops[:3]) + ("ほか" if len(stops) > 3 else ""),
            "href": "stop-high/index.html",
        })

    # 連続でランクインしている銘柄（今日を含む連続日数が2日以上）
    history = aggregate.stock_histories(days, min_appearances=2)
    streaks = []
    order = [d["rec_date"] for d in sorted(days, key=lambda d: d["rec_date"])]
    for stock in history:
        dates = sorted({r["rec_date"] for r in stock["rows"] if r["kind"] == "gainers"})
        if not dates or dates[-1] != today["rec_date"]:
            continue
        run, idx = 1, order.index(dates[-1])
        while idx - run >= 0 and order[idx - run] in dates:
            run += 1
        if run >= 2:
            streaks.append((run, stock))
    if streaks:
        run, stock = max(streaks, key=lambda x: x[0])
        out.append({
            "label": "連続ランクイン",
            "value": f"{run}営業日",
            "note": f"{stock['name']}（{stock['code']}）",
            "href": f"stock/{stock['code']}/" if stock["code"] in stock_pages else "frequent.html",
        })

    big = sum(1 for r in rows if abs(r["change_pct"]) >= 10)
    out.append({
        "label": "10%以上の上昇",
        "value": f"{big}銘柄",
        "note": f"上位{len(rows)}銘柄のうち",
        "href": "market.html",
    })
    return out[:3]


def turnover_note(rows: list[dict], prev_rows: list[dict] | None) -> str:
    """前営業日との顔ぶれの入れ替わり。

    毎日見る人が知りたいのは順位そのものより「昨日から何が変わったか」。
    掲載日が飛んでいる場合は前営業日ではないので、その旨を書く。
    """
    if not rows or not prev_rows:
        return ""
    prev_codes = {r["code"] for r in prev_rows}
    stayed = [r for r in rows if r["code"] in prev_codes]
    fresh = len(rows) - len(stayed)
    if not stayed:
        return f"前回の掲載から顔ぶれは総入れ替えで、{len(rows)}銘柄すべてが新しく入りました。"
    return (
        f"前回の掲載から続けて入っているのは{len(stayed)}銘柄、"
        f"新しく入ったのは{fresh}銘柄です。"
    )


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
    stop_key = price_limit.STOP_HIGH if kind == "gainers" else price_limit.STOP_LOW
    stopped = sum(1 for r in rows if price_limit.classify(r.get("close"), r.get("change_pct")) == stop_key)
    if stopped:
        parts.append(f"うち{stopped}銘柄は{price_limit.LABELS[stop_key]}です。")
    if cheap:
        parts.append(f"終値1,000円未満の低位株が{cheap}銘柄含まれます。")
    return "".join(parts)


# 「1日に10%以上動いた銘柄が何件あったか」を日ごとに並べたもの。
# その日の相場がどれだけ荒かったかを、1枚で見られるようにするための数字。
BIG_MOVE_PCT = 10
TREND_DAYS = 15


def big_move_series(days: list[dict], key: str = "gainers") -> list[dict]:
    """直近の営業日について、大きく動いた銘柄数を古い順に返す。"""
    recent = list(reversed(days[:TREND_DAYS]))
    out = []
    for day in recent:
        rows = day.get(key) or []
        if not rows:
            continue
        d = date.fromisoformat(day["rec_date"])
        out.append({
            "label": f"{d.month}/{d.day}",
            "value": sum(1 for r in rows if abs(r["change_pct"]) >= BIG_MOVE_PCT),
        })
    return out


def ranking_chart(rows: list[dict], kind: str, rec_date: str, heading: str) -> str:
    """ランキング上位を横棒にする。

    値上がり・値下がりは騰落率、活況は約定回数。活況で騰落率を描いても
    そのランキングの意味（取引の活発さ）と対応しない。
    """
    if kind == "active":
        top = [
            {"label": r["name"], "sub": r["code"], "value": r["metric_value"]}
            for r in rows[:10]
        ]
        return charts.horizontal_bars(
            top,
            aria_label=f"{rec_date} の活況銘柄ランキング上位10銘柄の約定回数を示す横棒グラフ",
            unit="回",
            signed=False,
        )
    top = [
        {"label": r["name"], "sub": r["code"], "value": r["change_pct"]}
        for r in rows[:10]
    ]
    return charts.horizontal_bars(
        top,
        aria_label=f"{rec_date} の{heading}上位10銘柄の騰落率を示す横棒グラフ",
        negative=(kind == "losers"),
    )


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


# 掲載開始直後の4日分は、as-of 日付をページ先頭の <time>（= NYダウの終値日）から
# 採っていたため、日付が信用できない状態だった（修正は libs/kabutan の
# extract_asof_date）。2026-09-24 に、株探の個別銘柄の日足（時系列データ）と
# 終値・騰落率を突き合わせて、4日分すべての実際の相場日を確定させた。
# 各ファイルとも上位3銘柄で照合し、3件とも同じ日に一致している。
#
#   2026-08-24.json … 2026-08-24（正しかった）
#   2026-08-28.json … 2026-08-28（正しかった）
#   2026-08-31.json … 実際は 2026-09-01
#   2026-09-01.json … 実際は 2026-09-02
#
# ファイル名は変えずに、読み込み時に正しい日付へ読み替える。
# 名前を変えるとデータの移動になり、取り返しのつかない操作になるため
# （中身は一切書き換えていない。照合のやり直しは tools/verify_rec_date.py）。
DATE_CORRECTIONS = {
    "2026-08-31": "2026-09-01",
    "2026-09-01": "2026-09-02",
}

# 日付が確定できず公開しない分。現在は無し（上のとおり4日分とも確定した）。
# 同じことが起きたときは、ここに入れて公開から外す。
UNRELIABLE_DATES: frozenset[str] = frozenset()


def group_by_month(dates: list[str], info: dict[str, dict] | None = None) -> list[dict]:
    """日付を年月ごとにまとめる。営業日が溜まると平坦な一覧では探せなくなる。

    info があれば各日の見出し（その日の首位など）も添える。日付だけの一覧では
    どの日を開けばよいか分からず、結局トップしか読まれない。
    """
    info = info or {}
    months: list[dict] = []
    for iso in dates:
        d = date.fromisoformat(iso)
        label = f"{d.year}年{d.month}月"
        if not months or months[-1]["label"] != label:
            months.append({"label": label, "dates": []})
        months[-1]["dates"].append({
            "iso": iso,
            "day": f"{d.month}月{d.day}日（{_WEEKDAY_JA[d.weekday()]}）",
            **info.get(iso, {}),
        })
    return months


def archive_index_info(with_data: list[tuple[str, list[dict]]], kind: str) -> dict[str, dict]:
    """アーカイブ一覧に添える、その日の一言。"""
    stop_key = price_limit.STOP_HIGH if kind == "gainers" else price_limit.STOP_LOW
    out = {}
    for rec, rows in with_data:
        if not rows:
            continue
        top = rows[0]
        stops = sum(1 for r in rows if r.get("flag") == stop_key)
        out[rec] = {
            "top_name": top["name"],
            "top_code": top["code"],
            "top_pct": top["change_pct"],
            "stops": stops,
            "stop_label": price_limit.LABELS[stop_key],
        }
    return out


def week_comparison(week: dict, previous: dict | None) -> str:
    """前の週との比べ。単独の数字だけでは、荒れた週なのか普通なのか分からない。

    営業日数が違う週（連休など）をそのまま比べると誤解するので、
    1営業日あたりに直して比べる。
    """
    if not previous or not previous["day_count"] or not week["day_count"]:
        return ""
    now = week["big_moves"] / week["day_count"]
    before = previous["big_moves"] / previous["day_count"]
    if before == 0:
        return ""
    ratio = now / before
    if ratio >= 1.2:
        judgement = "前の週より荒い動きが増えました"
    elif ratio <= 0.8:
        judgement = "前の週より落ち着きました"
    else:
        judgement = "前の週と同じくらいの荒さでした"
    return (
        f"1営業日あたり10%以上動いた銘柄は{now:.1f}銘柄で、"
        f"前の週（{before:.1f}銘柄）と比べて{judgement}。"
    )


def week_summary(week: dict) -> str:
    """週まとめの一文。数えた事実だけを書く。"""
    movers = week["top_movers"]
    if not movers:
        return f"{week['day_count']}営業日ぶんのランキングを掲載しています。"
    top = movers[0]
    repeat = len(week["frequent"])
    parts = [
        f"{format_date_ja(week['from'])}から{format_date_short_ja(week['to'])}までの{week['day_count']}営業日で、"
        f"最も上昇したのは{format_date_short_ja(top['rec_date'])}の{top['name']}（{top['code']}）で"
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
        # weeks は新しい週が先。ひとつ後ろが前の週になる。
        week["comparison"] = week_comparison(week, weeks[i + 1] if i + 1 < len(weeks) else None)
        week["from_ja"] = format_date_ja(week["from"])
        week["to_ja"] = format_date_short_ja(week["to"])
        _write(
            _OUTPUT_DIR / "weekly" / f"{week['slug']}.html",
            tmpl.render(
                base_url="../",
                canonical=canonical_url(f"weekly/{week['slug']}.html"),
                w=week,
                chart=charts.columns(
                    [
                        {"label": d["rec_date"][5:].replace("-", "/"),
                         "value": round(d["top"]["change_pct"], 2) if d["top"] else None}
                        for d in reversed(week["days"])
                    ],
                    aria_label=f"{week['from']}から{week['to']}までの、日ごとの首位の上昇率を示す棒グラフ",
                    unit="%",
                ),
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


def stock_summary(stock: dict, day_count: int) -> str:
    """銘柄ページの一文。数えた事実だけを書く。"""
    counts = stock["counts"]
    parts = [f"直近{day_count}営業日のランキングに{len(stock['rows'])}回登場しています（"]
    detail = []
    for key, label in (("gainers", "値上がり"), ("losers", "値下がり"), ("active", "活況")):
        if counts.get(key):
            detail.append(f"{label}{counts[key]}回")
    parts.append("、".join(detail) + "）。")
    if stock["best_pct"] is not None:
        parts.append(f"この期間の最大の変動は{stock['best_pct']:+.2f}%。")
    if stock["stops"]:
        parts.append(f"うち{stock['stops']}回は制限値幅いっぱいまで動いています。")
    return "".join(parts)


def _build_stock_pages(days: list[dict]) -> list[dict]:
    """銘柄ごとのページ。登場が少ない銘柄は作らない（薄いページを量産しない）。"""
    stocks = aggregate.stock_histories(days)
    tmpl = _env.get_template("stock.html")
    for stock in stocks:
        points = [
            {"label": r["rec_date"][5:].replace("-", "/"), "value": r["change_pct"]}
            for r in reversed(stock["rows"]) if r["kind"] != "active"
        ]
        _write(
            _OUTPUT_DIR / "stock" / stock["code"] / "index.html",
            tmpl.render(
                base_url="../../",
                canonical=canonical_url(f"stock/{stock['code']}/index.html"),
                s=stock,
                summary=stock_summary(stock, len(days)),
                together=aggregate.co_occurring(days, stock["code"]),
                labels=price_limit.LABELS,
                chart=charts.columns(
                    points,
                    aria_label=f"{stock['name']}がランキングに登場した日の騰落率を示す棒グラフ",
                    unit="%",
                ),
            ),
        )

    _write(
        _OUTPUT_DIR / "stock" / "index.html",
        _env.get_template("stock_index.html").render(
            base_url="../",
            canonical=canonical_url("stock/index.html"),
            stocks=stocks,
        ),
    )
    return stocks


def market_rows(days: list[dict]) -> list[dict]:
    """日ごとの相場の荒さ。新しい日が先。"""
    out = []
    for day in days:
        gainers = day.get("gainers") or []
        if not gainers:
            continue
        losers = day.get("losers") or []
        out.append({
            "rec_date": day["rec_date"],
            "big": sum(1 for r in gainers if abs(r["change_pct"]) >= BIG_MOVE_PCT),
            "stop_high": sum(
                1 for r in gainers
                if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_HIGH
            ),
            "stop_low": sum(
                1 for r in losers
                if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_LOW
            ),
            "top_pct": gainers[0]["change_pct"],
        })
    return out


def market_summary(rows: list[dict]) -> str:
    """相場の振り返りの一文。"""
    if not rows:
        return ""
    busiest = max(rows, key=lambda r: r["big"])
    stops = sum(r["stop_high"] for r in rows)
    return (
        f"この期間で最も荒かったのは{format_date_short_ja(busiest['rec_date'])}で、"
        f"上位30銘柄のうち{busiest['big']}銘柄が10%以上動きました。"
        f"期間を通したストップ高はのべ{stops}銘柄です。"
    )


def stop_high_summary(history: dict, day_count: int) -> str:
    """ストップ高の章の一文。数えた事実だけを書く。"""
    if not history["total"]:
        return f"直近{day_count}営業日では、上位30銘柄の中にストップ高はありませんでした。"
    busiest = max(history["per_day"], key=lambda d: d["count"])
    parts = [
        f"直近{day_count}営業日で、のべ{history['total']}銘柄がストップ高になりました"
        f"（{len({row['code'] for d in history['per_day'] for row in d['rows']})}銘柄）。"
    ]
    parts.append(
        f"最も多かったのは{format_date_short_ja(busiest['rec_date'])}の{busiest['count']}銘柄です。"
    )
    if history["stocks"]:
        top = history["stocks"][0]
        parts.append(
            f"最も回数が多いのは{top['name']}（{top['code']}）の{top['count']}回で、"
            f"最長{top['streak']}営業日連続でした。"
        )
    return "".join(parts)


def month_summary(month: dict) -> str:
    """月まとめの一文。"""
    movers = month["top_movers"]
    if not movers:
        return f"{month['day_count']}営業日ぶんのランキングを掲載しています。"
    top = movers[0]
    parts = [
        f"{month['year']}年{month['month']}月は{month['day_count']}営業日ぶんを掲載しています。"
        f"最も上昇したのは{format_date_short_ja(top['rec_date'])}の{top['name']}"
        f"（{top['code']}）で{top['change_pct']:.2f}%でした。"
    ]
    if month["stop_highs"]:
        parts.append(f"ストップ高はのべ{month['stop_highs']}銘柄。")
    if month["frequent"]:
        parts.append(f"2回以上ランクインした銘柄は{len(month['frequent'])}銘柄です。")
    return "".join(parts)


def _build_monthly_pages(days: list[dict]) -> list[dict]:
    """月ごとのまとめ。週より長い目で見たいときのため。"""
    months = aggregate.monthly_summaries(days)
    tmpl = _env.get_template("monthly.html")
    for i, month in enumerate(months):
        month["summary"] = month_summary(month)
        _write(
            _OUTPUT_DIR / "monthly" / f"{month['slug']}.html",
            tmpl.render(
                base_url="../",
                canonical=canonical_url(f"monthly/{month['slug']}.html"),
                m=month,
                newer=months[i - 1]["slug"] if i > 0 else None,
                older=months[i + 1]["slug"] if i + 1 < len(months) else None,
            ),
        )
    _write(
        _OUTPUT_DIR / "monthly" / "index.html",
        _env.get_template("monthly_index.html").render(
            base_url="../",
            canonical=canonical_url("monthly/index.html"),
            months=months,
        ),
    )
    return months


def _build_stop_high_page(days: list[dict], stock_pages: set[str]) -> None:
    """ストップ高の章。当日のランキングはどこにでもあるが、
    「いつ・どの銘柄が上限まで買われたか」を日をまたいで残している場所は少ない。"""
    history = aggregate.stop_high_history(days)
    per_day = [
        {
            **day,
            "rec_date_ja": format_date_ja(day["rec_date"]),
            # 一覧の時点で顔ぶれが見えるようにする（3件まで）
            "names": "、".join(r["name"] for r in day["rows"][:3])
                     + ("ほか" if len(day["rows"]) > 3 else ""),
        }
        for day in history["per_day"]
    ]
    stocks = [{**s, "has_page": s["code"] in stock_pages} for s in history["stocks"]]
    recent = list(reversed(history["per_day"][:TREND_DAYS]))

    _write(
        _OUTPUT_DIR / "stop-high" / "index.html",
        _env.get_template("stop_high.html").render(
            base_url="../",
            canonical=canonical_url("stop-high/index.html"),
            day_count=len(days),
            period_from=days[-1]["rec_date"],
            period_to=days[0]["rec_date"],
            period_from_ja=format_date_ja(days[-1]["rec_date"]),
            period_to_ja=format_date_short_ja(days[0]["rec_date"]),
            summary=stop_high_summary(history, len(days)),
            has_recorded=history["has_recorded"],
            has_estimated=history["has_estimated"],
            recorded_from=format_date_ja(min(
                (d["rec_date"] for d in history["per_day"] if d["source"] == "recorded"),
                default=days[0]["rec_date"],
            )),
            stocks=stocks,
            per_day=per_day,
            trend_chart=charts.columns(
                [{"label": format_date_short_ja(d["rec_date"])[:-3], "value": d["count"]}
                 for d in recent],
                aria_label="日ごとのストップ高の数を示す棒グラフ",
                unit="銘柄",
            ),
        ),
    )


def _build_market_page(days: list[dict]) -> None:
    rows = market_rows(days)
    recent = list(reversed(rows[:TREND_DAYS]))

    def series(key):
        return [{"label": r["rec_date"][5:].replace("-", "/"), "value": r[key]} for r in recent]

    _write(
        _OUTPUT_DIR / "market.html",
        _env.get_template("market.html").render(
            base_url="",
            canonical=canonical_url("market.html"),
            rows=rows,
            day_count=len(rows),
            period_from=rows[-1]["rec_date"] if rows else "",
            period_to=rows[0]["rec_date"] if rows else "",
            period_from_ja=format_date_ja(rows[-1]["rec_date"]) if rows else "",
            period_to_ja=format_date_short_ja(rows[0]["rec_date"]) if rows else "",
            summary=market_summary(rows),
            big_move_chart=charts.columns(
                series("big"), aria_label="日ごとの、10%以上動いた銘柄数を示す棒グラフ", unit="銘柄"),
            stop_chart=charts.columns(
                series("stop_high"), aria_label="日ごとのストップ高の数を示す棒グラフ", unit="銘柄"),
            top_chart=charts.columns(
                series("top_pct"), aria_label="日ごとの首位の上昇率を示す棒グラフ", unit="%"),
        ),
    )


def _load_all_days() -> list[dict]:
    """data/YYYY-MM-DD.json を全て読み込み、rec_date 降順（新しい順）で返す。

    読み込みながら3つのことをする:

    - `DATE_CORRECTIONS` にあるものは、実際の相場日へ **rec_date を読み替える**
      （ファイルは触らない。経緯はその定義のところに書いてある）
    - `UNRELIABLE_DATES` は読み飛ばす（日付の当てにならない回を混ぜると、
      アーカイブ全体が「いつのランキングなのか分からないもの」になる）
    - 壊れたファイルは読み飛ばす（1件でサイト全体を落とさない）

    同じ rec_date が2件になったら、後から来たほうを捨てて警告する。
    読み替え先と同じ日付のファイルが後から増えると起こりうる形で、
    黙って通すと集計（登場回数・銘柄数）が二重に数えられる。
    """
    days = []
    seen: dict[str, str] = {}
    for path in sorted(_DATA_DIR.glob("????-??-??.json")):
        # 1件が壊れていてもサイト全体を落とさない。落とすと、その日から
        # ずっと公開が止まる（古いデータで出続けるほうが損が小さい）。
        # 壊れたファイル自体は CI の整合性テストが必ず赤で知らせる。
        try:
            with open(path, encoding="utf-8") as f:
                day = _normalize_day(json.load(f))
            rec_date = DATE_CORRECTIONS.get(day["rec_date"], day["rec_date"])
            day["rec_date"] = rec_date
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            print(f"  [WARN] {path.name} を読み飛ばしました（{e}）")
            continue
        if rec_date in UNRELIABLE_DATES:
            continue
        if rec_date in seen:
            print(
                f"  [WARN] {path.name} は {rec_date} の二重登録です"
                f"（{seen[rec_date]} を採用し、こちらを読み飛ばしました）"
            )
            continue
        seen[rec_date] = path.name
        days.append(day)
    days.sort(key=lambda d: d["rec_date"], reverse=True)
    return days


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def siblings_for(days: list[dict]) -> dict[str, list[dict]]:
    """日付 → その日にデータがあるランキングの一覧。

    「読み方」では値上がりと値下がりを併せて見るよう書いているのに、
    その日の別のランキングへ行く道が無かった。
    """
    out: dict[str, list[dict]] = {}
    for day in days:
        entries = []
        for json_key, dirname, heading, *_rest in _RANKING_TYPES:
            if day.get(json_key):
                entries.append({"kind": json_key, "dir": dirname, "heading": heading})
        out[day["rec_date"]] = entries
    return out


def _build_ranking_pages(days: list[dict], stock_pages: set[str] | None = None) -> None:
    latest = days[0]
    siblings = siblings_for(days)
    today_tmpl = _env.get_template("ranking_today.html")
    day_tmpl = _env.get_template("ranking_day.html")
    archive_index_tmpl = _env.get_template("ranking_archive_index.html")

    for json_key, dirname, heading, metric_label, out_name, intro_fmt in _RANKING_TYPES:
        rows = annotate_rows(latest.get(json_key, []), stock_pages)
        _write(
            _OUTPUT_DIR / out_name,
            today_tmpl.render(
                base_url="",
                canonical=canonical_url(out_name),
                rec_date=latest["rec_date"],
                rec_date_ja=format_date_ja(latest["rec_date"]),
                updated_line=updated_line(latest["rec_date"]),
                rows=rows,
                notes=flag_notes(rows),
                heading=heading,
                metric_label=metric_label,
                intro=intro_fmt.format(n=len(rows)),
                summary=day_summary(rows, json_key),
                highlights=highlights(days, stock_pages or set()) if json_key == "gainers" else [],
                turnover=turnover_note(
                    rows, annotate_rows(days[1].get(json_key, [])) if len(days) > 1 else None
                ),
                chart=ranking_chart(rows, json_key, latest["rec_date"], heading),
                trend_chart=charts.columns(
                    big_move_series(days, json_key),
                    aria_label=f"直近{TREND_DAYS}営業日について、"
                               f"{BIG_MOVE_PCT}%以上動いた銘柄の数を示す棒グラフ",
                    unit="銘柄",
                ) if json_key in ("gainers", "losers") else "",
                trend_days=len(big_move_series(days, json_key)),
                archive_href=f"archive/{dirname}/index.html",
            ),
        )

        # 新しい順。前後ナビを付けるので、先に対象日を確定させてから描く。
        with_data = [(d["rec_date"], annotate_rows(d[json_key], stock_pages)) for d in days if d.get(json_key)]
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
                    notes=flag_notes(day_rows),
                    heading=heading,
                    metric_label=metric_label,
                    summary=day_summary(day_rows, json_key),
                    kind_dir=dirname,
                    siblings=[e for e in siblings[rec] if e["kind"] != json_key],
                    turnover=turnover_note(
                        day_rows, with_data[i + 1][1] if i + 1 < len(with_data) else None
                    ),
                    chart=ranking_chart(day_rows, json_key, rec, heading),
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
                months=group_by_month(dates_with_data, archive_index_info(with_data, json_key)),
            ),
        )


_ROBOTS_TXT = f"""User-agent: *
Allow: /
# 検索ページが読み込む索引。ページではないので取りに来なくてよい
# （中身は各ページに載っている情報の写し）。
Disallow: /search-index.json

Sitemap: {SITE_URL}/sitemap.xml
"""

# 検索用の索引はページではないので、リンクされていてもクロールしなくてよい。
# （robots.txt では触れず、HTML から直接リンクしないことで十分）

def _ads_txt() -> str | None:
    """ads.txt の中身。pub-ID が無いあいだは**置かない**（None を返す）。

    中身がコメントだけの ads.txt は「ファイルはあるが有効なレコードが無い」
    という報告対象になる。広告枠と同じで、揃うまでは出さないほうがよい。
    """
    if not ADSENSE_CLIENT:
        return None
    pub_id = ADSENSE_CLIENT.removeprefix("ca-")
    return f"google.com, {pub_id}, DIRECT, f08c47fec0942fa0\n"


def _write_feed(days: list[dict]) -> None:
    (_OUTPUT_DIR / "feed.xml").write_text(
        feed.build(
            days,
            site_url=SITE_URL,
            url_for=lambda rec: canonical_url(f"archive/gainers/{rec}.html"),
            summarize=lambda rows: day_summary(rows, "gainers"),
        ),
        encoding="utf-8",
    )


def _write_sitemap(days: list[dict], weeks: list[dict], stocks: list[dict],
                   months: list[dict]) -> None:
    latest_date = days[0]["rec_date"]

    # データと一緒に毎日変わるページ。lastmod は最新の相場日でよい。
    urls = [
        (canonical_url(name), latest_date)
        for name in (
            "index.html", "losers.html", "active.html",
            "about.html", "frequent.html", "search.html",
        )
    ]
    # 文章だけのページは毎日変わらない。データの日付を書くと
    # 「毎日更新している」という嘘になり、そのうち lastmod ごと信用されなくなる。
    # 正しい日が分からないものは lastmod を書かない（省略してよい）。
    urls += [(canonical_url("privacy.html"), None),
             (canonical_url("operator.html"), None),
             (canonical_url("contact.html"), None),
             (canonical_url("guide.html"), None),
             (canonical_url("glossary.html"), None)]
    urls.append((canonical_url("weekly/index.html"), latest_date))
    urls.append((canonical_url("stock/index.html"), latest_date))
    urls.append((canonical_url("stop-high/index.html"), latest_date))
    urls.append((canonical_url("monthly/index.html"), latest_date))
    for month in months:
        urls.append((canonical_url(f"monthly/{month['slug']}.html"), month["to"]))
    for stock in stocks:
        urls.append((canonical_url(f"stock/{stock['code']}/index.html"), stock["latest"]))
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
        f"  <url><loc>{loc}</loc>"
        + (f"<lastmod>{lastmod}</lastmod>" if lastmod else "")
        + "</url>"
        for loc, lastmod in urls
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

    # 銘柄ページを先に確定させてから表を描く（リンクの有無を知るため）
    stocks = _build_stock_pages(days)
    stock_pages = {s["code"] for s in stocks}
    _build_ranking_pages(days, stock_pages)
    _build_stop_high_page(days, stock_pages)
    months = _build_monthly_pages(days)
    weeks = _build_weekly_pages(days)
    _build_market_page(days)

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
        "missing_days": [format_date_ja(d) for d in missing_business_days(days)],
        "limit_table": price_limit.table_rows(),
    }
    for name in ("about.html", "privacy.html", "operator.html", "contact.html",
                 "guide.html", "glossary.html"):
        tmpl = _env.get_template(name)
        _write(
            _OUTPUT_DIR / name,
            tmpl.render(base_url="", canonical=canonical_url(name), **fixed_context),
        )

    # 存在しないURL用。Cloudflare Pages は 404 のときこれを返す。
    # canonical を空にすると base.html 側が noindex を出す（404を検索結果に載せない）。
    _write(_OUTPUT_DIR / "404.html", _env.get_template("404.html").render(base_url="/", canonical=""))

    (_OUTPUT_DIR / "robots.txt").write_text(_ROBOTS_TXT, encoding="utf-8")
    ads = _ads_txt()
    if ads:
        (_OUTPUT_DIR / "ads.txt").write_text(ads, encoding="utf-8")
    _write_sitemap(days, weeks, stocks, months)
    _write_feed(days)

    static_dir = _ROOT / "static"
    if static_dir.exists():
        for f in static_dir.iterdir():
            if f.is_file():
                shutil.copy(f, _OUTPUT_DIR / f.name)

    print(f"  output/ を生成しました（{len(days)}日分）")
