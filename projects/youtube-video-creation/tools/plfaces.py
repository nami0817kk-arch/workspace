"""オーナーと名選手の顔写真を集める（2026-09-20）。

ユーザー指示「**オーナーと選手の話の時には写真をだす**」。

    python tools/plfaces.py            # 20クラブぶん集めて assets/photos/pl/ に置く
    python tools/plfaces.py --sheet    # 集めた顔を1枚に並べる（目で確かめるため）

**顔は必ず目で確かめる。**同姓の別人を拾った前科がある（2026-09-20、中村敬斗の
ところでチェスの中村ヒカルの写真を拾った）。このツールは集めるところまでで、
採否はこちらが1枚ずつ見て決める。

取り方:
    その人の Wikipedia の**記事の代表画像**（`prop=pageimages`）を使う。
    記事の代表画像なら、まず人違いにならない。**Commons にあって、
    自由なライセンスのものだけ**を落とす（en 側のフェアユース画像は落とさない）。
    日本語名しか無い人は、日本語版で引いてから英語版へ渡る。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research" / "pl_data"
OUT = ROOT / "assets" / "photos" / "pl"
UA = {"User-Agent": "kaigai-soccer-riyuu/1.0 (nami.0817.kk@gmail.com)"}
EN = "https://en.wikipedia.org/w/api.php"
JA = "https://ja.wikipedia.org/w/api.php"
FREE = ("cc0", "cc by", "cc-by", "public domain", "pd-")


def api(url: str, **params) -> dict:
    params.setdefault("format", "json")
    params.setdefault("formatversion", 2)
    r = requests.get(url, params=params, headers=UA, timeout=40)
    r.raise_for_status()
    return r.json()


def en_title_from_ja(name: str) -> str:
    """日本語名から英語版の記事名へ。**見つからなければ空。**"""
    hit = api(JA, action="query", list="search", srsearch=name, srlimit=1)
    pages = hit.get("query", {}).get("search") or []
    if not pages:
        return ""
    got = api(JA, action="query", prop="langlinks", titles=pages[0]["title"],
              lllang="en", redirects=1)
    for page in got.get("query", {}).get("pages", []):
        for link in page.get("langlinks") or []:
            return link.get("title", "")
    return ""


def page_image(title: str) -> str:
    """記事の代表画像のファイル名（`File:` を除いたもの）。"""
    got = api(EN, action="query", prop="pageimages", piprop="name",
              titles=title, redirects=1)
    for page in got.get("query", {}).get("pages", []):
        if page.get("pageimage"):
            return page["pageimage"]
    return ""


def commons_file(name: str) -> dict | None:
    """Commons の控え。**自由なライセンスでなければ None**（en のフェアユースを弾く）。"""
    got = api("https://commons.wikimedia.org/w/api.php", action="query",
              titles="File:" + name, prop="imageinfo",
              iiprop="url|extmetadata", iiurlwidth=1280)
    for page in got.get("query", {}).get("pages", []):
        for info in page.get("imageinfo") or []:
            meta = info.get("extmetadata") or {}

            def field(key: str) -> str:
                return re.sub(r"<[^>]+>", " ", meta.get(key, {}).get("value", "")).strip()

            lic = field("LicenseShortName")
            if not any(k in lic.lower() for k in FREE):
                return None
            return {"title": "File:" + name, "author": " ".join(field("Artist").split()),
                    "license": lic, "page_url": info["descriptionurl"],
                    "image_url": info.get("thumburl") or info["url"]}
    return None


CLUB_PAGE = {
    "bournemouth": "AFC Bournemouth", "arsenal": "Arsenal F.C.", "villa": "Aston Villa F.C.",
    "brentford": "Brentford F.C.", "brighton": "Brighton & Hove Albion F.C.",
    "chelsea": "Chelsea F.C.", "coventry": "Coventry City F.C.", "palace": "Crystal Palace F.C.",
    "everton": "Everton F.C.", "fulham": "Fulham F.C.", "hull": "Hull City A.F.C.",
    "ipswich": "Ipswich Town F.C.", "leeds": "Leeds United F.C.", "liverpool": "Liverpool F.C.",
    "mancity": "Manchester City F.C.", "manutd": "Manchester United F.C.",
    "newcastle": "Newcastle United F.C.", "forest": "Nottingham Forest F.C.",
    "sunderland": "Sunderland A.F.C.", "tottenham": "Tottenham Hotspur F.C.",
}


def is_person(title: str) -> bool:
    """その記事は人物か。**カテゴリの「… births」で見る**（会社を弾くため）。"""
    got = api(EN, action="query", prop="categories", titles=title, cllimit=500, redirects=1)
    for page in got.get("query", {}).get("pages", []):
        for cat in page.get("categories") or []:
            if re.search(r"\d{4} births", cat.get("title", "")):
                return True
    return False


def owner_person(club_page: str) -> str:
    """クラブの記事の owner / chairman から、人物の記事名を1つ選ぶ。"""
    if not club_page:
        return ""
    r = requests.get("https://en.wikipedia.org/w/index.php",
                     params={"action": "raw", "title": club_page}, headers=UA, timeout=40)
    r.raise_for_status()
    seen = []
    for field in ("owner", "owntitle", "chairman", "chrtitle", "owners"):
        for m in re.finditer(rf"^\s*\|\s*{field}\s*=\s*(.+)$", r.text, re.M):
            for link in re.findall(r"\[\[([^\]|#]+)", m.group(1)):
                link = link.strip()
                if link and link not in seen:
                    seen.append(link)
    for title in seen:
        if is_person(title):
            return title
    return ""


def find(name_ja: str, source: str) -> dict | None:
    title = ""
    m = re.match(r"https://en\.wikipedia\.org/wiki/(.+)$", source or "")
    if m and not m.group(1).startswith("List_of"):
        title = m.group(1).replace("_", " ")
    if not title:
        title = en_title_from_ja(name_ja)
    if not title:
        return None
    name = page_image(title)
    if not name:
        return None
    got = commons_file(name)
    if got:
        got["page"] = title
    return got


def save(row: dict, out: Path) -> None:
    r = requests.get(row["image_url"], headers=UA, timeout=120)
    r.raise_for_status()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(r.content)


def collect() -> None:
    legends = {c["club"]: c for c in json.loads((DATA / "pl_legends.json").read_text(encoding="utf-8"))}
    ledger = OUT / "credits.json"
    rows = json.loads(ledger.read_text(encoding="utf-8")) if ledger.exists() else []
    found = {r["file"]: r for r in rows}
    index_path = DATA / "faces.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else {}

    for path in sorted(DATA.glob("*.json")):
        key = path.stem
        if key.endswith("_raw") or key.endswith("_squad") or key in (
                "kana", "kana_a", "kana_b", "_names", "pl_legends", "map", "faces"):
            continue
        facts = json.loads(path.read_text(encoding="utf-8"))
        if "title" not in facts or "tiles" not in facts:
            continue
        club = facts["title"].replace(" 基礎DATA", "")
        entry = index.setdefault(key, {})
        people = []
        for name in (legends.get(club) or legends.get("AFC" + club) or {}).get("legends", []):
            people.append(("legend", name["name"], name.get("source", "")))
        if not people:
            for c in legends.values():
                if c["club"].replace("・", "") in club.replace("・", "") or club.replace("・", "") in c["club"].replace("・", ""):
                    people = [("legend", n["name"], n.get("source", "")) for n in c["legends"]]
                    break
        # **オーナーの名前は板から拾わない**（2026-09-20）。板の小さい字は
        # 「米NFL 49ers系」「86.58%を保有」のような説明で、人の名前ではない。
        # クラブの Wikipedia の owner / chairman の**リンク先**から、
        # **人物の記事**（カテゴリに「… births」がある）だけを採る
        owner_page = owner_person(CLUB_PAGE.get(key, ""))
        if owner_page:
            people.insert(0, ("owner", owner_page, "https://en.wikipedia.org/wiki/"
                              + owner_page.replace(" ", "_")))
        for role, name_ja, source in people:
            # **名前から決まる名前にする。**`hash()` は起動ごとに変わるので、
            # 走らせ直すたびにファイル名が変わってしまう
            slug = f"{key}_{role}_{hashlib.md5(name_ja.encode('utf-8')).hexdigest()[:8]}.jpg"
            if name_ja in entry:
                continue
            got = find(name_ja, source)
            if not got:
                print(f"  ！ {key} {role} {name_ja}: 自由に使える顔写真が見つかりません", file=sys.stderr)
                entry[name_ja] = {"role": role, "file": ""}
                continue
            save(got, OUT / slug)
            entry[name_ja] = {"role": role, "file": f"assets/photos/pl/{slug}",
                              "page": got["page"]}
            found[slug] = dict(got, file=slug, source="wikimedia", person=name_ja,
                               subject_check="未確認（目で確かめること）")
            print(f"  {key:12s} {role:6s} {name_ja:18s} {got['license']}")
        index[key] = entry
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text(json.dumps(list(found.values()), ensure_ascii=False, indent=1), encoding="utf-8")
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")


def sheet(out: Path) -> None:
    """集めた顔を1枚に並べる。**人違いを目で見つけるため。**"""
    from PIL import Image, ImageDraw, ImageFont
    sys.path.insert(0, str(ROOT))
    from src.config import load_config
    font_path = str(load_config().video.font_path())

    index = json.loads((DATA / "faces.json").read_text(encoding="utf-8"))
    items = [(key, name, got["file"]) for key, people in index.items()
             for name, got in people.items() if got.get("file")]
    cols, cell = 6, 240
    rows = -(-len(items) // cols)
    sheet_img = Image.new("RGB", (cols * cell, rows * (cell + 34)), (250, 249, 246))
    d = ImageDraw.Draw(sheet_img)
    font = ImageFont.truetype(font_path, 17)
    for i, (key, name, path) in enumerate(items):
        x, y = (i % cols) * cell, (i // cols) * (cell + 34)
        try:
            im = Image.open(ROOT / path).convert("RGB")
        except OSError:
            continue
        im.thumbnail((cell - 8, cell - 8))
        sheet_img.paste(im, (x + (cell - im.width) // 2, y + 4))
        d.text((x + 6, y + cell + 4), f"{name}", font=font, fill=(28, 22, 30))
    sheet_img.save(out)
    print(f"並べた: {out}（{len(items)}枚）")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sheet", help="集めた顔を並べた1枚の書き出し先")
    args = ap.parse_args()
    if args.sheet:
        sheet(Path(args.sheet))
        return 0
    collect()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
