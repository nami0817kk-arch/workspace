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
import os
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
              "Long ball accuracy", "Dribbled past", "Dispossessed", "xG excl. penalty", "Running", "Total Distance Covered",
              "Penalties awarded", "Penalties conceded"}   # 武器にならない項目（オリーズで「Penalties awarded 100」が武器に出た）
BRAND_GREEN = (11, 61, 46)
BRAND_GOLD = (255, 213, 74)
# 代表の相手（FotMob は英語）。直近5試合の表に出る
COUNTRY_JA = {"Portugal": "ポルトガル", "Denmark": "デンマーク", "Norway": "ノルウェー", "Italy": "イタリア", "Slovenia": "スロベニア",
              "Spain": "スペイン", "France": "フランス", "Germany": "ドイツ", "England": "イングランド", "Netherlands": "オランダ",
              "Belgium": "ベルギー", "Croatia": "クロアチア", "Brazil": "ブラジル", "Argentina": "アルゼンチン", "Austria": "オーストリア",
              "Switzerland": "スイス", "Poland": "ポーランド", "Scotland": "スコットランド", "Wales": "ウェールズ", "Ireland": "アイルランド",
              "Sweden": "スウェーデン", "Finland": "フィンランド", "Iceland": "アイスランド", "Turkey": "トルコ", "Turkiye": "トルコ", "Türkiye": "トルコ", "Greece": "ギリシャ",
              "Serbia": "セルビア", "Ukraine": "ウクライナ", "Czech Republic": "チェコ", "Hungary": "ハンガリー", "Romania": "ルーマニア",
              "Japan": "日本", "Morocco": "モロッコ", "Senegal": "セネガル", "USA": "アメリカ", "Mexico": "メキシコ", "Uruguay": "ウルグアイ",
              "Colombia": "コロンビア", "Israel": "イスラエル", "Kosovo": "コソボ", "Albania": "アルバニア", "Georgia": "ジョージア",
              "Slovakia": "スロバキア", "Bosnia-Herzegovina": "ボスニア・ヘルツェゴビナ", "Northern Ireland": "北アイルランド"}
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
    group = {"stats_comparison_forwards": "同じFW", "stats_comparison_midfielders": "同じMF", "stats_comparison_att_mid_wingers": "同じ攻撃的MF・ウイング",
             "stats_comparison_defenders": "同じDF", "stats_comparison_keepers": "同じGK", "stats_comparison_fullbacks": "同じサイドバック",
             "stats_comparison_centre_backs": "同じセンターバック"}.get(str(t.get("key")), "同じポジション")
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
        opp = COUNTRY_JA.get(str(m.get("opponentTeamName") or ""), standings_mod.japanese(str(m.get("opponentTeamName") or "")))
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
    cx, cy, r = px + pw // 2 + 40, py + ph // 2 + 34, 172
    n = max(3, len(items))
    angles = [-math.pi / 2 + 2 * math.pi * i / n for i in range(n)]
    # 網目：5段。段ごとに薄い塗りを交互に入れて奥行きを出す（2026-09-28「図のクオリティを上げて」）
    web = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    wd = ImageDraw.Draw(web)
    for k in range(5, 0, -1):
        level = k / 5
        pts = [(cx + r * level * math.cos(a), cy + r * level * math.sin(a)) for a in angles]
        wd.polygon(pts, fill=(255, 255, 255, 14 if k % 2 else 4), outline=(255, 255, 255, 70 if k < 5 else 150), width=2 if k < 5 else 3)
    for a in angles:
        wd.line([(cx, cy), (cx + r * math.cos(a), cy + r * math.sin(a))], fill=(255, 255, 255, 60), width=2)
    f_tick = _font(20)
    for k in (2, 4):
        wd.text((cx + 8, cy - r * k / 5 - 12), str(k * 20), font=f_tick, fill=(160, 170, 186, 200))
    canvas.alpha_composite(web)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    pts = [(cx + r * max(0.04, v) * math.cos(a), cy + r * max(0.04, v) * math.sin(a)) for (_, v), a in zip(items, angles)]
    ld.polygon(pts, fill=BRAND_GOLD + (120,), outline=BRAND_GOLD + (255,), width=6)
    canvas.alpha_composite(layer)
    draw = ImageDraw.Draw(canvas)
    f_label, f_val = _font(30), _font(28)
    for (label, v), a, (x, y) in zip(items, angles, pts):
        draw.ellipse([x - 9, y - 9, x + 9, y + 9], fill=BRAND_GOLD + (255,), outline=(20, 24, 32, 255), width=2)
        lx, ly = cx + (r + 62) * math.cos(a), cy + (r + 62) * math.sin(a)
        # 軸の名前（白）＋ 値の札（黄の丸い札に濃い字）
        value = f"{int(round(v * 100))}"
        tw, vw = draw.textlength(label, font=f_label), draw.textlength(value, font=f_val)
        total = tw + 14 + vw + 28
        x0 = lx - total / 2
        draw.text((x0, ly - 18), label, font=f_label, fill=(255, 255, 255, 255))
        chip = [x0 + tw + 14, ly - 20, x0 + tw + 14 + vw + 28, ly + 20]
        draw.rounded_rectangle(chip, radius=20, fill=BRAND_GOLD + (255,))
        draw.text((chip[0] + 14, ly - 17), value, font=f_val, fill=(16, 18, 24, 255))
    draw.text((px + pw - 130, py + ph - 50), "FotMob", font=f_val, fill=(120, 130, 146, 255))
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
    draw.text((px + 40, py + 78), "丸の位置＝どこから蹴ったか、大きさ＝xG（決まりやすさ）", font=_font(26), fill=(168, 178, 194, 255))
    # 左に大きな数字の札（シュート・得点・xG）
    f_big, f_small = _font(56), _font(24)
    ty = py + 130
    rate = f"{100 * len(goals) / len(shot_list):.0f}%" if shot_list else "-"
    for label, value in (("シュート", f"{len(shot_list)}"), ("得点", f"{len(goals)}"), ("xG合計", f"{xg:.1f}"), ("決定率", rate)):
        draw.rounded_rectangle([px + 40, ty, px + 300, ty + 84], radius=16, fill=(30, 36, 48, 255))
        draw.text((px + 60, ty + 8), label, font=f_small, fill=(168, 178, 194, 255))
        vw = draw.textlength(value, font=f_big)
        draw.text((px + 280 - vw, ty + 22), value, font=f_big, fill=BRAND_GOLD + (255,))
        ty += 96
    # 敵陣の半面。ゴールが上。横=幅68m、縦=52.5m。芝は縞にする
    gx, gy, gw, gh = px + 360, py + 130, 560, ph - 190
    stripe = gh // 8
    for i in range(8):
        draw.rectangle([gx, gy + i * stripe, gx + gw, gy + (i + 1) * stripe], fill=(30, 104, 64, 255) if i % 2 else (26, 92, 56, 255))
    draw.rectangle([gx, gy, gx + gw, gy + gh], outline=(230, 230, 230, 255), width=3)

    def X(y_m):  # 幅方向（0〜68）→ 横
        return gx + gw * (y_m / PITCH_WID)

    def Y(x_m):  # 長さ方向（52.5〜105）→ 縦（ゴールが上）
        return gy + gh * (1 - (x_m - PITCH_LEN / 2) / (PITCH_LEN / 2))

    # ペナルティエリア・ゴールエリア・ゴール・センターサークル（半円）
    draw.rectangle([X(34 - 20.16), Y(105), X(34 + 20.16), Y(105 - 16.5)], outline=(230, 230, 230, 255), width=3)
    draw.rectangle([X(34 - 9.16), Y(105), X(34 + 9.16), Y(105 - 5.5)], outline=(230, 230, 230, 255), width=3)
    # ゴール枠（網の点も置く）
    draw.rectangle([X(34 - 3.66), gy - 16, X(34 + 3.66), gy], fill=(245, 245, 245, 255))
    for i in range(int(X(34 - 3.66)) + 6, int(X(34 + 3.66)) - 4, 8):
        draw.line([(i, gy - 14), (i, gy - 2)], fill=(180, 180, 180, 255), width=1)
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
            # 得点はやわらかい光を敷いてから
            glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            gd = ImageDraw.Draw(glow)
            gd.ellipse([cx - rad * 1.9, cy - rad * 1.9, cx + rad * 1.9, cy + rad * 1.9], fill=BRAND_GOLD + (70,))
            canvas.alpha_composite(glow)
            draw = ImageDraw.Draw(canvas)
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=BRAND_GOLD + (255,), outline=(20, 20, 20, 255), width=2)
        elif s.get("isOnTarget"):
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(255, 255, 255, 60), outline=(255, 255, 255, 255), width=3)
        else:
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(90, 96, 108, 200), outline=(200, 200, 200, 160), width=2)
    # 凡例（数字の札の下）
    lx, ly = px + 40, py + 520
    f = _font(28)
    f = _font(24)
    for label, style in (("得点", "goal"), ("枠内", "on"), ("外れ・ブロック", "off")):
        if style == "goal":
            draw.ellipse([lx, ly, lx + 26, ly + 26], fill=BRAND_GOLD + (255,))
        elif style == "on":
            draw.ellipse([lx, ly, lx + 26, ly + 26], fill=(255, 255, 255, 60), outline=(255, 255, 255, 255), width=3)
        else:
            draw.ellipse([lx, ly, lx + 26, ly + 26], fill=(90, 96, 108, 200), outline=(200, 200, 200, 160), width=2)
        draw.text((lx + 40, ly - 2), label, font=f, fill=(255, 255, 255, 255))
        ly += 38
    draw.text((px + pw - 130, py + ph - 50), "FotMob", font=_font(26), fill=(120, 130, 146, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    statboard._write_mark(out, f"{name}の{season_label}のシュート", "xG", [("shots", len(shot_list)), ("goals", len(goals)), ("xg", round(xg, 2))], "FotMob")
    return out


def _panel_at(size: tuple[int, int]):
    """板の下地（横 1280x720 / 縦 1080x1920 どちらも）。縦はピッチの絵を敷かず暗い地にする。"""
    if size[0] < size[1]:
        canvas = Image.new("RGBA", size, (14, 20, 30, 255))
        return canvas, ImageDraw.Draw(canvas)
    return _panel(size)


def value_board(history: list[dict], out: Path, name: str, club_of=None, size: tuple[int, int] = (1280, 720)) -> Path:
    """市場価値の推移の折れ線（Transfermarkt の履歴から）。転機がどこかを目で追える。"""
    from src import statboard

    canvas, draw = _panel_at(size)
    W, H = canvas.size
    px, py, pw, ph = 80, 40, W - 160, H - 80
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=24, fill=(12, 18, 28, 246), outline=(255, 255, 255, 50), width=2)
    draw.rectangle([px, py + 24, px + 12, py + ph - 24], fill=BRAND_GOLD + (255,))
    draw.text((px + 40, py + 26), f"{name}の市場価値の推移", font=_font(40), fill=(255, 255, 255, 255))
    pts = sorted(((str((e.get("marketValue") or {}).get("determined") or ""), int((e.get("marketValue") or {}).get("value") or 0), str(e.get("clubId") or ""))
                  for e in history if (e.get("marketValue") or {}).get("determined")), key=lambda x: x[0])
    if len(pts) < 2:
        draw.text((px + 40, py + 100), "推移の記録がありません", font=_font(30), fill=(168, 178, 194, 255))
    else:
        top = max(v for _, v, _ in pts) or 1
        gx, gy, gw, gh = px + 150, py + 110, pw - 230, ph - 220
        # 横軸は年、縦軸は最大値を4分割
        years = sorted({d[:4] for d, _, _ in pts})
        y0, y1 = int(years[0]), int(years[-1])
        # 横軸は最後の年の終わり（翌年の頭）まで取る。y1 の1月で切ると、その年の7月の点が
        # 枠の外へはみ出した（2026-09-30 ヤマルの板で 2026-07 の 2.2億が右の芝まで出ていた）
        span = max(1, y1 + 1 - y0)
        f_axis = _font(24)
        for k in range(5):
            yy = gy + gh - gh * k / 4
            draw.line([(gx, yy), (gx + gw, yy)], fill=(255, 255, 255, 30), width=1)
            label = _compact(top * k / 4)
            draw.text((gx - 12 - draw.textlength(label, font=f_axis), yy - 14), label, font=f_axis, fill=(168, 178, 194, 255))
        for year in range(y0, y1 + 2):
            xx = gx + gw * (year - y0) / span
            draw.line([(xx, gy), (xx, gy + gh)], fill=(255, 255, 255, 18), width=1)
            if year <= y1 and ((year - y0) % max(1, span // 6) == 0 or year == y1):
                draw.text((xx - 24, gy + gh + 10), str(year), font=f_axis, fill=(168, 178, 194, 255))

        def P(d, v):
            year = int(d[:4]) + (int(d[5:7]) - 1) / 12
            return gx + gw * (year - y0) / span, gy + gh - gh * v / top

        line = [P(d, v) for d, v, _ in pts]
        # 塗り（折れ線の下）
        fill_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(fill_layer).polygon(line + [(line[-1][0], gy + gh), (line[0][0], gy + gh)], fill=BRAND_GOLD + (50,))
        canvas.alpha_composite(fill_layer)
        draw = ImageDraw.Draw(canvas)
        draw.line(line, fill=BRAND_GOLD + (255,), width=6, joint="curve")
        # クラブが替わったところに縦の点線と名前
        last_club = None
        last_label_x = -999
        row = 0
        for (d, v, club), (x, y) in zip(pts, line):
            if club != last_club and last_club is not None and club_of:
                for yy in range(int(gy), int(gy + gh), 14):
                    draw.line([(x, yy), (x, yy + 7)], fill=(255, 255, 255, 120), width=2)
                # 近い札は段をずらして重ねない
                row = (row + 1) % 3 if x - last_label_x < 150 else 0
                draw.text((x + 8, gy + 4 + row * 30), club_of(club), font=_font(24), fill=(230, 234, 240, 255))
                last_label_x = x
            last_club = club
        x, y = line[-1]
        draw.ellipse([x - 10, y - 10, x + 10, y + 10], fill=BRAND_GOLD + (255,), outline=(20, 24, 32, 255), width=2)
        label = _compact(pts[-1][1])
        lw = draw.textlength(label, font=_font(32))
        draw.text((min(x - lw - 14, gx + gw - lw), max(gy - 44, y - 50)), label, font=_font(32), fill=BRAND_GOLD + (255,))
    draw.text((px + pw - 210, py + ph - 50), "Transfermarkt", font=_font(26), fill=(120, 130, 146, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    statboard._write_mark(out, f"{name}の市場価値の推移", "EUR", [(d, v) for d, v, _ in pts[-6:]], "Transfermarkt")
    return out


def _compact(value: float) -> str:
    if value >= 100_000_000:
        return f"{value / 100_000_000:.1f}".rstrip("0").rstrip(".") + "億€"
    if value >= 10_000:
        return f"{int(value // 10_000)}万€"
    return f"{int(value)}€"


def heatmap_board(coords: list[dict], out: Path, name: str, size: tuple[int, int] = (1280, 720)) -> Path:
    """今季のヒートマップ（どこにいたか）。全面のピッチに点を重ねて色を濃くする。"""
    from PIL import ImageFilter
    from src import statboard

    canvas, draw = _panel_at(size)
    W, H = canvas.size
    px, py, pw, ph = 80, 40, W - 160, H - 80
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=24, fill=(12, 18, 28, 246), outline=(255, 255, 255, 50), width=2)
    draw.rectangle([px, py + 24, px + 12, py + ph - 24], fill=BRAND_GOLD + (255,))
    draw.text((px + 40, py + 26), f"{name}の今季のヒートマップ", font=_font(40), fill=(255, 255, 255, 255))
    draw.text((px + 40, py + 78), "ボールに触った場所。色が濃いほど多い（攻める向きは右）", font=_font(26), fill=(168, 178, 194, 255))
    gx, gy = px + 60, py + 130
    gw = pw - 120
    gh = int(gw * PITCH_WID / PITCH_LEN)
    if gy + gh > py + ph - 40:
        gh = py + ph - 40 - gy
        gw = int(gh * PITCH_LEN / PITCH_WID)
        gx = px + (pw - gw) // 2
    stripe = gw // 10
    for i in range(10):
        draw.rectangle([gx + i * stripe, gy, gx + (i + 1) * stripe, gy + gh], fill=(30, 104, 64, 255) if i % 2 else (26, 92, 56, 255))
    line = (230, 230, 230, 255)
    draw.rectangle([gx, gy, gx + gw, gy + gh], outline=line, width=3)
    draw.line([(gx + gw / 2, gy), (gx + gw / 2, gy + gh)], fill=line, width=3)
    r = gw * 9.15 / PITCH_LEN
    draw.ellipse([gx + gw / 2 - r, gy + gh / 2 - r, gx + gw / 2 + r, gy + gh / 2 + r], outline=line, width=3)
    for side in (0, 1):
        x_edge = gx if side == 0 else gx + gw
        sgn = 1 if side == 0 else -1
        bw, bh = gw * 16.5 / PITCH_LEN, gh * 40.32 / PITCH_WID
        draw.rectangle([min(x_edge, x_edge + sgn * bw), gy + (gh - bh) / 2, max(x_edge, x_edge + sgn * bw), gy + (gh + bh) / 2], outline=line, width=3)
        sw, sh = gw * 5.5 / PITCH_LEN, gh * 18.32 / PITCH_WID
        draw.rectangle([min(x_edge, x_edge + sgn * sw), gy + (gh - sh) / 2, max(x_edge, x_edge + sgn * sw), gy + (gh + sh) / 2], outline=line, width=3)
    # 密度で塗る（品質100回の41）。点を重ねるだけだと芝と混ざって濁った。
    # 格子で数えて、ぼかして、最大値で正規化し、密度に応じて 黄 → 橙 → 赤。薄い所は透ける
    cols, rows_ = 70, 45
    grid = [[0.0] * cols for _ in range(rows_)]
    for c in coords:
        x, y = float(c.get("x") or 0), float(c.get("y") or 0)
        i = min(cols - 1, max(0, int(x / PITCH_LEN * cols)))
        j = min(rows_ - 1, max(0, int(y / PITCH_WID * rows_)))
        grid[j][i] += 1.0
    peak0 = max(v for row in grid for v in row) or 1.0
    small = Image.new("L", (cols, rows_))
    small.putdata([int(255 * v / peak0) for row in grid for v in row])
    dens = small.resize((int(gw), int(gh)), Image.BICUBIC).filter(ImageFilter.GaussianBlur(22))
    peak = max(dens.getdata()) or 1
    heat = Image.new("RGBA", (int(gw), int(gh)), (0, 0, 0, 0))
    px_data = []
    for v in dens.getdata():
        t = max(0.0, min(1.0, v / peak))
        if t < 0.06:
            px_data.append((0, 0, 0, 0))
            continue
        # 黄(255,213,74) → 橙(255,140,40) → 赤(220,50,40)
        if t < 0.5:
            k = t / 0.5
            col = (255, int(213 + (140 - 213) * k), int(74 + (40 - 74) * k))
        else:
            k = (t - 0.5) / 0.5
            col = (int(255 + (220 - 255) * k), int(140 + (50 - 140) * k), int(40 + (40 - 40) * k))
        px_data.append(col + (int(40 + 175 * t ** 0.8),))
    heat.putdata(px_data)
    canvas.alpha_composite(heat, (int(gx), int(gy)))
    draw = ImageDraw.Draw(canvas)
    if os.environ.get("HEAT_DEBUG"):
        for (mx, my), col in (((PITCH_LEN, PITCH_WID / 2), (255, 0, 0, 255)), ((0, PITCH_WID / 2), (0, 120, 255, 255))):
            cx, cy = gx + gw * mx / PITCH_LEN, gy + gh * my / PITCH_WID
            draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=col)
    draw.text((px + pw - 130, py + ph - 50), "FotMob", font=_font(26), fill=(120, 130, 146, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    statboard._write_mark(out, f"{name}の今季のヒートマップ", "touches", [("points", len(coords))], "FotMob")
    return out


def heat(data: dict) -> list[dict]:
    return list(((data.get("firstSeasonStats") or {}).get("heatmap") or {}).get("coordinates") or [])


def portrait_variant(board: Path) -> Path:
    """横の板（1280x720）から縦版（1080x1920、`<名前>_v.png`）を作る。ショートは `_drop_boards` がこれを拾う。

    板そのものは 1080 幅に縮めて画面の上寄り（登録カードの下）に置く。下は暗い地のまま（字幕が乗る）。
    """
    from src import statboard

    src = Image.open(board).convert("RGBA")
    # 芝の縁を落として板だけを取り出し（品質100回の51）、幅いっぱいに敷いて画面の中ほどに置く。下は字幕のぶん空ける
    W, H = src.size
    panel = src.crop((80, 40, W - 80, H - 40))
    scale = 1060 / panel.width
    small = panel.resize((1060, int(panel.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (1080, 1920), (14, 20, 30, 255))
    canvas.alpha_composite(small, (10, 400))
    out = board.with_name(board.stem + "_v.png")
    canvas.convert("RGB").save(out)
    mark = board.with_name(board.name + ".statboard.txt")
    if mark.exists():
        out.with_name(out.name + ".statboard.txt").write_text(mark.read_text(encoding="utf-8"), encoding="utf-8")
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("find"); f.add_argument("name")
    b = sub.add_parser("boards"); b.add_argument("player_id"); b.add_argument("--name", default=""); b.add_argument("--date", default=datetime.date.today().isoformat())
    b.add_argument("--tm", default="", help="Transfermarkt の番号（市場価値の推移の板）")
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
    hm = heatmap_board(heat(data), BOARD_DIR / f"player_{stamp}_{args.player_id}_heat.png", name)
    print(f"板 → {radar}\n板 → {sm}\n板 → {hm}")
    for b in (radar, sm, hm):
        portrait_variant(b)
    if args.tm:
        import importlib.util as _iu

        spec = _iu.spec_from_file_location("player_intro", ROOT / "tools" / "player_intro.py")
        pi = _iu.module_from_spec(spec); spec.loader.exec_module(pi)
        history = pi.ja_mod._get(f"/player/{args.tm}/market-value-history").get("history") or []
        vb = value_board(history, BOARD_DIR / f"player_{stamp}_{args.player_id}_value.png", name, club_of=pi.club_ja)
        portrait_variant(vb)
        print(f"板 → {vb}（縦版も）")
    strong, weak = strengths(season_stats(data))
    print("武器:", [(s["ja"], s["value"], int(s["pct"])) for s in strong])
    print("弱点:", [(s["ja"], s["value"], int(s["pct"])) for s in weak])
    print("直近:", recent(data))
    print("次戦:", next_match(data))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
