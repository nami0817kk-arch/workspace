"""ホームタウンの地図を作る（2026-09-20）。

ユーザーがプレミア20クラブのスタジアム地図を見本として提示した
（「ホームタウンは以下の画像を参考に」）。**あの画像は使わない。**
使うのは形（イングランドの地図にクラブの紋章を置く）だけで、
地図も座標もこちらで取り直す。

    python tools/plmap.py            # 材料を集めて research/pl_data/map.json に控える
    python tools/plmap.py --draw     # 20クラブぶんの地図を assets/stats/ に書き出す

地図は Wikimedia Commons の白地図（CC BY-SA）。**撮影者とライセンスは
assets/stats/credits.json に控える。**座標は各スタジアムの Wikipedia から。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402

# リーグは CLUB_LEAGUE で切り替える（2026-09-26 ラ・リーガ版）
LEAGUE = clubleague.current()
DATA = clubleague.data_dir()
UA = {"User-Agent": "kaigai-soccer-riyuu/1.0 (nami.0817.kk@gmail.com)"}
API = "https://en.wikipedia.org/w/api.php"
# Module:Location map/data/England の値（下の fetch_bounds で取り直して控える）
MAP_FILE = LEAGUE["map_file"]

CLUBS = [
    ("bournemouth", "AFC Bournemouth"), ("arsenal", "Arsenal F.C."),
    ("villa", "Aston Villa F.C."), ("brentford", "Brentford F.C."),
    ("brighton", "Brighton & Hove Albion F.C."), ("chelsea", "Chelsea F.C."),
    ("coventry", "Coventry City F.C."), ("palace", "Crystal Palace F.C."),
    ("everton", "Everton F.C."), ("fulham", "Fulham F.C."),
    ("hull", "Hull City A.F.C."), ("ipswich", "Ipswich Town F.C."),
    ("leeds", "Leeds United F.C."), ("liverpool", "Liverpool F.C."),
    ("mancity", "Manchester City F.C."), ("manutd", "Manchester United F.C."),
    ("newcastle", "Newcastle United F.C."), ("forest", "Nottingham Forest F.C."),
    ("sunderland", "Sunderland A.F.C."), ("tottenham", "Tottenham Hotspur F.C."),
]
# **ラ・リーガは clubs.json から**（2026-09-26）。プレミアの一覧は上の決め打ちのまま
if clubleague.name() != "premier" and (DATA / "clubs.json").exists():
    _got = json.loads((DATA / "clubs.json").read_text(encoding="utf-8"))
    _rows = _got.get("clubs", _got) if isinstance(_got, dict) else _got
    if isinstance(_rows, dict):
        _rows = [dict(v, key=k) for k, v in _rows.items()]
    CLUBS = [(r["key"], str(r.get("wiki") or r.get("wiki_title") or r.get("club_title") or r.get("title")).replace("_", " "))
             for r in _rows]


def _rgb(code: str) -> tuple[int, int, int]:
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def raw(title: str) -> str:
    r = requests.get("https://en.wikipedia.org/w/index.php",
                     params={"action": "raw", "title": title}, headers=UA, timeout=30)
    r.raise_for_status()
    return r.text


def fetch_bounds() -> dict:
    """白地図の四隅（緯度経度）を Wikipedia の元データから取る。**覚えで書かない。**"""
    # England は別ページへの転送なので、実体のほうを読む
    text = raw(f"Module:Location map/data/{LEAGUE['map_module']}")
    got = {}
    # **スペインは四隅ではなく式で書いてある**（2026-09-26）。カナリア諸島を左下に
    # はめ込んだ地図で、経度 -10 を境に式が2つに分かれる:
    #   x = 100*(($2 < -10)*($2+26.925)/(-13.2+26.925) + ($2 >= -10)*($2+9.9)/(4.8+9.9))
    #   y = 100*(($2 < -10)*(38.1-$1)/(38.1-27.4) + ($2 >= -10)*(44.4-$1)/(44.4-34.7))
    # 本土の四隅と、はめ込みの四隅を両方控える
    xf = re.search(r"x\s*=\s*'([^']+)'", text)
    yf = re.search(r"y\s*=\s*'([^']+)'", text)
    if xf and yf and "$2 <" in xf.group(1):
        nums = lambda f: [float(n) for n in re.findall(r"-?\d+\.?\d*", re.sub(r"\$\d", "", f))]
        xs, ys = nums(xf.group(1)), nums(yf.group(1))
        # xs: 100, -10, 26.925, -13.2, 26.925, -10, 9.9, 4.8, 9.9
        # ys: 100, -10, 38.1, 38.1, 27.4, -10, 44.4, 44.4, 34.7
        got = {"left": -xs[6], "right": xs[7], "top": ys[6], "bottom": abs(ys[8]),
               "inset": {"split": xs[1], "left": -xs[2], "right": xs[3], "top": ys[2], "bottom": abs(ys[4])}}
        m = re.search(r"image\s*=\s*[\"']([^\"']+)[\"']", text)
        got["image"] = m.group(1) if m else MAP_FILE
        return got
    for key in ("top", "bottom", "left", "right"):
        m = re.search(rf"{key}\s*=\s*(-?[\d.]+)", text)
        if not m:
            raise SystemExit(f"■ 地図の {key} が読めませんでした")
        got[key] = float(m.group(1))
    m = re.search(r"image\s*=\s*[\"']([^\"']+)[\"']", text)
    got["image"] = m.group(1) if m else MAP_FILE
    return got


def ground_of(club_title: str) -> str:
    text = raw(club_title)
    # **`ground` とは限らない。**クリスタル・パレスは `stadium` と書いてある
    m = (re.search(r"^\s*\|\s*ground\s*=\s*(.+)$", text, re.M)
         or re.search(r"^\s*\|\s*stadium\s*=\s*(.+)$", text, re.M))
    if not m:
        return ""
    line = m.group(1)
    link = re.search(r"\[\[([^\]|]+)", line)
    return (link.group(1) if link else re.sub(r"[\[\]']", "", line)).strip()


def coords_of(title: str) -> tuple[float, float] | None:
    r = requests.get(API, params={"action": "query", "prop": "coordinates",
                                  "titles": title, "format": "json", "redirects": 1},
                     headers=UA, timeout=30)
    r.raise_for_status()
    for page in r.json().get("query", {}).get("pages", {}).values():
        for c in page.get("coordinates") or []:
            return float(c["lat"]), float(c["lon"])
    return None


def collect() -> dict:
    out = {"bounds": fetch_bounds(), "clubs": {}}
    for key, title in CLUBS:
        ground = ground_of(title)
        at = coords_of(ground) if ground else None
        if at is None:
            at = coords_of(title)
        if at is None:
            print(f"  ！ {key}: 座標が取れませんでした（{ground}）", file=sys.stderr)
            continue
        out["clubs"][key] = {"ground": ground, "lat": at[0], "lon": at[1]}
        print(f"  {key:12s} {ground:34s} {at[0]:.4f}, {at[1]:.4f}")
    (DATA / "map.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    return out


def _fit(draw_on, text, font_path, size, width):
    while size > 16:
        font = ImageFont.truetype(font_path, size)
        if draw_on.textlength(text, font=font) <= width:
            return font
        size -= 2
    return ImageFont.truetype(font_path, size)


def draw(key: str, spec: dict, base: Image.Image, crests: dict, facts: dict, out: Path) -> Path:
    """白地図に20クラブの紋章を置き、その回のクラブだけ大きく残す。

    見た目は基礎DATAの板に合わせる（クラブの色の地、上に帯、左に文字）。
    **20クラブ全部を置くのは、その回のクラブがどこにいるか分かるため。**
    """
    sys.path.insert(0, str(ROOT))
    from src.config import load_config
    font_path = str(load_config().video.font_path())

    SIZE, HEAD, MARGIN = (1280, 720), 118, 28
    bounds = spec["bounds"]
    base_c = (_rgb(facts["colors"][0]), _rgb(facts["colors"][1]))
    card = Image.new("RGB", SIZE, base_c[0])
    d = ImageDraw.Draw(card)
    for y in range(SIZE[1]):
        v = y / SIZE[1]
        d.line([(0, y), (SIZE[0], y)], fill=tuple(round(c * (1 - 0.35 * v)) for c in base_c[0]))
    d.rectangle([0, HEAD - 8, SIZE[0], HEAD - 2], fill=base_c[1])

    crest_w = 0
    if key in crests:
        mark = crests[key].copy()
        mark.thumbnail((96, 96))
        card.paste(mark, (MARGIN, (HEAD - 8 - mark.height) // 2), mark)
        crest_w = mark.width + 20
    title = facts["title"].replace(" 基礎DATA", "") + " のホームタウン"
    d.text((MARGIN + crest_w, 22), title,
           font=_fit(d, title, font_path, 60, SIZE[0] - 2 * MARGIN - crest_w), fill=(255, 255, 255))

    # 地図は高さに合わせて置く（右寄せ）
    top = HEAD + 10
    room = SIZE[1] - top - 16
    shot = base.copy()
    shot.thumbnail((room, room))
    map_x = SIZE[0] - MARGIN - shot.width
    card.paste(shot.convert("RGB"), (map_x, top), shot)

    def xy(lat, lon):
        b = bounds
        # カナリア諸島ははめ込みの枠で測る（スペインの地図だけ）
        if b.get("inset") and lon < b["inset"]["split"]:
            b = b["inset"]
        x = (lon - b["left"]) / (b["right"] - b["left"]) * shot.width
        y = (b["top"] - lat) / (b["top"] - b["bottom"]) * shot.height
        return map_x + round(x), top + round(y)

    for other, at in spec["clubs"].items():
        if other == key or other not in crests:
            continue
        x, y = xy(at["lat"], at["lon"])
        small = crests[other].copy()
        small.thumbnail((26, 26))
        faded = small.copy()
        faded.putalpha(small.getchannel("A").point(lambda a: round(a * 0.5)))
        card.paste(faded, (x - small.width // 2, y - small.height // 2), faded)

    at = spec["clubs"][key]
    x, y = xy(at["lat"], at["lon"])
    ring = ImageDraw.Draw(card, "RGBA")
    ring.ellipse([x - 44, y - 44, x + 44, y + 44], fill=(255, 255, 255, 240),
                 outline=base_c[1] + (255,), width=5)
    if key in crests:
        big = crests[key].copy()
        big.thumbnail((66, 66))
        card.paste(big, (x - big.width // 2, y - big.height // 2), big)

    # 左の文字（ホームタウンのタイルから）
    town = next((t for t in facts["tiles"] if str(t[0]).startswith("ホームタウン")), None)
    if town:
        left_w = map_x - MARGIN - 24
        d.text((MARGIN, top + 40), "ホームタウン", font=ImageFont.truetype(font_path, 28),
               fill=base_c[1])
        d.text((MARGIN, top + 86), town[1], font=_fit(d, town[1], font_path, 58, left_w),
               fill=(255, 255, 255))
        if town[2]:
            d.text((MARGIN, top + 168), town[2], font=_fit(d, town[2], font_path, 26, left_w),
                   fill=(235, 230, 235))
        # **日本語の名前を出す。**Wikipedia から取った英語名ではなく、
        # 板に載せている「本拠地」のタイルの字を使う
        home = next((x for x in facts["tiles"] if str(x[0]).startswith("本拠地")), None)
        ground = home[1] if home else ""
        if ground:
            d.text((MARGIN, top + 240), "本拠地", font=ImageFont.truetype(font_path, 24),
                   fill=base_c[1])
            d.text((MARGIN, top + 276), ground, font=_fit(d, ground, font_path, 40, left_w),
                   fill=(255, 255, 255))
            if home and home[2]:
                d.text((MARGIN, top + 336), home[2],
                       font=_fit(d, home[2], font_path, 26, left_w), fill=(235, 230, 235))
    out.parent.mkdir(parents=True, exist_ok=True)
    card.save(out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--draw", action="store_true", help="控えた材料から地図を書き出す")
    args = ap.parse_args()
    if not args.draw:
        collect()
        return 0
    spec = json.loads((DATA / "map.json").read_text(encoding="utf-8"))
    base = Image.open(DATA / LEAGUE["map_png"])
    facts = {}
    crests = {}
    for key, _t in CLUBS:
        # **基礎DATAの板がまだ無いクラブは紋章だけ探す**（ラ・リーガは見本の1クラブから作る）
        if not (DATA / f"{key}.json").exists():
            continue
        facts[key] = json.loads((DATA / f"{key}.json").read_text(encoding="utf-8"))
        path = ROOT / facts[key]["crest"]
        if path.exists():
            crests[key] = Image.open(path).convert("RGBA")
    made = []
    for key in spec["clubs"]:
        if key not in facts:
            continue
        made.append(draw(key, spec, base, crests, facts[key],
                         ROOT / f"assets/stats/{LEAGUE['prefix']}{key}_map.png"))
        print(made[-1])
    # **白地図は CC BY-SA。**書き出した1枚ごとに控えを残さないと、
    # 概要欄に撮影者が出ない（review の「写真のクレジット」もここを見る）
    cred = ROOT / "assets" / "stats" / "credits.json"
    rows = json.loads(cred.read_text(encoding="utf-8")) if cred.exists() else []
    src = next((r for r in rows if r.get("file") == f"{LEAGUE['prefix']}map_base.png"), None)
    if src:
        names = {out.name for out in made}
        rows = [r for r in rows if r.get("file") not in names]
        for out in made:
            rows.append(dict(src, file=out.name,
                             note=LEAGUE["map_note"]))
        cred.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"控え: {cred}（{len(rows)}件）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
