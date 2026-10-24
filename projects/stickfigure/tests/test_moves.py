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


def test_flip_comes_back_upright_on_the_ground():
    # バク転は 2π 回って着地する。着地のコマ(2π → 0 を 1 コマで戻したあと)には roll 0・根元が地面にある
    def script(F, T):
        T.exchange(F["B"], F["A"], "round", 1.2, "flip")
    sc, rep, beats = _build(script, 3.0)
    keys = sc["keys"]["A"]
    peak = max(abs(k["roll"]) for k in keys[:60])
    assert peak > 4.0                                         # 途中で大きく回っている
    for f in range(60, 75):
        assert abs(keys[f]["roll"]) < 1e-6 or abs(keys[f]["roll"] - 2 * math.pi) < 1e-3, f


def test_slam_wave_registers_wave_and_flash():
    cast = dict(A=CAST["A"], B=dict(color=[0.62, 0.35, 0.85], style="giant", x=1.9, d=-1, scale=1.25))

    def script(F, T):
        T.slam_wave(F["B"], F["A"], 1.4, "hop")
    sc, rep, beats = _build(script, 3.0, cast)
    assert len(sc["fx"]["waves"]) == 1
    assert sc["fx"]["flashes"] == [1.4]
    assert any(h["kind"] == "slam" for h in sc["hits"])


def test_air_combo_hits_in_the_air_and_leaves_defender_lying():
    def script(F, T):
        T.air_combo(F["A"], F["B"], 1.5)
    sc, rep, beats = _build(script, 5.0)
    kinds = [h["kind"] for h in sc["hits"]]
    assert kinds.count("kick") >= 3 and "heel" in kinds
    air = [b for b in beats if b["t"] > 1.5 and not b["miss"]]
    assert len(air) >= 3
    heel = next(h for h in sc["hits"] if h["kind"] == "heel")
    last = sc["keys"]["B"][-1]
    assert abs(abs(last["roll"]) - 1.57) < 0.05               # 倒れたまま
    assert heel["tau"] < 4.0


CAST3 = dict(A=dict(color=[0.5, 0.85, 0.3], style="kenpo", x=0.0, d=1),
             B=dict(color=[0.25, 0.55, 0.95], style="kicker", x=1.6, d=-1),
             D=dict(color=[0.92, 0.32, 0.28], style="brawler", x=-1.6, d=1))


def test_three_fighters_turn_to_face_each_attacker():
    # 3 対 1: 左の赤に殴られるときは緑が左を向き、右の青を殴るときは右を向く
    def script(F, T):
        T.exchange(F["A"], F["B"], "jab", 1.0, "stagger")
        T.exchange(F["D"], F["A"], "cross", 1.8, "block")
        T.exchange(F["A"], F["B"], "cross", 2.8, "stagger")
    sc, rep, beats = _build(script, 3.6, CAST3)
    keys = sc["keys"]["A"]
    assert keys[int(1.0 * 30)]["dir"] > 0
    assert keys[int(1.8 * 30)]["dir"] < 0
    assert keys[int(2.8 * 30)]["dir"] > 0
    for b in beats:
        assert _tip_error(sc, b) < 0.06, b


def test_anime_techniques_register_fx():
    def script(F, T):
        T.charge([F["D"], F["B"]], 0.5, 1.5, [[255, 110, 90], [110, 170, 255]])
        T.beam(F["D"], 1.6, 0.8, F["A"].x, [255, 240, 220], targets=[F["A"]], dist=1.0, stay=True)
        T.teleport(F["B"], 2.0, 2.4, -1)
    sc, rep, beats = _build(script, 3.0, CAST3)
    fx = sc["fx"]
    assert len(fx["charge"]) == 2 and len(fx["beams"]) == 1 and len(fx["afterimages"]) == 1
    assert sc["qa"]["max_teleport_frames"] >= 1
    kb = sc["keys"]["B"]
    assert abs(kb[int(2.0 * 30) + 1]["dx"] - kb[int(2.0 * 30)]["dx"]) > 0.5      # 1 コマで飛ぶ
