"""勝ち抜き戦(第 2 版・動作部品 moves.py の殴り合い)。2026-10-22「バトルをもっと激しくして、参考動画みてね」。

第 1 版(kachinuki.py)は 1 発ずつ手で書いた 4〜8 発の短い戦いだった。第 2 版は moves.py で 13〜16 発の殴り合いに(打ち合い 1.5/秒)。
会場の歩き入り・歩き出し・看板は kachinuki.py のものをそのまま使う。

使い方: python tools/shots/kachinuki2.py blue|giant|red --out out/k2_blue [--check|--plan-only]
エピソード: scenes/episodes/tournament_kachinuki.yaml(shot: tools/shots/kachinuki2_*.py)
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1]))
import kachinuki as K1  # noqa: E402
from stickfig import animecheck, bout  # noqa: E402


def _load(name):
    sp = importlib.util.spec_from_file_location("_k2_" + name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    return mod


def _duel(name, stage, board_x, walk_in_from=None, walk_out_to=None):
    def build():
        mod = _load(name)
        sc, rep, beats = mod.build()
        K1.add_board(sc, board_x, [[0.0, K1.ladder(stage)]])
        dt = 0.0
        if walk_in_from is not None:
            dt = K1.walk_in(sc, from_x=walk_in_from, scale_in=4.2, scale_fight=3.4)
        if walk_out_to is not None:
            K1.walk_out(sc, to_x=walk_out_to, scale=4.0)
        return sc, rep, beats, dt
    return build


BUILDS = dict(blue=_duel("duel_blue", 0, -3.6, None, 5.6),
              giant=_duel("duel_giant", 1, -3.6, -6.2, 5.6),
              red=_duel("duel_red", 2, -3.6, -6.2, None))


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("part", choices=list(BUILDS))
    ap.add_argument("--out", required=True)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--plan-only", action="store_true")
    a = ap.parse_args()
    from stickfig import cli, plan as pm, qa
    sc, rep, beats, dt = BUILDS[a.part]()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    if a.check or a.plan_only:
        pl = pm.build_plan(sc)
        pm.save_plan(pl, out / "plan.json")
        g = qa.run_gate(pl, sc.get("qa"))
        print("点検:", "合格" if g["passed"] else f"不合格 {g['failed']}")
        sb = [dict(b, t=b["t"] + dt) for b in beats]
        print(animecheck.report(animecheck.check(sc, pl, sb, None)))
        print(animecheck.intensity_report(animecheck.intensity(sc, sb)))
    else:
        print(cli.build_scene(sc, out))


if __name__ == "__main__":
    main()
