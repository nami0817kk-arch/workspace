"""動作部品(moves.py)の殴り合い: 当たり位置に届く・間隔が詰まりすぎるとエラー・書いていない項目は 0・倒れたままの人は弾まない。"""
import math

import pytest

from stickfig import animecheck, bout, moves

BG = dict(image="assets/bg/dojo.png", x0=-9.5, x1=9.0, ground=0.82)
CAST = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=-0.9, d=1),
            B=dict(color=[0.92, 0.32, 0.28], style="brawler", x=0.9, d=-1))


def _build(script, t_end=4.0, cast=None):
    return moves.build_bout("t", BG, t_end, cast or CAST, script)


def _tip_error(sc, beat):
    keys = sc["keys"][beat["by"]]
    actor = sc["actors"][beat["by"]]
    h = next(h for h in sc["hits"] if abs(h["tau"] - beat["t"]) < 1e-3)
    limb = {"st": "front_arm", "rst": "rear_arm", "lst": "front_leg", "rlst": "rear_leg"}[beat["limb"]]
    tip = bout.skel(keys, actor, beat["t"])[limb][-1]
    return math.hypot(tip[0] - h["pos"][0], tip[1] - h["pos"][1])


def test_strikes_reach_their_targets():
    def script(F, T):
        T.exchange(F["A"], F["B"], "jab", 1.0, "stagger", push=0.3)
        T.exchange(F["B"], F["A"], "front", 1.7, "block")
        T.exchange(F["A"], F["B"], "upper", 2.3, "stagger", push=0.3, ret=0.0)
    sc, rep, beats = _build(script)
    assert len(beats) == 3
    for b in beats:
        assert _tip_error(sc, b) < 0.05, b


def test_hit_times_are_quantized_to_frames():
    def script(F, T):
        T.exchange(F["A"], F["B"], "jab", 1.0123, "stagger")
    sc, rep, beats = _build(script, 3.0)
    t = beats[0]["t"]
    assert abs(t * 30 - round(t * 30)) < 1e-6


def test_overlapping_moves_raise():
    def script(F, T):
        T.exchange(F["A"], F["B"], "jab", 1.0, "stagger")
        T.exchange(F["A"], F["B"], "cross", 1.05, "stagger")        # 0.05 秒後: 前の動作の戻りを詰めても入らない
    with pytest.raises(ValueError):
        _build(script, 3.0)


def test_unspecified_fields_do_not_drift():
    # 吹き飛びの前は、書いていない roll が 0 のまま(以前は最初の roll の値へだらだら補間され、離れた時刻の体が傾いた)
    def script(F, T):
        T.exchange(F["A"], F["B"], "jab", 1.0, "stagger")
        T.exchange(F["A"], F["B"], "palm", 2.0, "launch", dist=1.8, stay=True)
    sc, rep, beats = _build(script, 4.0)
    for f in range(0, 55):
        assert abs(sc["keys"]["A"][f]["roll"]) < 1e-6 and abs(sc["keys"]["B"][f]["roll"]) < 1e-6, f


def test_fighter_who_stays_down_does_not_get_up():
    def script(F, T):
        T.exchange(F["A"], F["B"], "palm", 1.0, "launch", dist=1.8, stay=True)
    sc, rep, beats = _build(script, 3.5)
    last = sc["keys"]["B"][-1]
    assert abs(last["roll"]) > 1.4 and last["rz"] < 0.4


def test_intensity_counts_exchanges():
    def script(F, T):
        T.exchange(F["A"], F["B"], "jab", 1.0, "stagger", push=0.25, ret=0.0)
        T.exchange(F["A"], F["B"], "cross", 1.4, "stagger", push=0.25, ret=0.0)
        T.exchange(F["A"], F["B"], "palm", 1.8, "launch", dist=2.0, stay=True)
    sc, rep, beats = _build(script, 3.5)
    r = animecheck.intensity(sc, beats)
    assert r["exchanges_per_s"] >= 1.2 and r["knockdown"] == 1 and r["moving"] > 0.5


def test_apply_vertical_zooms_out_and_fixes_crop():
    from stickfig import episode
    sc = {"vertical_zoom": 2.4, "shots": [dict(t=0.0, follow="mid", scale=3.4, target_z=1.0)], "cam_zoom": 1.0}
    episode.apply_vertical(sc)
    assert sc["output"] == {"aspect": "vertical", "crop": "camera"}
    assert abs(sc["cam_zoom"] - 2.4) < 1e-9 and sc["shots"][0]["target_z"] > 2.0
    plain = episode.apply_vertical({"shots": [dict(t=0.0, target_z=1.0)]})        # 自動の場面(vertical_zoom なし)は触らない
    assert plain["output"] == {"aspect": "vertical"} and plain["shots"][0]["target_z"] == 1.0
