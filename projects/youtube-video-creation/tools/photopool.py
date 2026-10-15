"""1本ぶんの写真を、記事の出典からまとめて集めて、縦に切って並べる（2026-10-15）。

ユーザー「画像を複数使ったりしている点が違うよね」。参考ショートの絵の切り替わりは1分あたり13〜58回
（ch-ic4op 34〜58・ハーフタイム速報 13〜15）、こちらのショートは 0〜1回だった。
写真の入れ替えの仕組み（`shorts._rotate_photos`、3.5秒ごと）は 10/15 に入れたが、
**入れ替える縦写真が1枚しか無い**ので動かなかった。この道具は、その写真を揃える。

    python tools/photopool.py --note research/20261016_xxx.yaml --dir assets/images/20261016_xxx --who 久保建英
    python tools/photopool.py --note ... --dir ... --who ... --max 5 --dry-run   # 候補を見るだけ

やること
1. 取材メモの出典（記事）から画像を集める。**記事の主写真（og:image）と、説明（alt・キャプション）に本人の名前が入った写真だけ**。
   関連記事・ランキング・サイドバーのサムネは別人なので拾わない（横 900px 以上）
2. **代理店（Getty・AFLO・AFP・ロイター等）のURLは落とす**。画像の中の透かしは機械で分からないので、**一覧画像を必ず目で見る**
3. 顔の面積は一覧に出す（既定は足切りしない。`--min-face 0.025` で小さい写真を落とせる）。顔が検出できない写真は中央で縦に切り、一覧に「要確認」と出す（手で `facecrop.py --center` を使う）
4. 同じ写真（縮小・色違い）は1枚にまとめる（8x8 の平均ハッシュ）。`--dir` にすでにある写真とも重複させない
5. 残ったものを `pressphoto.py` で取り込み（出どころ・被写体・「許諾は得ていない」を控える。放送局は止まる）、
   顔の位置から縦 `NN_v.jpg`（9:16）と横 `NN_w.jpg`（16:9）を切る
6. `<dir>/_pool.png` に縦切りの一覧を書く。**本人が写っているか・別人でないか・透かしが無いかを目で見る**
   外すものは、その番号のファイル（`NN.jpg` `NN_v.jpg` `NN_w.jpg`）と `credits.json` の行を消す

**この道具が確かめられないこと**：被写体が本人か（`--who` は「人がそう言った」控え）、画像の中の透かし、
写真の権利（許諾は得ていない。引き受ける危険）。
"""
from __future__ import annotations

import argparse
import io
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

import articlephoto as ap          # noqa: E402

MIN_W = 900
MIN_FACE_AREA = 0.0                # 顔が画面に占める割合の下限（記事の主写真は別人にならないので既定は外す。顔%は一覧に出す）
# 放送映像の静止画は使わない（2026-09-17「動画はだめ！」）。配信元のURLで落とす
BROADCAST = ("espnmedia", "dazn", "skysports", "bbc.", "nhk", "abema", "tv-asahi", "tbs.co", "fujitv", "wowow")


def _hash(im) -> int:
    g = im.convert("L").resize((8, 8))
    px = list(g.get_flattened_data()) if hasattr(g, 'get_flattened_data') else list(g.getdata())
    avg = sum(px) / 64
    return sum(1 << i for i, p in enumerate(px) if p > avg)


