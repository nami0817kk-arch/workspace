"""手付け(keyshot)の焼き込み: 足が世界の目標に届く(体の大きさ scale を含む)・溜めで全身が止まる・構えの型の置き換え。"""
from stickfig import bout, fk, keyshot as ks


def _tracks(x=0.0, hz=0.80, feet=(0.30, -0.30)):
    return dict(body=[dict(t=0.0, x=x, hz=hz, lean=0.12, ht=0.0, dir=1), dict(t=1.0, x=x, hz=hz, lean=0.12, ht=0.0)],
                f_foot=[dict(t=0.0, p=(feet[0], 0)), dict(t=1.0, p=(feet[0], 0))],
                r_foot=[dict(t=0.0, p=(feet[1], 0)), dict(t=1.0, p=(feet[1], 0))],
                f_hand=[dict(t=0.0, ang=bout.GUARD_F), dict(t=1.0, ang=bout.GUARD_F)],
                r_hand=[dict(t=0.0, ang=bout.GUARD_R), dict(t=1.0, ang=bout.GUARD_R)])


def _foot(keys, actor, f, chain="front_leg"):
    sk = bout.skel(keys, actor, f / 30)
    return sk[chain][-1]


def test_feet_reach_targets():
    actor = dict(base_x=0.0)
    keys = ks.bake(_tracks(), actor, 30, 1.0)
    p = _foot(keys, actor, 15)
    assert abs(p[0] - 0.30) < 0.02 and abs(p[1]) < 0.02


def test_feet_reach_targets_with_scale():
    # 巨漢(1.25 倍): 世界の目標は根元から 1/scale に縮めて解く。縮めないと足が届かず浮いた
    actor = dict(base_x=0.0, scale=1.25)
    keys = ks.bake(_tracks(feet=(0.40, -0.40)), actor, 30, 1.0)
    for chain, want in (("front_leg", 0.40), ("rear_leg", -0.40)):
        p = _foot(keys, actor, 15, chain)
        assert abs(p[0] - want) < 0.02 and abs(p[1]) < 0.02


def test_windup_freezes_whole_body():
    tr = _tracks()
    tr["body"] = [dict(t=0.0, x=0.0, hz=0.80, lean=0.0), dict(t=1.0, x=0.5, hz=0.80, lean=0.6)]
    keys = ks.bake(tr, dict(base_x=0.0), 30, 1.0, holds=[dict(kind="windup", t=0.8, hold=4, burst=3)])
    f0 = round(0.8 * 30) - 3 - 4
    for f in range(f0, f0 + 4):
        assert keys[f]["lean"] == keys[f0]["lean"] and keys[f]["dx"] == keys[f0]["dx"]
    assert keys[24]["lean"] > keys[f0]["lean"]


def test_stylize_replaces_only_guard_values():
    tr = _tracks()
    tr["body"].append(dict(t=0.5, hz=0.45, lean=0.40))                 # しゃがみは触らない
    bout.stylize(tr, "kenpo")
    st = bout.STYLES["kenpo"]
    assert tr["body"][0]["hz"] == round(0.80 - st["hz_drop"], 3) and tr["body"][0]["lean"] == st["lean"]
    assert tr["body"][-1]["hz"] == 0.45 and tr["body"][-1]["lean"] == 0.40
    assert tr["f_hand"][0]["ang"] == st["guard_f"]


def test_widen_stance_scales_with_body():
    tr = ks.widen_stance(_tracks(feet=(0.20, -0.20)), scale=1.25)
    L = fk.LEG_TOTAL * 1.25
    hz = 0.80 * 1.25
    rear = abs(tr["r_foot"][0]["p"][0])
    assert (rear ** 2 + hz ** 2) ** 0.5 >= 0.95 * L
