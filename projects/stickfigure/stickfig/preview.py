"""下書きの動画(プレビュー): Blender を使わず、棒人間を PIL で線画に描いて、数秒で動画にする。

台本・カメラ・字幕・効果音のタイミングを、本番(約3分/場面)を待たずに確かめる。見た目は本番と違う(陰影・輪郭・光の演出は省く)が、
人物の動き・位置・カメラのカット・字幕・命中の瞬間・音は、本番と同じ plan から作るので、同じ。

    python -m stickfig preview scenes/x.yaml --out out/x_preview.mp4
    python -m stickfig episode scenes/episodes/ep.yaml --out out/ep --preview
"""
from __future__ import annotations

import math
import subprocess
from pathlib import Path
from typing import Dict, List

from PIL import Image, ImageDraw

from . import camera, captions, compose, fk, look, sfx

W, H = camera.W, camera.H


def _proj(cam: dict, x: float, z: float, y: float = 0.0):
    px, py = camera.project(cam, x, y, z)[:2]
    return px, py


def _floor(d: ImageDraw.ImageDraw, cam: dict, wall_x) -> None:
    cx = int(cam.get("tx", cam.get("x", 0.0)))
    x0, x1 = cx - 16, cx + 17                           # 見える範囲だけ描く(画面の外へ伸びる長い線は、PIL で極端に遅い)
    pts = [camera.project(cam, x, y, 0.0)[:2] for x, y in ((x0, -4), (x1, -4), (x1, 12), (x0, 12))]
    d.polygon(pts, fill=(150, 130, 105))
    for k in range(x0, x1, 2):                          # 床の目地
        a, b = camera.project(cam, k, -4, 0.0)[:2], camera.project(cam, k, 12, 0.0)[:2]
        d.line([a, b], fill=(120, 104, 84), width=1)
    if wall_x is not None:
        pts = [camera.project(cam, wall_x, y, z)[:2] for y, z in ((-5, 0), (9, 0), (9, 6.5), (-5, 6.5))]
        d.polygon(pts, fill=(140, 140, 150))


def draw_frame(plan: dict, f: int) -> Image.Image:
    fr = plan["frames"][f]
    cam = fr["cam"]
    lk = fr.get("look")
    if lk is not None:
        im = look.streak_bg(f, int(lk)).convert("RGB")
    else:
        im = Image.new("RGB", (W, H), (170, 190, 225))
        _floor(ImageDraw.Draw(im), cam, plan.get("stage", {}).get("wall_x"))
    d = ImageDraw.Draw(im)
    u = camera.px_per_unit(cam)
    for who, a in plan["actors"].items():
        p = fr["actors"][who]
        s = 1 if a.get("facing", 1) >= 0 else -1
        sk = fk.skeleton(p, s, p["root_x"], a.get("scale", 1.0))
        col = tuple(int(255 * c) for c in a["color"])
        w = max(3, int(0.075 * u * a.get("scale", 1.0)))
        for key in ("rear_arm", "rear_leg", "torso", "front_leg", "front_arm"):
            pts = [_proj(cam, x, z, a.get("y", 0.0)) for x, z in sk[key]]
            d.line(pts, fill=col, width=w, joint="curve")
        if a.get("weapon"):
            d.line([_proj(cam, *sk["sword"][0], a.get("y", 0.0)), _proj(cam, *sk["sword"][1], a.get("y", 0.0))], fill=(120, 200, 220), width=max(3, w // 2))
        hx, hy = _proj(cam, *sk["head"], a.get("y", 0.0))
        r = sk["head_r"] * u
        d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=col, outline=(20, 16, 26), width=2)
    for e in plan["events"]:                          # 命中の瞬間: 放射線
        age = f - e["frame"]
        if 0 <= age <= 6 and e["kind"] in compose.BIG:
            cx, cy = compose.to_px(e["pos"][0], e["pos"][1], cam)
            r = (0.4 + age * 0.12) * u * 1.6
            for k in range(18):
                ang = k * math.pi / 9
                d.line([cx + math.cos(ang) * r * 0.4, cy + math.sin(ang) * r * 0.4, cx + math.cos(ang) * r, cy + math.sin(ang) * r], fill=(255, 250, 235), width=3)
    return captions.draw(im, plan, f)


def preview_scene(scene: dict, out_mp4: Path, ffmpeg: str, with_audio: bool = True) -> Path:
    """台本(dict)から、下書きの mp4 を作る(Blender 不要)。点検(qa)は通さずに描く: 台本を直しながら見るための物。"""
    from . import plan as planmod
    out_mp4 = Path(out_mp4)
    out_mp4.parent.mkdir(parents=True, exist_ok=True)
    pl = planmod.build_plan(scene)
    fdir = out_mp4.parent / (out_mp4.stem + "_frames")
    fdir.mkdir(exist_ok=True)
    for p in fdir.glob("*.png"):
        p.unlink()
    for f in range(pl["n"]):
        draw_frame(pl, f).save(fdir / f"{f + 1:04d}.png")
    silent = out_mp4.with_name(out_mp4.stem + "_silent.mp4")
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-framerate", str(pl["fps"]), "-i", str(fdir / "%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "23", str(silent)], check=True)
    au = scene.get("audio", {})
    if with_audio and au is not False:
        wav = out_mp4.with_suffix(".wav")
        sfx.render(pl, wav, (au or {}).get("mood", "battle"), float((au or {}).get("bgm_gain", 0.5)))
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(silent), "-i", str(wav), "-c:v", "copy", "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2", "-shortest", str(out_mp4)], check=True)
        silent.unlink()
    else:
        silent.replace(out_mp4)
    for p in fdir.glob("*.png"):
        p.unlink()
    fdir.rmdir()
    return out_mp4
