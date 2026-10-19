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
from typing import Optional

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


def cmd_rhythm(a) -> int:
    from . import rhythm
    print(rhythm.report(a.video))
    return 0


def cmd_check(a) -> int:
    scene = planmod.load_scene(a.scene)
    pl = planmod.build_plan(scene)
    res = qa.run_gate(pl, scene.get("qa"))
    print(qa.format_report(res))
    from . import rhythm, motion
    print(rhythm.plan_report(pl))
    print(motion.report(pl))
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


def build_scene(scene: dict, out: Path, reuse_figs: bool = False, force: bool = False, quiet: bool = False):
    """台本(dict)から動画まで。通れば mp4 の Path、点検で止まれば None。episode.py からも使う。"""
    from . import compose, video_check
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    pl = planmod.build_plan(scene)
    plan_path = out / "plan.json"
    planmod.save_plan(pl, plan_path)
    res = qa.run_gate(pl, scene.get("qa"))
    (out / "gate_report.md").write_text(qa.format_report(res), encoding="utf-8")
    if not quiet:
        print(qa.format_report(res))
    if not res["passed"] and not force:
        print("\n点検に通らないので、書き出さずに止める(--force で続ける)")
        return None
    figs = out / "figs"
    if reuse_figs and len(list(figs.glob("f_*.png"))) == pl["n"]:
        print("書き出し済みの人物を再利用する(--reuse-figs)")
    else:
        render_figures(plan_path, figs)
    stage = None
    if pl["view"].get("persp") and pl.get("stage", {}).get("style") != "flat":          # 遠近のカメラのときは、舞台(床・壁・柱)も立体で別に書き出す(2D の舞台 flat は PIL で描く)
        stage = out / "stage"
        if not (reuse_figs and len(list(stage.glob("f_*.png"))) == pl["n"]):
            render_figures(plan_path, stage, "stage")
    ff = find_ffmpeg()
    mp4 = compose.compose(pl, figs, out / "frames", out / f"{scene.get('name', 'scene')}.mp4", ff, stage)
    au = scene.get("audio", {})
    if au is not False:                       # 効果音+BGM(計算で作る)を付ける
        from . import sfx
        wav = out / f"{scene.get('name', 'scene')}.wav"
        sfx.render(pl, wav, (au or {}).get("mood", "battle"), float((au or {}).get("bgm_gain", 0.5)))
        silent = Path(mp4).with_name(Path(mp4).stem + "_silent.mp4")
        Path(mp4).replace(silent)
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(silent), "-i", str(wav), "-c:v", "copy", "-af", "loudnorm=I=-16:TP=-2:LRA=12", "-c:a", "aac", "-b:a", "192k",
                        "-ar", "44100", "-ac", "2", "-shortest", str(mp4)], check=True)
        silent.unlink()
    holds = []
    for e in pl["events"]:
        holds += list(range(e["frame"], e["frame"] + e.get("hold_frames", 0) + 1))
    vres = video_check.check_video(ff, mp4, out / "check", holds, pl["fps"])
    print(f"\n動画: {mp4}\n動画の点検: 静止 {len(vres['static'])} / 急な変化 {len(vres['pops'])} / 白黒 {len(vres['flashes'])}")
    fh = figure_height(figs)
    if fh:
        print(f"人物の高さ/画面: 中央値 {fh['median']:.2f} / 1/3 未満のコマ {fh['small']:.0%}(参考は 1/3〜1/2)")
    return Path(mp4)


