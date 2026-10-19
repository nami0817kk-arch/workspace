import math

import numpy as np
import pytest
from PIL import Image

from stickfig import anime, camera, plan

SCENE = None


def tiny_plan(n=20, events=None):
    cam = camera.make_cam(0.0, 0.0, 8.0, 15.0, 7.0, 40.0)
    frames = []
    for f in range(n):
        a = dict(fa=0.5, fe=1.0, ra=0.5, re=1.0, fl=0.3, fk=0.3, rl=-0.3, rk=0.3, lean=0.0, hz=0.92, rz=0.0, roll=0.0,
                 ht=0.0, root_x=0.1 * f, root_z=0.0)
        frames.append(dict(tau=f / 30, actors={"A": a}, cam=dict(cam, roll=0.0)))
    return dict(fps=30, n=n, actors={"A": {"scale": 1.0, "facing": 1, "weapon": "sword"}}, frames=frames,
                events=events or [], view=dict(persp=True, lens=40.0), scene={})


def test_chaikin_smooths_and_keeps_ends():
    pts = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)]
    out = anime.chaikin(pts, 2)
    assert out[0] == pts[0] and out[-1] == pts[-1] and len(out) > len(pts)
    assert (10.0, 0.0) not in out                    # 角が落ちる


def test_sfx_appears_after_event_and_fades():
    ev = [dict(frame=3, kind="kick", pos=[0.5, 1.2], tau=0.1, hold_frames=2)]
    pl = tiny_plan(events=ev)
    assert anime.sfx_overlay(pl, 2, {}) is None       # 命中の前は出ない
    ov = anime.sfx_overlay(pl, 4, {})
    assert ov is not None and ov.getbbox() is not None
    assert anime.sfx_overlay(pl, 19, {}) is None      # 十分あとには消える


def test_custom_sfx_text_is_used():
    ev = [dict(frame=0, kind="kick", pos=[0.0, 1.0], tau=0.0, hold_frames=0)]
    a = anime.sfx_overlay(tiny_plan(events=ev), 1, {"sfx_text": {"kick": "!"}})
    b = anime.sfx_overlay(tiny_plan(events=ev), 1, {})
    assert a.getbbox()[2] - a.getbbox()[0] < b.getbbox()[2] - b.getbbox()[0]     # 短い文字は幅が小さい


def test_trails_only_when_fast():
    pl = tiny_plan()
    assert anime.trails(pl, 10, {"trail_speed": 5.0}, {}) is None        # しきい値を高くすると出ない
    # 速く動く(1コマ 0.1 → 身長比 0.05)。しきい値を下げれば出る
    assert anime.trails(pl, 10, {"trail_speed": 0.01}, {}) is not None


def test_tilt_keeps_size_and_zero_is_identity():
    im = Image.new("RGB", (1280, 720), (50, 80, 120))
    assert anime.tilt(im, 0.0) is im
    assert anime.tilt(im, 3.0).size == (1280, 720)


def test_grade_keeps_size_and_darkens_corners():
    im = Image.new("RGB", (1280, 720), (160, 160, 160))
    out = np.asarray(anime.grade(im))
    assert out.shape == (720, 1280, 3)
    assert out[5, 5].mean() < out[360, 640].mean()    # 四隅が暗い(ビネット)


def test_zoom_blur_zero_is_identity():
    im = Image.new("RGB", (1280, 720), (10, 20, 30))
    assert anime.zoom_blur(im, 640, 360, 0.0) is im
