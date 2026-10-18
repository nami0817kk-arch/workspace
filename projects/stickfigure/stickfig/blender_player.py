# Blender の中で動く「再生係」。plan.json を読み、人物を組んで、コマごとの姿勢を当てて、透過PNGで書き出す。
#   blender -b -P blender_player.py -- plan.json out_dir
# 動きの計算はここではしない(すべて plan に入っている)。人物の形は fk.py と同じ寸法にそろえてある。
# このファイルだけ bpy が要るので、CI のテストの対象外。形を変えたら fk.py の定数も直すこと。
import json
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
PLAN = json.load(open(argv[0], encoding="utf-8"))
OUT = argv[1].rstrip("/\\") + "/f_"
VIEW = PLAN["view"]
NSEG = 6

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = VIEW["width"], VIEW["height"]
sc.render.fps = PLAN["fps"]
sc.frame_start, sc.frame_end = 1, PLAN["n"]
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.filepath = OUT
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.render.film_transparent = True
sh = sc.display.shading
sh.light = "FLAT"
sh.color_type = "MATERIAL"
sc.display.render_aa = "8"
sc.view_settings.view_transform = "Standard"


def mat(c):
    m = bpy.data.materials.new("m")
    m.diffuse_color = (c[0], c[1], c[2], 1)
    return m


SKIN = mat((0.93, 0.93, 0.90))
DIAM = mat((0.35, 0.90, 0.95))


def empty(name, parent, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    sc.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o


def sphere(r, parent, loc, m, seg=24, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=seg // 2)
    o = bpy.context.object
    o.parent, o.location, o.scale = parent, loc, scale
    o.data.materials.append(m)
    return o


def limb(name, parent, length, ink, loc=(0, 0, 0), r=0.030):
    j = empty(name, parent, loc)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r, radius2=r, depth=length)
    c = bpy.context.object
    c.parent, c.location = j, (0, 0, -length / 2)
    c.data.materials.append(ink)
    sphere(r, j, (0, 0, 0), ink, 10)
    return j


def chain(name, parent, total, ink):
    seg = total / NSEG
    js, par, pos = [], parent, (0, 0, 0)
    for i in range(NSEG):
        j = limb(f"{name}{i}", par, seg, ink, pos)
        js.append(j)
        par, pos = j, (0, 0, -seg)
    return js, seg


def make_figure(tag, color, weapon, front):
    ink = mat(color)
    F = {}
    F["root"] = root = empty(tag + "root", None)
    F["hip"] = hip = empty(tag + "hip", root, (0, 0, 0.92))
    F["chest"] = chest = empty(tag + "chest", hip)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.030, depth=0.66, vertices=16)
    tor = bpy.context.object
    tor.parent, tor.location = chest, (0, 0, 0.33)
    tor.data.materials.append(ink)
    F["neck"] = neck = empty(tag + "neck", chest, (0, 0, 0.66))
    F["head"] = head = empty(tag + "head", neck)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.03, major_segments=36, minor_segments=10)
    ring = bpy.context.object
    ring.rotation_euler = (math.pi / 2, 0, 0)
    ring.parent, ring.location = head, (0, 0, 0.24)
    ring.data.materials.append(ink)
    for side, x in (("L", -0.115), ("R", 0.115)):
        s = empty(tag + "sh" + side, chest, (x, 0, 0.6))
        js, seg = chain(tag + "arm" + side, s, 0.66, ink)
        sphere(0.034, js[-1], (0, 0, -seg), ink, 12)
        F["arm" + side] = js
    for side, x in (("L", -0.07), ("R", 0.07)):
        h = empty(tag + "hp" + side, hip, (x, 0, 0))
        js, seg = chain(tag + "leg" + side, h, 0.90, ink)
        sphere(0.032, js[-1], (0.04, 0, -seg + 0.01), ink, 12, (1.7, 0.9, 0.6))
        F["leg" + side] = js
    if weapon == "sword":
        hand = F["arm" + front][-1]
        bpy.ops.mesh.primitive_cube_add(size=1)
        blade = bpy.context.object
        blade.scale = (0.045, 0.02, 0.85)
        blade.parent, blade.location = hand, (0, 0, -0.11 - 0.43)
        blade.data.materials.append(DIAM)
        bpy.ops.mesh.primitive_cube_add(size=1)
        guard = bpy.context.object
        guard.scale = (0.18, 0.03, 0.04)
        guard.parent, guard.location = hand, (0, 0, -0.13)
        guard.data.materials.append(DIAM)
        F["extra"] = [blade, guard]
    F["objs"] = [v for k, v in F.items() if k in ("root", "hip", "chest", "neck", "head")]
    for k in ("armL", "armR", "legL", "legR"):
        F["objs"] += F[k]
    F["objs"] += F.get("extra", [])
    return F


def set_chain(js, th_up, th_low):
    n = len(js)
    prev = 0.0
    for i, j in enumerate(js):
        u = (i + 0.5) / n
        t = max(0.0, min(1.0, (u - 0.2) / 0.6))
        w = t * t * (3 - 2 * t)
        ang = th_up * (1 - w) + th_low * w
        j.rotation_euler = (0, ang - prev, 0)
        prev = ang


RIG = {}
for who, a in PLAN["actors"].items():
    s = 1 if a.get("facing", 1) >= 0 else -1
    front, rear = ("R", "L") if s == 1 else ("L", "R")
    RIG[who] = dict(F=make_figure(who + "_", a["color"], a.get("weapon"), front), s=s, front=front, rear=rear, scale=a.get("scale", 1.0))

cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
sc.camera = co

for f, fr in enumerate(PLAN["frames"], start=1):
    for who, R in RIG.items():
        p, F, s, fa, ra, sca = fr["actors"][who], R["F"], R["s"], R["front"], R["rear"], R["scale"]
        F["root"].scale = (sca, sca, sca)
        F["root"].location = (p["root_x"], 0, p["root_z"])
        F["root"].rotation_euler = (0, -p["roll"] * s, 0)
        F["hip"].location = (0, 0, p["hz"])
        F["chest"].rotation_euler = (0, p["lean"] * s, p["spin"])
        F["head"].rotation_euler = (0, -p["ht"] * s, 0)
        set_chain(F["arm" + fa], -p["fa"] * s, -(p["fa"] + p["fe"]) * s)
        set_chain(F["arm" + ra], -p["ra"] * s, -(p["ra"] + p["re"]) * s)
        set_chain(F["leg" + fa], -p["fl"] * s, (-p["fl"] + p["fk"]) * s)
        set_chain(F["leg" + ra], -p["rl"] * s, (-p["rl"] + p["rk"]) * s)
        F["arm" + fa][0].scale = (1, 1, 1 + p["st"])
        F["leg" + fa][0].scale = (1, 1, 1 + p["lst"])
        for o in F["objs"]:
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    c = fr["cam"]
    cam.ortho_scale = c["scale"]
    cam.keyframe_insert("ortho_scale", frame=f)
    co.location = (c["x"], -10.0, c["z"])
    co.rotation_euler = (math.radians(90), 0, 0)
    co.keyframe_insert("location", frame=f)
    co.keyframe_insert("rotation_euler", frame=f)

bpy.ops.render.render(animation=True)
