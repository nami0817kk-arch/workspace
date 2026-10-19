import json
import math

import numpy as np
import pytest

from stickfig import mocap, plan


def make_bvh(frames):
    """必要な関節だけの最小の BVH。frames は {関節名: (rx, ry, rz) 度} の辞書の列(腰の位置は (0, 4.0+..., 0))。"""
    def joint(name, off, ch, children="", ind=1):
        pad = "\t" * ind
        return (f"{pad}JOINT {name}\n{pad}{{\n{pad}\tOFFSET {off[0]} {off[1]} {off[2]}\n{pad}\tCHANNELS 3 Zrotation Yrotation Xrotation\n"
                f"{children}{pad}}}\n")
    def end(ind):
        pad = "\t" * ind
        return f"{pad}End Site\n{pad}{{\n{pad}\tOFFSET 0 0 0\n{pad}}}\n"
    foot = joint("LeftFoot", (0, -4, 0), 3, joint("LeftToeBase", (0, 0, 1), 3, end(5), 4), 3)
    rfoot = joint("RightFoot", (0, -4, 0), 3, joint("RightToeBase", (0, 0, 1), 3, end(5), 4), 3)
    leg = joint("LeftUpLeg", (1, 0, 0), 3, joint("LeftLeg", (0, -4, 0), 3, foot, 2), 1)
    rleg = joint("RightUpLeg", (-1, 0, 0), 3, joint("RightLeg", (0, -4, 0), 3, rfoot, 2), 1)
    larm = joint("LeftArm", (1.5, 4, 0), 3, joint("LeftForeArm", (0, -3, 0), 3, joint("LeftHand", (0, -3, 0), 3, end(4), 3), 2), 1)
    rarm = joint("RightArm", (-1.5, 4, 0), 3, joint("RightForeArm", (0, -3, 0), 3, joint("RightHand", (0, -3, 0), 3, end(4), 3), 2), 1)
    names = ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
             "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]
    head = ("HIERARCHY\nROOT Hips\n{\n\tOFFSET 0 0 0\n\tCHANNELS 6 Xposition Yposition Zposition Zrotation Yrotation Xrotation\n"
            + leg + rleg + larm + rarm + "}\n")
    n_ch = 6 + 3 * (len(names) - 1)
    lines = [head, f"MOTION\nFrames: {len(frames)}\nFrame Time: 0.0083333\n"]
    for fr in frames:
        vals = [0, 8.0, 0, 0, 0, 0]
        for nm in names[1:]:
            rx, ry, rz = fr.get(nm, (0, 0, 0))
            vals += [rz, ry, rx]
        assert len(vals) == n_ch
        lines.append(" ".join(str(v) for v in vals) + "\n")
    return "".join(lines)


def test_parse_and_standing_retarget():
    b = mocap.parse_bvh(make_bvh([{} for _ in range(240)]))
    assert len(b.names) == 15 and len(b.frames) == 240
    c = mocap.retarget(b)
    P = c["params"]
    assert c["fps"] == 30 and c["n"] == 29 or c["n"] >= 28
    assert abs(P["fl"][0]) < 1e-6 and abs(P["lean"][0]) < 1e-6
    assert P["hz"][0] == pytest.approx(0.92, abs=0.05)         # 脚の長さ0.9に直した、立った腰の高さ


def test_thigh_swing_sign_and_size():
    """腰の関節を X まわりに +45° 回すと、つま先側(前)の逆=後ろへ振れる。-45° なら前へ。"""
    back = mocap.retarget(mocap.parse_bvh(make_bvh([{"RightUpLeg": (45, 0, 0)}] * 240)))
    fwd = mocap.retarget(mocap.parse_bvh(make_bvh([{"RightUpLeg": (-45, 0, 0)}] * 240)))
    assert back["params"]["fl"][0] == pytest.approx(-math.radians(45), abs=0.02)
    assert fwd["params"]["fl"][0] == pytest.approx(math.radians(45), abs=0.02)


def test_mirror_swaps_sides():
    b = mocap.parse_bvh(make_bvh([{"LeftUpLeg": (-45, 0, 0)}] * 240))
    plain = mocap.retarget(b)["params"]
    mir = mocap.retarget(b, mirror=True)["params"]
    assert plain["rl"][0] == pytest.approx(math.radians(45), abs=0.02) and abs(plain["fl"][0]) < 0.02
    assert mir["fl"][0] == pytest.approx(math.radians(45), abs=0.02)


