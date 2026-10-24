"""勝ち抜き戦を札なしでつなぐ(2026-10-21「参考の動画のような見せ方をしたい」→「話のつなぎ方」)。
Animation vs. Minecraft のように、黒い札を挟まず、場面の中で話を進める:
  - 試合は、緑が会場へ歩いて入ってくる所から始まり(相手は待っている)、勝ったら歩いて画面の外へ出る
  - 勝ち抜きの表は会場に立てた看板(tools/ladder_board.py の絵)。入口の看板が今の段を示し、最後は看板の星で優勝を見せる

使い方: python tools/shots/kachinuki.py r1|sf|final|win --out out/k_r1 [--check|--preview|--plan-only]
エピソード: scenes/episodes/tournament_kachinuki.yaml(shot: tools/shots/kachinuki_*.py)
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import bout, keyshot as ks  # noqa: E402

HERE = Path(__file__).resolve().parent
VERTICAL_ZOOM = 2.4        # 縦(9:16)では枠が横の 1/3 なので、カメラをこの倍率で引く(2 人が収まる)。2026-10-22「ショートがめちゃくちゃ」(片方が切れた)
BG_DIR = HERE.parents[1] / "assets" / "bg"
RELAX = dict(hz=0.84, lean=0.05, ht=0.0, fa=0.35, fe=0.6, ra=0.25, re=0.7)


def _load(name):
    sp = importlib.util.spec_from_file_location("_k_" + name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    return mod


def ladder(stage: int) -> str:
    return str(BG_DIR / f"ladder_s{stage}.png")


def _bake(tracks, actor, dur, t_go=0.1, t_stop=None):
    """歩きを焼き、歩いている間は承認済みの歩きの周期(pose.WALK、姿勢の walk)に任せる(2026-10-20「歩き方変では？」で直した周期)。
    IK の足運びだけだと膝の曲がった小刻みに見えた。出だしと止まりの 0.25 秒で周期と焼いた姿勢を混ぜる。"""
    keys = ks.bake(tracks, actor, bout.FPS, dur)
    t_stop = dur - 0.35 if t_stop is None else t_stop
    for k in keys:
        t = k["t"]
        w = min(1.0, max(0.0, (t - t_go) / 0.25), max(0.0, (t_stop - t) / 0.25))
        if w > 0:
            k["walk"] = round(w, 3)
            k["hz"] = round(k["hz"] * (1 - w) + 0.87 * w, 4)        # 周期は脚を伸ばして歩く。IK 用の低い腰のままだと足が地面に潜った
    return keys


def walk_in(sc: dict, who: str = "A", from_x: float = -5.2, dur: float = 3.0, cam_x: float = None, scale_in: float = 4.6, scale_fight: float = 3.6) -> float:
    """緑が左から歩いて入り、場面の最初の構えで止まる。待っている相手は最初のコマのまま(構えて待つ)。"""
    a = sc["actors"][who]
    end = bout.pose_of(sc["keys"][who], a, 0)
    w = 0.18
    start = dict(RELAX, x=from_x, dir=1, f=from_x + w, r=from_x - w)
    frames = _bake(bout.walk_tracks(start, end, dur), a, dur)
    cx = cam_x if cam_x is not None else (from_x + end["x"]) / 2 + 0.6
    shots = [dict(t=0.0, follow=round(cx, 3), scale=scale_in, yaw=-4.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.0),       # 引きで、入ってくる緑と待つ相手
             dict(t=round(dur - 0.9, 3), follow="mid", scale=scale_fight, yaw=-5.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.3)]
    return bout.prepend(sc, {who: frames}, shots)


def walk_out(sc: dict, who: str = "A", to_x: float = 6.5, dur: float = 2.5, hold: float = 0.0, scale: float = 4.4, facing: int = 1) -> float:
    """最後のコマから、facing の向き(既定は右)を向いて歩いて画面の外へ出る。カメラは止めて見送る。"""
    a = sc["actors"][who]
    n = len(sc["keys"][who]) - 1
    start = bout.pose_of(sc["keys"][who], a, n)
    w = 0.18
    end = dict(RELAX, x=to_x, dir=facing, f=to_x + w * facing, r=to_x - w * facing)
    frames = _bake(bout.walk_tracks(start, end, dur, turn=facing), a, dur, t_go=0.12)      # 立ち止まりは 4 コマ未満(動画の点検が「意図しない静止」で止める)。画面から出たら終わる
    if hold:
        frames = [dict(frames[0]) for _ in range(int(hold * bout.FPS))] + frames
    shots = [dict(t=0.0, follow=round(start["x"] + 1.2 * facing, 3), scale=scale, yaw=-4.0, pitch=3.0, lens=40.0, target_z=1.0, lag=0.0)]
    return bout.append(sc, {who: frames}, shots)


def add_board(sc: dict, x: float, images, z: float = 0.55):
    sc.setdefault("fx", {}).setdefault("props", []).append(bout.board(x, images, z=z))


def build_r1():
    mod = _load("bout_r1")
    sc, rep = mod.build()
    add_board(sc, -3.6, [[0.0, ladder(0)]])                       # 道場の看板(紹介で見たもの)
    walk_out(sc, to_x=4.6)
    return sc, rep, mod.BEATS, 0.0


def build_sf():
    mod = _load("bout_sf")
    sc, rep = mod.build()
    add_board(sc, -3.3, [[0.0, ladder(1)]])                       # 河川敷の入口の看板: 青に×、緑は 1 段上がった
    dt = walk_in(sc, from_x=-5.6)
    walk_out(sc, to_x=5.4)
    return sc, rep, mod.BEATS, dt


def build_final():
    mod = _load("fight01")
    sc, rep = mod.build_scene()
    add_board(sc, -3.4, [[0.0, ladder(2)]])                       # 境内の入口の看板: 紫にも×、あとは赤だけ
    dt = walk_in(sc, from_x=-5.4)
    return sc, rep, mod.BEATS, dt


def build_win():
    mod = _load("bout_win")
    sc, rep = mod.build()
    add_board(sc, -1.5, [[0.0, ladder(2)], [1.22, ladder(3)]])    # 拳を突き上げた瞬間に、看板のてっぺんに星
    sc["shots"].append(dict(t=3.6, follow=-0.75, scale=3.4, yaw=-4.0, pitch=2.0, lens=40.0, target_z=1.0, lag=0.5))   # 最後は緑と看板が入る引き
    sc["shots"].sort(key=lambda s: s["t"])
    return sc, rep, [], 0.0


def build_intro():
    mod = _load("bout_intro")
    sc, rep = mod.build()
    add_board(sc, -4.0, [[0.0, ladder(0)]])
    return sc, rep, [], 0.0


def _side(fn):
    def w():
        sc, rep, beats, dt = fn()
        sc["vertical_zoom"] = VERTICAL_ZOOM
        return bout.side_view(sc), rep, beats, dt
    return w


BUILDS = {k: _side(v) for k, v in dict(intro=build_intro, r1=build_r1, sf=build_sf, final=build_final, win=build_win).items()}


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("part", choices=list(BUILDS))
    ap.add_argument("--out", required=True)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--plan-only", action="store_true")
    a = ap.parse_args()
    from stickfig import animecheck, cli, plan as pm, qa
    sc, rep, beats, dt = BUILDS[a.part]()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    if a.check or a.plan_only:
        pl = pm.build_plan(sc)
        pm.save_plan(pl, out / "plan.json")
        g = qa.run_gate(pl, sc.get("qa"))
        print("点検:", "合格" if g["passed"] else f"不合格 {g['failed']}")
        if a.check and beats:
            sb = [dict(b, t=b["t"] + dt) for b in beats]
            print(animecheck.report(animecheck.check(sc, pl, sb, None)))
    elif a.preview:
        from stickfig import preview
        print(preview.preview_scene(sc, out / "preview.mp4", cli.find_ffmpeg()))
    else:
        print(cli.build_scene(sc, out))


if __name__ == "__main__":
    main()
