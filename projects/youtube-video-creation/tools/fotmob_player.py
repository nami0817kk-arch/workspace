"""FotMob の選手データから、紹介動画の「プレースタイル」の材料と板を作る（2026-09-28）。

    python tools/fotmob_player.py find "Erling Haaland"          # FotMob の番号を探す
    python tools/fotmob_player.py boards 737066 --date 2026-10-01 # レーダー・シュートマップの板を書く

材料（公開ドキュメントの無い内部API。壊れたら例外で止まる。1人1日1回だけ取って控える）:
- `traits`: 同じポジション群と比べたパーセンタイル（6軸）→ **レーダーの板**
- `firstSeasonStats.statsSection`: 今季の数字と 90分あたりのパーセンタイル → **武器3つ・弱点1つ**（機械で選ぶ）
- `firstSeasonStats.shotmap`: 今季のシュート（位置・xG・結果）→ **シュートマップの板**
- `recentMatches`: 直近の試合の評点 → 今季の節の小さな表
- `nextMatch`: 次の試合 → 見立て

板は `assets/stats/` に置き、`statboard._write_mark` の印を付ける（自作の図として review が通す）。
ユーザー「ただの数字の列挙以外の要素も盛り込みたい」（2026-09-28）→ 数字は絵にして、言葉はプレースタイルの説明に使う。
"""

from __future__ import annotations

import argparse
import datetime
import json
import math
import sys
import time
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import standings as standings_mod  # noqa: E402

API = "https://www.fotmob.com/api/data"
CACHE = ROOT / "research" / "player_pool"
BOARD_DIR = ROOT / "assets" / "stats"
HEADERS = {"User-Agent": standings_mod.UA}

TRAIT_JA = {
    "chances_created": "チャンス創出", "aerials_won": "空中戦", "defensive_actions": "守備の関与", "goals": "得点",
    "shot_attempts": "シュート数", "touches": "ボールタッチ", "assists": "アシスト", "passes": "パス", "dribbles": "ドリブル",
    "tackles": "タックル", "interceptions": "インターセプト", "saves": "セーブ", "clean_sheets": "無失点",
    "accurate_passes": "パス成功", "duels_won": "デュエル", "long_balls": "ロングボール", "key_passes": "キーパス",
    "shots_on_target": "枠内シュート", "crosses": "クロス", "blocks": "ブロック", "clearances": "クリア",
}
STAT_JA = {
    "Goals": "得点", "xG": "xG（ゴール期待値）", "xGOT": "xGOT（枠内の質）", "xG excl. penalty": "PK抜きのxG",
    "Shots": "シュート", "Shots on target": "枠内シュート", "Headed shots": "ヘディングシュート",
    "Top Speed": "最高速度", "Total Distance Covered": "走行距離", "Running": "ランニング距離", "Sprinting": "スプリント距離",
    "Number of Sprints": "スプリント回数", "Assists": "アシスト", "xA": "xA（アシスト期待値）", "Accurate passes": "パス成功",
    "Pass accuracy": "パス成功率", "Accurate long balls": "ロングボール成功", "Long ball accuracy": "ロングボール成功率",
    "Line-breaking passes": "ラインを破るパス", "Chances created": "チャンス創出", "Big chances created": "決定機の演出",
    "Dribbles": "ドリブル", "Dribbles success rate": "ドリブル成功率", "Duels won": "デュエル勝ち", "Duels won %": "デュエル勝率",
    "Aerials won": "空中戦勝ち", "Aerials won %": "空中戦勝率", "Touches": "ボールタッチ", "Touches in opposition box": "敵陣ボックス内タッチ",
    "Dispossessed": "ボールロスト", "Fouls won": "被ファウル", "Defensive actions": "守備アクション", "Interceptions": "インターセプト",
    "Fouls committed": "ファウル", "Recoveries": "ボール回収", "Possession won final 3rd": "敵陣でのボール奪取", "Dribbled past": "抜かれた回数",
    "Clearances": "クリア", "Clean sheets": "無失点", "Goals conceded while on pitch": "出場中の失点", "Tackles": "タックル",
    "Blocks": "ブロック", "Yellow cards": "警告", "Red cards": "退場", "Saves": "セーブ", "Save percentage": "セーブ率",
}
# 武器・弱点に使わない項目（数が少なすぎる／意味が薄い）
SKIP_STATS = {"Yellow cards", "Red cards", "Goals conceded while on pitch", "Clean sheets", "Fouls committed",
              "Long ball accuracy", "Dribbled past", "Dispossessed", "xG excl. penalty", "Running", "Total Distance Covered"}
