"""ワンピース ノックアップストリームのセットを予約投稿する(本編 10/31 19:00、ショート 11/1 11〜16 時。作るだけで実行しない)。題名は titles.json から subprocess で渡す(シェル変数は文字化けする)。
python episodes/knockup/post.py [long|shorts]。結果は episodes/knockup/posted.json に足す。"""
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out"
POSTED = HERE / "posted.json"
SLOTS = {"long": "2026-10-31T19:00:00+09:00", "s1": "2026-11-01T11:00:00+09:00", "s2": "2026-11-01T12:00:00+09:00",
         "s3": "2026-11-01T13:00:00+09:00", "s4": "2026-11-01T14:00:00+09:00", "s5": "2026-11-01T16:00:00+09:00"}
TAGS = "なぜ,解説,ワンピース,ノックアップストリーム,物理,空島"

posted = json.loads(POSTED.read_text(encoding="utf-8")) if POSTED.exists() else {}
which = sys.argv[1] if len(sys.argv) > 1 else "long"
keys = ["long"] if which == "long" else ["s1", "s2", "s3", "s4", "s5"]
subprocess.run([sys.executable, str(HERE / "make_desc.py")] + ([posted["long"]["id"]] if "long" in posted else []), check=True)
titles = json.loads((OUT / "knockup" / "titles.json").read_text(encoding="utf-8"))
for k in keys:
    if k in posted:
        print(k, "済み", posted[k]["id"])
        continue
    video = OUT / "knockup" / "knockup.mp4" if k == "long" else OUT / f"knockup_{k}" / f"knockup_{k}.mp4"
    cmd = [sys.executable, "-m", "naze.upload", str(video), "--title", titles[k], "--desc-file", str(OUT / "knockup" / f"desc_{k}.txt"),
           "--publish-at", SLOTS[k], "--tags", TAGS]
    if k == "long":
        cmd += ["--thumb", str(OUT / "knockup" / "thumb_long.jpg")]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    print(r.stdout, r.stderr[-800:])
    m = re.search(r"youtu\.be/([\w-]+)", r.stdout)
    if not m:
        raise SystemExit(f"{k} の投稿に失敗")
    posted[k] = dict(id=m.group(1), publish_at=SLOTS[k], **({"thumb": "out/knockup/thumb_long.jpg"} if k == "long" else {}))
    POSTED.write_text(json.dumps(posted, ensure_ascii=False, indent=1), encoding="utf-8")
