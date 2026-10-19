import math

import pytest

from stickfig import camera


def test_zero_yaw_pitch_matches_orthographic_scale():
    """yaw=0・pitch=0 なら、y=0 の面で、画面の幅が scale 単位(従来の平行投影と同じ)。"""
    cam = camera.make_cam(0.0, 0.0, 8.0, 0.0, 0.0, 40.0)
    x0, _, _ = camera.project(cam, -4.0, 0.0, 0.0)
    x1, _, _ = camera.project(cam, 4.0, 0.0, 0.0)
    assert x1 - x0 == pytest.approx(1280.0, abs=1.0)


def test_ground_lands_at_ground_px():
    cam = camera.make_cam(1.0, 0.0, 8.0, 0.0, 0.0, 40.0)
    _, py, _ = camera.project(cam, 1.0, 0.0, 0.0)
    assert py == pytest.approx(560.0, abs=0.5)


def test_target_is_screen_centre_horizontally_and_right_is_plus_x():
    cam = camera.make_cam(2.0, 0.0, 8.0, 25.0, 7.0, 40.0)
    px, _, _ = camera.project(cam, 2.0, 0.0, 0.0)
    assert px == pytest.approx(640.0, abs=0.5)
    right, _, _ = camera.project(cam, 3.0, 0.0, 0.0)
    assert right > px


def test_depth_makes_far_things_smaller():
    cam = camera.make_cam(0.0, 0.0, 8.0, 0.0, 0.0, 40.0)
    near = camera.project(cam, 1.0, 0.0, 1.0)
    far = camera.project(cam, 1.0, 6.0, 1.0)
    assert abs(far[0] - 640) < abs(near[0] - 640)        # 奥は画面の中心へ寄る(遠近)


def test_yaw_reveals_depth_axis():
    """斜めから見ると、奥行き(y)の違いが横の位置に出る(3D感の元)。"""
    cam = camera.make_cam(0.0, 0.0, 8.0, 30.0, 0.0, 40.0)
    a = camera.project(cam, 0.0, 0.0, 1.0)
    b = camera.project(cam, 0.0, 3.0, 1.0)
    assert abs(a[0] - b[0]) > 30


def test_legacy_ortho_cam_projection():
    cam = dict(x=1.0, pxu=150.0, sz=0.0)
    assert camera.project(cam, 1.0, 0.0, 0.0)[:2] == (640.0, 560.0)


def test_tempo_speeds_up_timeline():
    from stickfig.interp import build_timeline
    a, _ = build_timeline(3.0, 30, [])
    b, _ = build_timeline(3.0, 30, [], tempo=1.5)
    assert len(b) == pytest.approx(len(a) / 1.5, abs=2)
