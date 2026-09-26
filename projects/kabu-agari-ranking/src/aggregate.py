"""アーカイブ全体を横断して数える。

1日ぶんの表は他所にもあるが、「何日ランクインしたか」はこのサイトが
毎日ためているからこそ出せる。読み物として成立する唯一の持ち札なので、
ここは数えた事実だけを書く（見通し・推奨は書かない）。
"""
from __future__ import annotations

from collections import defaultdict

import price_limit


def _tally(days: list[dict], key: str) -> dict[str, dict]:
    """銘柄コードごとに、登場した日と最大騰落率を集める。"""
    acc: dict[str, dict] = defaultdict(
        lambda: {"code": "", "name": "", "dates": [], "best_pct": None, "stops": 0}
    )
    stop_key = price_limit.STOP_LOW if key == "losers" else price_limit.STOP_HIGH
    # days は新しい順。集計は古い順に見たほうが「最新の名称」を残しやすい。
    for day in reversed(days):
        for row in day.get(key, []):
            e = acc[row["code"]]
            e["code"] = row["code"]
            e["name"] = row["name"]  # 社名変更があれば新しいほうが残る
            e["dates"].append(day["rec_date"])
            pct = row["change_pct"]
            if e["best_pct"] is None or abs(pct) > abs(e["best_pct"]):
                e["best_pct"] = pct
            # 「何回ランクインしたか」だけだと、上限まで買われた日と
            # 少し動いただけの日が同じに見える。
            if price_limit.classify(row.get("close"), pct) == stop_key:
                e["stops"] += 1
    return acc


def frequent(days: list[dict], key: str = "gainers", top_n: int = 20) -> list[dict]:
    """ランクイン回数の多い順。2回以上のものだけ返す。

    1回だけの銘柄は全体の大半で、並べても「その日たまたま上がった」以上の
    ことを言わない。数えた意味があるのは複数回のものだけ。
    """
    entries = [e for e in _tally(days, key).values() if len(e["dates"]) >= 2]
    for e in entries:
        e["count"] = len(e["dates"])
        e["latest"] = max(e["dates"])
        e["streak"] = _longest_run(e["dates"], _all_dates(days))
    entries.sort(key=lambda e: (-e["count"], -abs(e["best_pct"] or 0), e["code"]))
    return entries[:top_n]


def _all_dates(days: list[dict]) -> list[str]:
    """掲載のある日付を古い順に。連続判定はこの並びの上で数える。"""
    return sorted(d["rec_date"] for d in days)


def _longest_run(dates: list[str], all_dates: list[str]) -> int:
    """連続してランクインした最大日数。

    「連続」はカレンダーの連日ではなく**掲載日の並び**で数える。
    取得を取り逃した日や休場日を挟んでも、間に他の掲載日が無ければ連続とみなす。
    """
    index = {d: i for i, d in enumerate(all_dates)}
    positions = sorted(index[d] for d in dates if d in index)
    best = run = 1
    for prev, cur in zip(positions, positions[1:]):
        run = run + 1 if cur == prev + 1 else 1
        best = max(best, run)
    return best


# 検索用インデックスに載せる営業日数の上限。
# 全期間を入れると、掲載日が増えるほど JSON が太り、スマホでの読み込みに響く。
# 「最近どのくらい動いたか」を引くのが目的なので、直近だけで足りる。
SEARCH_WINDOW_DAYS = 60


def search_index(days: list[dict]) -> dict:
    """銘柄名・コードから登場日を引くための索引。

    { "from": 最古の日, "to": 最新の日,
      "stocks": [ {"c": コード, "n": 名前, "g": [日...], "l": [...], "a": [...]} ] }

    キーを1文字にしているのは、そのままブラウザに配る JSON だから。
    銘柄数×日数ぶん繰り返されるので、ここのバイト数がそのまま読み込み時間になる。
    """
    window = days[:SEARCH_WINDOW_DAYS]
    if not window:
        return {"from": "", "to": "", "stocks": []}

    stocks: dict[str, dict] = {}
    for day in reversed(window):  # 古い順に見て、名前は新しいもので上書きする
        for key, short in (("gainers", "g"), ("losers", "l"), ("active", "a")):
            for row in day.get(key, []):
                e = stocks.setdefault(row["code"], {"c": row["code"], "n": row["name"],
                                                    "g": [], "l": [], "a": [],
                                                    "b": None, "s": 0})
                e["n"] = row["name"]
                e[short].append(day["rec_date"])
                if key == "active":
                    continue
                # 「いつ出たか」だけでは、どれくらい動いた日なのかが分からない。
                pct = row["change_pct"]
                if e["b"] is None or abs(pct) > abs(e["b"]):
                    e["b"] = pct
                if price_limit.classify(row.get("close"), pct) in (
                    price_limit.STOP_HIGH, price_limit.STOP_LOW
                ):
                    e["s"] += 1

    return {
        "from": window[-1]["rec_date"],
        "to": window[0]["rec_date"],
        "stocks": sorted(stocks.values(), key=lambda e: e["c"]),
    }


