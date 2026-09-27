"""読み手に送る量が、気づかないうちに増えていないか。

検索ページは索引をまるごと読み込む。スマホの回線で開くので、
**キーを1つ足すだけで全体が一回り重くなる**（銘柄数ぶん効く）。
窓いっぱい（60営業日）でどれくらいになるかを、ここで見積もって止める。
"""
import json

import aggregate

# 1銘柄あたりの上限（バイト）。いまは 100 前後。
# 超えたら、索引に足したキーが本当に要るかを考え直す合図。
MAX_BYTES_PER_STOCK = 160

# 索引そのものの上限（KB）。窓いっぱいの見積もりで使う。
MAX_INDEX_KB = 400


def _days(n_days=30, per_day=30, pool=400):
    """実データの密度に寄せる。**毎日ほぼ別の顔ぶれ**が並ぶ（同じ銘柄が
    何十日も続けて載ることはまれ）。全部同じ銘柄にすると日付の一覧だけが
    伸びて、実態より重い見積もりになる。"""
    days = []
    for d in range(n_days):
        start = (d * per_day) % pool
        days.append({
            "rec_date": f"2026-{(d // 28) + 1:02d}-{(d % 28) + 1:02d}",
            "gainers": [{"rank": i + 1, "code": f"{1000 + (start + i) % pool}",
                         "name": f"銘柄名{(start + i) % pool}",
                         "close": 1234.0, "change_pct": 12.34, "metric_value": 1000}
                        for i in range(per_day)],
            "losers": [], "active": [],
        })
    return days


def test_索引は1銘柄あたりが軽い():
    index = aggregate.search_index(_days())
    size = len(json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    per = size / len(index["stocks"])
    assert per <= MAX_BYTES_PER_STOCK, f"1銘柄あたり {per:.0f} バイト（上限 {MAX_BYTES_PER_STOCK}）"


def test_窓いっぱいでも重くなりすぎない():
    """60営業日ぶんたまったときの見積もり。実データの密度で測る。"""
    days = _days(n_days=aggregate.SEARCH_WINDOW_DAYS)
    index = aggregate.search_index(days)
    size = len(json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    assert size / 1024 <= MAX_INDEX_KB, f"{size/1024:.0f} KB（上限 {MAX_INDEX_KB} KB）"


def test_窓より古い日は索引に入れない():
    """入れ続けると、検索ページだけが毎日重くなる。"""
    days = _days(n_days=aggregate.SEARCH_WINDOW_DAYS + 20, per_day=5, pool=10)
    index = aggregate.search_index(days)
    dates = {d for s in index["stocks"] for d in (s.get("g") or [])}
    assert len(dates) <= aggregate.SEARCH_WINDOW_DAYS
