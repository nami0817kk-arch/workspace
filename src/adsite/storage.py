"""SQLiteによる永続化。台帳の重複計上と、日次実績の履歴を扱う。"""

from __future__ import annotations

import sqlite3
from datetime import date, datetime, timedelta
from pathlib import Path

from .models import AdDaily, LedgerEntry

SCHEMA = """
CREATE TABLE IF NOT EXISTS ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    kind TEXT NOT NULL,
    category TEXT NOT NULL,
    amount_usd REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    ref TEXT NOT NULL,
    UNIQUE(ref)
);

CREATE TABLE IF NOT EXISTS ad_daily (
    day TEXT NOT NULL,
    page TEXT NOT NULL DEFAULT '',
    impressions INTEGER NOT NULL DEFAULT 0,
    clicks INTEGER NOT NULL DEFAULT 0,
    pageviews INTEGER NOT NULL DEFAULT 0,
    earnings_usd REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (day, page)
);
"""


class Storage:
    """薄いDAO。呼び出し側はSQLを書かない。"""

    def __init__(self, db_path: str | Path = ":memory:") -> None:
        self.db_path = str(db_path)
        if self.db_path != ":memory:":
            Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(SCHEMA)
        self.conn.commit()

    def close(self) -> None:
        self.conn.close()

    def __enter__(self) -> "Storage":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    # ---------- ledger ----------

    def add_ledger(self, entry: LedgerEntry, replace: bool = False) -> bool:
        """ref をキーに計上する。

        replace=False なら既存refはスキップ（原価の二重計上を防ぐ）。
        replace=True なら金額を上書きする。広告収益は「推定値」で提供され、
        後日確定値に改定されるため、こちらを使う。
        """
        if not entry.ref:
            raise ValueError("冪等性のため ref は必須です")
        verb = "INSERT OR REPLACE" if replace else "INSERT OR IGNORE"
        cur = self.conn.execute(
            f"""{verb} INTO ledger (ts, kind, category, amount_usd, note, ref)
                VALUES (?,?,?,?,?,?)""",
            (entry.ts.isoformat(), entry.kind, entry.category, entry.amount_usd, entry.note, entry.ref),
        )
        self.conn.commit()
        return cur.rowcount > 0

    def ledger_entries(self, since: date | None = None, until: date | None = None) -> list[LedgerEntry]:
        sql = "SELECT * FROM ledger WHERE 1=1"
        params: list[object] = []
        if since:
            sql += " AND ts >= ?"
            params.append(since.isoformat())
        if until:
            # ts は日時なので、until 当日を含めるため翌日0時を上限にする。
            sql += " AND ts < ?"
            params.append((until + timedelta(days=1)).isoformat())
        rows = self.conn.execute(sql + " ORDER BY ts", params)
        return [
            LedgerEntry(
                id=r["id"],
                ts=datetime.fromisoformat(r["ts"]),
                kind=r["kind"],
                category=r["category"],
                amount_usd=r["amount_usd"],
                note=r["note"],
                ref=r["ref"],
            )
            for r in rows
        ]

    # ---------- ad_daily ----------

    def save_ad_daily(self, rows: list[AdDaily]) -> int:
        """日×ページの実績を保存する。

        再取り込みは上書き。AdSenseは推定値を後から改定するので、
        「最後に取り込んだ値が正」とするのが実態に合う。
        """
        for row in rows:
            self.conn.execute(
                """INSERT OR REPLACE INTO ad_daily
                   (day, page, impressions, clicks, pageviews, earnings_usd)
                   VALUES (?,?,?,?,?,?)""",
                (
                    row.day.isoformat(),
                    row.page,
                    row.impressions,
                    row.clicks,
                    row.pageviews,
                    row.earnings_usd,
                ),
            )
        self.conn.commit()
        return len(rows)

    def ad_daily(self, since: date | None = None, until: date | None = None) -> list[AdDaily]:
        sql = "SELECT * FROM ad_daily WHERE 1=1"
        params: list[object] = []
        if since:
            sql += " AND day >= ?"
            params.append(since.isoformat())
        if until:
            sql += " AND day <= ?"
            params.append(until.isoformat())
        rows = self.conn.execute(sql + " ORDER BY day, page", params)
        return [
            AdDaily(
                day=date.fromisoformat(r["day"]),
                page=r["page"],
                impressions=r["impressions"],
                clicks=r["clicks"],
                pageviews=r["pageviews"],
                earnings_usd=r["earnings_usd"],
            )
            for r in rows
        ]