def _iso_week(rec_date: str) -> tuple[int, int]:
    from datetime import date as _date

    y, w, _ = _date.fromisoformat(rec_date).isocalendar()
    return y, w


def weekly_summaries(days: list[dict]) -> list[dict]:
    """週ごとのまとめ。新しい週が先。

    日ごとの表は毎日増えるが、「その週に何が起きたか」を見る場所が無かった。
    週の区切りは ISO 週（月曜始まり）。連休で2日しか無い週もそのまま1週として出す。
    """
    buckets: dict[tuple[int, int], list[dict]] = {}
    for day in days:
        buckets.setdefault(_iso_week(day["rec_date"]), []).append(day)

    out = []
    for (year, week), group in buckets.items():
        group = sorted(group, key=lambda d: d["rec_date"], reverse=True)
        movers = []
        for day in group:
            for row in day.get("gainers", []):
                movers.append({**row, "rec_date": day["rec_date"]})
        movers.sort(key=lambda r: r["change_pct"], reverse=True)

        big = sum(
            1 for day in group for r in day.get("gainers", []) if abs(r["change_pct"]) >= 10
        )
        stops = sum(
            1 for day in group for r in day.get("gainers", [])
            if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_HIGH
        )
        out.append({
            "big_moves": big,
            "stop_highs": stops,
            "slug": f"{year}-W{week:02d}",
            "year": year,
            "week": week,
            "from": group[-1]["rec_date"],
            "to": group[0]["rec_date"],
            "day_count": len(group),
            "days": [
                {
                    "rec_date": d["rec_date"],
                    "top": (d.get("gainers") or [None])[0],
                }
                for d in group
            ],
            "top_movers": movers[:10],
            "frequent": frequent(group, "gainers", top_n=10),
        })

    out.sort(key=lambda w: (w["year"], w["week"]), reverse=True)
    return out


# 銘柄ページを作る下限。1〜2回しか出ていない銘柄のページは、表が1行あるだけの
# 薄いページになる。そういうものを量産すると、サイト全体の評価が落ちる。
STOCK_PAGE_MIN_APPEARANCES = 3

_KINDS = (("gainers", "値上がり"), ("losers", "値下がり"), ("active", "活況"))


def stock_histories(days: list[dict], min_appearances: int = STOCK_PAGE_MIN_APPEARANCES) -> list[dict]:
    """銘柄ごとの登場履歴。新しい日が先。

    「この銘柄は最近どうだったか」を1ページで見せるためのもの。
    登場が少ない銘柄は作らない（薄いページを量産しない）。
    """
    stocks: dict[str, dict] = {}
    for day in reversed(days):  # 古い順に見て、名前は新しいもので上書き
        for key, label in _KINDS:
            for row in day.get(key, []):
                e = stocks.setdefault(row["code"], {"code": row["code"], "name": row["name"],
                                                    "rows": [], "counts": {}})
                e["name"] = row["name"]
                e["counts"][key] = e["counts"].get(key, 0) + 1
                e["rows"].append({
                    "rec_date": day["rec_date"],
                    "kind": key,
                    "kind_label": label,
                    "rank": row["rank"],
                    "close": row["close"],
                    "change_pct": row["change_pct"],
                    "metric_value": row["metric_value"],
                    "flag": price_limit.classify(row.get("close"), row.get("change_pct")),
                })

    out = []
    for e in stocks.values():
        if len(e["rows"]) < min_appearances:
            continue
        e["rows"].sort(key=lambda r: (r["rec_date"], r["kind"]), reverse=True)
        moves = [r["change_pct"] for r in e["rows"] if r["kind"] != "active"]
        e["best_pct"] = max(moves, key=abs) if moves else None
        e["stops"] = sum(
            1 for r in e["rows"] if r["flag"] in (price_limit.STOP_HIGH, price_limit.STOP_LOW)
        )
        e["first"] = e["rows"][-1]["rec_date"]
        e["latest"] = e["rows"][0]["rec_date"]
        out.append(e)

    out.sort(key=lambda e: (-len(e["rows"]), e["code"]))
    return out


# --- ストップ高 -------------------------------------------------------------
#
# 当日のランキングはどこにでもあるが、「いつ・どの銘柄が上限まで買われたか」を
# 日をまたいで残している場所はほとんど無い。**このサイトの持ち札はここ**なので、
# 独立した章として出せる形にまとめる。
#
# 対象は値上がりランキングの上位30銘柄に限られる（取得しているのがそこまで）。
# 「東証の全ストップ高」ではないので、見せる側でその旨を必ず書く。

