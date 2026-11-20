"""素材を探して取り、出典を控える(画面の作りの回の assets/)。Pexels の API(無料。鍵は platform/ai-lab の .env の PEXELS_API_KEY)。

  python tools/media.py find-v "namib desert aerial"          映像を探す(番号・秒・撮った人・見本の絵の URL)
  python tools/media.py find-p "fog desert dunes"             写真を探す
  python tools/media.py get-v <id> episodes/<題材> sea.mp4     映像を取って assets/stock/ に置き(git に入れない。sources.json の id で取り直せる)、sources.json に控える
  python tools/media.py get-p <id> episodes/<題材> fog.jpg     写真
  python tools/media.py ai episodes/<題材> x.png "何の絵か"     AI で作った絵を控える(右上に「イメージ」と出る)

素材は「この文を分からせる絵」を先に決めてから探す(フリー素材を並べるだけにしない。2026-11-20)。
"""
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, r"C:/Users/なみ/dev/workspace/platform/ai-lab/src")


def key() -> str:
    from imagegen.config import load_dotenv
    load_dotenv()
    return os.environ["PEXELS_API_KEY"]


def api(u: str) -> dict:
    return json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"Authorization": key(), "User-Agent": "naze"}), timeout=60))


def dl(u: str, p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "naze"}), timeout=300).read())


def note(folder: Path, name: str, rec: dict) -> None:
    sp = folder / "assets" / "sources.json"
    s = json.loads(sp.read_text(encoding="utf-8")) if sp.exists() else {}
    s[name] = rec
    sp.parent.mkdir(parents=True, exist_ok=True)
    sp.write_text(json.dumps(s, ensure_ascii=False, indent=1), encoding="utf-8")


def main(a):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # 撮った人の名前に外国の文字があると cp932 で止まった(2026-11-20)
    mode = a[0]
    if mode == "find-v":
        v = api("https://api.pexels.com/videos/search?" + urllib.parse.urlencode(dict(query=a[1], orientation=a[2] if len(a) > 2 else "landscape", per_page=12)))
        for x in v["videos"]:
            hd = any(f.get("width", 0) >= 1920 or f.get("height", 0) >= 1920 for f in x["video_files"])
            print(x["id"], f"{x['duration']}秒", x["user"]["name"], "HD" if hd else "--", x["image"])
    elif mode == "find-p":
        p = api("https://api.pexels.com/v1/search?" + urllib.parse.urlencode(dict(query=a[1], per_page=12)))
        for x in p["photos"]:
            print(x["id"], f"{x['width']}x{x['height']}", x["photographer"], x["src"]["medium"])
    elif mode == "get-v":
        x = api(f"https://api.pexels.com/videos/videos/{a[1]}")
        fs = sorted([f for f in x["video_files"] if f["file_type"] == "video/mp4" and max(f.get("width", 0), f.get("height", 0)) >= 1920],
                    key=lambda f: max(f.get("width", 0), f.get("height", 0)))
        folder = Path(a[2])
        dl(fs[0]["link"], folder / "assets" / "stock" / a[3])
        note(folder, a[3], dict(by=x["user"]["name"], site="Pexels", url=x["url"], id=x["id"]))
        print("取った", a[3], x["user"]["name"], x["url"])
    elif mode == "get-p":
        x = api(f"https://api.pexels.com/v1/photos/{a[1]}")
        folder = Path(a[2])
        dl(x["src"]["large2x"], folder / "assets" / "stock" / a[3])
        note(folder, a[3], dict(by=x["photographer"], site="Pexels", url=x["url"], id=x["id"]))
        print("取った", a[3], x["photographer"], x["url"])
    elif mode == "ai":
        note(Path(a[1]), a[2], dict(ai=True, by="AI", what=a[3] if len(a) > 3 else ""))
        print("控えた", a[2])


if __name__ == "__main__":
    main(sys.argv[1:])
