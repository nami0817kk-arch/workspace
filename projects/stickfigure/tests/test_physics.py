import math

import pytest

pymunk = pytest.importorskip("pymunk")

from stickfig import fk, physics, pose  # noqa: E402


def two_scene():
    return {"actors": {"A": {"scale": 1.0, "base_x": 0.0, "facing": 1},
                       "B": {"scale": 1.45, "base_x": 3.0, "facing": -1, "heavy": True}}, "stage": {}, "physics": {}}


def stand_targets():
    a = dict(pose.STANCE_A, hz=0.92, lean=0.05, fl=0.35, fk=0.3, rl=-0.35, rk=0.4)
    b = dict(pose.STANCE_B, hz=0.92)
    return lambda w, t: dict(a if w == "A" else b)


def test_stands_and_tracks_targets():
    """目標の姿勢に、関節のバネが追従する(Chipmunk の回転バネの符号の取り違えを防ぐ)。

    腕・脚は曲線の当てはめで角度の組が変わるので、角度ではなく、先端(手・足)の位置で比べる。"""
    sc = two_scene()
    tf = stand_targets()
    r = physics.simulate(sc, tf, 1.5)
    for who in ("A", "B"):
        a = sc["actors"][who]
        s = 1 if a["facing"] >= 0 else -1
        p = physics.sample(r["states"][who], r["taus"], 1.4, a)
        tg = tf(who, 1.4)
        sk_t = fk.skeleton(dict(tg, rz=0.0), s, a["base_x"], a["scale"])
        sk_o = fk.skeleton(dict(p, rz=0.0), s, p["root_x"], a["scale"])
        for part in ("hand", "foot"):
            d = math.hypot(sk_t[part][0] - sk_o[part][0], sk_t[part][1] - sk_o[part][1])
            assert d < 0.3 * a["scale"], (who, part, d)
        assert p["hz"] == pytest.approx(tg["hz"], abs=0.12)


def test_two_standing_fighters_do_not_cross():
    sc = two_scene()
    r = physics.simulate(sc, stand_targets(), 1.0)
    for who in ("A", "B"):
        p = physics.sample(r["states"][who], r["taus"], 0.9, sc["actors"][who])
        assert p["root_x"] == pytest.approx(sc["actors"][who]["base_x"], abs=0.2)     # 立ったまま動かない


def test_round_trip_pose_to_rig_params():
    """剛体を目標の姿勢に置き→rig のパラメータに戻すと、元に近い(曲線の当てはめが先端を合わせる)。"""
    sc = two_scene()
    space = pymunk.Space()
    actor = sc["actors"]["A"]
    f = physics.Fighter(space, "A", actor, 1, 1)
    tgt = dict(pose.STANCE_A, hz=0.92, lean=0.1, fa=0.9, fe=1.2, ra=-0.4, re=0.8, fl=0.9, fk=1.1, rl=-0.5, rk=0.6)
    f.place(tgt)
    out = physics.convert(f.snapshot(), actor, tgt)
    # 先端(手・足)の位置が合っていれば、曲線の角度が多少違っても良い
    sk_t = fk.skeleton(dict(tgt, rz=0.0), 1, 0.0, 1.0)
    sk_o = fk.skeleton(dict(out, rz=0.0), 1, out["root_x"], 1.0)
    for part in ("hand", "foot"):
        assert math.hypot(sk_t[part][0] - sk_o[part][0] + out["root_x"] * 0, sk_t[part][1] - sk_o[part][1]) < 0.2


def test_kick_boost_launches_target():
    """蹴りが当たる(衝突が起きる)と、威力の上乗せで倒される側が飛ぶ。"""
    sc = two_scene()
    sc["actors"]["B"]["base_x"] = 0.8
    sc["physics"] = {"knockable": ["B"], "boost": {"kick": 9.0, "hit": 9.0, "slash": 9.0}, "thresholds": {"hit": 0.05, "knock": 0.05}}
    a_stand = dict(pose.STANCE_A, hz=0.92, lean=0.0, fl=0.2, fk=0.2, rl=-0.2, rk=0.2)

    def tf(w, t):
        if w == "B":
            return dict(pose.STANCE_B, hz=0.92)
        p = dict(a_stand)
        if t > 0.3:                       # Aが前へ踏み込み、前の脚を高く突き出す
            u = min(1.0, (t - 0.3) / 0.25)
            p.update(dx=0.8 * u, fl=0.2 + 1.5 * u, fk=0.0, fa=1.2 * u)
        return p
    r = physics.simulate(sc, tf, 1.6)
    assert r["events"], "衝突が起きなかった"
    x0 = r["states"]["B"][0]["snap"]["torso"][0]
    x1 = r["states"]["B"][-1]["snap"]["torso"][0]
    assert x1 - x0 > 1.0                  # 敵が押されて遠くへ行った


def test_sample_interpolates():
    sc = two_scene()
    r = physics.simulate(sc, stand_targets(), 0.5)
    a = physics.sample(r["states"]["A"], r["taus"], 0.2, sc["actors"]["A"])
    b = physics.sample(r["states"]["A"], r["taus"], 0.2 + physics.DT / 2, sc["actors"]["A"])
    assert abs(a["hz"] - b["hz"]) < 0.01
