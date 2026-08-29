"""SQLiteによる永続化。重複配信と二重課金を防ぐのがここの責務。"""

from __future__ import annotations

import sqlite3
from datetime import date, datetime, timedelta
from pathlib import Path

from .models import Issue, Item, LedgerEntry, Subscriber

SCHEMA = """
CREATE TABLE IF NOT EXISTS items (
    hash TEXT PRIMARY KEY,
    niche TEXT NOT NULL,
    source TEXT NOT NULL,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    summary TEXT NOT NULL DEFAULT '',
    published_at TEXT,
    fetched_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_items_niche ON items(niche);

CREATE TABLE IF NOT EXISTS issues (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    niche TEXT NOT NULL,
    issue_date TEXT NOT NULL,
    title TEXT NOT NULL,
    teaser_md TEXT NOT NULL,
    body_md TEXT NOT NULL,
    takeaways TEXT NOT NULL DEFAULT '',
    item_hashes TEXT NOT NULL DEFAULT '',
    model TEXT NOT NULL DEFAULT '',
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    cost_usd REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    UNIQUE(niche, issue_date)
);

CREATE TABLE IF NOT EXISTS subscribers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    niche TEXT NOT NULL,
    plan TEXT NOT NULL DEFAULT 'free',
    status TEXT NOT NULL DEFAULT 'active',
    started_at TEXT,
    canceled_at TEXT,
    UNIQUE(email, niche)
);

CREATE TABLE IF NOT EXISTS deliveries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    issue_id INTEGER NOT NULL,
    subscriber_id INTEGER NOT NULL,
    variant TEXT NOT NULL,
    delivered_at TEXT NOT NULL,
    UNIQUE(issue_id, subscriber_id)
);

CREATE TABLE IF NOT EXISTS ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    kind TEXT NOT NULL,
    category TEXT NOT NULL,
    amount_usd REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    ref TEXT NOT NULL DEFAULT '',
    UNIQUE(kind, category, ref)
);
"""


