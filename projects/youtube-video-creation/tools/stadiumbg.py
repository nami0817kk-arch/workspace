"""プレミア20クラブの本拠地の写真を集めて、下地にする（2026-09-17）。

ユーザー指示「**プレミアのスタジアムとかの画像を集めて質をあげよう**」。
それまでの下地はエンブレム（`crest_<クラブ>.png`）で、20本とも同じ作りだった。

**ここは Commons で足りる。**建物の写真は愛好家が大量に上げていて、
CC BY / BY-SA が揃う。**報道写真を使う必要がない**ので、危険を増やさずに質が上がる。

- 1920x1080 に切って、下半分を暗く落とす（カードとテロップが乗るため）
- 撮影者・ライセンス・URL を `assets/backgrounds/credits.json` に控える
  （**CC BY / BY-SA は表示が条件**。ここは消せない）
- **放送映像は使わない。**Commons から取るので、そもそも入り込まない

    python tools/stadiumbg.py --all-premier
    python tools/stadiumbg.py --club アーセナル --query "Emirates Stadium"
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image, ImageDraw  # noqa: E402

from src.portrait import _download, info, is_image, license_ok  # noqa: E402
from src.subjects import COMMONS_API, _get  # noqa: E402

SIZE = (1920, 1080)
OUT = Path("assets/backgrounds")

# 2026-27 プレミアリーグの20クラブと本拠地。**英語名で引く**（Commons の説明が英語）
PREMIER = {
    "アーセナル": "Emirates Stadium",
    "アストンヴィラ": "Villa Park",
    "ボーンマス": "Vitality Stadium Bournemouth",
    "ブレントフォード": "Gtech Community Stadium",
    "ブライトン": "Falmer Stadium Brighton",
    "バーンリー": "Turf Moor",
    "チェルシー": "Stamford Bridge",
    "クリスタルパレス": "Selhurst Park",
    "エヴァートン": "Hill Dickinson Stadium Everton",
    "フラム": "Craven Cottage",
    "リーズ": "Elland Road",
    "リヴァプール": "Anfield",
    "マンチェスターシティ": "City of Manchester Stadium",
    "マンチェスターユナイテッド": "Old Trafford",
    "ニューカッスル": "St James Park Newcastle",
    "ノッティンガムフォレスト": "City Ground Nottingham",
    "サンダーランド": "Stadium of Light Sunderland",
    "トッテナム": "Tottenham Hotspur Stadium",
    "ウェストハム": "London Stadium",
    "ウルヴァーハンプトン": "Molineux Stadium",
}

# 建物ではないもの。**記章・地図・図面・観客の顔のアップは下地にならない**
# **中身が違うものが5枚通った**（2026-09-17。20枚を並べて目で見つけた）。
# ロックのライブ・ロッカールーム・建設中のクレーン・駐車場。
# **機械が通しても目で見る**（CLAUDE.md の決まりどおり）
REJECT = ("logo", "crest", "badge", "map", "plan", "diagram", "sign", "ticket",
          "coat of arms", "seal", "flag", "statue", "portrait",
          # 会場では使われているが、サッカーの下地にならないもの
          "concert", "gig", "tour", "festival", "band", "music",
          "dressing", "changing room", "tunnel", "museum", "shop", "car park",
          "construction", "building site", "crane", "under construction")


# **内観と外観を分けて集める**（2026-09-17 指示「内観と外観映したい」）。
# 外観を下地、内観を画面に出す写真にすると、「下地は1本のあいだ変えない」を
# 守ったまま両方出せる
# **"from the" を入れてはいけない**（2026-09-17 に踏んだ）。
# "from the air"（＝空撮＝外観）に当たって、内観の枠に空撮が入った
INSIDE_WORDS = ("inside", "pitch", "stand", "interior", "kop", "tier", "seats",
                "view of the pitch", "end", "terrace")
# **geograph は外さない**（2026-09-17 に踏んだ）。英国のスタジアム写真の多くが
# geograph.org.uk 由来で、これを弾くと候補が0件になる
OUTSIDE_WORDS = ("aerial", "from above", "from the air", "facade",
                 "entrance", "car park", "surrounds")


def candidates(query: str, session=None, inside: bool | None = None) -> list[str]:
    """候補を集めて、内観／外観の順に並べ替える。

    **検索語に inside や pitch を足してはいけない**（2026-09-17 に踏んだ）。
    Commons の検索は語をANDで取るので、**0件になる**。
    検索は同じにして、**題名の言葉で並べ替える**。
    確実ではないので、**最後は目で見る**（20枚のうち5枚は機械を通り抜けた）。
    """
    found = _get(COMMONS_API, {
        "action": "query", "format": "json", "list": "search",
        "srsearch": f"{query} stadium", "srnamespace": 6, "srlimit": 30,
    }, session).get("query", {}).get("search", [])
    out = []
    for hit in found:
        title = hit["title"]
        low = title.lower()
        if not is_image(title) or any(word in low for word in REJECT):
            continue
        out.append(title)
    if inside is None:
        return out
    words = INSIDE_WORDS if inside else OUTSIDE_WORDS
    liked = [x for x in out if any(w in x.lower() for w in words)]
    return liked + [x for x in out if x not in liked]


def ground(path: Path) -> Image.Image:
    """1920x1080 に敷いて、下半分を落とす。**カードとテロップが乗る場所**。"""
    with Image.open(path) as raw:
        photo = raw.convert("RGB")
    scale = max(SIZE[0] / photo.width, SIZE[1] / photo.height)
    photo = photo.resize((round(photo.width * scale), round(photo.height * scale)),
                         Image.LANCZOS)
    left = (photo.width - SIZE[0]) // 2
    top = max(0, int((photo.height - SIZE[1]) * 0.35))   # 空を少し多めに残す
    board = photo.crop((left, top, left + SIZE[0], top + SIZE[1])).convert("RGBA")
    shade = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    pen = ImageDraw.Draw(shade)
    start = int(SIZE[1] * 0.42)
    for y in range(start, SIZE[1]):
        alpha = int(170 * (y - start) / (SIZE[1] - start))
        pen.line([(0, y), (SIZE[0], y)], fill=(6, 10, 18, alpha))
    board.alpha_composite(shade)
    return board.convert("RGB")


def record(entry: dict) -> None:
    ledger = OUT / "credits.json"
    rows = []
    if ledger.exists():
        try:
            rows = json.loads(ledger.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            rows = []
    rows = [r for r in rows if r.get("file") != entry["file"]] + [entry]
    ledger.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")


def build(club: str, query: str, session=None, inside: bool | None = None,
          only: str = "") -> str:
    reasons = []
    suffix = "_in" if inside else ""
    # **同じ写真を内と外に使わない。**もう一方で使った題名は飛ばす
    other = OUT / f"stadium_{club}{'' if inside else '_in'}.png"
    taken = ""
    ledger = OUT / "credits.json"
    if ledger.exists():
        try:
            for row in json.loads(ledger.read_text(encoding="utf-8")):
                if row.get("file") == other.name:
                    taken = row.get("title", "")
        except (OSError, ValueError):
            pass
    pool = [only] if only else candidates(query, session, inside)[:14]
    for title in pool:
        if title == taken:
            continue
        meta = info(title, session)
        fine, note = license_ok(meta["license"], modify=True)
        if not fine:
            reasons.append(f"{title}: {note}")
            continue
        # **portrait と同じ道で落とす。**urllib だと Wikimedia の証明書で落ちた
        raw = _download(meta["image_url"], session)
        tmp = OUT / "_tmp_stadium"
        tmp.write_bytes(raw)
        try:
            board = ground(tmp)
        except Exception as err:      # noqa: BLE001
            reasons.append(f"{title}: 開けません {err!r}")
            continue
        finally:
            tmp.unlink(missing_ok=True)
        if board.width < SIZE[0]:
            reasons.append(f"{title}: 小さすぎます")
            continue
        out = OUT / f"stadium_{club}{suffix}.png"
        board.save(out)
        record({"file": out.name, "source": "wikimedia", "title": title,
                "page_url": meta["page_url"], "author": meta["author"],
                "license": meta["license"], "club": club})
        return f"{club}: {out.name}  {meta['license']} / {meta['author']}  ({title})"
    return f"{club}: 取れません（{len(reasons)}件見て全部落ちた）" + (
        "" if not reasons else f" 例: {reasons[0][:80]}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all-premier", action="store_true")
    ap.add_argument("--club", default="")
    ap.add_argument("--query", default="")
    ap.add_argument("--file", default="",
                    help="この File: だけを使う（**機械に選べない差は人が決める**）")
    ap.add_argument("--list", action="store_true", help="候補の題名だけ出す")
    ap.add_argument("--inside", action="store_true",
                    help="内観（ピッチ・スタンドが見えるもの）を集める。既定は外観")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.all_premier:
        for club, query in PREMIER.items():
            try:
                print(build(club, query, inside=args.inside or None), flush=True)
            except Exception as err:      # noqa: BLE001
                print(f"{club}: 失敗 {err!r}", flush=True)
        return 0
    if not args.club:
        print("--all-premier か --club を指定してください", file=sys.stderr)
        return 1
    query = args.query or PREMIER.get(args.club, args.club)
    if args.list:
        for title in candidates(query, inside=args.inside or None)[:14]:
            print("  ", title)
        return 0
    print(build(args.club, query, inside=args.inside or None, only=args.file))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