def figure_height(figs: Path, step: int = 5) -> Optional[dict]:
    """人物 PNG のアルファの縦幅(画面の高さに対する比)。参考(Becker・アニメ)は 1/3〜1/2。1/4 以下が続く区間はカメラが遠い。"""
    import numpy as np
    from PIL import Image
    files = sorted(figs.glob("f_*.png"))
    if not files:
        return None
    hs = []
    for p in files[::step]:
        a = np.array(Image.open(p).split()[-1])
        ys = np.where(a.max(axis=1) > 40)[0]
        if len(ys):
            hs.append((ys.max() - ys.min()) / a.shape[0])
    if not hs:
        return None
    hs.sort()
    return dict(median=hs[len(hs) // 2], small=sum(1 for h in hs if h < 1 / 3) / len(hs))


def cmd_build(a) -> int:
    scene = planmod.load_scene(a.scene)
    return 0 if build_scene(scene, Path(a.out), a.reuse_figs, a.force) else 1


def cmd_kit(a) -> int:
    from . import kit
    d = kit.make_kit(a.ep_dir, a.title, a.hero, a.rival or "", a.arc or "")
    print(f"投稿の下書き: {d}")
    return 0


def cmd_preview(a) -> int:
    from . import preview
    mp4 = preview.preview_scene(planmod.load_scene(a.scene), Path(a.out), find_ffmpeg())
    print(f"下書き: {mp4}")
    return 0


def cmd_motion(a) -> int:
    from . import motion
    print(motion.report(planmod.build_plan(planmod.load_scene(a.scene))))
    return 0


def cmd_review(a) -> int:
    from . import episode, review
    print(review.report(episode.load_episode(a.episode)))
    return 0


def cmd_series(a) -> int:
    from . import series
    out = Path(a.out)
    if a.compile_only:
        mp4s = sorted(p for p in out.glob("ep*/ep*.mp4"))
        return 0 if (mp4s and series.compile_series(mp4s, out, a.vertical)) else 1
    if not a.build:
        for p in series.write_specs(a.n, out, a.seed):
            print(p)
        return 0
    return 0 if series.build_series(a.n, out, a.seed, a.vertical, compile_all=a.compile) else 1


def cmd_episode(a) -> int:
    from . import episode
    mp4 = episode.build_episode(episode.load_episode(a.episode), Path(a.out), a.reuse_figs, a.force, a.vertical, a.preview)
    return 0 if mp4 else 1


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
    p = sub.add_parser("episode"); p.add_argument("episode"); p.add_argument("--out", required=True); p.add_argument("--force", action="store_true"); p.add_argument("--reuse-figs", action="store_true"); p.add_argument("--vertical", action="store_true", help="縦画面(ショート用 720x1280)で作る"); p.add_argument("--preview", action="store_true", help="下書き(線画・Blender なし)で数十秒で作る"); p.set_defaults(fn=cmd_episode)
    p = sub.add_parser("kit"); p.add_argument("ep_dir"); p.add_argument("--title", required=True); p.add_argument("--hero", default="ミドリ"); p.add_argument("--rival"); p.add_argument("--arc"); p.set_defaults(fn=cmd_kit)
    p = sub.add_parser("series"); p.add_argument("--n", type=int, default=5); p.add_argument("--out", required=True); p.add_argument("--seed", type=int, default=100); p.add_argument("--vertical", action="store_true"); p.add_argument("--build", action="store_true"); p.add_argument("--compile", action="store_true", help="全話を題名カードつきで 1 本につなぐ(長尺用)"); p.add_argument("--compile-only", dest="compile_only", action="store_true", help="作成済みのエピソードをつなぐだけ"); p.set_defaults(fn=cmd_series)
    p = sub.add_parser("preview"); p.add_argument("scene"); p.add_argument("--out", required=True); p.set_defaults(fn=cmd_preview)
    p = sub.add_parser("motion"); p.add_argument("scene"); p.set_defaults(fn=cmd_motion)
    p = sub.add_parser("review"); p.add_argument("episode"); p.set_defaults(fn=cmd_review)
    p = sub.add_parser("rhythm"); p.add_argument("video"); p.set_defaults(fn=cmd_rhythm)
    p = sub.add_parser("video-check"); p.add_argument("video"); p.add_argument("--out"); p.add_argument("--fps", type=float, default=30.0); p.set_defaults(fn=cmd_video_check)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
