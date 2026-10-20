"""戦いの台本の自動生成・物語の型・字幕。clips/(モーションキャプチャ)が無い CI でも回る範囲(台本の dict まで)。"""
import pytest

from stickfig import episode, fight, plan as planmod, story


def _times_sorted(scene):
    for who, ks in scene["keys"].items():
        ts = [k["t"] for k in ks]
        assert ts == sorted(ts), who


@pytest.mark.parametrize("spec", [
    dict(weapon="sword", kick=True, hits=3, counter=True, finisher="launch_slash"),
    dict(weapon="none", kick=False, hits=4, counter=False, finisher="none", palette="cool"),
    dict(weapon="sword", kick=False, hits=1, counter=True, finisher="launch_slash"),
    dict(weapon="spear", kick=True, hits=3, counter=True, finisher="launch_slash", seed=4),
    dict(weapon="staff", kick=False, hits=2, counter=False, finisher="none", stage="dojo"),
])
def test_build_fight_is_valid_scene(spec):
    sc = fight.build_fight(spec)
    planmod.validate_scene(sc)
    _times_sorted(sc)
    kinds = [h["kind"] for h in sc["hits"]]
    main = "hit" if spec["weapon"] == "none" else "slash"
    assert kinds.count(main) + kinds.count("clash") + kinds.count("miss") >= spec["hits"]        # 連打の途中は受け止め(clash)・かわし(miss)になることがある
    by_a = [h["kind"] for h in sc["hits"] if h.get("by") == "A"]
    assert (by_a.count("clash") + by_a.count("miss")) == (0 if spec["hits"] < 3 else (1 if spec["hits"] == 3 else 2))
    assert ("wall" in kinds) == spec["kick"]            # 冒頭の蹴り→壁。連打の中の蹴り(mix_kick)は壁に当てない
    assert (("heel" in kinds) == (spec["finisher"] == "launch_slash"))
    assert sc["tau_end"] > max(h["tau"] for h in sc["hits"])


def test_lines_become_captions_in_order():
    sc = fight.build_fight(dict(captions=True, lines=[dict(at="opening", text="a"), dict(at="finisher", dt=-0.2, kind="shout", text="b")]))
    caps = sc["captions"]
    assert [c["text"] for c in caps] == ["a", "b"] and caps[0]["t0"] < caps[1]["t0"] < sc["tau_end"]
    assert all(c["t1"] > c["t0"] for c in caps)


@pytest.mark.parametrize("arc", ["revenge", "tournament", "duel", "protect", "mentor"])
def test_story_arcs_build_valid_episodes(arc):
    ep = story.build_story(dict(arc=arc, hero="X", rival="Y"))
    assert ep["items"][0].get("card") and ep["items"][-1].get("card")
    n_scene = 0
    for it in ep["items"]:
        if "scene" in it:
            n_scene += 1
            sc = fight.expand(dict(it["scene"]))
            planmod.validate_scene(sc)
    assert n_scene >= 1


def test_unknown_arc_is_rejected():
    with pytest.raises(ValueError):
        story.build_story(dict(arc="nope"))


def test_kit_titles_and_description_have_credit():
    from stickfig import kit
    assert all(kit.titles(a, "H", "R") for a in story.ARCS)
    d = kit.description("雪辱戦", "H", "R")
    assert "CMU" in d and "mocap.cs.cmu.edu" in d


def test_seed_changes_details_but_is_reproducible():
    a1 = fight.build_fight(dict(seed=1))
    a2 = fight.build_fight(dict(seed=1))
    b = fight.build_fight(dict(seed=2))
    assert a1 == a2
    assert a1["clips"] != b["clips"] or a1["hits"] != b["hits"] or a1["fx"]["charge"] != b["fx"]["charge"]
    ep = story.build_story(dict(arc="revenge", seed=3))
    seeds = [it["scene"]["fight"]["seed"] for it in ep["items"] if "scene" in it]
    assert len(set(seeds)) == len(seeds)


def test_story_lines_vary_with_seed_but_not_without():
    def texts(ep):
        return [l["text"] for it in ep["items"] if "scene" in it for l in it["scene"]["fight"]["lines"]]
    a = texts(story.build_story(dict(arc="revenge")))
    assert a == texts(story.build_story(dict(arc="revenge")))
    variants = {tuple(texts(story.build_story(dict(arc="revenge", seed=s)))) for s in range(1, 8)}
    assert len(variants) > 1


def test_series_plan_is_varied_and_valid():
    from stickfig import series, episode
    sp = series.plan_series(6, 100)
    assert len({s["name"] for s in sp}) == 6 and len({s["story"]["seed"] for s in sp}) == 6
    for s in sp:
        ep = story.build_story(s["story"])
        for it in ep["items"]:
            if "scene" in it:
                planmod.validate_scene(fight.expand(dict(it["scene"])))


