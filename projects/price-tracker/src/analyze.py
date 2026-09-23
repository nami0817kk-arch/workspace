"""価格履歴から「買い時か」を機械的に判定する。

判定はすべて四則演算で行い、実行時に AI は使わない。
理由は2つ。定額のサブスク以外に従量課金を発生させないため、
そして「事実の提示」に留めることで、根拠のない推奨を書かないため。
"""

# 履歴がこの日数に満たない商品について「過去最安値」を名乗らない。
# 初日は当然すべてが最安値になるが、それは情報ではないため。
from .store import entry as _entry

MIN_DAYS_FOR_LOW = 7


def last_change(rec: dict) -> str | None:
    """価格が最後に動いた日。

    sitemap の lastmod に使う。毎日「今日更新」と申告すると、実際には何も
    変わっていないページまで再クロールさせることになる。
    """
    tail = [(e[0], e[1]) for e in map(_entry, rec.get("tail") or [])]
    for i in range(len(tail) - 1, 0, -1):
        if tail[i][1] != tail[i - 1][1]:
            return tail[i][0]
    return tail[0][0] if tail else None


def effective(price, rate) -> int:
    """ポイント分を引いた実質価格。

    楽天の値引きは価格よりポイント倍率で動く。実測では、価格がほぼ動かなかった
    2026-09-10 に実質価格は376件が5%以上下がっていた。価格だけを見ると、その日の
    値引きを丸ごと取り逃す。

    倍率は「購入額の何%が戻るか」に相当する（10倍 = 10%）。実際の付与は SPU や
    会員ランクでも変わるため、これは目安であって確定額ではない。表示側で必ず
    そう断ること。
    """
    if not price:
        return 0
    return round(int(price) * (1 - min(int(rate or 1), 100) / 100))


def evaluate(rec: dict, drop_threshold: float, near_low_threshold: float) -> dict:
    """1商品の履歴レコードを判定結果に変える。"""
    price = rec.get("last")
    low = rec.get("min")
    if not price or not low:
        return {}

    days = int(rec.get("days") or 0)
    prev = rec.get("prev")
    drop_pct = (prev - price) / prev if prev and prev > price else 0.0
    rise_pct = (price - prev) / prev if prev and price > prev else 0.0
    vs_low_pct = (price - low) / low if low else 0.0
    high = rec.get("max") or price
    off_high_pct = (high - price) / high if high else 0.0

    trustworthy = days >= MIN_DAYS_FOR_LOW
    at_low = trustworthy and price <= low
    near_low = trustworthy and 0 < vs_low_pct <= near_low_threshold
    dropped = drop_pct >= drop_threshold

    if at_low:
        label = "記録した中で最安"
    elif near_low:
        label = "最安値に近い"
    elif dropped:
        label = "値下がり"
    elif not trustworthy:
        label = "記録中"
    else:
        label = "横ばい"

    rate = int(rec.get("last_rate") or 1)
    eff = effective(price, rate)
    # 倍率を記録し始める前の日は prev_rate が無い。1倍と決めつけると、記録開始の
    # 翌日に「倍率が下がった/上がった」偽の変化が一斉に出る。分からない日は
    # 実質の比較そのものをしない。
    prev_rate = rec.get("prev_rate")
    if prev and prev_rate is not None:
        eff_prev = effective(prev, int(prev_rate))
        eff_drop_pct = (eff_prev - eff) / eff_prev if eff_prev > eff else 0.0
    else:
        eff_prev, eff_drop_pct = None, 0.0

    return {
        "changed_date": last_change(rec),
        "point_rate": rate, "eff_price": eff, "eff_prev": eff_prev,
        "eff_drop_pct": eff_drop_pct,
        "price": price, "low": low, "high": high, "days": days,
        "prev": prev, "drop_pct": drop_pct, "rise_pct": rise_pct,
        "vs_low_pct": vs_low_pct, "off_high_pct": off_high_pct,
        "at_low": at_low, "near_low": near_low, "dropped": dropped,
        "trustworthy": trustworthy, "label": label,
        "low_date": rec.get("min_date"), "tail": rec.get("tail") or [],
    }


