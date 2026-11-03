"""Blender 側: 場面の組み立て(描き方の設定・空・床・マット・台・球)。grey=True は色と光を省いた下見。"""
from __future__ import annotations

import math

import bpy
from mathutils import Vector


def setup_render(size, fps: int, grey: bool, exposure: float = 0.0):
    sc = bpy.context.scene
    sc.render.fps = fps
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.resolution_percentage = 50 if grey else 100
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except Exception:
            pass
    try:
        sc.eevee.taa_render_samples = 4 if grey else 16
    except Exception:
        pass
    for k, v in (("use_shadows", True), ("use_raytracing", False)):
        try:
            setattr(sc.eevee, k, v)
        except Exception:
            pass
    try:
        sc.view_settings.view_transform = "Standard" if grey else "AgX"
        sc.view_settings.exposure = 0.0 if grey else exposure
    except Exception:
        pass
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    return sc


def material(name: str, color=(0.8, 0.8, 0.8), rough: float = 0.6, emission=None):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def glow_material(name: str = "fx", fade_z: bool = False):
    """透ける光の材質。色と濃さは物体の color(RGBA)で決める(Object Info)。
    fade_z=True は物体の z の向き(生成座標 0→1)に沿って薄くなる(光の筋の円すい用)。"""
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 2.5
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(info.outputs["Color"], em.inputs["Color"])
    alpha = info.outputs["Alpha"]
    if fade_z:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
        nt.links.new(sep.outputs["Z"], inv.inputs[1])
        pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 1.8
        nt.links.new(inv.outputs[0], pw.inputs[0])
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        nt.links.new(pw.outputs[0], mul.inputs[0])
        nt.links.new(alpha, mul.inputs[1])
        alpha = mul.outputs[0]
    nt.links.new(alpha, mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    for k, v in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND"), ("use_transparency_overlap", True)):
        try:
            setattr(m, k, v)
        except Exception:
            pass
    return m


def sun_from_hdr(img) -> Vector:
    """HDR の一番明るい所(太陽)の向き(Blender の正距円筒の向きに合わせる)。"""
    import numpy as np
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    lum = px.reshape(h, w, 4)[:, :, :3].sum(axis=2)
    y, x = np.unravel_index(int(np.argmax(lum)), lum.shape)
    u, v = (x + 0.5) / w, (y + 0.5) / h
    phi = (u - 0.5) * 2 * math.pi
    el = (v - 0.5) * math.pi
    return Vector((-math.cos(phi) * math.cos(el), math.sin(phi) * math.cos(el), math.sin(el)))


def world(sky_path: str | None, sun_dir_xy=(0.35, -1.0), grey: bool = False):
    w = bpy.data.worlds.new("sky")
    bpy.context.scene.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    nt = w.node_tree
    bg = nt.nodes.get("Background")
    if grey or not sky_path:
        bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
        bg.inputs["Strength"].default_value = 1.0
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = 3.0
        o = bpy.data.objects.new("sun", sun)
        bpy.context.scene.collection.objects.link(o)
        o.rotation_euler = (math.radians(40), 0, math.radians(30))
        return None
    img = bpy.data.images.load(sky_path)
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = img
    mp = nt.nodes.new("ShaderNodeMapping")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], env.inputs["Vector"])
    hs = nt.nodes.new("ShaderNodeHueSaturation")          # 青空を少し濃く
    hs.inputs["Saturation"].default_value = 1.45
    nt.links.new(env.outputs["Color"], hs.inputs["Color"])
    nt.links.new(hs.outputs["Color"], bg.inputs["Color"])
    # 太陽が望みの向き(水平の向き sun_dir_xy)に来るよう、空を z まわりに回す
    s = sun_from_hdr(img)
    want = math.atan2(sun_dir_xy[1], sun_dir_xy[0])
    have = math.atan2(s.y, s.x)
    rz = want - have
    mp.inputs["Rotation"].default_value = (0, 0, rz)
    el = math.asin(max(-1.0, min(1.0, s.z)))
    sdir = Vector((math.cos(want) * math.cos(el), math.sin(want) * math.cos(el), math.sin(el)))
    # EEVEE は空の明るい所を太陽として影を付ける。付かない版のために弱い太陽の灯りも置く
    try:
        w.sun_threshold = 10.0
        w.sun_angle = math.radians(1.5)
        w.use_sun_shadow = True
    except Exception:
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = 3.0
        o = bpy.data.objects.new("sun", sun)
        bpy.context.scene.collection.objects.link(o)
        o.rotation_euler = sdir.to_track_quat("Z", "Y").to_euler()
    return sdir


