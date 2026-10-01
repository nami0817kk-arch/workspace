"""有名選手の紹介（毎日1人、10月の案21）の取材メモの雛形。2026-09-28。

    python tools/player_intro.py 342229 --date 2026-10-01     # Transfermarkt の番号（player_pool.py list に出る）

材料は Transfermarkt（詳細・市場価値の推移・今季の大会別の数字）と Wikidata の日本語名。
節は「基礎DATA（表）→ 歩んできた道（季ごとの所属と市場価値の表）→ 今季の数字（大会別の表、main）
→ 見立て」。**紹介ものなので他人の声は無くてよい。**顔写真は記事か Commons から人が取る
（`tools/articlephoto.py` → `portrait`）。雛形の `thumbnail.photos` は空で出す。

- 選手名の日本語は `player_pool.py` と同じ（Wikidata → `research/kana/players.json` で上書き）
- クラブ名は `config/clubs.yaml` の日本語（無ければ Transfermarkt の英語のまま。雛形の頭に出る）
- 数字はすべて Transfermarkt のものなので、出典はその選手のページ1本。**成績の節は 報道 で書く**
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_spec = importlib.util.spec_from_file_location("player_pool", ROOT / "tools" / "player_pool.py")
pool_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pool_mod)
ja_mod = pool_mod.ja_mod

TM_URL = "https://www.transfermarkt.jp/{slug}/profil/spieler/{id}"
FOOT_JA = {"right": "右", "left": "左", "both": "両足"}
# 代表の大会など、japan_abroad の一覧に無い大会の番号
COMPETITIONS_EXTRA = {"UNLA": "ネーションズリーグA", "UNLB": "ネーションズリーグB", "WMQE": "W杯予選（欧州）",
                      "EMQ": "ユーロ予選", "USC": "UEFAスーパーカップ", "KLUB": "クラブワールドカップ",
                      "SUC": "スペイン・スーパーカップ", "CDR": "国王杯", "FRC": "フランス・スーパーカップ",
                      "GBCS": "コミュニティ・シールド", "DFL": "DFLスーパーカップ", "ISC": "イタリア・スーパーカップ"}


def competition_ja(comp: str) -> str:
    return ja_mod.COMPETITIONS.get(comp) or COMPETITIONS_EXTRA.get(comp) or comp


def compact_value(value: int) -> str:
    """市場価値を「2億ユーロ」「3500万ユーロ」の形に。"""
    if value >= 100_000_000:
        oku = value / 100_000_000
        return f"{oku:.1f}".rstrip("0").rstrip(".") + "億ユーロ"
    if value >= 10_000:
        return f"{value // 10_000}万ユーロ"
    return f"{value}ユーロ"


def club_ja(club_id: str) -> str:
    return ja_mod.club_ja(ja_mod.club_info(str(club_id)).get("name") or str(club_id))


def career_rows(history: list[dict]) -> list[list[str]]:
    """市場価値の推移から、季ごとの所属を1クラブ1行にまとめる（季・クラブ・年齢・市場価値）。"""
    rows: list[list[str]] = []
    runs: list[dict] = []
    for e in sorted(history, key=lambda x: (int(x.get("seasonId") or 0), str(x.get("marketValue", {}).get("determined") or ""))):
        club = str(e.get("clubId") or "")
        season = int(e.get("seasonId") or 0)
        value = int((e.get("marketValue") or {}).get("value") or 0)
        club_name = club_ja(club)
        if runs and runs[-1]["name"] == club_name:
            runs[-1]["to"] = season
            runs[-1]["peak"] = max(runs[-1]["peak"], value)
            runs[-1]["last"] = value
            runs[-1]["age_to"] = e.get("age")
        else:
            runs.append(dict(club=club, name=club_name, frm=season, to=season, peak=value, last=value,
                             age_from=e.get("age"), age_to=e.get("age")))
    for r in runs:
        seasons = f"{r['frm'] % 100:02d}/{(r['frm'] + 1) % 100:02d}" + (f"〜{r['to'] % 100:02d}/{(r['to'] + 1) % 100:02d}" if r["to"] != r["frm"] else "")
        ages = f"{r['age_from']}歳" + (f"〜{r['age_to']}歳" if r["age_to"] != r["age_from"] else "")
        rows.append([seasons, r["name"], ages, f"最高 {compact_value(r['peak'])}"])
    return rows


def season_rows(performance: list[dict]) -> list[list[str]]:
    """今季の大会別の数字（大会・試合・得点・アシスト・出場時間）。"""
    rows = []
    for p in performance:
        info = p.get("generalInformation") or {}
        st = p.get("statistics") or {}
        goals, play = st.get("goalStatistics") or {}, st.get("playingTimeStatistics") or {}
        comp = info.get("competitionId") or ""
        rows.append([competition_ja(comp), str(play.get("appearancesCount") or 0),
                     str(goals.get("goalsSum") or 0), str(goals.get("assistsSum") or 0), f"{play.get('playedMinutesSum') or 0}分"])
    return rows


def past_rows(player_id: str, seasons: int = 5) -> list[list[str]]:
    """過去の季の数字（季・試合・得点・アシスト）。今季を含めず、直近から seasons 季ぶん。

    尺を出すための節（1分半の紹介では薄い。2026-09-28 見本の1本目で分かった）。
    """
    rows = []
    for season in range(ja_mod.SEASON - 1, ja_mod.SEASON - 1 - seasons, -1):
        data = ja_mod._get(f"/player/{player_id}/performance-season?season={season}")
        agg = data.get("aggregated") or {}
        t = totals(agg)
        if not t["apps"]:
            continue
        rows.append([f"{season % 100:02d}/{(season + 1) % 100:02d}", str(t["apps"]), str(t["goals"]), str(t["assists"]), f"{t['minutes']}分"])
    return rows


def totals(aggregated: dict) -> dict:
    goals, play = aggregated.get("goalStatistics") or {}, aggregated.get("playingTimeStatistics") or {}
    return dict(apps=int(play.get("appearancesCount") or 0), goals=int(goals.get("goalsSum") or 0),
                assists=int(goals.get("assistsSum") or 0), minutes=int(play.get("playedMinutesSum") or 0))


def gather(player_id: str) -> dict:
    data = pool_mod.profile(player_id)
    attrs = data.get("attributes") or {}
    life = data.get("lifeDates") or {}
    current = next((c for c in data.get("clubAssignments") or [] if c.get("type") == "current"), {})
    club = club_ja(current.get("clubId")) if current.get("clubId") else ""
    history = ja_mod._get(f"/player/{player_id}/market-value-history").get("history") or []
    season = ja_mod._get(f"/player/{player_id}/performance-season?season={ja_mod.SEASON}")
    labels = pool_mod.japanese_names([player_id])
    name_ja = pool_mod.overrides().get(data.get("name", "")) or labels.get(player_id, "")
    return dict(
        id=player_id, name=str(data.get("name") or ""), ja=name_ja, club=club, club_id=str(current.get("clubId") or ""),
        shirt=current.get("shirtNumber"), captain=bool(current.get("isCaptain")),
        age=life.get("age"), birth=life.get("dateOfBirth"), height=attrs.get("height"),
        foot=FOOT_JA.get((attrs.get("preferredFoot") or {}).get("name", ""), ""),
        position=pool_mod.POSITION_JA.get((attrs.get("position") or {}).get("name", ""), (attrs.get("position") or {}).get("name", "")),
        contract=attrs.get("contractUntil"), value=int(((data.get("marketValueDetails") or {}).get("current") or {}).get("value") or 0),
        value_prev=int(((data.get("marketValueDetails") or {}).get("previous") or {}).get("value") or 0),
        history=history, season=season.get("performance") or [], aggregated=season.get("aggregated") or {},
        past=past_rows(player_id),
        url=str(data.get("relativeUrl") or ""),
    )


def next_player(day: datetime.date) -> str:
    """翌日の人（research/players_202610.yaml）。締めのカード「明日は②…」に使う。"""
    try:
        book = yaml.safe_load((ROOT / "research" / "players_202610.yaml").read_text(encoding="utf-8")) or {}
    except OSError:
        return ""
    target = (day + datetime.timedelta(days=1)).isoformat()
    for r in book.get("players") or []:
        if r.get("date") == target:
            head = str(r.get("head", "")).split("（")[0]
            return f"明日は{_circled(int(r.get('num', 0)))}{head}"
    return ""


# **型の定型文は本ごとに言い換える**（品質100回の88）。①②③を並べたら同じ文が12か所あり、
# 審査が対象外にする「続けて数本視聴した後、繰り返しのように感じられる」の芽だった。
# 雛形は選手の番号で言い回しを回す。人が書き換えてよい
TEMPLATES = {
    "style": ["{short}のプレースタイルを、{group}と比べた数字で見ます。",
              "{group}の中で、{short}はどこが尖っているか。レーダーで見ます。",
              "{short}のプレースタイルは、{group}との比較で見ると分かりやすい。レーダーです。",
              "{short}の武器と弱点を、{group}と並べた数字で。"],
    "past": ["{short}の直近5シーズン、代表を含む全公式戦です。古い順に見ます。",
             "5シーズン前まで戻ります。{short}の、代表を含む全公式戦の数字です。",
             "次に、{short}の5シーズンの推移。代表を含む全公式戦を、古いほうから追います。",
             "{short}の5年を数字で。代表を含む全公式戦、古い季から並べます。"],
    "story": ["数字の外側に、この選手らしい話が2つあります。",
              "ここからは数字を離れて、{short}らしい話を2つ。",
              "数字を置いて、人となりの話を2つ。",
              "表に出ない{short}の話を、2つだけ。"],
    "view": ["話を数字に戻して、最後に見立てです。",
             "最後に、数字でこの先を見ます。",
             "締めは、この先の見立てです。",
             "終わりに、これからの{short}を数字で見立てます。"],
    "pace": ["{m}分に1点のペースです。", "{m}分に1点。", "1点あたり{m}分です。", "計算すると{m}分に1点。"],
    "value_up": ["前回の{before}から、さらに上がりました。", "この夏、{before}から上がりました。",
                 "{before}から、また上がりました。", "前回は{before}でした。"],
    "body": ["身長は{h}、利き足は{foot}。{contract}", "身長は{h}。{foot}利きで、{contract}", "{foot}利き、身長{h}。{contract}"],
    "contract": ["契約は{y}年まで残っています。", "契約は{y}年まで。", "{y}年まで契約があります。"],
}


def phrase(key: str, seed: int, **kw) -> str:
    """定型文を選手ごとに回す。同じ選手はいつも同じ言い回し（作り直しても変わらない）。"""
    options = TEMPLATES[key]
    return options[seed % len(options)].format(**kw)


def _circled(n: int) -> str:
    return chr(0x2460 + n - 1) if 1 <= n <= 20 else f"{n}."


def fotmob_bundle(p: dict, day: datetime.date) -> dict:
    """FotMob の材料（レーダー・シュートマップ・ヒートマップ・折れ線の板、武器と弱点、直近5試合、次戦）。"""
    import importlib.util as _iu

    spec = _iu.spec_from_file_location("fotmob_player", ROOT / "tools" / "fotmob_player.py")
    fm = _iu.module_from_spec(spec); spec.loader.exec_module(fm)
    found = fm.find(p["name"])
    if not found:
        return {}
    fid = found[0]["id"]
    data = fm.load(fid)
    name = p["ja"] or p["name"]
    stamp = day.strftime("%Y%m%d")
    board_dir = fm.BOARD_DIR
    group, items = fm.traits(data)
    boards = dict(
        radar=fm.radar_board(group, items, board_dir / f"player_{stamp}_{fid}_radar.png", name),
        shots=fm.shotmap_board(fm.shots(data), board_dir / f"player_{stamp}_{fid}_shots.png", name),
        heat=fm.heatmap_board(fm.heat(data), board_dir / f"player_{stamp}_{fid}_heat.png", name),
        value=fm.value_board(p["history"], board_dir / f"player_{stamp}_{fid}_value.png", name, club_of=club_ja),
    )
    for b in boards.values():
        fm.portrait_variant(b)
    strong, weak = fm.strengths(fm.season_stats(data))
    return dict(fotmob_id=fid, group=group, traits=items, boards={k: str(v.relative_to(ROOT)).replace("\\", "/") for k, v in boards.items()},
                strong=strong, weak=weak, recent=fm.recent(data, 5), next=fm.next_match(data))


def write_note(p: dict, day: datetime.date, path: Path, fb: dict | None = None) -> list[str]:
    """8節の雛形（2026-09-28 夜、ハーランドで組んだ型）。返すのは英語のまま残った名前。

    フック → 基礎DATA → 歩んできた道と転機 → プレースタイル → 過去5シーズン → 今季と直近5試合 → マル秘話 → 見立て。
    数字の行は埋めてある。**（…）の行は人が書く**（材料は research/raw/<日付>_<選手>_material.md に下請けが集める）。
    写真は時期ごとに `image:` を置く（縦写真は表のある節なら可、表の無い節は tools/widecrop.py で16:9に）。
    """
    fb = fb or {}
    name = p["ja"] or p["name"]
    short = name.split("・")[-1] if "・" in name else name
    url = "https://www.transfermarkt.com" + p["url"] if p["url"].startswith("/") else "https://www.transfermarkt.com/"
    fm_url = f"https://www.fotmob.com/players/{fb['fotmob_id']}" if fb.get("fotmob_id") else "https://www.fotmob.com/"
    tot = totals(p["aggregated"])
    birth = p["birth"] or ""
    birth_ja = f"{birth[:4]}年{int(birth[5:7])}月{int(birth[8:10])}日" if len(birth) == 10 else birth
    data_rows = [["所属", p["club"] + (f"（{p['shirt']}番）" if p["shirt"] else "")],
                 ["ポジション", p["position"]],
                 ["生年月日", f"{birth_ja}（{p['age']}歳）"],
                 ["身長", f"{p['height']}m" if p["height"] else ""],
                 ["利き足", p["foot"]],
                 ["契約", f"{p['contract'][:4]}年まで" if p["contract"] else ""],
                 ["市場価値", compact_value(p["value"])]]
    data_rows = [r for r in data_rows if r[1]]
    career = career_rows(p["history"])
    season = season_rows(p["season"])
    # 言い回しを回す種。選手の番号（無ければ名前）で決めるので、作り直しても同じ選手は同じ文になる
    seed = sum(ord(c) for c in str(p.get("id") or p.get("name") or ""))
    value_before = compact_value(p["value_prev"]) if p["value_prev"] and p["value"] > p["value_prev"] else ""
    boards = fb.get("boards") or {}
    strong, weak = fb.get("strong") or [], fb.get("weak") or []
    past = p.get("past") or []
    nxt = fb.get("next") or {}

    def line(text, **extra):
        return {"text": text, **extra} if extra else text

    sections = [
        {"id": "hook", "heading": "どんな選手か", "tier": "報道", "telop": "（一言の定義。例：ボールに触らないのに、点だけ取る）", "narrator": "キャスター",
         "say": [f"（{name}を一言で定義する1行。数字か意外な事実を1つ）",
                 "（同じポジションの中でどこが最上位・最下位かを、100人の中の何番目、の言い方で）",
                 "（幼少期の逸話を1つ）",
                 {"voice": short, "text": "（本人の言葉を1つ。声は16秒までに。記事の訳をそのまま）", "pause": 0.5}],
         "sources": [fm_url]},
        {"id": "data", "heading": "基礎DATA", "tier": "報道", "telop": f"{name}の基礎DATA", "narrator": "キャスター",
         "card": {"type": "table", "title": f"{name}（{p['club']}）", "columns": ["項目", "内容"], "rows": data_rows, "source": "Transfermarkt"},
         "say": [f"{name}、{p['age']}歳。{p['club']}の{p['position']}です。",
                 "（生まれた場所と家族の話を1行。出典つき）"]
                + ([phrase("body", seed, h=_meters(p['height']), foot=p['foot'],
                           contract=(phrase("contract", seed, y=p['contract'][:4]) if p["contract"] else ""))] if p["height"] and p["foot"] else [])
                + ([f"市場価値は{compact_value(p['value'])}。" + (phrase("value_up", seed, before=value_before) if value_before else "")] if p["value"] else []),
         "sources": [url]},
        {"id": "career", "heading": "歩んできた道と転機", "tier": "報道", "telop": "（どこで値が跳ねたかを一言で）", "narrator": "解説",
         "card": {"type": "table", "title": "歩んできた道", "columns": ["シーズン", "クラブ", "年齢", "市場価値"], "rows": career[-6:], "source": "Transfermarkt"},
         "say": [f"{short}の{career[0][2].split('〜')[0] if career else ''}は{career[0][1] if career else ''}。市場価値は{career[0][3].replace('最高 ', '') if career else ''}でした。"]
                + ([line("（2つ目のクラブと年齢・市場価値を1行）", image=boards["value"], no_telop=True)] if boards.get("value") else ["（2つ目のクラブと年齢・市場価値を1行）"])
                + ["（転機を1つ：入団拒否・大怪我・大舞台での一撃、など。日付と相手を入れる。出典つき）",
                   "（いまのクラブまでの道を1〜2行。「そしていまの額に」で締める）"],
         "sources": [url]},
        {"id": "style", "heading": "プレースタイル", "tier": "報道", "telop": "（左足・ボックスの中・ボールは持たない、のような3語）", "narrator": "解説",
         **({"card": {"type": "bars", "title": f"{fb.get('group', '同じポジション')}の中での位置（100が最上位）", "unit": "",
                      "items": [{"label": s_["ja"], "value": int(s_["pct"]), "highlight": i == 0} for i, s_ in enumerate(strong)]
                               + [{"label": w["ja"], "value": int(w["pct"])} for w in weak], "source": "FotMob"}} if strong else {}),
         "say": ([line(phrase("style", seed, short=short, group=fb.get('group', '同じポジション')), image=boards["radar"], no_telop=True)] if boards.get("radar") else [phrase("style", seed, short=short, group="同じポジション")])
                + ["（6つの軸のうち最上位と最下位を言う）",
                   "（つまりどういう選手か、を1行で）",
                   "（弱点を1つ。数字で）"]
                + ([line("（では、その強みはどこから来るか。動きの話を1〜2行。出典つき）", image=boards["heat"], no_telop=True)] if boards.get("heat") else ["（では、その強みはどこから来るか。動きの話を1〜2行。出典つき）"])
                + ([line("（今季のシュートの傾向を1行：本数・ペナルティエリアの中の割合）", image=boards["shots"], no_telop=True)] if boards.get("shots") else [])
                + ["（体の数字：身長・最高速度など1行）"],
         "sources": [fm_url]},
        {"id": "past", "heading": "過去5シーズンの数字", "tier": "報道", "telop": "直近5シーズンの試合と得点", "narrator": "解説",
         "card": {"type": "table", "title": f"{name} 直近5シーズン（代表を含む全公式戦）", "columns": ["シーズン", "試合", "得点", "アシスト", "出場時間"],
                  "rows": list(reversed(past)), "source": "Transfermarkt"},
         "say": [phrase("past", seed, short=short)]
                + ([f"{_season_ja(past[-1][0])}は{past[-1][1]}試合で{past[-1][2]}点。"] if past else [])
                + ["（いちばん多かったシーズンと、その意味を1行。記録があれば出典つきで）",
                   "そのあとのシーズンも表のとおり。（傾向を1行）"],
         "sources": [url]},
        {"id": "season", "heading": "今季の数字と直近5試合", "tier": "報道", "main": True, "telop": "今季ここまで", "narrator": "解説",
         "card": {"type": "table", "title": "直近5試合（代表を含む）", "columns": ["日付", "相手", "出場", "得点", "評点"],
                  "rows": fb.get("recent") or [], "source": "FotMob"},
         "say": [{"text": f"（前置き1行：{short}はどういう選手か＋題の答えを一言で。ショートはここから）", "short_only": True},
                 f"今季はここまで{tot['apps']}試合で{tot['goals']}得点{tot['assists']}アシスト、出場時間は{tot['minutes']}分。"
                 + (phrase("pace", seed, m=tot['minutes'] // tot['goals']) if tot["goals"] and tot["minutes"] else "")]
                + [f"{r[0]}は{r[1]}試合で{r[2]}得点{r[3]}アシスト。" for r in season[:2]]
                + ["（直近5試合の表から1行：出場時間・得点・10点満点の評点）",
                   "（題の答えを1行。ショートはこの節だけで完結させる）"],
         "sources": [url, fm_url]},
        {"id": "story", "heading": "マル秘話", "tier": "報道", "telop": "（エピソードを一言で）", "narrator": "解説",
         "say": [phrase("story", seed, short=short),
                 "（1つ目：食事・家族・背番号の由来・憧れの選手など。出典つき）",
                 {"voice": short, "text": "（本人の言葉。記事の訳をそのまま。30字で割る。最後の行に pause: 0.6）"},
                 "（2つ目のエピソード）",
                 {"text": "（締めの1行）", "pause": 0.5}],
         "sources": ["（記事のURL）"]},
        {"id": "view", "heading": "（何についての見立てか。例：エムバペとの今季の差）", "tier": "背景", "viewpoint": True, "narrator": "解説",
         "telop": (f"{nxt['when']}、{nxt['home']}対{nxt['away']}" if nxt else "次の試合で見るところ"),
         "say": [phrase("view", seed, short=short),
                 "（同じポジションの選手1人と比べる数字を1つ）",
                 "（数字が落ちていないか・伸びているか。1行）"]
                + ([f"クラブの次の試合は{nxt['when']}、{nxt['home']}対{nxt['away']}。", "（そこで何を見るか）"] if nxt else ["（次の試合で何を見るか）"]),
         "sources": [url, fm_url]},
    ]
    watch = next_player(day)
    note = {
        "date": day.strftime("%Y年%m月%d日"),
        "slot": "other_1",
        "format": "news",
        "series": "有名選手の紹介",
        "people": [name],
        "theme": {
            "id": f"player_{p['id']}", "league": next((r["league"] for r in _pool_rows() if r["id"] == p["id"]), "england"),
            "kind": "other", "topic": p["club"],
            "title": f"{short}ってどんな選手？（答えを伏せた言い換えを足す。例：ボールに触らないのに点だけ取る理由）",
            "question": f"{name}はどういう作りの選手で、なぜ数字が出るのか",
            "takeaway": "（数字で分かったことを1文で）",
            "nameplate": f"{name}｜{p['club']} {_pos_short(p['position'])}",
            "bgm": "assets/audio/bgm_calm.wav",
        },
        **({"watch": watch} if watch else {}),
        "short_title": f"{short}ってどんな選手？",
        "thumbnail": {"line1": short, "line2": "（いちばん強い事実を伏せる。例：ボールに触らないのに●●）",
                      "tags": [p["club"], "選手紹介", "プレースタイル"],  # 札（note_red）は付けない（2026-10-01 ユーザー「サムネの選手紹介は無くして」）
                      "photo": "（横長の顔写真1枚。縦なら tools/widecrop.py）", "photos": []},
        "sections": sections,
    }
    unknown = [n for n in [p["name"] if not p["ja"] else ""] + [r[1] for r in career if r[1].isascii()] if n]
    head = [f"# {name}（{p['club']}）の紹介。8節の型。数字は Transfermarkt（{url}）と FotMob（{fm_url}）。",
            "# （…）の行は人が書く。材料は research/raw/<日付>_<選手>_material.md に下請けが出典つきで集める（docs/player_material_prompt.md）。",
            "# 写真は時期ごとに image: を置く（同じ選手を横に並べない。表の無い節は横長に切る）。スタジアムの写真は使わない。",
            "# 身長・利き足は Transfermarkt の値。クラブ公式と食い違えば公式に直す（ヤマルは TM 1.83m／公式 178cm だった）。"]
    if strong:
        head.append("# 武器（同じポジション比のパーセンタイル）: " + "、".join(f"{s_['ja']} {int(s_['pct'])}" for s_ in strong)
                    + " ／ 弱点: " + "、".join(f"{w['ja']} {int(w['pct'])}" for w in weak))
    if unknown:
        head.append("# 日本語にする（辞書に無い名前）: " + "、".join(dict.fromkeys(unknown)))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(head) + "\n" + yaml.safe_dump(note, allow_unicode=True, sort_keys=False, width=100),
                    encoding="utf-8")
    return unknown


def _meters(height) -> str:
    try:
        cm = int(round(float(height) * 100))
        return f"{cm // 100}メートル{cm % 100:02d}"
    except (TypeError, ValueError):
        return str(height)


def _season_ja(label: str) -> str:
    """'21/22' → '2021年からのシーズン'（合成音声は 21/22 を「にじゅうに、にじゅうさん」と読む）。"""
    try:
        return f"20{label.split('/')[0]}年からのシーズン"
    except (AttributeError, IndexError):
        return label


def _pos_short(position: str) -> str:
    table = {"GK": "GK", "センターバック": "DF", "左サイドバック": "DF", "右サイドバック": "DF", "守備的MF": "MF", "セントラルMF": "MF",
             "攻撃的MF": "MF", "左MF": "MF", "右MF": "MF", "左ウイング": "FW", "右ウイング": "FW", "センターフォワード": "FW", "セカンドストライカー": "FW"}
    return table.get(position, position)


def _pool_rows() -> list[dict]:
    import json

    try:
        return json.loads(pool_mod.POOL.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("player_id")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    args = ap.parse_args(argv)
    day = datetime.date.fromisoformat(args.date)
    p = gather(args.player_id)
    fb = fotmob_bundle(p, day)
    path = ROOT / "research" / f"{day.strftime('%Y%m%d')}_player_{args.player_id}.yaml"
    unknown = write_note(p, day, path, fb)
    for k, v in (fb.get("boards") or {}).items():
        print(f"  板 {k}: {v}")
    print(f"取材メモ → {path}")
    print(f"  {p['ja'] or p['name']}（{p['club']}／{p['position']}／{p['age']}歳／{compact_value(p['value'])}）")
    for r in career_rows(p["history"]):
        print("   ", "  ".join(r))
    if unknown:
        print("日本語にする: " + "、".join(dict.fromkeys(unknown)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
