"""Blender 側: 人形の読み込みと動きの割り当て(NLA)、拳の先の位置の測定。"""
from __future__ import annotations

import math

import bpy
import numpy as np
from mathutils import Matrix, Vector


def load_character(glb: str, pos=(0, 0, 0), yaw_deg: float = 0.0, color=(0.6, 0.65, 0.72), grey=False):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    body = next(o for o in new if o.type == "MESH" and o.name.startswith("Mannequin"))
    for o in new:                       # glb に入っている余計な物(Icosphere など)は消す
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    arm.location = pos
    arm.rotation_mode = "XYZ"            # glTF の読み込みは四元数にするので、オイラー角で回せるよう戻す
    arm.rotation_euler = (0, 0, math.radians(yaw_deg))
    m = bpy.data.materials.new("body")
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*((0.8, 0.8, 0.8) if grey else color), 1)
    b.inputs["Roughness"].default_value = 0.55
    body.data.materials.clear()
    body.data.materials.append(m)
    try:
        body.data.shade_smooth()
    except Exception:
        pass
    return arm, body


def assign_clips(arm, clips, fps: int, anim_fps: int = 24, blend_s: float = 0.12):
    """clips=[(動きの名前, 始まる時刻[秒], 速さ)]。最初のものは最後まで繰り返し、後のものは上の段に重ねる。
    場面の 0 秒 = フレーム 1。"""
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    end = bpy.context.scene.frame_end
    for j, (name, t0, speed) in enumerate(clips):
        act = bpy.data.actions[name]
        tr = ad.nla_tracks.new()
        tr.name = name
        st = ad.nla_tracks[-1].strips.new(name, int(round(1 + t0 * fps)), act)
        try:
            st.action_slot = act.slots[0]
        except Exception:
            pass
        st.scale = fps / anim_fps / speed
        if j == 0:
            st.repeat = max(1.0, (end - st.frame_start) / max(1.0, st.frame_end - st.frame_start))
            st.extrapolation = "HOLD"
        else:
            st.blend_in = st.blend_out = blend_s * fps
            st.extrapolation = "NOTHING"
    return ad


def set_time(s: float, fps: int):
    f = 1 + s * fps
    bpy.context.scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))


def eval_verts(body) -> np.ndarray:
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3)
    mw = np.array(body.matrix_world)
    return co @ mw[:3, :3].T + mw[:3, 3]


def fist_front(arm, body, hand: str = "r", forward=(1, 0, 0)) -> list:
    """拳の先(手の骨の近くの頂点のうち、前に一番出ている点)。"""
    pb = arm.pose.bones.get(f"middle_01_{hand}") or arm.pose.bones[f"hand_{hand}"]
    c = np.array(arm.matrix_world @ pb.head)
    v = eval_verts(body)
    near = v[np.linalg.norm(v - c, axis=1) < 0.13]
    f = np.array(forward, float)
    i = int(np.argmax(near @ f))
    return near[i].tolist()


def facing(arm) -> list:
    """人形の前の向き(UAL のマネキンは自分の -y が前)。"""
    d = arm.matrix_world.to_3x3() @ Vector((0, -1, 0))
    return list(d.normalized())
