"""1か月の投稿カレンダーを組む（2026-09-28 ユーザー「1ヶ月の投稿スケジュールが欲しい」）。

    python tools/schedule.py 2026-10            # research/schedule_202610.yaml と output/pages/schedule_202610/index.html

組み方（CLAUDE.md「10月のシリーズ」）：1日10本（本編）。毎日クラブ紹介1、曜日のシリーズ1、
試合日は「数字で振り返る注目試合」、残りを日本人ニュース3＋ほかのニュースで埋める。
試合日は ESPN の月の日程（research/_october_matchdays.json）から。代表ウィークは
リーグ戦が無いので、試合の数字の枠を「代表紹介・監督の経歴・財政・スタジアム・記録・10年前」で埋める。
"""
from __future__ import annotations

import datetime
import html
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
PER_DAY = 10
SERIES_TARGET = 6      # 1日のシリーズの本数（2026-09-28 ユーザー「シリーズの割合を上げたい」）。残りがニュース
JP_NEWS = 3            # 日本人ニュースは減らさない（登録者の柱）
# 毎日1本の型（クラブ紹介のほかに、選手紹介も毎日）
DAILY = [("クラブ紹介", 2), ("有名選手の紹介", 21)]
# 空いた枠を埋める随時のシリーズ（順に回す）
POOL = [("有名選手の比較", 22), ("日本人選手と同僚の序列の理由", 27), ("日本人選手 今季の軌跡", 10),
        ("監督の経歴", 13), ("クラブの財政", 12), ("記録の解説", 26), ("クラブ同士の比較（ダービーの数字）", 23),
        ("スタジアム紹介", 19), ("同じ年齢での比較", 24), ("若手の数字", 17), ("10年前の今日", 6), ("1年前の噂の検証", 15)]
WEEKDAY = {0: ("欧州組の1週間（週報）", 1), 1: ("5大リーグの順位表と今週の1つ", 3),
           2: ("仕組みの解説", 4), 3: ("数字で見るランキング／得点王レース", 5),
           4: ("有名選手の比較", 22)}
# 代表ウィーク・試合の無い日の埋め草（順に回す）
FILLERS = [("代表チームの紹介", 25), ("監督の経歴", 13), ("クラブの財政", 12), ("スタジアム紹介", 19),
           ("記録の解説", 26), ("10年前の今日", 6), ("若手の数字", 17), ("1年前の噂の検証", 15)]
CLUB_SERIES = [("ラ・リーガ", f"ll{i:02d}") for i in range(1, 21)] + [("ブンデスリーガ", f"bd{i:02d}") for i in range(1, 19)]


