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
MODE = argv[2] if len(argv) > 2 else "figs"      # figs=人物だけ(透過) / stage=舞台だけ(遠近のとき)
VIEW = PLAN["view"]
PERSP = bool(VIEW.get("persp"))
NSEG = 6
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__))))
from stickfig import camera as cam_math  # noqa: E402  (純粋な Python。Blender の Python から読める)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = VIEW["width"], VIEW["height"]
sc.render.fps = PLAN["fps"]
sc.frame_start, sc.frame_end = 1, int(__import__("os").environ.get("STICKFIG_FRAMES", PLAN["n"]))   # STICKFIG_FRAMES: 見た目の確認用に先頭だけ書き出す
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.filepath = OUT
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.render.film_transparent = MODE == "figs"
sh = sc.display.shading
FLAT2D = PLAN.get("scene", {}).get("style") == "flat2d"
sh.light = "STUDIO" if (PERSP and not FLAT2D) else "FLAT"           # 遠近のときは陰影を付ける(立体に見える)
sh.color_type = "MATERIAL"
if PERSP:
    sh.show_specular_highlight = False
    sh.show_object_outline = False                 # 輪郭線は付けない(節ごとの縁取りが竹のように見える)
    try:
        sh.object_outline_color = (0.02, 0.02, 0.03)
    except Exception:
        pass
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


def limb(name, parent, length, ink, loc=(0, 0, 0), r=0.036):
    j = empty(name, parent, loc)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r, radius2=r, depth=length)
    c = bpy.context.object
    c.parent, c.location = j, (0, 0, -length / 2)
    c.data.materials.append(ink)
    sphere(r, j, (0, 0, 0), ink, 10)
    return j


LIMB = PLAN.get("scene", {}).get("limb") or {}        # 線の太さ: {base: 根元の半径, tip: 先の半径, tip_color: 先の2節の色}(Alan Becker は根元が太く先が細い。手足の先は暗い色)


def chain(name, parent, total, ink):
    seg = total / NSEG
    js, par, pos = [], parent, (0, 0, 0)
    rb, rt = LIMB.get("base", 0.036), LIMB.get("tip", 0.036)
    tip_ink = mat(LIMB["tip_color"]) if LIMB.get("tip_color") else ink
    for i in range(NSEG):
        r = rb + (rt - rb) * (i / (NSEG - 1))
        j = limb(f"{name}{i}", par, seg, tip_ink if i >= NSEG - 2 else ink, pos, r)
        js.append(j)
        par, pos = j, (0, 0, -seg)
    return js, seg


# 武器(fk.WEAPON_TIP と長さをそろえる: 先端 = 0.115 + len)。w, t は太さ、guard は鍔、head は穂先
WEAPONS = {
    "sword": dict(len=0.85, w=0.045, t=0.02, guard=True),
    "dagger": dict(len=0.42, w=0.04, t=0.02, guard=True),
    "staff": dict(len=1.5, w=0.04, t=0.04, color=(0.45, 0.3, 0.15)),
    "spear": dict(len=1.5, w=0.035, t=0.035, color=(0.45, 0.3, 0.15), head=True),
}