def test_find_strikes_picks_fastest_hand():
    frames = []
    for i in range(480):
        a = 0.0 if i < 240 else 90.0 * (i - 240) / 30      # 2秒後から、右腕が速く回る
        frames.append({"RightArm": (min(a, 90.0), 0, 0)})
    b = mocap.parse_bvh(make_bvh(frames))
    st = mocap.find_strikes(b, top=1)[0]
    assert st["joint"] in ("RightHand", "RightFoot") and 1.9 < st["t"] < 3.2


def test_clip_sampling_and_loop(tmp_path):
    data = dict(fps=30, n=31, params={k: [0.0] * 31 for k in mocap.CLIP_KEYS})
    data["params"]["dx"] = [i * 0.1 for i in range(31)]
    c = mocap.Clip(data)
    assert c.duration == pytest.approx(1.0)
    assert c.sample(0.5)["dx"] == pytest.approx(1.5)
    assert c.sample(1.25, loop=True)["dx"] == pytest.approx(0.75, abs=0.01)


def test_clipbank_strike_alignment_and_blend(tmp_path):
    n = 61
    params = {k: [0.0] * n for k in mocap.CLIP_KEYS}
    params["fa"] = [1.0] * n
    params["hz"] = [0.9] * n
    (tmp_path / "k.json").write_text(json.dumps(dict(fps=30, n=n, params=params, strike=dict(t=1.0, kind="foot", front=True))), encoding="utf-8")
    scene = dict(clips_dir=str(tmp_path), clips={"A": [{"file": "k", "strike_at": 5.0}]})
    bank = plan.ClipBank(scene)
    c = scene["clips"]["A"][0]
    assert c["start"] == pytest.approx(4.0)                    # 突く瞬間(clip の1.0秒)が台本の5.0秒に来る
    assert bank.weight(c, 5.0) == pytest.approx(1.0)
    p0 = dict(fa=0.0, fe=0, ra=0, re=0, fl=0, fk=0, rl=0, rk=0, lean=0, hz=0.8, dx=0.0)
    assert bank.apply("A", p0, 5.0)["fa"] == pytest.approx(1.0)
    assert bank.apply("A", p0, 1.0)["fa"] == pytest.approx(0.0)  # 区間の外では混ざらない


def test_find_loop_closes_a_periodic_clip_and_skips_the_seam():
    """走りの周期を輪にする。先頭1コマ(データの継ぎ目の乱れ)は始点に使わない。"""
    n, fps = 60, 30
    t = np.arange(n) / fps
    params = {k: (0.8 * np.sin(2 * math.pi * 1.5 * t + i)).tolist() for i, k in enumerate(mocap.CLIP_KEYS)}
    params["dx"] = (3.0 * t).tolist()
    for k in ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean"):
        params[k][0] = 9.0                                   # 先頭の乱れ
    loop = mocap.find_loop(dict(fps=fps, n=n, params=params))
    assert loop["loop"] and 18 <= loop["n"] <= 22             # 周期は 1/1.5 秒 = 20 コマ
    assert loop["dx_cycle"] == pytest.approx(2.0, abs=0.25)   # 1周期で進む距離
    assert max(abs(v) for v in loop["params"]["fa"]) < 2.0    # 乱れたコマが入っていない
    c = mocap.Clip(loop)
    a, b = c.sample(0.0, loop=True), c.sample(loop["n"] / fps, loop=True)
    assert a["fa"] == pytest.approx(b["fa"], abs=1e-6)        # 周期で元に戻る



def test_loop_clip_dx_is_continuous_across_seam():
    """輪にした clip の継ぎ目(最後→最初のコマ)で、dx が 1 周ぶん後ろへ飛ばない(2026-10-19 の不具合)。"""
    import numpy as np
    from stickfig.mocap import Clip
    n = 10
    data = dict(fps=30, n=n, scale=0.06, loop=True, dx_cycle=1.0, params=dict(dx=[i / n for i in range(n)], fa=[0.0] * n))
    clip = Clip(data)
    ts = [(n - 1 + k * 0.25) / 30 for k in range(0, 9)]            # 最後のコマの前後をまたぐ
    xs = [clip.sample(t, loop=True)["dx"] + (1.0 if t * 30 >= n else 0.0) for t in ts]
    diffs = [b - a for a, b in zip(xs, xs[1:])]
    assert all(0.0 <= d < 0.06 for d in diffs), diffs
    before = clip.sample(-0.5 / 30, loop=True)["dx"]              # 始まりの少し前(区間に入る混ぜのコマ)
    assert 0.9 < before <= 1.0
