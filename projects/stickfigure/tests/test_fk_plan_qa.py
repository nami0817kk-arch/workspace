import copy
from pathlib import Path

import pytest

from stickfig import fk, plan, pose, qa

SCENE = Path(__file__).resolve().parents[1] / "scenes" / "showpiece.yaml"


def stand(**kw):
    p = dict(pose.STANCE_A, hz=0.92, lean=0, fa=0, fe=0, ra=0, re=0, fl=0, fk=0, rl=0, rk=0)
    p.update(kw)
    return p


def test_standing_figure_geometry():
    sk = fk.skeleton(stand(), 1, 0.0, 1.0)
    assert sk["foot"][1] == pytest.approx(0.02, abs=1e-6)       # 足は地面すれすれ
    assert sk["head"][1] == pytest.approx(0.92 + 0.66 + 0.24)
    assert sk["hand"][1] == pytest.approx(0.92 + 0.60 - 0.66)    # 肩から腕の長さぶん下


def test_facing_mirrors_forward_swing():
    r = fk.skeleton(stand(fl=1.0), 1, 0.0, 1.0)["foot"]
    l = fk.skeleton(stand(fl=1.0), -1, 0.0, 1.0)["foot"]
    assert r[0] > 0.5 and l[0] < -0.5 and r[1] == pytest.approx(l[1])


def test_scale_scales_positions():
    a = fk.skeleton(stand(), 1, 0.0, 1.0)["head"]
    b = fk.skeleton(stand(), 1, 0.0, 1.45)["head"]
    assert b[1] == pytest.approx(a[1] * 1.45)


def test_roll_lays_figure_down():
    sk = fk.skeleton(stand(roll=1.5707963, hz=0.92), -1, 5.0, 1.0)
    assert sk["head"][1] < 0.4          # 頭が地面近くに来る


def test_distance_helpers():
    assert fk.dist_point_segment((0, 1), (-1, 0), (1, 0)) == pytest.approx(1.0)
    assert fk.dist_point_segment((3, 0), (-1, 0), (1, 0)) == pytest.approx(2.0)


@pytest.fixture(scope="module")
def built():
    scene = plan.load_scene(SCENE)
    return scene, plan.build_plan(scene)


def test_plan_shape(built):
    scene, pl = built
    assert pl["n"] == len(pl["frames"]) > 100
    assert set(pl["frames"][0]["actors"]) == {"A", "B"}
    assert {e["kind"] for e in pl["events"]} >= {"kick", "wall", "heel"}


def test_contact_solver_reaches_target(built):
    _, pl = built
    for c in pl["contacts"]:
        assert c["distance_to_body"] < 0.12, c


def test_gate_passes_on_showpiece(built):
    _, pl = built
    res = qa.run_gate(pl)
    assert res["passed"], qa.format_report(res)


def test_gate_catches_missing_contact():
    """接触の調整を切ると、足が相手に届かず不合格になる(点検が効いている証拠)。"""
    scene = plan.load_scene(SCENE)
    pl = plan.build_plan(scene, solve=False)
    pl["contacts"] = [dict(tau=2.7, striker="A", target="B", effector="foot", distance_to_body=0.8,
                           distance_to_point=0.9, effector_pos=[0, 0], target_pos=[0, 0])]
    res = qa.run_gate(pl)
    assert not res["passed"] and any(n.startswith("contact") for n in res["failed"])


def test_gate_catches_long_hit_stop():
    scene = plan.load_scene(SCENE)
    scene = copy.deepcopy(scene)
    next(h for h in scene["hits"] if h["kind"] == "kick")["hold"] = 0.4
    res = qa.run_gate(plan.build_plan(scene))
    assert "hit_stop@2.7" in res["failed"]


def test_gate_catches_ground_penetration():
    scene = copy.deepcopy(plan.load_scene(SCENE))
    for a in scene["actors"].values():
        a["plant"] = False            # 足の接地を切ると、しゃがみで足が地面に潜る
    res = qa.run_gate(plan.build_plan(scene))
    assert "ground" in res["failed"]


def test_planter_keeps_feet_above_ground():
    actor = {"scale": 1.0, "facing": 1}
    pl = plan.Planter(actor)
    p = dict(pose.STANCE_A, hz=0.5, fl=0.8, fk=0.0, rl=-0.3, rk=0.0)
    for _ in range(30):
        q = pl.apply(p, 1 / 30)
    sk = fk.skeleton(q, 1, 0.0, 1.0)
    assert min(pt[1] for pt in sk["front_leg"]) >= -0.02
    assert q["fk"] > 0.5              # 膝を曲げて足を地面に合わせた


def test_scene_validation():
    with pytest.raises(ValueError):
        plan.validate_scene({"fps": 30})
    bad = copy.deepcopy(plan.load_scene(SCENE))
    bad["keys"]["A"].reverse()
    with pytest.raises(ValueError):
        plan.validate_scene(bad)