def test_review_caption_rules():
    from stickfig import review
    ok = [dict(kind="say", who="A", text="行くぞ！", t0=1.0, t1=2.2)]
    assert review.check_captions(ok, 5.0) == []
    long = [dict(kind="say", who="A", text="あ" * 30, t0=1.0, t1=4.0)]
    assert any("長い" in m for m in review.check_captions(long, 5.0))
    short = [dict(kind="say", who="A", text="これは少し長めの台詞です。", t0=1.0, t1=1.4)]
    assert any("短い" in m for m in review.check_captions(short, 5.0))
    over = [dict(kind="narr", text="終わり。", t0=4.0, t1=6.0)]
    assert any("はみ出す" in m for m in review.check_captions(over, 5.0))


def test_weapon_tip_lengths_match_between_fk_and_blender():
    """fk.WEAPON_TIP と blender_player.WEAPONS の長さ(0.115 + len)は、片方だけ直すとずれる。ソースの文字列から突き合わせる。"""
    import re
    from pathlib import Path
    from stickfig import fk
    src = (Path(__file__).resolve().parent.parent / "stickfig" / "blender_player.py").read_text(encoding="utf-8")
    for name, tip in fk.WEAPON_TIP.items():
        m = re.search(r'"%s": dict\(len=([0-9.]+)([^\n]*)' % name, src)
        assert m, name
        extra = 0.18 if "head=True" in m.group(2) else 0.0          # 槍の穂先
        assert abs(0.115 + float(m.group(1)) + extra - tip) < 0.01, name


def test_captions_are_off_by_default():
    sc = fight.build_fight(dict(lines=[dict(at="opening", text="a")]))
    assert sc["captions"] == []


def test_leg_ik_reaches_target():
    import math
    from stickfig import fk
    pose = dict(fa=0.7, fe=1.6, ra=0.5, re=1.7, fl=0.3, fk=0.4, rl=-0.3, rk=0.3, lean=0.1, hz=0.84, dx=0.0, rz=0.0, roll=0.0, ht=0.0, spin=0.0, st=0.0, lst=0.0, run=0.0)
    for s in (1, -1):
        for tx in (-0.25, 0.0, 0.25):
            r = fk.leg_ik(pose, s, 2.0, 1.0, (2.0 + tx, 0.0))
            assert r is not None
            q = dict(pose, fl=r[0], fk=r[1])
            foot = fk.skeleton(q, s, 2.0, 1.0)["foot"]
            assert math.hypot(foot[0] - (2.0 + tx), foot[1]) < 0.03
    assert fk.leg_ik(pose, 1, 0.0, 1.0, (3.0, 0.0)) is None        # 届かない


def test_riposte_adds_a_block_by_b():
    sc = fight.build_fight(dict(hits=3, counter=True, b_combo=0))
    by_b = [h for h in sc["hits"] if h.get("kind") == "clash" and h.get("by") == "B"]
    assert len(by_b) == 1
    ts = [h["tau"] for h in sc["hits"] if h.get("by") == "A" and h["kind"] in ("slash", "clash", "miss")]
    assert ts == sorted(ts)
    off = fight.build_fight(dict(hits=3, riposte=False, b_combo=0))["hits"]
    assert off and not [h for h in off if h.get("by") == "B" and h["kind"] == "clash"]


def test_b_first_opening_only_without_kick():
    sc = fight.build_fight(dict(kick=False, hits=3))
    early = [h for h in sc["hits"] if h.get("by") == "B" and h["tau"] < min(x["tau"] for x in sc["hits"] if x.get("by") == "A")]
    assert [h["kind"] for h in early] == ["miss", "clash"]
    sc2 = fight.build_fight(dict(kick=True, hits=3))
    assert not [h for h in sc2["hits"] if h.get("by") == "B" and h["tau"] < 4.0]
    planmod.validate_scene(sc)


def test_b_combo_adds_b_strikes_before_last_hit():
    sc = fight.build_fight(dict(hits=3, counter=True))
    a_last = max(h["tau"] for h in sc["hits"] if h.get("by") == "A" and h["kind"] in ("slash", "hit"))
    bs = [h for h in sc["hits"] if h.get("by") == "B" and h["tau"] < a_last]
    sc0 = fight.build_fight(dict(hits=3, counter=True, b_combo=0))
    a_last0 = max(h["tau"] for h in sc0["hits"] if h.get("by") == "A" and h["kind"] in ("slash", "hit"))
    bs0 = [h for h in sc0["hits"] if h.get("by") == "B" and h["tau"] < a_last0]
    assert len(bs) == len(bs0) + 2
    assert [h["kind"] for h in bs[-2:]] == ["miss", "clash"]
    planmod.validate_scene(sc)