def ground(colors, grey: bool = False, size: float = 400.0):
    bpy.ops.mesh.primitive_plane_add(size=size)
    g = bpy.context.active_object
    g.name = "ground"
    m = material("ground", colors[0], 0.75)
    if not grey:
        nt = m.node_tree
        b = nt.nodes.get("Principled BSDF")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        ck = nt.nodes.new("ShaderNodeTexChecker")
        ck.inputs["Scale"].default_value = 1.0
        ck.inputs["Color1"].default_value = (*colors[0], 1)
        ck.inputs["Color2"].default_value = (*colors[1], 1)
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (0.5, 0.5, 0.5)    # 市松の1マス = 1 m
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], ck.inputs["Vector"])
        nt.links.new(ck.outputs["Color"], b.inputs["Base Color"])
    g.data.materials.append(m)
    return g


def box(name, center, size, color, rough=0.8):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    try:
        bpy.ops.object.transform_apply(scale=True)
    except Exception:
        pass
    o.data.materials.append(material(name, color, rough))
    return o


def mat_wall(mat: dict, color, grey=False):
    sx, sy, sz = mat["size"]
    o = box("mat", (mat["x"], 0, sz / 2), (sx, sy, sz), (0.7, 0.7, 0.7) if grey else color, 0.95)
    # 角を丸める(柔らかいマットらしく)
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = 0.06
    mod.segments = 4
    return o


def tee(ball_pos, radius, grey=False):
    """球を載せる細い台(拳の当たる高さに球を置く)。"""
    top = ball_pos[2] - radius * 0.85
    bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=top, location=(ball_pos[0], ball_pos[1], top / 2), vertices=16)
    pole = bpy.context.active_object
    pole.name = "tee"
    m = material("tee", (0.9, 0.9, 0.9), 0.4)
    pole.data.materials.append(m)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=0.03, location=(ball_pos[0], ball_pos[1], 0.015), vertices=32)
    base = bpy.context.active_object
    base.data.materials.append(m)
    bpy.ops.mesh.primitive_torus_add(major_radius=radius * 0.45, minor_radius=0.01, location=(ball_pos[0], ball_pos[1], top))
    cup = bpy.context.active_object
    cup.data.materials.append(m)
    return pole


def ball(radius, color, band, grey=False):
    """球: 親(位置と潰れ・世界の軸)→子(回転)。帯を2本描いて回っているのが見えるようにする。"""
    root = bpy.data.objects.new("ball_root", None)
    bpy.context.scene.collection.objects.link(root)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=48, ring_count=24)
    b = bpy.context.active_object
    b.name = "ball"
    b.parent = root
    b.rotation_mode = "QUATERNION"
    try:
        b.data.shade_smooth()
    except Exception:
        bpy.ops.object.shade_smooth()
    m = material("ball", (0.75, 0.75, 0.75) if grey else color, 0.45)
    nt = m.node_tree
    bs = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    c1 = nt.nodes.new("ShaderNodeMath"); c1.operation = "COMPARE"; c1.inputs[1].default_value = 0.0; c1.inputs[2].default_value = radius * 0.12
    c2 = nt.nodes.new("ShaderNodeMath"); c2.operation = "COMPARE"; c2.inputs[1].default_value = 0.0; c2.inputs[2].default_value = radius * 0.12
    nt.links.new(sep.outputs["Z"], c1.inputs[0])
    nt.links.new(sep.outputs["Y"], c2.inputs[0])
    mx = nt.nodes.new("ShaderNodeMath"); mx.operation = "MAXIMUM"
    nt.links.new(c1.outputs[0], mx.inputs[0]); nt.links.new(c2.outputs[0], mx.inputs[1])
    mixc = nt.nodes.new("ShaderNodeMix"); mixc.data_type = "RGBA"
    mixc.inputs["A"].default_value = (*((0.75, 0.75, 0.75) if grey else color), 1)
    mixc.inputs["B"].default_value = (*((0.2, 0.2, 0.2) if grey else band), 1)
    nt.links.new(mx.outputs[0], mixc.inputs["Factor"])
    nt.links.new(mixc.outputs["Result"], bs.inputs["Base Color"])
    b.data.materials.append(m)
    return root, b


def camera():
    cd = bpy.data.cameras.new("cam")
    cd.sensor_width = 36
    cd.clip_start = 0.05
    cd.clip_end = 500
    c = bpy.data.objects.new("cam", cd)
    bpy.context.scene.collection.objects.link(c)
    bpy.context.scene.camera = c
    return c


def aim(cam, loc, target, lens):
    cam.location = Vector(loc)
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
