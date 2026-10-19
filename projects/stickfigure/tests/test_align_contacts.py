"""clip とキーの位置合わせ・接触の距離の測り直し・瞬間移動の点検。clips/ が無い CI でも回るよう、小さな clip をその場で作る。

作る clip: 60 コマ、腕を前へ突き出す(fa が 0.3 → 1.6 → 0.3)、突く瞬間 t=1.0 秒。dx は 0.8 進む。
台本: A が走らずに立ち、1.5 秒にこの clip で B の胸を突く(contact)。キーの dx は clip の位置と大きく食い違えてある。
"""
import json
import math
from pathlib import Path

import pytest

from stickfig import plan as planmod, qa


def _make_clip(path: Path) -> None:
    n = 60
    fa = [0.3 + 1.3 * math.exp(-((i - 30) / 6.0) ** 2) for i in range(n)]
    fe = [1.6 - 1.4 * math.exp(-((i - 30) / 6.0) ** 2) for i in range(n)]
    data = dict(fps=30, n=n, scale=0.06, strike=dict(t=1.0, kind="hand", front=True),
                params=dict(lean=[0.1] * n, fa=fa, fe=fe, ra=[0.5] * n, re=[1.7] * n, fl=[0.35] * n, fk=[0.3] * n, rl=[-0.35] * n, rk=[0.4] * n,
                            hz=[0.84] * n, dx=[0.8 * i / (n - 1) for i in range(n)]))
    path.write_text(json.dumps(data), encoding="utf-8")


def _scene(clips_dir: Path, key_dx: float) -> dict:
    return dict(
        name="t", fps=30, tau_end=3.0, clips_dir=str(clips_dir),
        actors=dict(A=dict(color=[0.3, 0.7, 0.1], base_x=-1.0, facing=1), B=dict(color=[0.8, 0.1, 0.1], base_x=1.4, facing=-1)),
        stage=dict(wall_x=6.0, style="flat"),
        hits=[dict(tau=1.5, hold=0.05, kind="hit", by="A", contact=dict(striker="A", effector="hand", target=dict(actor="B", point="chest"), tol=0.3, max_anticipation=50))],
        keys=dict(A=[dict(t=0.0, dx=0.0), dict(t=1.0, dx=key_dx), dict(t=3.0, dx=key_dx)], B=[dict(t=0.0, dx=0.0), dict(t=3.0, dx=0.0)]),
        camera=[[0.0, 0.2, 8.0], [3.0, 0.2, 8.0]],
        clips=dict(A=[dict(file="poke", strike_at=1.5, start=1.0, end=2.0, **{"in": 0.1, "out": 0.1})]),
        body_drive=dict(strength=1.7), footwork={}, qa=dict(max_cross_frames=400, max_stops=5, max_jerk=1.5),
    )


@pytest.mark.parametrize("key_dx", [0.0, 2.5])
def test_contact_lands_and_no_teleport(tmp_path, key_dx):
    _make_clip(tmp_path / "poke.json")
    pl = planmod.build_plan(_scene(tmp_path, key_dx))
    assert pl["contacts"] and pl["contacts"][0]["distance_to_body"] < 0.3        # 出来上がりのコマで測った距離
    res = qa.run_gate(pl)
    assert "teleport" not in res["failed"], res["failed"]
    fr = pl["frames"]
    mx = max(abs(fr[f]["actors"]["A"]["root_x"] - fr[f - 1]["actors"]["A"]["root_x"]) for f in range(1, len(fr)) if fr[f]["tau"] != fr[f - 1]["tau"])
    assert mx < 0.5


def test_align_is_idempotent(tmp_path):
    _make_clip(tmp_path / "poke.json")
    sc = _scene(tmp_path, 2.5)
    import copy
    sc = copy.deepcopy(sc)
    tracks = planmod.make_tracks(sc)
    sc["_bank"] = planmod.ClipBank(sc)
    planmod._align_keys_to_clips(sc, tracks)
    k1 = [(k["t"], k.get("dx")) for k in sc["keys"]["A"]]
    planmod._align_keys_to_clips(sc, planmod.make_tracks(sc))
    k2 = [(k["t"], k.get("dx")) for k in sc["keys"]["A"]]
    assert k1 == k2


def test_clip_timing_keeps_strike_and_is_monotone(tmp_path):
    _make_clip(tmp_path / "poke.json")
    sc = _scene(tmp_path, 0.0)
    sc["clip_timing"] = dict(pre=0.4, post=0.3)
    bank = planmod.ClipBank(sc)
    c = sc["clips"]["A"][0]
    raw = lambda tau: (tau - c["start"]) * c.get("speed", 1.0) + c.get("offset", 0.0)
    assert abs(bank.warped_u(c, 1.5) - raw(1.5)) < 1e-9                # 命中の瞬間は元のまま
    us = [bank.warped_u(c, 1.0 + i * 0.01) for i in range(101)]
    assert all(b >= a - 1e-9 for a, b in zip(us, us[1:]))               # 戻らない
    assert abs(us[0] - raw(1.0)) < 1e-9 and abs(us[-1] - raw(2.0)) < 1e-9   # 両端は元の時間につながる
    pulls = [bank.antic_phase(c, 1.5 - x)[0] for x in (0.04, 0.2, 0.38)]
    assert pulls[0] == 0.0 and pulls[1] == 1.0 and pulls[2] < 0.5      # 振りの最中は引かない、溜めで引く
    assert abs(bank.antic_phase(c, 1.56)[1] - 1.0) < 1e-6 and bank.antic_phase(c, 1.8)[1] == 0.0