def test_launch_kick_finisher_and_random():
    sc = fight.build_fight(dict(hits=3, finisher="launch_kick"))
    a_hits = [h for h in sc["hits"] if h.get("by") == "A" and h["kind"] in ("slash", "hit", "kick")]
    launcher = max(a_hits, key=lambda h: h["tau"] if h.get("contact") else -1)
    assert launcher["kind"] == "kick" and launcher["contact"]["effector"] == "foot"
    assert "heel" in [h["kind"] for h in sc["hits"]]
    planmod.validate_scene(sc)
    kinds = {fight.build_fight(dict(hits=3, finisher="random", seed=s))["hits"][-2]["kind"] for s in range(6)}
    assert kinds                                              # seed で選ばれる(どちらかは出る)


def test_beam_finisher_builds_and_flies_to_wall():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="beam"))
    kinds = [h["kind"] for h in sc["hits"]]
    assert "beam" in kinds and "wall" in kinds
    assert sc["fx"]["beams"] and sc["fx"]["charge"]
    bm = sc["fx"]["beams"][0]
    assert abs(bm["x_end"] - (sc["stage"]["wall_x"] + 1.2)) < 1e-6   # 光線は壁を突き抜ける長さ。壁は飛ぶ前の位置で決めてある
    t_beam = next(h["tau"] for h in sc["hits"] if h["kind"] == "beam")
    t_wall = next(h["tau"] for h in sc["hits"] if h["kind"] == "wall" and h["tau"] > t_beam)
    assert 0.2 <= t_wall - t_beam <= 0.5
    planmod.validate_scene(sc)


def test_blast_finisher_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="blast"))
    kinds = [h["kind"] for h in sc["hits"]]
    assert "throw" in kinds and "blast" in kinds and "wall" in kinds
    assert sc["fx"]["orbs"] and sc["fx"]["projectiles"]
    pj = sc["fx"]["projectiles"][0]
    assert pj["x1"] > pj["x0"] and 0.1 <= pj["end"] - pj["start"] <= 0.3
    planmod.validate_scene(sc)


def test_wave_finisher_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="wave"))
    kinds = [h["kind"] for h in sc["hits"]]
    assert "slam" in kinds and "wave" in kinds
    wv = sc["fx"]["waves"][0]
    assert wv["x1"] > wv["x0"]
    planmod.validate_scene(sc)


def test_beam_clash_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="beam_clash"))
    bms = sc["fx"]["beams"]
    assert {b["who"] for b in bms} == {"A", "B"}
    assert len(sc["fx"]["charge"]) >= 2
    a_end = next(b for b in bms if b["who"] == "A")["x_end"]
    assert isinstance(a_end, list) and a_end[-1][1] > a_end[0][1]        # A の光線は最後に壁まで伸びる
    planmod.validate_scene(sc)


def test_opening_blast_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, opening="blast", hits=2, finisher="none"))
    kinds = [h["kind"] for h in sc["hits"] if h["tau"] < 2.0]
    assert "throw" in kinds and "miss" in kinds and "blast" in kinds
    pj = sc["fx"]["projectiles"][0]
    assert abs(pj["x1"] - sc["stage"]["wall_x"]) < 1e-6                 # 玉は壁で爆発
    planmod.validate_scene(sc)


def test_opening_teleport_builds():
    sc = fight.build_fight(dict(weapon="sword", kick=False, opening="teleport", hits=2, finisher="none"))
    kinds = [h["kind"] for h in sc["hits"] if h["tau"] < 2.5]
    assert "vanish" in kinds and "appear" in kinds
    assert sc["fx"]["afterimages"]
    planmod.validate_scene(sc)


def test_opening_fly_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, opening="fly", hits=2, finisher="none"))
    kinds = [h["kind"] for h in sc["hits"] if h["tau"] < 3.0]
    assert "launch" in kinds and "land" in kinds
    top = max(k.get("rz", 0.0) for k in sc["keys"]["A"] if k["t"] < 3.0)
    assert top >= 2.0                                                   # 身長以上の高さを飛ぶ
    planmod.validate_scene(sc)


def test_air_combo_adds_two_air_hits():
    sc = fight.build_fight(dict(weapon="sword", kick=False, hits=2, finisher="air_combo"))
    sc0 = fight.build_fight(dict(weapon="sword", kick=False, hits=2, finisher="launch_slash"))
    t_heel = next(h["tau"] for h in sc["hits"] if h["kind"] == "heel")
    t_heel0 = next(h["tau"] for h in sc0["hits"] if h["kind"] == "heel")
    assert abs((t_heel - t_heel0) - 0.5) < 1e-6
    air_hits = [h for h in sc["hits"] if h["kind"] == "hit" and h.get("by") == "A" and h["pos"][1] > 2.0]
    assert len(air_hits) == 2
    planmod.validate_scene(sc)