def make_figure(tag, color, weapon, front):
    ink = mat(color)
    F = {}
    F["root"] = root = empty(tag + "root", None)
    F["hip"] = hip = empty(tag + "hip", root, (0, 0, 0.92))
    F["chest"] = chest = empty(tag + "chest", hip)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.042, depth=0.66, vertices=20)
    tor = bpy.context.object
    tor.parent, tor.location = chest, (0, 0, 0.33)
    tor.data.materials.append(ink)
    F["neck"] = neck = empty(tag + "neck", chest, (0, 0, 0.66))
    F["head"] = head = empty(tag + "head", neck)
    sphere(0.215, head, (0, 0, 0.215), ink, 32)        # 頭は中まで塗りつぶした球(首の位置に重ねて、すき間を無くす)
    for side, y in (("L", 0.07), ("R", -0.07)):          # 付け根は胴の線の真上。左右は奥行きだけずらす
        s = empty(tag + "sh" + side, chest, (0, y, 0.6))
        js, seg = chain(tag + "arm" + side, s, 0.66, ink)
        sphere(0.034, js[-1], (0, 0, -seg), ink, 12)
        F["arm" + side] = js
    for side, y in (("L", 0.05), ("R", -0.05)):
        h = empty(tag + "hp" + side, hip, (0, y, 0))
        js, seg = chain(tag + "leg" + side, h, 0.90, ink)
        sphere(0.032, js[-1], (0.04, 0, -seg + 0.01), ink, 12, (1.7, 0.9, 0.6))
        F["leg" + side] = js
    if weapon in WEAPONS:
        W_ = WEAPONS[weapon]
        L = W_["len"]
        hand = F["arm" + front][-1]
        bpy.ops.mesh.primitive_cube_add(size=1)
        blade = bpy.context.object
        blade.scale = (W_["w"], W_["t"], L)
        blade.parent, blade.location = hand, (0, 0, -0.115 - L / 2)
        blade.data.materials.append(mat(W_["color"]) if W_.get("color") else DIAM)
        F["extra"] = [blade]
        if W_.get("guard"):
            bpy.ops.mesh.primitive_cube_add(size=1)
            guard = bpy.context.object
            guard.scale = (0.18, 0.03, 0.04)
            guard.parent, guard.location = hand, (0, 0, -0.13)
            guard.data.materials.append(DIAM)
            F["extra"].append(guard)
        if W_.get("head"):                              # 槍の穂先
            bpy.ops.mesh.primitive_cube_add(size=1)
            head_ = bpy.context.object
            head_.scale = (0.09, 0.025, 0.26)
            head_.parent, head_.location = hand, (0, 0, -0.115 - L - 0.05)
            head_.data.materials.append(DIAM)
            F["extra"].append(head_)
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


def box(name, x0, x1, y0, y1, z0, z1, color):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    o.location = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    o.data.materials.append(mat(color))
    return o


# 舞台の色の組(theme)。台本の stage: {theme: dojo} で選ぶ。cave が既定
THEMES = {
    "cave": dict(floor=(0.34, 0.31, 0.27), joint=(0.24, 0.22, 0.18), joint2=(0.26, 0.24, 0.20), back=(0.17, 0.17, 0.20), ledge=(0.13, 0.13, 0.16),
                 pillar=(0.28, 0.21, 0.14), crate=(0.22, 0.20, 0.17), wall=(0.27, 0.26, 0.25), wall_line=(0.18, 0.17, 0.16), world=(0.10, 0.10, 0.12)),
    "dojo": dict(floor=(0.55, 0.38, 0.22), joint=(0.42, 0.28, 0.15), joint2=(0.46, 0.31, 0.17), back=(0.82, 0.76, 0.62), ledge=(0.55, 0.42, 0.28),
                 pillar=(0.33, 0.18, 0.09), crate=(0.45, 0.30, 0.18), wall=(0.80, 0.72, 0.58), wall_line=(0.55, 0.42, 0.28), world=(0.30, 0.25, 0.2)),
    "field": dict(floor=(0.36, 0.52, 0.26), joint=(0.31, 0.46, 0.22), joint2=(0.33, 0.49, 0.24), back=(0.55, 0.76, 0.95), ledge=(0.6, 0.8, 0.97),
                  pillar=(0.28, 0.2, 0.12), crate=(0.5, 0.5, 0.52), wall=(0.5, 0.5, 0.52), wall_line=(0.38, 0.38, 0.4), world=(0.55, 0.75, 0.95)),
    "night": dict(floor=(0.13, 0.14, 0.22), joint=(0.09, 0.10, 0.17), joint2=(0.10, 0.11, 0.18), back=(0.05, 0.05, 0.12), ledge=(0.16, 0.16, 0.32),
                  pillar=(0.22, 0.22, 0.34), crate=(0.16, 0.16, 0.24), wall=(0.2, 0.2, 0.3), wall_line=(0.12, 0.12, 0.2), world=(0.03, 0.03, 0.08)),
    "sunset": dict(floor=(0.50, 0.34, 0.30), joint=(0.40, 0.26, 0.24), joint2=(0.42, 0.28, 0.25), back=(0.96, 0.55, 0.34), ledge=(0.85, 0.42, 0.28),
                   pillar=(0.38, 0.30, 0.30), crate=(0.4, 0.3, 0.28), wall=(0.42, 0.34, 0.34), wall_line=(0.3, 0.24, 0.24), world=(0.9, 0.5, 0.3)),
}
TH = THEMES.get(PLAN.get("stage", {}).get("theme", "cave"), THEMES["cave"])


