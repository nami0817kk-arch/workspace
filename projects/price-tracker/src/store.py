"""価格の記録と集計。

APIは「今日の価格」しか返さない。毎日それを保存し続けることで、
他が持っていない価格履歴になる。この蓄積がこのサイトの唯一の資産なので、
保存処理は「同じ日に二回動かしても壊れない」ことを最優先にする。
"""
import csv
import gzip
import json
from pathlib import Path

SNAPSHOT_FIELDS = ["date", "item_code", "price", "point_rate",
                   "review_count", "review_average"]


def snapshot_path(data_dir: Path, day: str) -> Path:
    return data_dir / "snapshots" / f"{day}.csv.gz"


def write_snapshot(data_dir: Path, day: str, items: list[dict]) -> Path:
    """その日の価格を1ファイルに書く。既にあれば上書きする（再実行しても二重に増えない）。"""
    path = snapshot_path(data_dir, day)
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=SNAPSHOT_FIELDS)
        writer.writeheader()
        for item in items:
            writer.writerow({
                "date": day,
                "item_code": item["item_code"],
                "price": item["price"],
                "point_rate": item.get("point_rate", 1),
                "review_count": item.get("review_count", 0),
                "review_average": item.get("review_average", 0),
            })
    return path


def read_snapshot(data_dir: Path, day: str) -> list[dict]:
    path = snapshot_path(data_dir, day)
    if not path.exists():
        return []
    with gzip.open(path, "rt", encoding="utf-8", newline="") as fh:
        return [
            {"date": r["date"], "item_code": r["item_code"], "price": int(r["price"])}
            for r in csv.DictReader(fh) if r.get("price")
        ]


def load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return default


def save_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=1, sort_keys=True),
                    encoding="utf-8")


def entry(row) -> tuple:
    """履歴の1点を (日付, 価格, ポイント倍率) に揃える。

    倍率を記録し始めたのは 2026-09-10 で、それ以前の点は2要素しかない。
    古い点は通常倍率（1倍）として扱う。
    """
    return (row[0], row[1], row[2] if len(row) > 2 else 1)


def previous_prices(data_dir: Path, day: str) -> dict:
    """その日より前で、いちばん新しい記録の (価格, 倍率) を返す。"""
    snaps = sorted(p for p in (data_dir / "snapshots").glob("*.csv.gz")
                   if p.name[:10] < day)
    if not snaps:
        return {}
    out = {}
    with gzip.open(snaps[-1], "rt", encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            out[row["item_code"]] = (int(row["price"]), int(row.get("point_rate") or 1))
    return out


def update_summary(summary: dict, items: list[dict], day: str, tail_days: int) -> dict:
    """その日の価格を履歴に足し込む。

    同じ日を二度渡しても結果が変わらないようにする（Actions の再実行や
    手動実行が重なっても履歴が歪まないため）。
    """
    out = dict(summary)
    for item in items:
        code, price = item["item_code"], int(item["price"])
        rate = int(item.get("point_rate") or 1)
        rec = dict(out.get(code) or {})
        tail = [list(p) for p in rec.get("tail") or []]

        if tail and tail[-1][0] == day:
            tail[-1] = [day, price, rate]
            recompute = True
        else:
            tail.append([day, price, rate])
            recompute = False
        tail = tail[-tail_days:]

        if recompute or "min" not in rec:
            # その日を上書きした場合、過去の最安値が今日の値だった可能性があるので
            # 保持している範囲から取り直す。
            prices = [e[1] for e in map(entry, tail)]
            rec["min"] = min(prices)
            rec["max"] = max(prices)
            rec["min_date"] = next(e[0] for e in map(entry, tail) if e[1] == rec["min"])
        else:
            if price < rec["min"]:
                rec["min"], rec["min_date"] = price, day
            if price > rec["max"]:
                rec["max"] = price

        rec["prev"] = rec.get("last")
        rec["prev_date"] = rec.get("last_date")
        rec["prev_rate"] = rec.get("last_rate")
        if rec.get("last_date") == day:
            # 同日再実行。prev は元のまま維持する。
            rec["prev"] = (out.get(code) or {}).get("prev")
            rec["prev_date"] = (out.get(code) or {}).get("prev_date")
            rec["prev_rate"] = (out.get(code) or {}).get("prev_rate")
        rec["last"], rec["last_date"] = price, day
        rec["last_rate"] = rate
        rec["days"] = len(tail)
        rec["tail"] = tail
        out[code] = rec
    return out
