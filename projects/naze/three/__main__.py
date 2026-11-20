"""python -m three <手順> <場面> [--grey] [--step N] [--only 1,2,3]

手順: probe → sim → plan → render → check → compose → sheet(all で一気に)
  --grey  色・光・効果を省いた下見(半分の大きさ・少ないサンプル)。動き・当たり・カメラを先に確かめる
出力: out/three/<場面>[_grey]/
"""
from __future__ import annotations

import argparse
import importlib
import json
import subprocess
import sys
import time

from . import config as C


def job_base(sc, grey, out):
    return dict(scene=sc, fps=C.FPS, size=list(C.SIZE), grey=grey, anim_fps=C.ANIM_FPS,
                assets={k: str(v) for k, v in C.ASSET.items()}, look=C.LOOK, seconds=30)


def blender(job: dict, out, name: str):
    p = out / f"job_{name}.json"
    p.write_text(json.dumps(job, ensure_ascii=False), encoding="utf-8")
    log = out / f"blender_{name}.log"
    cmd = [C.BLENDER, "-b", "--factory-startup", "-P", str(C.ROOT / "three" / "bl" / "main.py"), "--", str(p)]
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        r = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        tail = log.read_text(encoding="utf-8", errors="replace")[-3000:]
        raise SystemExit(f"Blender が失敗した({log})\n{tail}")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("step", choices=["probe", "sim", "plan", "render", "check", "compose", "sheet", "all"])
    ap.add_argument("scene")
    ap.add_argument("--grey", action="store_true")
    ap.add_argument("--step", dest="every", type=int, default=1)
    ap.add_argument("--only", default="")
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--check-only", action="store_true", help="描かずに点検の数字だけ取り直す")
    a = ap.parse_args(argv)
    for m in (C.ASSET["mannequin"], C.ASSET["sky"]):
        if not m.exists():
            raise SystemExit(f"素材が無い: {m}(C:/Users/なみ/dev/assets3d/SOURCES.md を見る)")
    sc = importlib.import_module(f"three.scenes.{a.scene}").SCENE
    out = C.OUT / (a.scene + ("_grey" if a.grey else ""))
    out.mkdir(parents=True, exist_ok=True)
    steps = ["probe", "sim", "plan", "render", "check", "compose", "sheet"] if a.step == "all" else [a.step]
    from .physics import Track
    for st in steps:
        t0 = time.time()
        if st == "probe":
            blender(dict(job_base(sc, a.grey, out), mode="probe", out=str(out / "probe.json")), out, "probe")
        elif st == "sim":
            from . import physics
            d = physics.run(json.loads((out / "probe.json").read_text(encoding="utf-8")), sc, out / "track.json")
            print(f"当たる時刻 {d['t_hit']:.4f} 秒 / 止まる {d['t_stop']:.2f} 秒 / ぶつかり {[(e['kind'], round(e['t'], 3), round(e['speed'], 1)) for e in d['events']][:6]}")
        elif st == "plan":
            from . import timeline
            tr = Track(json.loads((out / "track.json").read_text(encoding="utf-8")))
            p = timeline.plan(tr, sc, C.FPS, out / "plan.json")
            print(f"コマ {p['n']}({p['n'] / C.FPS:.1f} 秒) / 切り替え {p['cuts']} / 当たる {p['v_hit']:.2f} 秒")
        elif st == "render":
            only = [int(x) for x in a.only.split(",") if x.strip()]
            blender(dict(job_base(sc, a.grey, out), mode="render", plan=str(out / "plan.json"), frames=str(out / "frames"),
                         checks=str(out / "check_frames.json"), step=a.every, only=only, skip_existing=a.resume, no_render=a.check_only), out, "render")
            c = json.loads((out / "check_frames.json").read_text(encoding="utf-8"))
            print(f"描いた {c['n_rendered']} コマ / 1コマ {c['sec_per_frame']:.2f} 秒")
        elif st == "check":
            from . import check
            plan = json.loads((out / "plan.json").read_text(encoding="utf-8"))
            fails = check.run(plan, json.loads((out / "check_frames.json").read_text(encoding="utf-8")), sc, out / "check.md")
            print((out / "check.md").read_text(encoding="utf-8"))
            if fails and a.step == "all":
                print("点検に通らないものがある(続けて書き出す)", file=sys.stderr)
        elif st == "compose":
            from . import compose
            plan = json.loads((out / "plan.json").read_text(encoding="utf-8"))
            v = compose.compose(out / "frames", out / "comp", plan, sc, a.grey, out / f"{a.scene}.mp4")
            print(f"動画 {v}")
        elif st == "sheet":
            from . import compose
            plan = json.loads((out / "plan.json").read_text(encoding="utf-8"))
            print(f"一覧 {compose.sheet(out / 'comp', plan, out / 'sheet.jpg')}")
        print(f"[{st}] {time.time() - t0:.1f} 秒")


if __name__ == "__main__":
    main()
