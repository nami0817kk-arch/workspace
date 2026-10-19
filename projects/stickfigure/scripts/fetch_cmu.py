"""CMU モーションキャプチャ(cgspeed の BVH 変換版)を取得して、clips/ に clip を作る。

  python scripts/fetch_cmu.py            # 既定の15本(走り・剣・蹴り・突き・武術・転倒)を取得して変換
  python scripts/fetch_cmu.py 09_01 75_16

出典: CMU Graphics Lab Motion Capture Database(mocap.cs.cmu.edu、NSF EIA-0196217)。
変換版: github.com/Shriinivas/cmubvh(cgspeed の変換。「CMU は元データの利用に制限を置かない」)。
BVH と clip は **リポジトリに入れない**(clips/ は gitignore)。取得先は専用フォルダに置く。
"""
import io
import json
import os
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from stickfig import mocap  # noqa: E402

BASE = "https://raw.githubusercontent.com/Shriinivas/cmubvh/main/"
# 動画 → 区間フォルダ(cmubvh の構成)
GROUP = {"02": "Sequence-001-009", "09": "Sequence-001-009", "13": "Sequence-010-014", "74": "Sequence-060-075", "75": "Sequence-060-075",
         "76": "Sequence-076-080", "90": "Sequence-086-094", "135": "Sequence-131-135"}
DEFAULT = ["09_01", "09_02", "02_07", "02_08", "02_09", "13_17", "74_03", "74_04", "75_16", "76_01", "76_03", "90_05", "90_16", "135_04", "135_07"]
RUNS = {"09_01", "09_02"}            # 進行方向で平面を決める(走り)


def fetch(name: str, dest: Path) -> Path:
    subj = name.split("_")[0]
    url = f"{BASE}{GROUP[subj]}/{subj}/Data/{name}.zip"
    data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "stickfig"})).read()
    z = zipfile.ZipFile(io.BytesIO(data))
    for n in z.namelist():
        if n.lower().endswith(".bvh") and ".." not in n and not n.startswith("/"):
            out = dest / os.path.basename(n)
            out.write_bytes(z.read(n))
            return out
    raise RuntimeError(f"{name}: zip に bvh が無い")


def convert(bvh: Path, name: str, clips: Path) -> None:
    b = mocap.parse_bvh(bvh.read_text(encoding="latin-1"))
    p = mocap.world_positions(b)
    if name in RUNS:
        c = mocap.retarget(b, heading="travel", p=p)
        loop = mocap.find_loop(c)
        if loop is not None:
            c = loop
        mocap.save_clip(c, clips / f"{name}.json")
        print(name, "走り", c["n"], "コマ", f"輪の誤差 {c.get('loop_error')}" if loop else "")
        return
    strikes = mocap.find_strikes(b, p, top=2)
    for i, st in enumerate(strikes, 1):
        t0 = max(0.0, st["t"] - 1.2)
        t1 = st["t"] + 1.2
        c = mocap.retarget(b, heading="strike", strike=st, mirror=(st["side"] == "L"), t0=t0, t1=t1, p=p)
        mocap.save_clip(c, clips / f"{name}_s{i}.json")
        print(f"{name}_s{i}", st["kind"], st["side"], f"t={st['t']:.2f}s 速度 {st['speed']:.1f}", c["n"], "コマ")


def main(argv):
    names = argv or DEFAULT
    clips = ROOT / "clips"
    clips.mkdir(exist_ok=True)
    dest = Path(os.environ.get("STICKFIG_MOCAP_DIR", ROOT.parents[2].parent / "output" / "mocap_cmu" / "bvh"))
    dest.mkdir(parents=True, exist_ok=True)
    for n in names:
        bvh = dest / f"{n}.bvh"
        if not bvh.exists():
            bvh = fetch(n, dest)
        convert(bvh, n, clips)


if __name__ == "__main__":
    main(sys.argv[1:])