BRAND_GREEN = (11, 61, 46)
BRAND_GOLD = (255, 213, 74)
PITCH_LEN, PITCH_WID = 105.0, 68.0


def find(name: str) -> list[dict]:
    got = requests.get(f"{API}/search/suggest", params={"term": name, "lang": "en"}, headers=HEADERS, timeout=25).json()
    out = []
    for block in got if isinstance(got, list) else []:
        for s in block.get("suggestions") or []:
            if s.get("type") == "player":
                out.append(dict(id=str(s.get("id")), name=s.get("name"), team=s.get("teamName")))
    return out


def load(player_id: str, max_age_hours: float = 24.0) -> dict:
    """選手データ。控えが新しければそれを読む。"""
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"fotmob_{player_id}.json"
    if path.exists() and (time.time() - path.stat().st_mtime) < max_age_hours * 3600:
        return json.loads(path.read_text(encoding="utf-8"))
    got = requests.get(f"{API}/playerData", params={"id": player_id}, headers=HEADERS, timeout=30)
    got.raise_for_status()
    data = got.json()
    if not data.get("name"):
        raise RuntimeError(f"FotMob の選手データが読めません（{player_id}）。作りが変わった可能性があります")
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return data


def traits(data: dict) -> tuple[str, list[tuple[str, float]]]:
    """(比較の相手, [(軸の日本語, 0〜1)])。"""
    t = data.get("traits") or {}
    group = {"stats_comparison_forwards": "同じFW", "stats_comparison_midfielders": "同じMF",
             "stats_comparison_defenders": "同じDF", "stats_comparison_keepers": "同じGK"}.get(str(t.get("key")), "同じポジション")
    items = [(TRAIT_JA.get(str(i.get("key")), str(i.get("title"))), float(i.get("value") or 0.0)) for i in t.get("items") or []]
    return group, items


def season_stats(data: dict) -> list[dict]:
    """今季の項目を平らに。(title, ja, value, per90, percentile)。"""
    out = []
    section = ((data.get("firstSeasonStats") or {}).get("statsSection") or {})
    for group in section.get("items") or []:
        for item in group.get("items") or []:
            title = str(item.get("title") or "")
            out.append(dict(group=str(group.get("title") or ""), title=title, ja=STAT_JA.get(title, title),
                            value=str(item.get("statValue") or ""), per90=item.get("per90"),
                            pct=float(item.get("percentileRankPer90") if item.get("percentileRankPer90") is not None else (item.get("percentileRank") or 0))))
    return out


def strengths(stats: list[dict], top: int = 3) -> tuple[list[dict], list[dict]]:
    """武器（パーセンタイル上位）と弱点（下位）。数の無い項目は外す。"""
    pool = [s for s in stats if s["title"] not in SKIP_STATS and s["value"] not in ("", "0", "0.0")]
    ranked = sorted(pool, key=lambda s: -s["pct"])
    strong = ranked[:top]
    weak_pool = [s for s in stats if s["title"] not in SKIP_STATS and s not in strong]
    weak = sorted(weak_pool, key=lambda s: s["pct"])[:1]
    return strong, weak


def shots(data: dict) -> list[dict]:
    return [s for s in ((data.get("firstSeasonStats") or {}).get("shotmap") or []) if not s.get("isOwnGoal")]


def recent(data: dict, n: int = 5) -> list[list[str]]:
    """直近 n 試合（日付・相手・出場・得点・評点）。出た試合だけ。"""
    rows = []
    for m in data.get("recentMatches") or []:
        if not m.get("playedInMatch"):
            continue
        date = str((m.get("matchDate") or {}).get("utcTime") or "")[:10]
        rating = str((m.get("ratingProps") or {}).get("rating") or "-")
        opp = standings_mod.japanese(str(m.get("opponentTeamName") or ""))
        rows.append([f"{int(date[5:7])}/{int(date[8:10])}" if len(date) == 10 else date, opp,
                     f"{m.get('minutesPlayed') or 0}分", f"{m.get('goals') or 0}G {m.get('assists') or 0}A", rating])
        if len(rows) >= n:
            break
    return rows


def next_match(data: dict) -> dict | None:
    nm = data.get("nextMatch") or {}
    if not nm.get("matchDate"):
        return None
    t = datetime.datetime.fromisoformat(str(nm["matchDate"]).replace("Z", "+00:00")).astimezone(datetime.timezone(datetime.timedelta(hours=9)))
    return dict(when=f"{t.month}月{t.day}日", home=standings_mod.japanese(str(nm.get("homeName") or "")),
                away=standings_mod.japanese(str(nm.get("awayName") or "")), league=str(nm.get("leagueName") or ""))