def _dist(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


RELATED = ("related", "recommend", "ranking", "popular", "pickup", "sidebar", "aside", "widget", "banner",
           "latest", "newest", "topics", "carousel", "slider", "footer", "header", "nav", "ad-", "sponsor")


def _tokens(who: str) -> list[str]:
    """名前の照合に使う語。姓と名を別々に（「鈴木彩艶」なら『鈴木彩艶』『彩艶』）。"""
    who = who.strip()
    toks = [who] + [t for t in who.replace("・", " ").split() if len(t) >= 2]
    if len(who) >= 4 and " " not in who and "・" not in who:
        toks.append(who[2:])
    return list(dict.fromkeys(toks))


def _lead_images(page_url: str, who: str) -> list[tuple[str, str]]:
    """記事の主写真（og:image）と、**説明に本人の名前が入っている**写真だけ。

    関連記事・ランキング・サイドバーのサムネは別人の写真なので拾わない
    （2026-10-15 に鈴木彩艶の記事から別の日本人選手2人を拾った）。
    """
    from urllib.parse import urljoin
    from bs4 import BeautifulSoup

    soup = BeautifulSoup(ap.page(page_url), "lxml")
    out, seen = [], set()

    def add(src, why):
        if not src:
            return
        full = urljoin(page_url, src.strip())
        if full.lower().startswith("http") and full not in seen and not any(w in full.lower() for w in ap.SKIP):
            seen.add(full)
            out.append((full, why))

    for prop in ("og:image", "twitter:image"):
        for tag in soup.find_all("meta", attrs={"property": prop}) + soup.find_all("meta", attrs={"name": prop}):
            add(tag.get("content", ""), "主写真")
    toks = _tokens(who)
    for img in soup.find_all("img"):
        anc = " ".join(" ".join(p.get("class", []) or []) + " " + (p.get("id") or "")
                       for p in img.parents if getattr(p, "get", None)).lower()
        if any(w in anc for w in RELATED):
            continue
        fig = img.find_parent("figure")
        text = " ".join([img.get("alt") or "", img.get("title") or "",
                         fig.get_text(" ") if fig else ""])
        if any(t in text for t in toks):
            add(img.get("src") or img.get("data-src") or "", "説明に名前")
    return out


def candidates(note: Path, who: str) -> list[dict]:
    """出典の記事から (url, 画像, 顔の面積) を集める。代理店・放送のURLは落とす。"""
    import requests
    from PIL import Image
    from src import faces

    out = []
    for page_url in ap.sources_of(note):
        try:
            found = _lead_images(page_url, who)
        except Exception:      # noqa: BLE001
            continue
        for src, where in found:
            low = src.lower()
            if any(a in low for a in ap.AGENCIES) or any(b in low for b in BROADCAST):
                continue
            try:
                raw = requests.get(src, timeout=25, headers={"User-Agent": ap.UA, "Referer": page_url}).content
                im = Image.open(io.BytesIO(raw)).convert("RGB")
            except Exception:  # noqa: BLE001
                continue
            if im.width < MIN_W:
                continue
            fs = faces.find_faces(im) if faces.available() else []
            area = fs[0][2] * fs[0][3] / (im.width * im.height) if fs else 0.0
            out.append({"url": src, "page": page_url, "im": im, "area": area, "hash": _hash(im), "why": where})
    return out


def pick(cands: list[dict], existing: list[int], limit: int, min_face: float = MIN_FACE_AREA) -> list[dict]:
    keep: list[dict] = []
    seen = list(existing)
    for c in sorted(cands, key=lambda c: -c["area"]):
        if c["area"] < min_face:
            continue
        if any(_dist(c["hash"], h) <= 6 for h in seen):
            continue
        seen.append(c["hash"])
        keep.append(c)
        if len(keep) >= limit:
            break
    return keep


def main() -> int:
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--note", required=True, help="取材メモ（中の出典URLを全部当たる）")
    a.add_argument("--dir", required=True, help="取り込み先（assets/images/...）")
    a.add_argument("--who", required=True, help="誰が写っているか（人がそう言った、という控え）")
    a.add_argument("--max", type=int, default=5, help="取り込む最大枚数")
    a.add_argument("--min-face", type=float, default=MIN_FACE_AREA, help="顔の面積の下限（画面に対する割合。試合の全景も入れるなら下げる）")
    a.add_argument("--dry-run", action="store_true", help="候補を見るだけ（取り込まない）")
    args = a.parse_args()

    from PIL import Image
    dest = ROOT / args.dir
    existing = []
    if dest.exists():
        for p in dest.glob("*.jpg"):
            if p.stem.endswith(("_v", "_w")):
                continue
            try:
                existing.append(_hash(Image.open(p)))
            except Exception:  # noqa: BLE001
                pass
    cands = candidates(ROOT / args.note, args.who)
    print(f"候補 {len(cands)} 枚（代理店のURLと {MIN_W}px 未満は除く）")
    chosen = pick(cands, existing, args.max, args.min_face)
    for i, c in enumerate(chosen, 1):
        print(f"  [{i}] 顔 {c['area'] * 100:.1f}%  {c['im'].width}x{c['im'].height}  {c['why']}  {c['url'][:80]}")
    if not chosen:
        print("顔が大きく写る新しい写真は見つかりませんでした")
        return 1
    if args.dry_run:
        return 0

    dest.mkdir(parents=True, exist_ok=True)
    n0 = len([p for p in dest.glob("*.jpg") if not p.stem.endswith(("_v", "_w"))])
    for i, c in enumerate(chosen, 1):
        name = f"{n0 + i:02d}"
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "pressphoto.py"), str(args.dir), c["url"],
                            "--article", c["page"], "--outlet", _outlet(c["page"]), "--who", args.who,
                            "--credit", _outlet(c["page"]), "--name", name],
                           capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
        if r.returncode != 0:
            print(f"  取り込めませんでした: {c['url'][:70]}\n  {r.stderr.strip()[:160]}")
            continue
        src = dest / name
        if src.exists() and not src.suffix:
            src.rename(dest / f"{name}.jpg")              # pressphoto が拡張子を付けない場合
            _fix_credit(dest, name)
        _crop(dest / f"{name}.jpg")
    _sheet(dest)
    print(f"\n一覧: {dest / '_pool.png'}  ← 開いて、本人か・別人でないか・透かしが無いかを見る")
    return 0