def build_stage():
    """床・奥の壁・柱・壁(あれば)を、立体で置く。遠近カメラで見ると、奥行きが出る。色は THEMES。"""
    wall_x = PLAN.get("stage", {}).get("wall_x")
    box("floor", -60, 60, -10, 16, -0.3, 0.0, TH["floor"])
    for i in range(-40, 60):                           # 床の目地(奥へ伸びる線)
        box("fl", i - 0.015, i + 0.015, -10, 16, 0.0, 0.004, TH["joint"])
    for j in range(-10, 16, 2):                        # 手前から奥への横の目地
        box("fy", -60, 60, j - 0.015, j + 0.015, 0.0, 0.004, TH["joint2"])
    box("back", -60, 60, 9, 9.4, 0.0, 14, TH["back"])          # 奥の壁
    for k in range(1, 12):
        box("ledge", -60, 60, 8.9, 9.0, k * 1.2, k * 1.2 + 0.05, TH["ledge"])
    for n, x in enumerate(range(-16, 40, 3)):          # 柱(奥行きが違う)
        y = 3.5 + (n % 4) * 1.4
        box("pillar", x, x + 0.22, y, y + 0.22, 0.0, 3.0, TH["pillar"])
    for n, x in enumerate(range(-14, 40, 4)):          # 手前の低い箱(奥行きの手がかり)
        box("crate", x, x + 0.7, -3.2 - (n % 3) * 0.5, -2.5 - (n % 3) * 0.5, 0.0, 0.5, TH["crate"])
    if wall_x is not None:
        box("wall", wall_x, wall_x + 2.5, -5, 9, 0.0, 6.5, TH["wall"])
        for k in range(1, 12):
            box("wl", wall_x - 0.02, wall_x + 0.02, -5, 9, k * 0.55, k * 0.55 + 0.03, TH["wall_line"])


RIG = {}
if MODE == "stage":
    build_stage()
    world = bpy.data.worlds.new("w")
    world.color = TH["world"]
    sc.world = world
for who, a in (PLAN["actors"].items() if MODE == "figs" else []):
    s = 1 if a.get("facing", 1) >= 0 else -1
    front, rear = ("R", "L") if s == 1 else ("L", "R")
    RIG[who] = dict(F=make_figure(who + "_", a["color"], a.get("weapon"), front), s=s, front=front, rear=rear, scale=a.get("scale", 1.0))

cam = bpy.data.cameras.new("cam")
cam.type = "PERSP" if PERSP else "ORTHO"
if PERSP:
    cam.lens = VIEW.get("lens", 40.0)
    cam.sensor_width = 36.0
    cam.sensor_fit = "HORIZONTAL"
    cam.clip_end = 400.0
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
sc.camera = co
if PERSP:
    co.rotation_mode = "QUATERNION"

for f, fr in enumerate(PLAN["frames"], start=1):
    for who, R in RIG.items():
        p, F, s, fa, ra, sca = fr["actors"][who], R["F"], R["s"], R["front"], R["rear"], R["scale"]
        if p.get("dir"):                                   # 姿勢の dir で向きを変える(位置は facing のまま、絵だけ左右反転)
            s = 1 if p["dir"] > 0 else -1
        F["root"].scale = (sca, sca, sca)
        F["root"].location = (p["root_x"], PLAN["actors"][who].get("y", 0.0), p["root_z"])
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
    if PERSP:
        from mathutils import Vector
        pos = Vector(cam_math.position(c))
        co.location = pos
        co.rotation_quaternion = (Vector((c["tx"], c["ty"], c["tz"])) - pos).to_track_quat("-Z", "Y")
        co.keyframe_insert("location", frame=f)
        co.keyframe_insert("rotation_quaternion", frame=f)
    else:
        cam.ortho_scale = c["scale"]
        cam.keyframe_insert("ortho_scale", frame=f)
        co.location = (c["x"], -10.0, c["z"])
        co.rotation_euler = (math.radians(90), 0, 0)
        co.keyframe_insert("location", frame=f)
        co.keyframe_insert("rotation_euler", frame=f)

bpy.ops.render.render(animation=True)
