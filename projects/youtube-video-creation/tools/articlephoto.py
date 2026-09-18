"""記事のページから、使える写真を探して並べる（2026-09-17）。

ユーザー指示「**他の写真とかも探して使ってね**」。
1枚ずつ URL を手で拾うやり方は続かないので、**取材メモの出典から自動で集める**。

    # 取材メモに書いた sources を全部当たって、候補を並べる
    python tools/articlephoto.py --note research/20260917_nakamura.yaml

    # 1ページだけ
    python tools/articlephoto.py --url https://www.footballchannel.jp/2026/09/17/post1012863/

    # 選んで取り込む（--pick は上の一覧の番号）
    python tools/articlephoto.py --url <記事URL> --pick 2 \\
        --dir assets/images/nakamura_press --who 中村敬斗

**権利は晴れていない。**[[video-asset-policy]] のとおり、引き受ける危険として使う。
取り込みは `pressphoto.py` に渡すので、出どころと被写体が控えに残り、
**放送局のページからは取り込めない**。

**小さい画像は落とす。**記事のサムネやアイコンが大量に混ざるので、
横 480px 未満は候補にしない（サムネイルにすると眠くなる）。

**この道具は「探す」までしかできない。**2026-09-17 に、最初の1枚で2つ踏んだ:

1. **代理店の印は URL ではなく画像の中にある。**gekisaka.jp から取った写真の
   右下に「©Getty Images」が焼き込まれていた。URLで見る警告は素通りする
2. **被写体が違った。**`--who 鈴木彩艶` と記録したが、写っていたのは
   ゴールを喜ぶ味方3人で、鈴木（GK）は奥に小さく写っているだけだった

**取り込んだら必ず開いて見る。**`--who` は「人がそう言った」という控えであって、
確かめた証拠ではない。
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import urljoin

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# **警告が文字化けで消える**（2026-09-18 に踏んだ）。`pressphoto` と同じ理由
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

MIN_WIDTH = 480
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/152.0 Safari/537.36")
# **写真代理店のものは、危険の質が違う**（2026-09-17 に1枚目で踏んだ）。
# 記事に載っている写真の多くは Getty / AFLO / AFP などの配信で、
# **代理店は画像を機械照合して請求書を送る**（媒体からの削除要請とは別の話）。
# [[api-adoption-decisions]] で Getty 契約は見送りにしている。
# **止めはしない**が、必ず知らせる
AGENCIES = ("gettyimages", "getty", "aflo", "afpbb", "afp", "reuters", "alamy",
            "imago", "shutterstock", "jiji", "kyodonews", "pa-images", "epa")

# 記事の中身ではないもの
SKIP = ("logo", "icon", "avatar", "banner", "ad_", "/ads/", "sprite", "blank",
        "placeholder", "favicon", "profile", "button", "bnr")


def page(url: str) -> str:
    import requests

    res = requests.get(url, timeout=30, headers={"User-Agent": UA})
    res.raise_for_status()
    res.encoding = res.apparent_encoding or res.encoding
    return res.text


def found(url: str) -> list[tuple[str, str]]:
    """(画像URL, どこから見つけたか) の一覧。**大きい順ではなく、出てきた順**。"""
    from bs4 import BeautifulSoup

    soup = BeautifulSoup(page(url), "lxml")
    out, seen = [], set()

    def add(src: str, where: str) -> None:
        if not src:
            return
        full = urljoin(url, src.strip())
        if not full.lower().startswith("http"):
            return
        if any(word in full.lower() for word in SKIP) or full in seen:
            return
        seen.add(full)
        out.append((full, where))

    for prop in ("og:image", "twitter:image", "og:image:secure_url"):
        for tag in soup.find_all("meta", attrs={"property": prop}) + \
                   soup.find_all("meta", attrs={"name": prop}):
            add(tag.get("content", ""), prop)
    # 本文らしいところを先に見る
    body = soup.find("article") or soup.find("main") or soup
    for img in body.find_all("img"):
        add(img.get("src") or img.get("data-src") or "", "本文")
    return out


def measure(src: str) -> tuple[int, int] | None:
    """大きさを見る。**開けないものは候補から外す。**"""
    import io

    import requests
    from PIL import Image

    try:
        raw = requests.get(src, timeout=25, headers={"User-Agent": UA, "Referer": src}).content
        with Image.open(io.BytesIO(raw)) as im:
            return im.size
    except Exception:      # noqa: BLE001
        return None


def sources_of(note: Path) -> list[str]:
    text = note.read_text(encoding="utf-8")
    urls = re.findall(r"https?://[^\s\"'\]]+", text)
    out = []
    for u in urls:
        if "x.com/search" in u or u in out:
            continue
        out.append(u.rstrip(",）)"))
    return out


def show(url: str, start: int = 1) -> list[str]:
    print(f"■ {url}")
    keep = []
    for src, where in found(url):
        size = measure(src)
        if not size or size[0] < MIN_WIDTH:
            continue
        keep.append(src)
        agency = next((a for a in AGENCIES if a in src.lower()), "")
        mark = f"  ⚠ {agency} の配信かもしれません" if agency else ""
        print(f"  [{start + len(keep) - 1:>2}] {size[0]}x{size[1]:<5} {where:<18} {src[:90]}{mark}")
    if not keep:
        print("  使える大きさの写真がありません")
    return keep


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--note", default="", help="取材メモ。中の出典URLを全部当たる")
    ap.add_argument("--url", default="", help="1ページだけ見る")
    ap.add_argument("--pick", type=int, default=0, help="取り込む番号（--url と一緒に）")
    ap.add_argument("--dir", default="", help="取り込み先")
    ap.add_argument("--who", default="", help="誰が写っているか")
    ap.add_argument("--outlet", default="", help="出どころの名前（既定: ホスト名）")
    args = ap.parse_args()

    if args.note:
        urls = sources_of(Path(args.note))
        print(f"出典 {len(urls)}件")
        for u in urls:
            try:
                show(u)
            except Exception as err:      # noqa: BLE001
                print(f"■ {u}\n  取れません: {err!r}"[:180])
            print()
        return 0

    if not args.url:
        print("--note か --url を指定してください", file=sys.stderr)
        return 1
    keep = show(args.url)
    if not args.pick:
        return 0
    if not args.dir:
        print("--dir が要ります", file=sys.stderr)
        return 1
    if not 1 <= args.pick <= len(keep):
        print(f"番号は 1〜{len(keep)} です", file=sys.stderr)
        return 1
    from urllib.parse import urlparse

    import pressphoto

    chosen = keep[args.pick - 1]
    agency = next((a for a in AGENCIES if a in chosen.lower()), "")
    if agency:
        print(f"■ **{agency} の配信の可能性があります。**代理店は画像を機械照合して"
              "請求書を送ります。媒体への削除要請とは別の話です", file=sys.stderr)
    # **注意書きは取り込みの前に出す**（2026-09-18）。後ろに置いていたら、
    # 印字が UnicodeEncodeError で落ちて**一度も表示されなかった**。
    # 取り込みは成功しているので失敗にも見えず、そのまま使うところだった
    _notice()
    sys.argv = ["pressphoto", args.dir, chosen,
                "--source", args.url,
                "--from", args.outlet or (urlparse(args.url).hostname or "不明"),
                "--who", args.who]
    code = pressphoto.main()
    if code == 0:
        _notice()
    return code


def _notice() -> None:
    """**この道具が確かめられない2つ。**取り込みの前と後の両方で出す。"""
    print()
    print("■ 必ず開いて見てください。この道具は2つを確かめられません:")
    print("   ・写真の中に代理店の透かし（©Getty Images 等）が焼き込まれていないか")
    print("     → 2026-09-17、gekisaka から取った1枚の右下に焼き込まれていた")
    print("   ・写っているのが本当にその人か")
    print("     → 2026-09-17、味方3人の写真を鈴木彩艶として取り込んだ")
    print("     → 2026-09-18、記事の og:image は久保建英ではなくボーンマスの選手だった。"
          "**記事の代表画像が題材の人とは限らない**")


if __name__ == "__main__":
    raise SystemExit(main())