def _outlet(page_url: str) -> str:
    from urllib.parse import urlparse
    host = urlparse(page_url).netloc.lower()
    return host[4:] if host.startswith("www.") else host


def _fix_credit(dest: Path, name: str) -> None:
    import json
    p = dest / "credits.json"
    if not p.exists():
        return
    rows = json.loads(p.read_text(encoding="utf-8"))
    for r in rows:
        if r.get("file") == name:
            r["file"] = f"{name}.jpg"
    p.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")


def _crop(photo: Path) -> None:
    subprocess.run([sys.executable, str(ROOT / "tools" / "facecrop.py"), str(photo.relative_to(ROOT)), "--force"],
                   capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
    v = photo.with_name(photo.stem + "_v.jpg")
    if not v.exists():                       # 顔が検出できない写真：中央で縦に切る（位置は人が直す）
        import json
        from PIL import Image
        im = Image.open(photo).convert("RGB")
        w = int(im.height * 9 / 16)
        left = max(0, (im.width - w) // 2)
        im.crop((left, 0, left + w, im.height)).save(v, quality=95)
        (photo.parent / (photo.stem + "_v.check")).write_text("顔が検出できず中央で切った", encoding="utf-8")
        cp = photo.parent / "credits.json"
        if cp.exists():
            rows = json.loads(cp.read_text(encoding="utf-8"))
            base = next((r for r in rows if r.get("file") == photo.name), None)
            if base and not any(r.get("file") == v.name for r in rows):
                rows.append({**base, "file": v.name})
                cp.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")


def _sheet(dest: Path) -> None:
    from PIL import Image, ImageDraw
    vs = sorted(dest.glob("*_v.jpg"))
    if not vs:
        return
    h = 640
    tiles = []
    for p in vs:
        im = Image.open(p).convert("RGB")
        im = im.resize((int(im.width * h / im.height), h))
        d = ImageDraw.Draw(im)
        warn = p.with_name(p.stem + ".check").exists()
        d.rectangle((0, 0, 150 if warn else 70, 34), fill=(0, 0, 0))
        d.text((8, 8), p.stem[:-2] + (" 要確認" if warn else ""), fill=(255, 80, 80) if warn else (255, 255, 0))
        tiles.append(im)
    sheet = Image.new("RGB", (sum(t.width for t in tiles) + 10 * len(tiles), h), (20, 20, 20))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 10
    sheet.save(dest / "_pool.png")


if __name__ == "__main__":
    raise SystemExit(main())
