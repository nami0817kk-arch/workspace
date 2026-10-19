"""コマンド。台本から動画まで、点検つきで一気に作る。

  python -m stickfig check scenes/showpiece.yaml          # 計算だけ(Blender 不要)。合否を出す
  python -m stickfig build scenes/showpiece.yaml --out out/showpiece   # 計算→点検→書き出し→合成→動画の点検
  python -m stickfig plan  scenes/showpiece.yaml --out plan.json
  python -m stickfig video-check out/showpiece/show.mp4

Blender は環境変数 STICKFIG_BLENDER、無ければ標準の場所、無ければ PATH の blender を使う。
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from . import plan as planmod
from . import qa

HERE = Path(__file__).parent
WIN_BLENDER = [r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
               r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe", r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"]


def find_blender() -> str:
    env = os.environ.get("STICKFIG_BLENDER")
    if env and Path(env).exists():
        return env
    for p in WIN_BLENDER:
        if Path(p).exists():
            return p
    exe = shutil.which("blender")
    if exe:
        return exe
    raise SystemExit("Blender が見つからない。STICKFIG_BLENDER に blender の場所を入れる")


def find_ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        raise SystemExit("ffmpeg が見つからない(pip install imageio-ffmpeg)")


def cmd_plan(a) -> int:
    pl = planmod.build_plan(planmod.load_scene(a.scene))
    planmod.save_plan(pl, a.out)
    print(f"plan: {pl['n']} コマ → {a.out}")
    return 0


def cmd_check(a) -> int:
    scene = planmod.load_scene(a.scene)
    pl = planmod.build_plan(scene)
    res = qa.run_gate(pl, scene.get("qa"))
    print(qa.format_report(res))
    if a.report:
        Path(a.report).write_text(qa.format_report(res), encoding="utf-8")
    return 0 if res["passed"] else 1


def render_figures(plan_path: Path, out_dir: Path, mode: str = "figs") -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in out_dir.glob("*.png"):
        p.unlink()
    r = subprocess.run([find_blender(), "-b", "-P", str(HERE / "blender_player.py"), "--", str(Path(plan_path).resolve()),
                        str(out_dir.resolve()), mode], capture_output=True, text=True)
    n = len(list(out_dir.glob("f_*.png")))
    if r.returncode != 0 or n == 0:
        sys.stderr.write((r.stdout or "")[-2000:] + (r.stderr or "")[-2000:])
        raise SystemExit("Blender の書き出しに失敗した")


def cmd_build(a) -> int:
    from . import compose, video_check
    scene = planmod.load_scene(a.scene)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    pl = planmod.build_plan(scene)
    plan_path = out / "plan.json"
    planmod.save_plan(pl, plan_path)
    res = qa.run_gate(pl, scene.get("qa"))
    (out / "gate_report.md").write_text(qa.format_report(res), encoding="utf-8")
    print(qa.format_report(res))
    if not res["passed"] and not a.force:
        print("\n点検に通らないので、書き出さずに止める(--force で続ける)")
        return 1
    figs = out / "figs"
    if a.reuse_figs and len(list(figs.glob("f_*.png"))) == pl["n"]:
        print("書き出し済みの人物を再利用する(--reuse-figs)")
    else:
        render_figures(plan_path, figs)
    stage = None
    if pl["view"].get("persp"):          # 遠近のカメラのときは、舞台(床・壁・柱)も立体で別に書き出す
        stage = out / "stage"
        if not (a.reuse_figs and len(list(stage.glob("f_*.png"))) == pl["n"]):
            render_figures(plan_path, stage, "stage")
    ff = find_ffmpeg()
    mp4 = compose.compose(pl, figs, out / "frames", out / f"{scene.get('name', 'scene')}.mp4", ff, stage)
    holds = []
    for e in pl["events"]:
        holds += list(range(e["frame"], e["frame"] + e.get("hold_frames", 0) + 1))
    vres = video_check.check_video(ff, mp4, out / "check", holds, pl["fps"])
    print(f"\n動画: {mp4}\n動画の点検: 静止 {len(vres['static'])} / 急な変化 {len(vres['pops'])} / 白黒 {len(vres['flashes'])}")
    return 0


def cmd_video_check(a) -> int:
    from . import video_check
    ff = find_ffmpeg()
    res = video_check.check_video(ff, a.video, a.out or Path(a.video).with_suffix("").as_posix() + "_check", fps=a.fps)
    print(Path(res["report"]).read_text(encoding="utf-8"))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="stickfig")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan"); p.add_argument("scene"); p.add_argument("--out", required=True); p.set_defaults(fn=cmd_plan)
    p = sub.add_parser("check"); p.add_argument("scene"); p.add_argument("--report"); p.set_defaults(fn=cmd_check)
    p = sub.add_parser("build"); p.add_argument("scene"); p.add_argument("--out", required=True); p.add_argument("--force", action="store_true"); p.add_argument("--reuse-figs", action="store_true", help="書き出し済みの人物PNGを再利用(plan が同じときだけ)"); p.set_defaults(fn=cmd_build)
    p = sub.add_parser("video-check"); p.add_argument("video"); p.add_argument("--out"); p.add_argument("--fps", type=float, default=30.0); p.set_defaults(fn=cmd_video_check)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
