"""
サイト全体のビルドエントリポイント。

1. 当日の値上がり/値下がり/活況ランキングを取得
2. data/YYYY-MM-DD.json ＋ data/latest.json に保存
3. output/ に静的HTMLを生成

市場休場日等でランキングが0件の場合は、既存データを壊さないよう
何もせずに正常終了する（呼び出し元のCIはこの場合コミット・デプロイをスキップする）。
"""
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aggregate
import fetcher
from fetcher import (
    fetch_active,
    fetch_gainers,
    fetch_losers,
    fetch_stop_high,
    fetch_stop_low,
)
import render
import stock_profile
import validate

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"

_ROW_COLS = ["rank", "code", "name", "close", "change_pct", "metric_value"]
# ストップ高・ストップ安の一覧には出来高が無い（その列がニュース欄になっている）
# 代わりに、引けで上限（下限）に張り付いていたかの印がある。
_STOP_COLS = ["rank", "code", "name", "close", "change_pct", "at_limit"]


def _stop_rows(df, label):
    """ストップ高／ストップ安の一覧を保存する形に直す。

    **1ページも取得できなかった日は `None` を返す**（呼び出し側がキーごと落とす）。
    空リスト（その日は本当に0件だった）と区別するため。0件は相場が穏やかなだけで
    異常ではないが、取れなかった日を0件として記録すると、あとから見たときに
    「その日はストップ高が無かった」という嘘になる。
    """
    if not fetcher.pages_fetched.get(label):
        return None
    return df[_STOP_COLS].to_dict(orient="records") if df is not None and not df.empty else []


def _count(payload, key):
    return len(payload[key]) if key in payload else "取得なし"


def _save_today(gainers, losers, active, stop_high=None, stop_low=None, *,
                skip_checks: bool = False) -> str | None:
    if gainers.empty:
        print("  本日分のランキングを取得できませんでした(休場日、または取得失敗)。スキップします。")
        return None

    rec_date = gainers["rec_date"].iloc[0]
    payload = {
        "rec_date": rec_date,
        # その日ストップ高をつけた銘柄の全件。上位30銘柄からの推定ではない。
        # 0件の日もある（相場が穏やかな日）。取得できなかった日はキーごと無い。
        "stop_high": _stop_rows(stop_high, fetcher.STOP_HIGH_LABEL),
        # ストップ安も同じ形で全件記録する。値下がり上位30銘柄からの推定では
        # 30位の外にあったストップ安が数えられない（ストップ高と同じ理由）。
        "stop_low": _stop_rows(stop_low, fetcher.STOP_LOW_LABEL),
        "gainers": gainers[_ROW_COLS].to_dict(orient="records"),
        "losers": losers[_ROW_COLS].to_dict(orient="records") if not losers.empty else [],
        "active": active[_ROW_COLS].to_dict(orient="records") if not active.empty else [],
    }

    # 取れなかったランキングはキーごと落とす（0件と取り違えさせない）
    for key in ("stop_high", "stop_low"):
        if payload[key] is None:
            del payload[key]

    # 保存する前に検査する。data/ は取り直しのきかない資産なので、
    # おかしなものを書き込むより、その日を落とすほうがまし。
    if not skip_checks:
        validate.check(payload, datetime.now(validate.JST))
    # 止めるほどではないが、黙って通すと穴に気づけないもの
    for warning in validate.warnings(payload):
        print(f"  [WARN] {warning}")

    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    day_path = _DATA_DIR / f"{rec_date}.json"
    day_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (_DATA_DIR / "latest.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(
        f"  {day_path} に保存しました"
        f"(値上がり{len(payload['gainers'])}/値下がり{len(payload['losers'])}"
        f"/活況{len(payload['active'])}/ストップ高{len(payload['stop_high'])}件)"
    )
    return rec_date


def main() -> None:
    # --force: 妥当性の検査を飛ばして保存する（検査が誤って弾いたときの逃げ道）。
    # --no-fetch: 取得せず data/ の既存データから output/ を作るだけ。
    # kabutan が GitHub Actions の IP をブロックしているため、取得は手元の PC
    # （タスクスケジューラ）が行い、CI はこのモードでビルド・公開だけを担当する。
    if "--no-fetch" in sys.argv:
        print("  --no-fetch: 取得をスキップし、既存データからビルドします。")
        if not any(_DATA_DIR.glob("????-??-??.json")):
            print("  [ERROR] data/ にデータがありません。")
            sys.exit(1)
        render.build_all()
        return

    gainers = fetch_gainers(top_n=30)
    losers = fetch_losers(top_n=30)
    active = fetch_active(top_n=30)
    stop_high = fetch_stop_high()
    stop_low = fetch_stop_low()

    try:
        rec_date = _save_today(gainers, losers, active, stop_high, stop_low,
                               skip_checks="--force" in sys.argv)
    except validate.InvalidPayload as e:
        # 既存のデータには一切触れずに落とす。run-daily.ps1 が通知を出す。
        print(f"  [ERROR] 取得したデータが妥当ではないため保存しませんでした: {e}")
        print("  内容を確認したうえで保存するなら --force を付けて実行する。")
        sys.exit(1)

    # 0件の理由が「休場日」ではなく「取得先との通信失敗」なら、正常終了させない。
    # ここを黙って通すと、CIは緑のままサイトの更新だけが止まる。
    if rec_date is None and fetcher.fetch_errors:
        print(f"  [ERROR] 取得失敗が {len(fetcher.fetch_errors)} 件あり、当日データを保存できませんでした。")
        sys.exit(1)

    # ページは取れたのに0件、は休場日ではなく解析の故障。
    # 休場日でも kabutan は直近営業日のランキングを出すので、ここは必ず異常。
    #
    # ただし**当日分が保存できているなら、ここで止めない**。止めると
    # run-daily.ps1 が commit の手前で終わり、取れている値上がり・値下がりまで
    # その日公開されなくなる（CI 側で「鮮度の警報を Deploy の後ろへ」と直したのと
    # 同じ問題）。知らせるのはログの [WARN] とデスクトップ通知で足りる。
    if fetcher.parse_failures:
        level = "ERROR" if rec_date is None else "WARN"
        for message in fetcher.parse_failures:
            print(f"  [{level}] {message}")
        if rec_date is None:
            sys.exit(1)

    if rec_date is None and not any(_DATA_DIR.glob("????-??-??.json")):
        print("  data/ に既存データも無いため、サイトのビルドを中止します。")
        return

    # 銘柄の基本属性（市場区分・業種・売買単位）。**未知の銘柄が出たときだけ**
    # 取りに行く。ここが失敗してもサイトの公開は止めない（属性は飾りで、
    # 無ければその行を出さないだけ。ランキングが出ないほうが損が大きい）。
    try:
        days = render.load_days()
        codes = stock_profile.needed_codes(days, (s["code"] for s in aggregate.stock_histories(days)))
        stock_profile.sync(codes)
    except Exception as e:
        print(f"  [WARN] 銘柄属性の取得に失敗しました（サイトは続けて作ります）: {e}")

    render.build_all()


if __name__ == "__main__":
    main()
