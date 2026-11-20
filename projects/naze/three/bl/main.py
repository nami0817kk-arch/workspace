"""Blender の入り口: blender -b --factory-startup -P three/bl/main.py -- job.json

job["mode"]:
  probe  … 殴る動きの間、拳の先の位置を細かく測る(probe.json)
  render … plan.json の各コマを描き、点検用の数字(check_frames.json)も書く
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))   # projects/naze

import bpy  # noqa: E402
import numpy as np  # noqa: E402

from three.bl import fx as FXM  # noqa: E402
from three.bl import rig, scene  # noqa: E402

job = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
sc_def = job["scene"]
FPS = job["fps"]
grey = bool(job.get("grey"))
look = job["look"]

bpy.ops.wm.read_factory_settings(use_empty=True)
S = scene.setup_render(job["size"], FPS, grey, look.get("exposure", 0.0))
S.frame_start, S.frame_end = 1, int(1 + job.get("seconds", 20) * FPS)

ch = sc_def["character"]
arm, body = rig.load_character(job["assets"]["mannequin"], ch["pos"], ch["yaw_deg"], look["body"], grey)
rig.assign_clips(arm, sc_def["clips"], FPS, job.get("anim_fps", 24))
hand = sc_def["punch"]["hand"]
bpy.context.view_layer.update()          # 回した向きを matrix_world に反映してから測る
fwd = rig.facing(arm)

if job["mode"] == "probe":
    p = sc_def["punch"]
    ts = np.arange(p["start"], p["start"] + p["window"], 1.0 / 240)
    rows = []
    for s in ts:
        rig.set_time(float(s), FPS)
        rows.append(rig.fist_front(arm, body, hand, fwd))
    Path(job["out"]).write_text(json.dumps(dict(t=ts.tolist(), front=rows, facing=fwd)), encoding="utf-8")
    sys.exit(0)

# ---------------- render ----------------
plan = json.loads(Path(job["plan"]).read_text(encoding="utf-8"))
R = plan["radius"]
sdir = scene.world(None if grey else job["assets"]["sky"], look.get("sun_dir", (0.35, -1)), grey)
scene.ground(look["ground"], grey)
mat_obj = scene.mat_wall(plan["mat"] if "mat" in plan else sc_def["mat"], look["mat"], grey)
scene.marks(plan["ball_start"][0], plan["mat_front"], plan.get("marks"), grey)
scene.tee(plan["ball_start"], R, grey)
ball_root, ball = scene.ball(R, look["ball"], look["ball_band"], grey)
cam = scene.camera()
fx = None if grey else FXM.FX(tuple(look["fx"]))

frames_dir = Path(job["frames"])
frames_dir.mkdir(parents=True, exist_ok=True)
only = set(job.get("only") or [])
step = int(job.get("step", 1))
checks = []
t_start = time.time()
n_done = 0
W, H = S.render.resolution_x, S.render.resolution_y


def project(cam_obj, pts: np.ndarray) -> np.ndarray:
    """世界の点 → 画面の画素(左上が原点、1920×1080 の座標)。"""
    dg = bpy.context.evaluated_depsgraph_get()
    P = np.array(cam_obj.calc_matrix_camera(dg, x=W, y=H)) @ np.array(cam_obj.matrix_world.inverted())
    h = np.c_[pts, np.ones(len(pts))] @ P.T
    z = h[:, 3:4]
    ndc = h[:, :2] / np.where(np.abs(z) < 1e-9, 1e-9, z)
    return np.c_[(ndc[:, 0] + 1) / 2 * W, (1 - ndc[:, 1]) / 2 * H, z[:, 0]] * [job["size"][0] / W, job["size"][1] / H, 1]


for fr in plan["frames"]:
    i = fr["i"]
    if only and i not in only:
        continue
    if not only and i % step:
        continue
    s = fr["s"]
    rig.set_time(s, FPS)
    b = fr["ball"]
    sq = fr["fx"]["squash"]
    ball_root.location = b["pos"]
    ball_root.scale = (1 - sq, 1 + sq / 2, 1 + sq / 2)
    ball.rotation_quaternion = b["quat"]
    c = fr["cam"]
    scene.aim(cam, c["loc"], c["target"], c["lens"])
    scene.dent(mat_obj, plan["mat_front"], fr["fx"].get("dent"))
    if fx:
        fx.apply(fr["fx"], c["loc"])
    # 点検の数字
    bpy.context.view_layer.update()
    verts = rig.eval_verts(body)
    front = rig.fist_front(arm, body, hand, fwd)
    bp = np.array(b["pos"])
    vp = project(cam, verts)
    in_front = vp[:, 2] > 0
    body_box = [float(vp[in_front, 0].min()), float(vp[in_front, 1].min()), float(vp[in_front, 0].max()), float(vp[in_front, 1].max())] if in_front.any() else None
    bc = project(cam, bp[None])[0]
    # 球の見かけの半径(中心と、カメラの右方向に R ずらした点の差)
    right = np.array(cam.matrix_world.to_3x3().col[0])
    be = project(cam, (bp + right * R)[None])[0]
    # 拳の先と球の表面の隙間(負ならめり込み)。人形の頂点のうち球の中にあるものの数も数える
    d_all = np.linalg.norm(verts - bp, axis=1)
    checks.append(dict(i=i, s=s, shot=fr["shot"], gap=float(np.linalg.norm(np.array(front) - bp) - R), body_in_ball=int((d_all < R * 0.97).sum()),
                       front=front, ball=b["pos"], ball_px=[float(bc[0]), float(bc[1])], ball_rpx=float(abs(be[0] - bc[0])), ball_z=float(bc[2]),
                       body_px=body_box, facing=rig.facing(arm), dent=(fr["fx"].get("dent") or {}).get("depth", 0.0)))
    out = frames_dir / f"{i:05d}.png"
    if not job.get("no_render") and not (job.get("skip_existing") and out.exists()):
        S.render.filepath = str(out)
        bpy.ops.render.render(write_still=True)
        n_done += 1
    if n_done and n_done % 20 == 0:
        print(f"[three] {n_done} コマ {(time.time() - t_start) / n_done:.2f} 秒/コマ", flush=True)

if only and Path(job["checks"]).exists():      # 一部だけ描き直したときは、前の点検の数字に上書きで混ぜる
    old = {r["i"]: r for r in json.loads(Path(job["checks"]).read_text(encoding="utf-8"))["frames"]}
    old.update({r["i"]: r for r in checks})
    checks = [old[k] for k in sorted(old)]
Path(job["checks"]).write_text(json.dumps(dict(frames=checks, sec_per_frame=(time.time() - t_start) / max(1, n_done), n_rendered=n_done)), encoding="utf-8")
print(f"[three] done {n_done} frames, {(time.time() - t_start) / max(1, n_done):.2f} s/frame", flush=True)