def test_barrage_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="barrage"))
    rapid = [h for h in sc["hits"] if h["kind"] == "rapid"]
    assert len(rapid) == 8
    gaps = [round(b["tau"] - a["tau"], 3) for a, b in zip(rapid, rapid[1:])]
    assert all(abs(g - 0.14) < 1e-6 for g in gaps)
    assert "wall" in [h["kind"] for h in sc["hits"]]
    planmod.validate_scene(sc)


def test_slash_wave_builds():
    sc = fight.build_fight(dict(weapon="sword", kick=False, hits=2, finisher="slash_wave"))
    pj = sc["fx"]["projectiles"][0]
    assert pj["shape"] == "crescent" and pj["x1"] > pj["x0"]
    assert "wall" in [h["kind"] for h in sc["hits"]]
    planmod.validate_scene(sc)


def test_iai_builds():
    sc = fight.build_fight(dict(weapon="sword", kick=False, hits=2, finisher="iai"))
    kinds = [h["kind"] for h in sc["hits"]]
    assert "vanish" in kinds and "appear" in kinds and sc["fx"]["cuts"]
    t_app = next(h["tau"] for h in sc["hits"] if h["kind"] == "appear")
    t_cut = sc["fx"]["cuts"][0]["start"]
    assert 0.5 <= t_cut - t_app <= 0.7                                 # 抜けてから斬撃線まで「間」がある
    planmod.validate_scene(sc)


def test_slam_throw_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="slam_throw"))
    kinds = [h["kind"] for h in sc["hits"]]
    assert "grab" in kinds and "heel" in kinds
    kb = [k for k in sc["keys"]["B"] if k.get("roll") is not None]
    assert min(k["roll"] for k in kb) <= -1.8                           # 頭上を回る(頂点で頭が下)
    planmod.validate_scene(sc)


def test_blink_combo_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, hits=2, finisher="blink_combo"))
    kinds = [h["kind"] for h in sc["hits"]]
    assert kinds.count("vanish") == 3 and kinds.count("appear") == 3
    assert "heel" in kinds and len(sc["snaps"]) >= 6
    planmod.validate_scene(sc)


def test_opening_counter_blast_builds():
    sc = fight.build_fight(dict(weapon="sword", kick=False, opening="counter_blast", hits=2, finisher="none"))
    early = [h for h in sc["hits"] if h["tau"] < 2.0]
    assert any(h["kind"] == "throw" and h.get("by") == "B" for h in early)
    assert any(h["kind"] == "blast" for h in early)
    pj = sc["fx"]["projectiles"][0]
    assert pj["x1"] < pj["x0"]                                           # B から A へ(左向き)
    planmod.validate_scene(sc)


def test_opening_air_clash_builds():
    sc = fight.build_fight(dict(weapon="sword", kick=False, opening="air_clash", hits=2, finisher="none"))
    early = [h for h in sc["hits"] if h["tau"] < 2.0]
    cl = next(h for h in early if h["kind"] == "clash")
    assert cl["pos"][1] > 2.0                                            # 空中でぶつかる
    assert max(k.get("rz", 0.0) for k in sc["keys"]["B"] if k["t"] < 2.0) >= 1.8   # B も跳ぶ
    planmod.validate_scene(sc)


def test_opening_dodge_beam_builds():
    sc = fight.build_fight(dict(weapon="none", kick=False, opening="dodge_beam", hits=2, finisher="none"))
    bm = next(b for b in sc["fx"]["beams"] if b["who"] == "B")
    assert bm["x_end"] < 0                                               # B の光線は左へ
    top = max(k.get("rz", 0.0) for k in sc["keys"]["A"] if k["t"] < 2.5)
    assert top >= 2.0                                                    # A は光線より高く跳ぶ
    planmod.validate_scene(sc)


def test_taunt_adds_pose_before_run():
    sc = fight.build_fight(dict(weapon="sword", kick=False, taunt=True, hits=2, finisher="none"))
    sc0 = fight.build_fight(dict(weapon="sword", kick=False, hits=2, finisher="none"))
    poses = [h for h in sc["hits"] if h["kind"] == "pose" and h["tau"] < 1.2]
    assert poses and any(abs(h["tau"] - 0.86) < 1e-6 for h in poses)
    run = next(c for c in sc["clips"]["A"] if c.get("loop"))
    run0 = next(c for c in sc0["clips"]["A"] if c.get("loop"))
    assert run["start"] > run0["start"]                                 # 走り出しが遅れる
    planmod.validate_scene(sc)
