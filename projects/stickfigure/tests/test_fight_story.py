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
    assert ("kick" in kinds) == spec["kick"]
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
    sc = fight.build_fight(dict(hits=3, counter=True))
    by_b = [h for h in sc["hits"] if h.get("kind") == "clash" and h.get("by") == "B"]
    assert len(by_b) == 1
    ts = [h["tau"] for h in sc["hits"] if h.get("by") == "A" and h["kind"] in ("slash", "clash", "miss")]
    assert ts == sorted(ts)
    assert fight.build_fight(dict(hits=3, riposte=False))["hits"] and not [h for h in fight.build_fight(dict(hits=3, riposte=False))["hits"] if h.get("by") == "B" and h["kind"] == "clash"]