def stop_high_rows(day: dict) -> tuple[list[dict], str]:
    """その日のストップ高銘柄と、その出どころ。

    - recorded … 取得元の専用ランキングをそのまま記録したもの（全件）
    - estimated … 値上がり上位30銘柄から、終値と騰落率で推定したもの

    2026-09-28 以降は recorded。それ以前は専用ランキングを取っていなかったので
    estimated しか無い。**出どころが違うものを混ぜて数えると、件数の増減が
    相場の変化なのか取り方の変化なのか分からなくなる**ので、区別して持つ。
    """
    recorded = day.get("stop_high")
    if recorded is not None:
        # 引けまで上限を保った銘柄だけを数える（場中につけて下げた分は除く）。
        return [r for r in recorded if r.get("at_limit")], "recorded"
    return [
        r for r in day.get("gainers", [])
        if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_HIGH
    ], "estimated"


def stop_high_history(days: list[dict]) -> dict:
    """ストップ高の日別・銘柄別のまとめ。

    returns:
        per_day … 新しい日が先。{rec_date, count, rows, source}
        stocks  … 複数回ストップ高になった銘柄（回数の多い順）
        total   … のべ件数
        has_estimated … 推定の日が混じっているか（画面で断るために使う）
    """
    per_day, by_code = [], {}
    order = [d["rec_date"] for d in sorted(days, key=lambda d: d["rec_date"])]

    for day in days:
        rows, source = stop_high_rows(day)
        per_day.append({"rec_date": day["rec_date"], "count": len(rows),
                        "rows": rows, "source": source})
        for row in rows:
            entry = by_code.setdefault(row["code"], {"code": row["code"], "name": row["name"],
                                                     "dates": [], "best_pct": None})
            entry["name"] = row["name"]
            entry["dates"].append(day["rec_date"])
            pct = row["change_pct"]
            if entry["best_pct"] is None or pct > entry["best_pct"]:
                entry["best_pct"] = pct

    stocks = []
    for entry in by_code.values():
        if len(entry["dates"]) < 2:
            continue
        entry["dates"].sort(reverse=True)
        entry["count"] = len(entry["dates"])
        entry["streak"] = _longest_run(entry["dates"], order)
        entry["latest"] = entry["dates"][0]
        stocks.append(entry)
    stocks.sort(key=lambda e: (-e["count"], -e["streak"], e["code"]))

    per_day.sort(key=lambda d: d["rec_date"], reverse=True)
    return {
        "per_day": per_day,
        "stocks": stocks,
        "total": sum(d["count"] for d in per_day),
        "has_estimated": any(d["source"] == "estimated" for d in per_day),
        "has_recorded": any(d["source"] == "recorded" for d in per_day),
    }


# --- 月ごと -----------------------------------------------------------------

def monthly_summaries(days: list[dict]) -> list[dict]:
    """月ごとのまとめ。新しい月が先。

    週まとめは「その週に何が起きたか」を見るためのもので、月をまたいだ
    傾向は追えない。営業日が20日たまると、月の単位が意味を持ち始める。
    """
    buckets: dict[str, list[dict]] = {}
    for day in days:
        buckets.setdefault(day["rec_date"][:7], []).append(day)

    out = []
    for month, group in buckets.items():
        group = sorted(group, key=lambda d: d["rec_date"], reverse=True)
        movers = [
            {**row, "rec_date": day["rec_date"]}
            for day in group for row in day.get("gainers", [])
        ]
        movers.sort(key=lambda r: r["change_pct"], reverse=True)
        stops = sum(
            1 for day in group for r in day.get("gainers", [])
            if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_HIGH
        )
        out.append({
            "slug": month,
            "year": int(month[:4]),
            "month": int(month[5:7]),
            "from": group[-1]["rec_date"],
            "to": group[0]["rec_date"],
            "day_count": len(group),
            "stop_highs": stops,
            "top_movers": movers[:20],
            "frequent": frequent(group, "gainers", top_n=20),
        })
    out.sort(key=lambda m: m["slug"], reverse=True)
    return out


# --- 同じ日に一緒にランクインした銘柄 ---------------------------------------

def co_occurring(days: list[dict], code: str, top_n: int = 10) -> list[dict]:
    """その銘柄が載った日に、一緒に載っていた銘柄。

    同じ日に動いた銘柄には、同じ材料（テーマ・指数のイベント）が効いている
    ことがある。ランキングを日ごとに持っているからこそ出せる切り口。
    因果は言えないので、数えた回数だけを出す。
    """
    target_days = [d for d in days if any(r["code"] == code for r in d.get("gainers", []))]
    counts: dict[str, dict] = {}
    for day in target_days:
        for row in day.get("gainers", []):
            if row["code"] == code:
                continue
            entry = counts.setdefault(row["code"], {"code": row["code"], "name": row["name"], "count": 0})
            entry["name"] = row["name"]
            entry["count"] += 1
    out = [e for e in counts.values() if e["count"] >= 2]
    out.sort(key=lambda e: (-e["count"], e["code"]))
    return out[:top_n]
