"""記事に載っている報道写真を、出典を控えたうえで取り込む（2026-09-17）。

**方針の変更。**それまでは Commons の CC0/BY/BY-SA と自作だけで賄っていた
（[[video-asset-policy]]）。同じ題材を扱う4チャンネルを測ったところ、
**どこも報道写真や他社の制作物をそのまま使っていて**、画像の差は
腕ではなく権利の差だった。ユーザーの判断で **C（報道写真）まで開けた**。

**権利は晴れていない。**「他もやっている」は摘発されにくさの話であって、
使ってよい理由ではない。これは**引き受ける危険**で、エンブレムやXの画像と同じ扱い:

- 写真は Content ID で自動検出されない。**人が申し立てたときだけ動く**
- 申し立て＝著作権侵害の警告。**3回でチャンネルが削除される**
- だから**連絡先を概要欄に置く**。権利者が「警告」ではなく「連絡」を選べるようにする

**放送映像の静止画（E）は入れない。**2026-09-05 に自分で除外していて、
今回も開けていない。テレビ局は監視が桁違いに厳しい。

**出典は必ず控える。**記事のURLと媒体名を credits.json に残し、概要欄に出す。
引用の要件を満たすわけではないが、**どこから来た写真かを隠さない**。

    python tools/pressphoto.py assets/images/nakamura_press \\
        https://.../photo.jpg \\
        --article https://www.footballchannel.jp/2026/09/17/post1012863/ \\
        --outlet フットボールチャンネル --credit "©Koki NAGAHAMA/GEKISAKA"
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/152.0 Safari/537.36")
IMAGE_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


def fetch(url: str) -> tuple[bytes, str]:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": url})
    with urllib.request.urlopen(req, timeout=40) as res:
        kind = (res.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        if kind not in IMAGE_TYPES:
            raise SystemExit(f"画像ではありません（{kind or '種類不明'}）: {url}")
        return res.read(), IMAGE_TYPES[kind]


def save(folder: Path, name: str, raw: bytes, ext: str) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    if not name:
        used = sorted(p.name for p in folder.glob("[0-9][0-9].*"))
        name = f"{len(used) + 1:02d}{ext}"
    out = folder / name
    out.write_bytes(raw)
    # 開けるか確かめる。**開けない画像を控えに書かない**
    from PIL import Image

    with Image.open(out) as image:
        size = image.size
    return out, size


def record(folder: Path, entry: dict) -> None:
    ledger = folder / "credits.json"
    rows = []
    if ledger.exists():
        try:
            rows = json.loads(ledger.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            rows = []
    rows = [r for r in rows if r.get("file") != entry["file"]] + [entry]
    ledger.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir", help="置き先（例: assets/images/nakamura_press）")
    ap.add_argument("url", help="画像のURL")
    ap.add_argument("--article", required=True, help="その写真が載っている記事のURL")
    ap.add_argument("--outlet", required=True, help="媒体名（フットボールチャンネル など）")
    ap.add_argument("--credit", default="", help="写真に入っている表記（©Koki NAGAHAMA/GEKISAKA など）")
    ap.add_argument("--name", default="", help="保存名（既定: 01.jpg から連番）")
    args = ap.parse_args()

    raw, ext = fetch(args.url)
    folder = Path(args.dir)
    out, size = save(folder, args.name, raw, ext)
    record(folder, {
        "file": out.name,
        "source": "press",
        "title": "",
        "page_url": args.article,
        "image_url": args.url,
        # **撮影者の表記があればそのまま残す。**消して使わない
        "author": args.credit or args.outlet,
        "license": "報道写真（許諾は得ていない／出典を明示して使用）",
        "outlet": args.outlet,
        "subject_check": "人が選んだ写真（機械では確かめていない）",
    })
    print(f"■ {out}  {size[0]}x{size[1]}")
    print(f"  媒体　: {args.outlet}")
    print(f"  記事　: {args.article}")
    if args.credit:
        print(f"  表記　: {args.credit}")
    print("  権利　: **許諾は得ていない。**引き受ける危険として使う")
    print(f"  台本に: thumbnail_photo: {out.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
