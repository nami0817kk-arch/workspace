"""
値上がり質ランキング DB 管理 (Microsoft Access .accdb)

data/db/quality_gainers.accdb に毎日の上位20件と
14 営業日分の追跡終値を蓄積する。
"""
import pyodbc
import pandas as pd
import yfinance as yf
from datetime import datetime, date
from pathlib import Path

DB_PATH = Path(__file__).parent.parent.parent / "data" / "db" / "quality_gainers.accdb"

_CREATE_TABLE = """
CREATE TABLE quality_gainers (
    id           COUNTER PRIMARY KEY,
    [記録日]     TEXT(20),
    [銘柄コード] TEXT(20),
    [銘柄名]     TEXT(100),
    [順位]       INTEGER,
    [記録時終値] DOUBLE,
    [d01]        DOUBLE,
    [d02]        DOUBLE,
    [d03]        DOUBLE,
    [d04]        DOUBLE,
    [d05]        DOUBLE,
    [d06]        DOUBLE,
    [d07]        DOUBLE,
    [d08]        DOUBLE,
    [d09]        DOUBLE,
    [d10]        DOUBLE,
    [d11]        DOUBLE,
    [d12]        DOUBLE,
    [d13]        DOUBLE,
    [d14]        DOUBLE,
    [最終更新]   TEXT(20)
)
"""

_INSERT_ROW = """
    INSERT INTO quality_gainers
      ([記録日],[銘柄コード],[銘柄名],[順位],[記録時終値],
       [d01],[d02],[d03],[d04],[d05],[d06],[d07],
       [d08],[d09],[d10],[d11],[d12],[d13],[d14],
       [最終更新])
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
"""


def _conn_str() -> str:
    return (
        r"Driver={Microsoft Access Driver (*.mdb, *.accdb)};"
        f"DBQ={DB_PATH};"
    )


def _create_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    import win32com.client
    catalog = win32com.client.Dispatch("ADOX.Catalog")
    catalog.Create(f"Provider=Microsoft.ACE.OLEDB.12.0;Data Source={DB_PATH};")
    del catalog
    con = pyodbc.connect(_conn_str(), autocommit=True)
    con.execute(_CREATE_TABLE)
    con.close()


def _connect() -> pyodbc.Connection:
    if not DB_PATH.exists():
        _create_db()
    return pyodbc.connect(_conn_str())


def _ensure_table():
    """quality_gainers テーブルが存在しなければ作成する"""
    if not DB_PATH.exists():
        _create_db()
        return
    con = pyodbc.connect(_conn_str(), autocommit=True)
    try:
        con.execute("SELECT TOP 1 id FROM quality_gainers")
    except Exception:
        con.execute(_CREATE_TABLE)
    finally:
        con.close()


def save(df: pd.DataFrame, rec_date: str | None = None) -> tuple[int, int]:
    """
    ランキング結果を DB に保存する。

    スキップルール（重複防止）:
    - 同日に既に登録済みの銘柄 → スキップ（冪等性）
    - d14 未記入で追跡中の銘柄 → スキップ（重複追跡防止）
    - d14 記入済み（追跡完了）の銘柄 → 再登録可能

    Returns:
        (inserted, skipped)
    """
    _ensure_table()
    today = rec_date or str(date.today())
    now   = datetime.now().strftime("%Y-%m-%d %H:%M")

    with _connect() as con:
        cur = con.cursor()
        cur.execute(
            "SELECT [銘柄コード] FROM quality_gainers WHERE [記録日] = ?", (today,)
        )
        same_day = {row[0] for row in cur.fetchall()}
        cur.execute(
            "SELECT [銘柄コード] FROM quality_gainers WHERE [d14] IS NULL"
        )
        active = {row[0] for row in cur.fetchall()}

    skip = same_day | active
    rows, skipped = [], 0

    for rank, row in enumerate(df.itertuples(), 1):
        ticker = getattr(row, "ticker", "")
        if ticker in skip:
            skipped += 1
            continue
        rows.append((
            today,
            ticker,
            getattr(row, "name", ""),
            rank,
            getattr(row, "終値", None),
            None, None, None, None, None, None, None,
            None, None, None, None, None, None, None,
            now,
        ))

    if rows:
        with _connect() as con:
            cur = con.cursor()
            cur.executemany(_INSERT_ROW, rows)
            con.commit()

    return len(rows), skipped


