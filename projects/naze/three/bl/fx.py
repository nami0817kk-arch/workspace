"""Blender 側: 効果(衝撃の輪・光の玉・光の筋・空気の線・一瞬の灯り)。

数を決めて先に作っておき(プール)、コマごとに plan の値を当てはめる。使わないものは隠す。
"""
from __future__ import annotations

import math

import bpy
from mathutils import Vector

from .scene import glow_material


def _hide(o, h: bool):
    o.hide_render = h
    o.hide_viewport = h


def _no_shadow(o):
    for k in ("visible_shadow",):
        try:
            setattr(o, k, False)
        except Exception:
            pass


class FX:
    def __init__(self, color=(1.0, 0.93, 0.7), n_rings=4, n_flash=2, n_trail=1, n_lines=6):
        self.color = color
        self.mat = glow_material("fx")
        self.mat_trail = glow_material("fx_trail", fade_z=True)
        self.rings = [self._make("ring", lambda: bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.03, major_segments=64, minor_segments=8)) for _ in range(n_rings)]
        self.flashes = [self._make("flash", lambda: bpy.ops.mesh.primitive_ico_sphere_add(radius=1.0, subdivisions=3)) for _ in range(n_flash)]
        self.trail = [self._make("trail", lambda: bpy.ops.mesh.primitive_cone_add(radius1=1.0, radius2=0.0, depth=1.0, vertices=24), self.mat_trail) for _ in range(n_trail)]
        self.lines = [self._make("line", lambda: bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=1.0, vertices=8)) for _ in range(n_lines)]
        ld = bpy.data.lights.new("fxlight", "POINT")
        ld.shadow_soft_size = 0.2
        try:
            ld.use_shadow = False          # 一瞬の灯りの影はざらつくので付けない
        except Exception:
            pass
        self.light = bpy.data.objects.new("fxlight", ld)
        bpy.context.scene.collection.objects.link(self.light)
        ld.color = color

    def _make(self, name, add, mat=None):
        add()
        o = bpy.context.active_object
        o.name = name
        o.data.materials.append(mat or self.mat)
        _no_shadow(o)
        _hide(o, True)
        return o

    def _seg(self, o, a, b, radius, alpha):
        a, b = Vector(a), Vector(b)
        d = b - a
        if d.length < 1e-4 or alpha <= 0.005:
            _hide(o, True)
            return
        o.location = (a + b) / 2
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        o.scale = (radius, radius, d.length)
        o.color = (*self.color, alpha)
        _hide(o, False)

    def apply(self, fx: dict):
        for o, r in zip(self.rings, fx["rings"] + [None] * len(self.rings)):
            if r is None:
                _hide(o, True)
                continue
            o.location = r["pos"]
            o.rotation_euler = (0, math.radians(90), 0) if r.get("axis", "x") == "x" else (0, 0, 0)
            o.scale = (r["radius"], r["radius"], r["thick"] / 0.03 * r["radius"])
            o.color = (*self.color, r["alpha"])
            _hide(o, False)
        for o, f in zip(self.flashes, fx["flashes"] + [None] * len(self.flashes)):
            if f is None:
                _hide(o, True)
                continue
            o.location = f["pos"]
            o.scale = (f["scale"],) * 3
            o.color = (*self.color, f["alpha"])
            _hide(o, False)
        tr = fx["trail"]
        for j, o in enumerate(self.trail):
            if j < len(tr):
                self._seg(o, tr[j]["a"], tr[j]["b"], tr[j]["radius"], tr[j]["alpha"])
            else:
                _hide(o, True)
        ln = fx["lines"]
        for j, o in enumerate(self.lines):
            if j < len(ln):
                self._seg(o, ln[j]["a"], ln[j]["b"], 0.006, ln[j]["alpha"])
            else:
                _hide(o, True)
        if fx.get("light"):
            self.light.location = fx["light"]["pos"]
            self.light.data.energy = fx["light"]["energy"]
            _hide(self.light, False)
        else:
            self.light.data.energy = 0.0
            _hide(self.light, True)
