"""Blender の中で動く: 標高のメッシュを作り、カメラのキー(job.json)どおりに動かして書き出す。地点の画面位置も proj.json に書く。

blender -b -P blender_terrain.py -- <job.json> [all|1,30,60]
job: {height, tex, Wkm, Hkm, exag, fps, frames, lens, keys:[{frame, cam:[x,y,z], tgt:[x,y,z]}], rise:[f0,f1]|null, points:{名前:[x,y,z]}, out}
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
job = json.load(open(argv[0], encoding="utf-8"))
MODE = argv[1] if len(argv) > 1 else "all"
NF, FPS, EX = job["frames"], job["fps"], job["exag"]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
sc.frame_start, sc.frame_end = 1, NF
sc.render.resolution_x, sc.render.resolution_y = 1080, 1920
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = eng
        break
    except Exception:
        pass
try:
    sc.eevee.taa_render_samples = 16
except Exception:
    pass
sc.view_settings.view_transform = "Standard"

# ---- 地形 ----
hs = np.load(job["height"])
ny, nx = hs.shape
bpy.ops.mesh.primitive_grid_add(x_subdivisions=nx - 1, y_subdivisions=ny - 1, size=1)
ob = bpy.context.active_object
me = ob.data
co = np.empty(len(me.vertices) * 3, np.float32)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
ix = np.clip(np.round((co[:, 0] + 0.5) * (nx - 1)).astype(int), 0, nx - 1)
iy = np.clip(np.round((0.5 - co[:, 1]) * (ny - 1)).astype(int), 0, ny - 1)
co[:, 2] = hs[iy, ix] * EX / 1000.0
co[:, 0] *= job["Wkm"]
co[:, 1] *= job["Hkm"]
me.vertices.foreach_set("co", co.ravel())
me.update()
me.shade_smooth()
mat = bpy.data.materials.new("terrain")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.9
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(job["tex"])
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
me.materials.append(mat)

# ---- 背景と光(北西からの日差し + 弱い補助光)----
world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.006, 0.012, 0.035, 1)
for name, energy, rot in (("sun", 3.2, (52, 0, 135)), ("fill", 0.6, (30, 0, -40))):
    o = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
    o.data.energy = energy
    o.data.angle = math.radians(3)
    o.rotation_euler = tuple(math.radians(v) for v in rot)
    sc.collection.objects.link(o)

# ---- カメラ ----
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = job.get("lens", 28)
cam.data.clip_start, cam.data.clip_end = 0.05, 400
tgt = bpy.data.objects.new("tgt", None)
sc.collection.objects.link(tgt)
c = cam.constraints.new("TRACK_TO")
c.target = tgt
c.track_axis, c.up_axis = "TRACK_NEGATIVE_Z", "UP_Y"
for k in job["keys"]:
    cam.location, tgt.location = k["cam"], k["tgt"]
    cam.keyframe_insert("location", frame=k["frame"])
    tgt.keyframe_insert("location", frame=k["frame"])
if job.get("rise"):                                             # 平らな地図から立ち上がる
    f0, f1 = job["rise"]
    ob.scale = (1, 1, 0.04)
    ob.keyframe_insert("scale", frame=1)
    ob.keyframe_insert("scale", frame=f0)
    ob.scale = (1, 1, 1)
    ob.keyframe_insert("scale", frame=f1)


def _fcurves(o):
    ad = o.animation_data
    if not ad or not ad.action:
        return []
    try:
        return list(ad.action.fcurves)
    except Exception:
        out = []
        for layer in ad.action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


for o in (cam, tgt, ob):
    for fc in _fcurves(o):
        for kp in fc.keyframe_points:
            kp.interpolation, kp.easing = "BEZIER", "AUTO"
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"

# ---- 地点の画面位置 ----
proj = {}
for f in range(1, NF + 1):
    sc.frame_set(f)
    s = ob.scale[2]
    row = {}
    for k, v in job["points"].items():
        p = world_to_camera_view(sc, cam, Vector((v[0], v[1], v[2] * s)))
        row[k] = [round(p.x, 4), round(1 - p.y, 4), round(p.z, 3)]
    proj[f] = row
out = job["out"]
json.dump(proj, open(os.path.join(out, "proj.json"), "w"), separators=(",", ":"))

# ---- 書き出し ----
sc.render.image_settings.file_format = "PNG"
if MODE == "all":
    sc.render.filepath = os.path.join(out, "frames", "f_")
    bpy.ops.render.render(animation=True)
else:
    for f in [int(x) for x in MODE.split(",")]:
        sc.frame_set(f)
        sc.render.filepath = os.path.join(out, "stills", f"s_{f:04d}.png")
        bpy.ops.render.render(write_still=True)