def _dt(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


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

    # ---------- items ----------

    def known_hashes(self, niche: str) -> set[str]:
        rows = self.conn.execute("SELECT hash FROM items WHERE niche = ?", (niche,))
        return {r["hash"] for r in rows}

    def save_items(self, items: list[Item]) -> int:
        """未知の記事だけを保存し、保存件数を返す（既知はINSERT時に弾かれる）。"""
        saved = 0
        for it in items:
            cur = self.conn.execute(
                """INSERT OR IGNORE INTO items
                   (hash, niche, source, title, url, summary, published_at, fetched_at)
                   VALUES (?,?,?,?,?,?,?,?)""",
                (
                    it.hash,
                    it.niche,
                    it.source,
                    it.title,
                    it.url,
                    it.summary,
                    it.published_at.isoformat() if it.published_at else None,
                    (it.fetched_at or datetime.now()).isoformat(),
                ),
            )
            saved += cur.rowcount
        self.conn.commit()
        return saved

    # ---------- issues ----------

    def get_issue(self, niche: str, issue_date: date) -> Issue | None:
        row = self.conn.execute(
            "SELECT * FROM issues WHERE niche = ? AND issue_date = ?",
            (niche, issue_date.isoformat()),
        ).fetchone()
        return self._row_to_issue(row) if row else None

    def save_issue(self, issue: Issue) -> Issue:
        cur = self.conn.execute(
            """INSERT OR REPLACE INTO issues
               (id, niche, issue_date, title, teaser_md, body_md, takeaways, item_hashes,
                model, input_tokens, output_tokens, cost_usd, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                issue.id,
                issue.niche,
                issue.issue_date.isoformat(),
                issue.title,
                issue.teaser_md,
                issue.body_md,
                "\n".join(issue.takeaways),
                "\n".join(issue.item_hashes),
                issue.model,
                issue.input_tokens,
                issue.output_tokens,
                issue.cost_usd,
                datetime.now().isoformat(),
            ),
        )
        self.conn.commit()
        issue.id = issue.id or cur.lastrowid
        return issue

    @staticmethod
    def _row_to_issue(row: sqlite3.Row) -> Issue:
        return Issue(
            id=row["id"],
            niche=row["niche"],
            issue_date=date.fromisoformat(row["issue_date"]),
            title=row["title"],
            teaser_md=row["teaser_md"],
            body_md=row["body_md"],
            takeaways=tuple(t for t in row["takeaways"].split("\n") if t),
            item_hashes=tuple(h for h in row["item_hashes"].split("\n") if h),
            model=row["model"],
            input_tokens=row["input_tokens"],
            output_tokens=row["output_tokens"],
            cost_usd=row["cost_usd"],
        )

    # ---------- subscribers ----------

    def upsert_subscriber(self, sub: Subscriber) -> Subscriber:
        self.conn.execute(
            """INSERT INTO subscribers (email, niche, plan, status, started_at, canceled_at)
               VALUES (?,?,?,?,?,?)
               ON CONFLICT(email, niche) DO UPDATE SET
                 plan = excluded.plan,
                 status = excluded.status,
                 started_at = COALESCE(subscribers.started_at, excluded.started_at),
                 canceled_at = excluded.canceled_at""",
            (
                sub.email,
                sub.niche,
                sub.plan,
                sub.status,
                (sub.started_at or date.today()).isoformat(),
                sub.canceled_at.isoformat() if sub.canceled_at else None,
            ),
        )
        self.conn.commit()
        row = self.conn.execute(
            "SELECT * FROM subscribers WHERE email = ? AND niche = ?", (sub.email, sub.niche)
        ).fetchone()
        return self._row_to_subscriber(row)

    def cancel_subscriber(self, email: str, niche: str, on: date | None = None) -> bool:
        cur = self.conn.execute(
            "UPDATE subscribers SET status = 'canceled', canceled_at = ? WHERE email = ? AND niche = ?",
            ((on or date.today()).isoformat(), email, niche),
        )
        self.conn.commit()
        return cur.rowcount > 0

    def subscribers(self, niche: str, status: str = "active") -> list[Subscriber]:
        sql = "SELECT * FROM subscribers WHERE niche = ?"
        params: list[object] = [niche]
        if status:
            sql += " AND status = ?"
            params.append(status)
        rows = self.conn.execute(sql + " ORDER BY id", params)
        return [self._row_to_subscriber(r) for r in rows]

    @staticmethod
    def _row_to_subscriber(row: sqlite3.Row) -> Subscriber:
        return Subscriber(
            id=row["id"],
            email=row["email"],
            niche=row["niche"],
            plan=row["plan"],
            status=row["status"],
            started_at=date.fromisoformat(row["started_at"]) if row["started_at"] else None,
            canceled_at=date.fromisoformat(row["canceled_at"]) if row["canceled_at"] else None,
        )

    # ---------- deliveries ----------

    def record_delivery(self, issue_id: int, subscriber_id: int, variant: str) -> bool:
        """未配信なら記録してTrueを返す。再実行時の二重配信はここで止まる。"""
        cur = self.conn.execute(
            """INSERT OR IGNORE INTO deliveries (issue_id, subscriber_id, variant, delivered_at)
               VALUES (?,?,?,?)""",
            (issue_id, subscriber_id, variant, datetime.now().isoformat()),
        )
        self.conn.commit()
        return cur.rowcount > 0

    # ---------- ledger ----------

    def add_ledger(self, entry: LedgerEntry) -> bool:
        """ref付きで冪等に計上する。同じ ref の再計上はスキップされTrueを返さない。"""
        cur = self.conn.execute(
            """INSERT OR IGNORE INTO ledger (ts, kind, category, amount_usd, note, ref)
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
                ts=_dt(r["ts"]),
                kind=r["kind"],
                category=r["category"],
                amount_usd=r["amount_usd"],
                note=r["note"],
                ref=r["ref"],
            )
            for r in rows
        ]

    def count_issues(self, since: date | None = None, until: date | None = None) -> int:
        sql = "SELECT COUNT(*) c FROM issues WHERE 1=1"
        params: list[object] = []
        if since:
            sql += " AND issue_date >= ?"
            params.append(since.isoformat())
        if until:
            sql += " AND issue_date <= ?"
            params.append(until.isoformat())
        return self.conn.execute(sql, params).fetchone()["c"]