def evaluate_all(summary: dict, items: dict, drop_threshold: float,
                 near_low_threshold: float) -> list[dict]:
    """商品マスタと履歴を突き合わせ、判定済みの一覧にする。

    履歴にしか無い商品（販売終了などで今日取得できなかったもの）は、
    価格が今日のものだと誤解されるため出さない。
    """
    out = []
    for code, meta in items.items():
        rec = summary.get(code)
        if not rec:
            continue
        verdict = evaluate(rec, drop_threshold, near_low_threshold)
        if not verdict:
            continue
        out.append({**meta, **verdict, "item_code": code})
    return out


def drops(rows: list[dict], limit: int | None = None) -> list[dict]:
    """前回より安くなったものを、下げ幅の大きい順に。"""
    hit = [r for r in rows if r["dropped"]]
    hit.sort(key=lambda r: (-r["drop_pct"], r["price"]))
    return hit[:limit] if limit else hit


def lows(rows: list[dict], limit: int | None = None) -> list[dict]:
    """記録した中で最安、またはそれに近いもの。"""
    hit = [r for r in rows if r["at_low"] or r["near_low"]]
    hit.sort(key=lambda r: (r["vs_low_pct"], -r["days"]))
    return hit[:limit] if limit else hit


def rises(rows: list[dict], threshold: float, limit: int | None = None) -> list[dict]:
    """前回より高くなったものを、上げ幅の大きい順に。

    値下がりだけを並べると「安いから買え」としか言わないサイトになる。
    高くなったものを同じ基準で出すことが、価格を追う道具としての値打ちになる。
    """
    hit = [r for r in rows if r.get("rise_pct", 0) >= threshold]
    hit.sort(key=lambda r: (-r["rise_pct"], r["price"]))
    return hit[:limit] if limit else hit


def effective_drops(rows: list[dict], threshold: float, limit: int | None = None) -> list[dict]:
    """ポイント込みで安くなったものを、下げ幅の大きい順に。

    価格が据え置きでも倍率が上がれば実質は下がる。その日を取り逃さないための一覧。
    """
    hit = [r for r in rows if r.get("eff_drop_pct", 0) >= threshold]
    hit.sort(key=lambda r: (-r["eff_drop_pct"], r["price"]))
    return hit[:limit] if limit else hit


def change_count(rec_or_row: dict) -> int:
    """記録している期間に価格が動いた回数。

    追跡5,506件のうち4,189件は一度も動かない。動く商品を見つけること自体が、
    毎日ためた履歴からしか作れない情報になる。
    """
    prices = [e[1] for e in map(_entry, rec_or_row.get("tail") or [])]
    return sum(1 for i in range(1, len(prices)) if prices[i] != prices[i - 1])


def active(rows: list[dict], limit: int | None = None) -> list[dict]:
    """よく動く商品を、動いた回数の多い順に。"""
    hit = [r for r in rows if change_count(r) >= 2]
    hit.sort(key=lambda r: (-change_count(r), r["vs_low_pct"]))
    return hit[:limit] if limit else hit


def new_lows(rows: list[dict], day: str, limit: int | None = None) -> list[dict]:
    """その日に最安値を更新した商品。

    「最安値圏」は近い価格も含むが、こちらは記録を塗り替えた当日だけ。
    履歴を持っていないと出せない一覧で、買い手にとっては一番強い合図になる。
    """
    hit = [r for r in rows
           if r.get("at_low") and r.get("trustworthy") and r.get("low_date") == day]
    hit.sort(key=lambda r: (-r.get("off_high_pct", 0), r["price"]))
    return hit[:limit] if limit else hit


def by_genre(rows: list[dict], genre_id: str, limit: int | None = None) -> list[dict]:
    """取得元ジャンルで絞り、注目すべき順に並べる。

    単品ページは価格比較サイトと正面から競合して勝ち目が薄い。ジャンル単位の
    入口ページを別に持ち、そこから各商品へ内部リンクを張る。

    並び順は「下げ幅の大きいもの → 最安値に近いもの → 高値からの下落幅」。
    値下がりが無い日でも空にならないよう、最後の基準で必ず順序が付く。
    """
    hit = [r for r in rows if str(r.get("source_genre") or "") == str(genre_id)]
    hit.sort(key=lambda r: (-r["drop_pct"], r["vs_low_pct"], -r["off_high_pct"]))
    return hit[:limit] if limit else hit