def load_matchdays() -> dict[str, dict[str, int]]:
    path = ROOT / "research" / "_october_matchdays.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def build(month: str) -> list[dict]:
    year, mon = int(month[:4]), int(month[5:7])
    first = datetime.date(year, mon, 1)
    days = []
    md = load_matchdays()
    club_i = 0
    filler_i = 0
    pool_i = 0
    d = first
    while d.month == mon:
        key = d.strftime("%m/%d")
        wd = d.weekday()
        leagues = [name for name, table in md.items() if table.get(key) and name not in ("親善", "ネーションズ")]
        national = [name for name in ("親善", "ネーションズ") if md.get(name, {}).get(key)]
        cups = [n for n in leagues if n in ("CL", "EL")]
        league_games = [n for n in leagues if n not in ("CL", "EL")]
        items: list[dict] = []
        # 1. 毎日の型：クラブ紹介と選手紹介
        league, code = CLUB_SERIES[club_i % len(CLUB_SERIES)]; club_i += 1
        items.append(dict(kind="シリーズ", name=f"クラブ紹介（{league} {code}）", plan=2))
        items.append(dict(kind="シリーズ", name="有名選手の紹介（1人）", plan=21))
        # 2. 曜日のシリーズ
        recent = [n for n, t in md.items() if n not in ("親善", "ネーションズ", "CL", "EL")
                  and any(t.get((d - datetime.timedelta(days=k)).strftime("%m/%d")) for k in range(1, 8))]
        if wd in WEEKDAY:
            name, plan = WEEKDAY[wd]
            if wd == 0 and not recent:
                name = "欧州組の1週間（代表戦の数字）"
            if wd == 1 and not recent:
                name, plan = "得点王・アシスト王レース（開幕からここまで）", 11   # 順位表は動いていない
            items.append(dict(kind="シリーズ", name=name, plan=plan))
        # 3. 試合の数字／代表ウィークの埋め草
        prev = (d - datetime.timedelta(days=1)).strftime("%m/%d")
        prev_games = [n for n, t in md.items() if t.get(prev) and n not in ("親善", "ネーションズ")]
        if prev_games:
            label = "・".join(prev_games[:3])
            items.append(dict(kind="シリーズ", name=f"数字で振り返る注目試合（前日の{label}）", plan=9))
        elif d.day <= 9 or wd in (5, 6):
            name, plan = FILLERS[filler_i % len(FILLERS)]; filler_i += 1
            items.append(dict(kind="シリーズ", name=name, plan=plan))
        # 4. 節目
        if d.day == 1:
            items.append(dict(kind="シリーズ", name="日本人選手の月間まとめ（前月）", plan=16))
        if (d + datetime.timedelta(days=1)).strftime("%m/%d") in md.get("CL", {}) and cups == []:
            items.append(dict(kind="シリーズ", name="欧州カップの対戦相手紹介（明日のCL）", plan=18))
        if d.day == 8:
            items.append(dict(kind="シリーズ", name="移籍の答え合わせ（夏の移籍の3か月後）", plan=28))
        if (d + datetime.timedelta(days=2)).strftime("%m/%d") in md.get("プレミア", {}) and wd == 3:
            items.append(dict(kind="シリーズ", name="日本人選手の次の相手（土日の試合）", plan=14))
        # 5. 目安の本数まで、随時のシリーズで埋める（同じ日に同じものは置かない）
        while len(items) < SERIES_TARGET:
            name, plan = POOL[pool_i % len(POOL)]; pool_i += 1
            if any(it["plan"] == plan for it in items):
                continue
            items.append(dict(kind="シリーズ", name=name, plan=plan))
        # 多すぎる日は埋め草から落とす
        while len(items) > SERIES_TARGET and any(it["plan"] in {f[1] for f in FILLERS + POOL} for it in items):
            items.remove(next(it for it in reversed(items) if it["plan"] in {f[1] for f in FILLERS + POOL}))
        # 6. ニュースで10本まで（日本人3は減らさない。残りが「ほか」で最低1本）
        series_n = len(items)
        other = max(1, PER_DAY - series_n - JP_NEWS)
        items.append(dict(kind="ニュース", name=f"日本人ニュース ×{JP_NEWS}", plan=0))
        items.append(dict(kind="ニュース", name=f"ほかのニュース ×{other}", plan=0))
        days.append(dict(date=d.isoformat(), weekday="月火水木金土日"[wd],
                         games=league_games, cups=cups, national=national,
                         series=series_n, total=series_n + JP_NEWS + other, items=items))
        d += datetime.timedelta(days=1)
    return days


SERIES_LABEL = {
    1: "欧州組の1週間（週報）", 2: "クラブ紹介", 3: "5大リーグの順位表と今週の1つ", 4: "仕組みの解説",
    5: "数字で見るランキング／得点王レース", 6: "10年前の今日", 9: "数字で振り返る注目試合",
    11: "得点王・アシスト王レース", 12: "クラブの財政", 13: "監督の経歴", 14: "日本人選手の次の相手",
    15: "1年前の噂の検証", 16: "日本人選手の月間まとめ", 17: "若手の数字", 18: "欧州カップの対戦相手紹介",
    19: "スタジアム紹介", 21: "有名選手の紹介・比較", 25: "代表チームの紹介", 26: "記録の解説",
    28: "移籍の答え合わせ",
}