# ------------------------------------------------------------------ 板
def _font(size: int) -> ImageFont.FreeTypeFont:
    from src.config import load_config

    return ImageFont.truetype(str(load_config().video.font_path()), size)


def _panel(size=(1280, 720)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    from src import statboard

    base = statboard._base("").convert("RGBA")
    return base, ImageDraw.Draw(base)


def radar_board(group: str, items: list[tuple[str, float]], out: Path, name: str) -> Path:
    """6軸のレーダー。値は同じポジション群の中のパーセンタイル（0〜1）。"""
    from src import statboard

    canvas, draw = _panel()
    W, H = canvas.size
    px, py, pw, ph = 80, 40, W - 160, H - 80
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=24, fill=(12, 18, 28, 246), outline=(255, 255, 255, 50), width=2)
    draw.rectangle([px, py + 24, px + 12, py + ph - 24], fill=BRAND_GOLD + (255,))
    draw.text((px + 40, py + 26), f"{name}のプレースタイル", font=_font(40), fill=(255, 255, 255, 255))
    draw.text((px + 40, py + 78), f"{group}と比べた位置（100が最上位）", font=_font(26), fill=(168, 178, 194, 255))
    # 上の軸の文字が見出しと重ならないよう、中心を下げて半径を抑える（実物で重なった）
    cx, cy, r = px + pw // 2 + 40, py + ph // 2 + 70, 180
    n = max(3, len(items))
    angles = [-math.pi / 2 + 2 * math.pi * i / n for i in range(n)]
    for level in (0.25, 0.5, 0.75, 1.0):
        pts = [(cx + r * level * math.cos(a), cy + r * level * math.sin(a)) for a in angles]
        draw.polygon(pts, outline=(255, 255, 255, 60 if level < 1.0 else 120))
    for a in angles:
        draw.line([(cx, cy), (cx + r * math.cos(a), cy + r * math.sin(a))], fill=(255, 255, 255, 50), width=1)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    pts = [(cx + r * max(0.04, v) * math.cos(a), cy + r * max(0.04, v) * math.sin(a)) for (_, v), a in zip(items, angles)]
    ld.polygon(pts, fill=BRAND_GOLD + (90,), outline=BRAND_GOLD + (255,), width=4)
    canvas.alpha_composite(layer)
    draw = ImageDraw.Draw(canvas)
    f_label, f_val = _font(30), _font(26)
    for (label, v), a, (x, y) in zip(items, angles, pts):
        draw.ellipse([x - 7, y - 7, x + 7, y + 7], fill=BRAND_GOLD + (255,))
        lx, ly = cx + (r + 56) * math.cos(a), cy + (r + 56) * math.sin(a)
        text = f"{label} {int(round(v * 100))}"
        tw = draw.textlength(text, font=f_label)
        draw.text((lx - tw / 2, ly - 18), text, font=f_label, fill=(255, 255, 255, 255))
    draw.text((px + 40, py + ph - 56), "FotMob", font=f_val, fill=(120, 130, 146, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    statboard._write_mark(out, f"{name}のプレースタイル", "percentile", [(l, round(v * 100)) for l, v in items], "FotMob")
    return out


def shotmap_board(shot_list: list[dict], out: Path, name: str, season_label: str = "今季") -> Path:
    """今季のシュートを半面のピッチに。得点は黄、枠内は白い輪、外れは灰。大きさは xG。"""
    from src import statboard

    canvas, draw = _panel()
    W, H = canvas.size
    px, py, pw, ph = 80, 40, W - 160, H - 80
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=24, fill=(12, 18, 28, 246), outline=(255, 255, 255, 50), width=2)
    draw.rectangle([px, py + 24, px + 12, py + ph - 24], fill=BRAND_GOLD + (255,))
    goals = [s for s in shot_list if s.get("eventType") == "Goal"]
    xg = sum(float(s.get("expectedGoals") or 0) for s in shot_list)
    draw.text((px + 40, py + 26), f"{name}の{season_label}のシュート", font=_font(40), fill=(255, 255, 255, 255))
    draw.text((px + 40, py + 78), f"シュート{len(shot_list)}本、得点{len(goals)}、xG合計{xg:.1f}", font=_font(26), fill=(168, 178, 194, 255))
    # 敵陣の半面。ゴールが上。横=幅68m、縦=52.5m
    gx, gy, gw, gh = px + 360, py + 130, 560, ph - 190
    draw.rectangle([gx, gy, gx + gw, gy + gh], fill=(28, 96, 60, 255), outline=(230, 230, 230, 255), width=3)

    def X(y_m):  # 幅方向（0〜68）→ 横
        return gx + gw * (y_m / PITCH_WID)

    def Y(x_m):  # 長さ方向（52.5〜105）→ 縦（ゴールが上）
        return gy + gh * (1 - (x_m - PITCH_LEN / 2) / (PITCH_LEN / 2))

    # ペナルティエリア・ゴールエリア・ゴール・センターサークル（半円）
    draw.rectangle([X(34 - 20.16), Y(105), X(34 + 20.16), Y(105 - 16.5)], outline=(230, 230, 230, 255), width=3)
    draw.rectangle([X(34 - 9.16), Y(105), X(34 + 9.16), Y(105 - 5.5)], outline=(230, 230, 230, 255), width=3)
    draw.rectangle([X(34 - 3.66), gy - 12, X(34 + 3.66), gy], fill=(255, 255, 255, 255))
    draw.ellipse([X(34) - 3, Y(94) - 3, X(34) + 3, Y(94) + 3], fill=(230, 230, 230, 255))
    cr = gw * (9.15 / PITCH_WID)
    draw.arc([X(34) - cr, Y(52.5) - cr, X(34) + cr, Y(52.5) + cr], start=180, end=360, fill=(230, 230, 230, 255), width=3)
    for s in sorted(shot_list, key=lambda s: s.get("eventType") == "Goal"):
        x, y = float(s.get("x") or 0), float(s.get("y") or 0)
        if x < PITCH_LEN / 2:
            continue
        rad = 7 + 26 * float(s.get("expectedGoals") or 0) ** 0.5
        cx, cy = X(y), Y(x)
        if s.get("eventType") == "Goal":
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=BRAND_GOLD + (255,), outline=(20, 20, 20, 255), width=2)
        elif s.get("isOnTarget"):
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(255, 255, 255, 60), outline=(255, 255, 255, 255), width=3)
        else:
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(90, 96, 108, 200), outline=(200, 200, 200, 160), width=2)
    # 凡例
    lx, ly = px + 40, py + 150
    f = _font(28)
    for label, style in (("得点", "goal"), ("枠内", "on"), ("外れ・ブロック", "off")):
        if style == "goal":
            draw.ellipse([lx, ly, lx + 26, ly + 26], fill=BRAND_GOLD + (255,))
        elif style == "on":
            draw.ellipse([lx, ly, lx + 26, ly + 26], fill=(255, 255, 255, 60), outline=(255, 255, 255, 255), width=3)
        else:
            draw.ellipse([lx, ly, lx + 26, ly + 26], fill=(90, 96, 108, 200), outline=(200, 200, 200, 160), width=2)
        draw.text((lx + 40, ly - 4), label, font=f, fill=(255, 255, 255, 255))
        ly += 50
    draw.text((lx, ly + 10), "丸の大きさ＝xG", font=f, fill=(168, 178, 194, 255))
    draw.text((px + 40, py + ph - 56), "FotMob", font=_font(26), fill=(120, 130, 146, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    statboard._write_mark(out, f"{name}の{season_label}のシュート", "xG", [("shots", len(shot_list)), ("goals", len(goals)), ("xg", round(xg, 2))], "FotMob")
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("find"); f.add_argument("name")
    b = sub.add_parser("boards"); b.add_argument("player_id"); b.add_argument("--name", default=""); b.add_argument("--date", default=datetime.date.today().isoformat())
    args = ap.parse_args(argv)
    if args.cmd == "find":
        for r in find(args.name):
            print(f"  {r['id']}  {r['name']}（{r['team']}）")
        return 0
    data = load(args.player_id)
    name = args.name or str(data.get("name"))
    stamp = args.date.replace("-", "")
    group, items = traits(data)
    radar = radar_board(group, items, BOARD_DIR / f"player_{stamp}_{args.player_id}_radar.png", name)
    sm = shotmap_board(shots(data), BOARD_DIR / f"player_{stamp}_{args.player_id}_shots.png", name)
    print(f"板 → {radar}\n板 → {sm}")
    strong, weak = strengths(season_stats(data))
    print("武器:", [(s["ja"], s["value"], int(s["pct"])) for s in strong])
    print("弱点:", [(s["ja"], s["value"], int(s["pct"])) for s in weak])
    print("直近:", recent(data))
    print("次戦:", next_match(data))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