def update_prices():
    """d01〜d14 終値を最新株価データで補完する。

    記録日の翌営業日を d01 とし、14 営業日分まで順に埋める。
    既に値が入っているカラムは変更しない。
    """
    _ensure_table()
    con = _connect()
    cur = con.cursor()
    cur.execute(
        "SELECT id, [記録日], [銘柄コード] FROM quality_gainers WHERE [d14] IS NULL"
    )
    pending = cur.fetchall()
    con.close()

    if not pending:
        print("  更新対象なし（全レコードの d14 が埋まっています）")
        return

    from collections import defaultdict
    ticker_map: dict[str, list[tuple]] = defaultdict(list)
    for row_id, rec_date, ticker in pending:
        ticker_map[ticker].append((row_id, rec_date))

    today_str = str(date.today())
    updated   = 0

    with _connect() as con:
        cur = con.cursor()
        for ticker, records in ticker_map.items():
            try:
                df = yf.download(
                    ticker, period="45d", interval="1d",
                    auto_adjust=True, progress=False
                )
                if df.empty:
                    continue
                df.columns = (
                    df.columns.droplevel(1)
                    if isinstance(df.columns, pd.MultiIndex) else df.columns
                )
                df.index   = pd.to_datetime(df.index).strftime("%Y-%m-%d")
                dates_list = df.index.tolist()

                for row_id, rec_date in records:
                    try:
                        base_idx = dates_list.index(rec_date)
                    except ValueError:
                        later = [d for d in dates_list if d > rec_date]
                        if not later:
                            continue
                        base_idx = dates_list.index(later[0]) - 1

                    # 現在の d カラム値を取得
                    cur.execute(
                        "SELECT [d01],[d02],[d03],[d04],[d05],[d06],[d07],"
                        "[d08],[d09],[d10],[d11],[d12],[d13],[d14] "
                        "FROM quality_gainers WHERE id = ?",
                        (row_id,)
                    )
                    existing = cur.fetchone()
                    if existing is None:
                        continue

                    updates = {}
                    for n in range(1, 15):
                        if existing[n - 1] is not None:
                            continue
                        idx = base_idx + n
                        if idx < len(dates_list) and dates_list[idx] <= today_str:
                            updates[f"d{n:02d}"] = round(float(df.iloc[idx]["Close"]), 2)

                    if not updates:
                        continue

                    set_parts = ", ".join(f"[{k}] = ?" for k in updates)
                    set_parts += ", [最終更新] = ?"
                    vals = list(updates.values()) + [today_str, row_id]
                    cur.execute(
                        f"UPDATE quality_gainers SET {set_parts} WHERE id = ?", vals
                    )
                    updated += 1

            except Exception as e:
                # 1銘柄の失敗で更新全体を止めない（記録の連続性が最優先。commit は
                # ループ後なので、ここで中断すると他銘柄の更新まで失われる）。
                # ただし黙って捨てると d カラムが埋まらない原因を追えなくなる。
                print(f"  [WARN] {ticker}: 追跡価格の更新に失敗: {e}")
                continue

        con.commit()

    print(f"  {updated} 件のレコードを更新しました。")


def report() -> str:
    """2週間パフォーマンス集計を文字列で返す。"""
    if not DB_PATH.exists():
        return "  DB が存在しません。"
    try:
        _ensure_table()
        con = _connect()
        df  = pd.read_sql("SELECT * FROM quality_gainers", con)
        con.close()

        if df.empty:
            return "  データがありません。"

        for col in ["記録時終値", "d05", "d10", "d14"]:
            df[col] = pd.to_numeric(df[col], errors="coerce")

        completed = df.dropna(subset=["記録時終値", "d14"])
        partial   = df[df["d14"].isna() & df["記録時終値"].notna()]

        lines = []
        lines.append(f"{'='*60}")
        lines.append(f"  記録件数: {len(df)} 件  (2週完了: {len(completed)} 件  追跡中: {len(partial)} 件)")

        if not completed.empty:
            completed = completed.copy()
            completed["2w損益率"] = (
                (completed["d14"] - completed["記録時終値"]) / completed["記録時終値"] * 100
            )
            completed["1w損益率"] = (
                (completed["d05"] - completed["記録時終値"]) / completed["記録時終値"] * 100
            )
            total = len(completed)
            wins  = (completed["2w損益率"] > 0).sum()
            avg2w = completed["2w損益率"].mean()
            avg1w = completed["1w損益率"].mean()

            lines.append(f"{'='*60}")
            lines.append(f"  【2週間パフォーマンス】 ({total} 件)")
            lines.append(
                f"  勝率: {wins}/{total} ({wins/total*100:.0f}%)  "
                f"平均2週後: {avg2w:+.1f}%  平均1週後: {avg1w:+.1f}%"
            )

            for bb in ["上限付近", "中央付近", "下限付近"]:
                sub = completed[completed["BB位置"] == bb]
                if len(sub) >= 3:
                    lines.append(
                        f"  BB={bb}: 平均 {sub['2w損益率'].mean():+.1f}% ({len(sub)}件)"
                    )

            top5 = completed.nlargest(5, "2w損益率")[["記録日", "銘柄名", "2w損益率"]]
            lines.append(f"\n  【2週後 TOP5】")
            for _, r in top5.iterrows():
                lines.append(f"    {r['記録日']}  {r['銘柄名']}  {r['2w損益率']:+.1f}%")

        lines.append(f"{'='*60}")
        return "\n".join(lines)

    except Exception as e:
        return f"  集計エラー: {e}"


def get_past_records() -> list[dict]:
    """quality_gainers の全レコードを検出用に返す。"""
    if not DB_PATH.exists():
        return []
    try:
        _ensure_table()
        con = _connect()
        df  = pd.read_sql(
            "SELECT [記録日],[銘柄コード],[銘柄名],[記録時終値] FROM quality_gainers",
            con,
        )
        con.close()
        records = []
        for _, row in df.iterrows():
            if row["記録時終値"] is None:
                continue
            records.append({
                "ticker":    row["銘柄コード"],
                "name":      row["銘柄名"],
                "rec_date":  row["記録日"],
                "rec_close": float(row["記録時終値"]),
            })
        return records
    except Exception:
        return []


def clear_all() -> int:
    """quality_gainers テーブルの全レコードを削除する。件数を返す。"""
    _ensure_table()
    with _connect() as con:
        cur = con.cursor()
        cur.execute("SELECT COUNT(*) FROM quality_gainers")
        n = cur.fetchone()[0]
        cur.execute("DELETE FROM quality_gainers")
        con.commit()
    return n


def query(sql: str) -> pd.DataFrame:
    """任意の SELECT を実行して DataFrame を返す（デバッグ用）"""
    _ensure_table()
    con = _connect()
    df  = pd.read_sql(sql, con)
    con.close()
    return df