def totals(days: list[dict]) -> dict:
    """月の内訳：シリーズごとの本数、ニュースの本数、本編とショートの合計。"""
    import re as _re

    series: dict[str, int] = {}
    jp = other = 0
    for x in days:
        for it in x["items"]:
            if it["kind"] == "シリーズ":
                label = SERIES_LABEL.get(it["plan"], _re.sub(r"（.*?）", "", it["name"]))
                series[label] = series.get(label, 0) + 1
            else:
                n = int(_re.search(r"×(\d+)", it["name"]).group(1))
                if it["name"].startswith("日本人"):
                    jp += n
                else:
                    other += n
    mains = sum(x["total"] for x in days)
    return dict(series=dict(sorted(series.items(), key=lambda kv: -kv[1])), japanese_news=jp, other_news=other,
                mains=mains, shorts=mains, days=len(days))


def page(month: str, days: list[dict]) -> str:
    """スマホで縦に読める形（2026-09-28 指示「スマホでも確認しやすいように」）。1日1枚のカード。"""
    cards = []
    for x in days:
        d = datetime.date.fromisoformat(x["date"])
        ev = []
        if x["games"]:
            ev.append("試合: " + "・".join(x["games"]))
        if x["cups"]:
            ev.append("・".join(x["cups"]))
        if x["national"]:
            ev.append("代表ウィーク")
        series = [it for it in x["items"] if it["kind"] == "シリーズ"]
        news = [it for it in x["items"] if it["kind"] != "シリーズ"]
        s_items = "".join(f'<li>{html.escape(it["name"])}</li>' for it in series)
        n_items = "・".join(html.escape(it["name"]) for it in news)
        cls = "card we" if d.weekday() >= 5 else "card"
        if d.weekday() == 0:
            cards.append(f'<h2 class="wk">{d.month}/{d.day} の週</h2>')
        cards.append(
            f'<section class="{cls}"><header><span class="date">{d.month}/{d.day}<b>{x["weekday"]}</b></span>'
            f'<span class="count">{x["total"]}本<small>シリーズ{x["series"]}</small></span></header>'
            f'<p class="ev">{html.escape(" ／ ".join(ev)) or "試合なし"}</p>'
            f'<ul class="s">{s_items}</ul><p class="n">{n_items}</p></section>')
    y, m = month[:4], int(month[5:7])
    t = totals(days)
    rows = "".join(f'<tr><td>{html.escape(k)}</td><td class="num">{v}本</td></tr>' for k, v in t["series"].items())
    series_total = sum(t["series"].values())
    summary = (f'<section class="sum"><h2>この月の本数</h2><table>'
               f'<tr class="head"><td>本編の合計</td><td class="num">{t["mains"]}本</td></tr>'
               f'<tr class="head"><td>ショート（本編ごとに1本）</td><td class="num">{t["shorts"]}本</td></tr>'
               f'<tr class="head"><td>シリーズの合計</td><td class="num">{series_total}本</td></tr>'
               f'{rows}'
               f'<tr class="head"><td>日本人ニュース</td><td class="num">{t["japanese_news"]}本</td></tr>'
               f'<tr class="head"><td>ほかのニュース</td><td class="num">{t["other_news"]}本</td></tr>'
               f'</table></section>')
    return f'''<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{y}年{m}月の投稿カレンダー</title>
<style>
:root{{--bg:#f6f4ef;--fg:#1d1c1a;--mut:#6a6660;--line:#dedad2;--card:#fff;--acc:#1f5f8b;--we:#fbf6ea}}
@media (prefers-color-scheme:dark){{:root:not([data-theme=light]){{--bg:#151412;--fg:#eeece6;--mut:#a29d94;--line:#3a3731;--card:#1f1d1a;--acc:#7fb3d9;--we:#2b261c}}}}
:root[data-theme=dark]{{--bg:#151412;--fg:#eeece6;--mut:#a29d94;--line:#3a3731;--card:#1f1d1a;--acc:#7fb3d9;--we:#2b261c}}
body{{margin:0;background:var(--bg);color:var(--fg);font:15px/1.65 "Hiragino Sans","Noto Sans JP",system-ui,sans-serif;padding-inline:16px;padding-block:16px 60px}}
main{{max-width:720px;margin:0 auto}} h1{{font-size:1.25rem;margin:0 0 .3rem;color:var(--acc)}} p.lead{{color:var(--mut);margin:0 0 10px;font-size:.86rem}}
.note{{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;font-size:.84rem;margin-bottom:12px}}
h2.wk{{font-size:.8rem;color:var(--mut);margin:18px 0 6px;letter-spacing:.04em;position:sticky;top:0;background:var(--bg);padding:6px 0;z-index:2}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 14px;margin:8px 0}} .card.we{{background:var(--we)}}
.card header{{display:flex;justify-content:space-between;align-items:baseline;gap:8px}}
.date{{font-size:1.15rem;font-weight:800;font-variant-numeric:tabular-nums}} .date b{{font-size:.8rem;font-weight:600;color:var(--mut);margin-left:6px}}
.count{{font-size:.95rem;font-weight:700;white-space:nowrap}} .count small{{display:block;font-weight:400;color:var(--mut);font-size:.72rem;text-align:right}}
.ev{{margin:.2rem 0 .4rem;font-size:.82rem;color:var(--mut)}}
ul.s{{margin:0;padding-left:1.1rem;color:var(--acc);font-size:.92rem}} ul.s li{{margin:.1rem 0}}
.n{{margin:.4rem 0 0;font-size:.84rem;color:var(--mut);border-top:1px dashed var(--line);padding-top:.35rem}}
.sum{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 14px;margin:0 0 14px}} .sum h2{{font-size:.95rem;margin:0 0 .4rem;color:var(--acc)}}
.sum table{{width:100%;border-collapse:collapse;font-size:.9rem}} .sum td{{padding:3px 0;border-bottom:1px solid var(--line)}} .sum td.num{{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap;width:5rem}}
.sum tr.head td{{font-weight:700}}
@media (min-width:700px){{.grid{{display:grid;grid-template-columns:1fr 1fr;gap:0 12px}} h2.wk{{grid-column:1/-1}}}}
</style></head><body><main>
<h1>{y}年{m}月の投稿カレンダー</h1>
<p class="lead">1日の本編の本数。ショートは本編ごとに1本（1日10本の上限内）。青がシリーズ（1日6本が目安）、下の灰色がニュースの枠（日本人3＋ほか）。</p>
<div class="note">月＝欧州組の1週間／火＝5大リーグの順位表／水＝仕組みの解説／木＝ランキング・得点王／金＝選手紹介・比較。毎日クラブ紹介1本（ラ・リーガ→ブンデス）。試合の翌日は「数字で振り返る注目試合」。10/1〜9は代表ウィークの続きでリーグ戦が無い。CLは10/14・15と21・22、ELは10/16・23。</div>
{summary}<div class="grid">{"".join(cards)}</div>
</main></body></html>'''


def main(argv: list[str]) -> int:
    month = argv[0] if argv else "2026-10"
    days = build(month)
    tag = month.replace("-", "")
    t = totals(days)
    (ROOT / "research" / f"schedule_{tag}.yaml").write_text(
        yaml.safe_dump({"month": month, "per_day": PER_DAY, "totals": t, "days": days}, allow_unicode=True, sort_keys=False), encoding="utf-8")
    print(f"本編 {t['mains']}本 / ショート {t['shorts']}本 / シリーズ {sum(t['series'].values())}本 / 日本人ニュース {t['japanese_news']}本 / ほか {t['other_news']}本")
    for k, v in t["series"].items():
        print(f"  {v:3}本  {k}")
    out = ROOT / "output" / "pages" / f"schedule_{tag}" / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page(month, days), encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
