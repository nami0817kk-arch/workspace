"""保存する前に、取ってきたデータが妥当かを見る。

data/ は追記しかできない資産で、**上書きしてしまうと元には戻せない**
（kabutan は当日分しか出さないので、取り直しができない）。
2026-09-07 は、月曜のデータに金曜の日付が付いたまま保存され、
金曜のファイルを潰した。あのとき保存前に日付を一言確かめていれば防げた。

ここは「おかしければ保存しない」側に倒す。疑わしいものを弾いて
その日を取り逃すほうが、古い正しいデータを消すよりましなため。
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from market_calendar import CalendarOutOfRange, is_business_day, previous_business_day

JST = timezone(timedelta(hours=9))

# 東証の大引け（15:30）。これを過ぎれば当日の終値ランキングが出ている。
MARKET_CLOSE = time(15, 30)

# 上位30件を取りにいって、これを下回るのは取得か解析が壊れている疑いが濃い。
MIN_ROWS = 20


class InvalidPayload(Exception):
    """保存を見送るべきデータ。"""


def expected_rec_dates(now: datetime) -> set[str]:
    """この時点で kabutan が出しうる相場日。

    - 大引け後の営業日 → 当日
    - 場中・休場日 → 直近の営業日（前営業日の終値がまだ出ている）
    """
    today = now.date()
    try:
        if is_business_day(today):
            prev = previous_business_day(today)
            if now.time() >= MARKET_CLOSE:
                return {today.isoformat()}
            return {today.isoformat(), prev.isoformat()}
        return {previous_business_day(today).isoformat()}
    except CalendarOutOfRange:
        # 祝日表の範囲外では日付の妥当性を判断しない（空集合＝何もチェックしない）
        return set()


def warnings(payload: dict) -> list[str]:
    """保存は止めないが、知らせたほうがよいこと。

    値上がりだけ取れて値下がり・活況が空、という半端な取得は起こりうる。
    落とすほどではない（その日のランキング自体は残せる）が、黙って通すと
    アーカイブに穴が空いていることに誰も気づかない。
    """
    out = []
    if not payload.get("gainers"):
        return out
    for key, label in (("losers", "値下がり"), ("active", "活況")):
        if not payload.get(key):
            out.append(f"{label}ランキングが0件です（この日の{label}のページは作られません）")
    return out


def check(payload: dict, now: datetime) -> None:
    """おかしければ InvalidPayload を投げる。問題なければ黙って戻る。"""
    rec_date = payload.get("rec_date")
    if not rec_date:
        raise InvalidPayload("rec_date がありません")

    try:
        rec = date.fromisoformat(rec_date)
    except ValueError as e:
        raise InvalidPayload(f"rec_date の形式が不正です: {rec_date}") from e

    if rec > now.date():
        raise InvalidPayload(f"rec_date が未来です: {rec_date}")

    expected = expected_rec_dates(now)
    if expected and rec_date not in expected:
        # ここが 2026-09-07 の事故を止める関門。
        raise InvalidPayload(
            f"rec_date {rec_date} は、この時点で出るはずの相場日"
            f"（{ '/'.join(sorted(expected)) }）と一致しません。"
            "ページ上の日付の読み取りが壊れている可能性があります。"
        )

    gainers = payload.get("gainers") or []
    if len(gainers) < MIN_ROWS:
        raise InvalidPayload(f"値上がりの件数が{len(gainers)}件しかありません（{MIN_ROWS}件未満）")

    for row in gainers:
        if not str(row.get("code", "")).strip():
            raise InvalidPayload("銘柄コードが空の行があります")
        if row.get("change_pct") is None:
            raise InvalidPayload(f"騰落率が取れていない行があります: {row.get('code')}")

    if all(row["change_pct"] == 0 for row in gainers):
        raise InvalidPayload("値上がり率が全て0です（解析が壊れている疑い）")

    # 値上がりランキングなのに首位が下落しているなら、並び替えか列の読み違い。
    if gainers[0]["change_pct"] < 0:
        raise InvalidPayload(
            f"値上がりランキングの首位が下落しています（{gainers[0]['change_pct']}%）"
        )


def archive_problems(data_dir) -> list[str]:
    """data/ 全体の整合性。おかしなところを文章で返す（空なら問題なし）。

    data/ は追記しかできない資産で、壊れても取り直せない。
    ファイル名と中身の日付が食い違う、latest.json が最新でない、といった
    ずれは**見た目には何も起きない**まま、アーカイブの日付をおかしくする。
    CI から毎回当てる。
    """
    import json
    from pathlib import Path

    data_dir = Path(data_dir)
    problems = []
    dates = []

    for path in sorted(data_dir.glob("????-??-??.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            problems.append(f"{path.name}: JSON として読めません（{e}）")
            continue

        rec_date = payload.get("rec_date")
        if rec_date != path.stem:
            problems.append(f"{path.name}: 中身の rec_date が {rec_date} でファイル名と違います")
        dates.append(path.stem)

        rows = payload.get("gainers") or []
        codes = [r.get("code") for r in rows]
        if len(codes) != len(set(codes)):
            problems.append(f"{path.name}: 値上がりに同じ銘柄コードが複数あります")
        ranks = [r.get("rank") for r in rows]
        if ranks and ranks != sorted(ranks):
            problems.append(f"{path.name}: 値上がりの順位が昇順になっていません")

    latest_path = data_dir / "latest.json"
    if latest_path.exists() and dates:
        latest = json.loads(latest_path.read_text(encoding="utf-8"))
        if latest.get("rec_date") != max(dates):
            problems.append(
                f"latest.json の rec_date が {latest.get('rec_date')} で、"
                f"最新のファイル {max(dates)} と違います"
            )

    return problems
