"""モーションキャプチャ(BVH)を、棒人間の姿勢パラメータ(横から見た2Dの角度)の列(clip)に変換する。純粋な Python + numpy。

人間の実際の動きは、手足が弧を描き、先端が遅れ、重心が移る。要の姿勢を数字で書く方式では出しにくい動きを、そのまま写す。
流れ: BVH を読む → 順運動学で3Dの関節位置 → 人物の向きで決めた縦の平面に射影 → 角度(真下から前へ) → 30fps に間引く。

出典: CMU Graphics Lab Motion Capture Database(mocap.cs.cmu.edu、NSF EIA-0196217)。
cgspeed の BVH 変換版を使う(「CMU は元データの利用に制限を置かない」)。
**元データ(BVH)と、そこから作った clip は、リポジトリに入れない**(再配布しない)。scripts/fetch_cmu.py で各自が取得して変換する。
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np

CLIP_KEYS = ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean", "hz", "dx")


class Bvh:
    def __init__(self, names, parent, offset, chans, frames, frame_time):
        self.names, self.parent, self.offset, self.chans = names, parent, offset, chans
        self.frames, self.frame_time = frames, frame_time
        self.index = {n: i for i, n in enumerate(names)}


def parse_bvh(text: str) -> Bvh:
    toks = re.split(r"\s+", text.strip())
    i = 0
    names: List[str] = []
    parent: List[int] = []
    offset: List[np.ndarray] = []
    chans: List[List[str]] = []
    stack: List[int] = []

    def nxt() -> str:
        nonlocal i
        t = toks[i]
        i += 1
        return t

    assert nxt() == "HIERARCHY"
    while i < len(toks):
        t = nxt()
        if t in ("ROOT", "JOINT"):
            names.append(nxt())
            parent.append(stack[-1] if stack else -1)
            offset.append(np.zeros(3))
            chans.append([])
            stack.append(len(names) - 1)
        elif t == "End":
            nxt()          # Site
            assert nxt() == "{"
            while nxt() != "}":
                pass
        elif t == "OFFSET":
            offset[stack[-1]] = np.array([float(nxt()), float(nxt()), float(nxt())])
        elif t == "CHANNELS":
            n = int(nxt())
            chans[stack[-1]] = [nxt() for _ in range(n)]
        elif t == "}":
            stack.pop()
        elif t == "MOTION":
            break
    assert nxt() == "Frames:"
    n_frames = int(nxt())
    assert nxt() == "Frame"
    assert nxt() == "Time:"
    frame_time = float(nxt())
    n_ch = sum(len(c) for c in chans)
    data = np.array(toks[i:i + n_frames * n_ch], dtype=float).reshape(n_frames, n_ch)
    return Bvh(names, parent, offset, chans, data, frame_time)


def _rot(axis: str, deg: np.ndarray) -> np.ndarray:
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    z, o = np.zeros_like(a), np.ones_like(a)
    if axis == "X":
        m = [[o, z, z], [z, c, -s], [z, s, c]]
    elif axis == "Y":
        m = [[c, z, s], [z, o, z], [-s, z, c]]
    else:
        m = [[c, -s, z], [s, c, z], [z, z, o]]
    return np.moveaxis(np.array(m), (0, 1), (-2, -1))


def world_positions(b: Bvh) -> np.ndarray:
    """全フレーム×全関節の3D位置。形は (frames, joints, 3)。"""
    nf, nj = len(b.frames), len(b.names)
    pos = np.zeros((nf, nj, 3))
    rot = np.tile(np.eye(3), (nf, nj, 1, 1))
    col = 0
    for j in range(nj):
        ch = b.chans[j]
        vals = {c: b.frames[:, col + k] for k, c in enumerate(ch)}
        col += len(ch)
        local = np.tile(np.eye(3), (nf, 1, 1))
        for c in ch:
            if c.endswith("rotation"):
                local = local @ _rot(c[0], vals[c])      # チャンネルの並びの順に掛ける(BVH の規約)
        trans = np.stack([vals.get("Xposition", np.zeros(nf)), vals.get("Yposition", np.zeros(nf)),
                          vals.get("Zposition", np.zeros(nf))], axis=1)
        p = b.parent[j]
        if p < 0:
            pos[:, j] = b.offset[j] + trans
            rot[:, j] = local
        else:
            pos[:, j] = pos[:, p] + np.einsum("fij,j->fi", rot[:, p], b.offset[j])
            rot[:, j] = rot[:, p] @ local
    return pos


def _fwd(p: np.ndarray, ix: Dict[str, int], frame: int = 0) -> np.ndarray:
    """向いている向き(水平)。つま先が足首より前にあることから決める。"""
    v = np.zeros(3)
    for side in ("Left", "Right"):
        if f"{side}ToeBase" in ix and f"{side}Foot" in ix:
            v += p[frame, ix[f"{side}ToeBase"]] - p[frame, ix[f"{side}Foot"]]
    v[1] = 0.0
    n = np.linalg.norm(v)
    if n < 1e-9:
        v = np.array([0.0, 0.0, 1.0])
        n = 1.0
    return v / n


def _angle_down(v_f: np.ndarray, v_u: np.ndarray) -> np.ndarray:
    """平面内のベクトルの、真下からの角度(前=+)。"""
    return np.arctan2(v_f, -v_u)


def _unwrap(a: np.ndarray) -> np.ndarray:
    return np.unwrap(a)


EFFECTORS = {"RightHand": ("hand", "R"), "LeftHand": ("hand", "L"), "RightFoot": ("foot", "R"), "LeftFoot": ("foot", "L")}


def find_strikes(b: Bvh, p: Optional[np.ndarray] = None, top: int = 3, min_gap: float = 1.0) -> List[dict]:
    """突く・蹴る瞬間を、手首・足首の最大速度から見つける(3D速度。5コマで平滑化)。"""
    p = world_positions(b) if p is None else p
    ix = b.index
    dt = b.frame_time
    cands = []
    for name, (kind, side) in EFFECTORS.items():
        pos = p[:, ix[name]]
        v = np.linalg.norm(np.gradient(pos, dt, axis=0), axis=1)
        v = np.convolve(v, np.ones(5) / 5, mode="same")
        margin = max(2, int(0.5 / dt))      # 先頭・末尾の0.5秒は、データの継ぎ目の乱れが出るので見ない
        for i in range(margin, len(v) - margin):
            if v[i] >= v[i - 1] and v[i] > v[i + 1]:
                cands.append((float(v[i]), i * dt, name))
    cands.sort(reverse=True)
    out: List[dict] = []
    for sp, t, name in cands:
        if all(abs(t - o["t"]) >= min_gap for o in out):
            out.append(dict(t=t, speed=sp, joint=name, kind=EFFECTORS[name][0], side=EFFECTORS[name][1]))
        if len(out) >= top:
            break
    return out


def heading_vector(b: Bvh, p: np.ndarray, mode: str, frame: int = 0, around: Optional[float] = None, joint: Optional[str] = None) -> np.ndarray:
    ix = b.index
    if mode == "travel":              # 腰が進む向き
        hip = (p[:, ix["LeftUpLeg"]] + p[:, ix["RightUpLeg"]]) / 2
        v = hip[-1] - hip[0]
        v[1] = 0
    elif mode == "strike" and around is not None and joint is not None:   # 突く・蹴る手足が動く向き
        i = int(round(around / b.frame_time))
        k = 6
        pos = p[:, ix[joint]]
        v = pos[min(len(pos) - 1, i + k)] - pos[max(0, i - k)]
        v[1] = 0
    else:                             # つま先の向き
        return _fwd(p, ix, frame)
    n = np.linalg.norm(v)
    return v / n if n > 1e-6 else _fwd(p, ix, frame)


def retarget(b: Bvh, out_fps: int = 30, heading_frame: int = 0, flip: bool = False, leg_len_m: float = 0.9,
             t0: float = 0.0, t1: Optional[float] = None, heading: str = "face", strike: Optional[dict] = None,
             mirror: bool = False, p: Optional[np.ndarray] = None) -> Dict[str, object]:
    """BVH → clip。

    heading: 平面(横から見る向き)の決め方。face=つま先の向き / travel=腰の進行方向 / strike=突く・蹴る手足の動く向き
    mirror: 左右を入れ替える(左手で突く動きを、前の腕=右として使えるようにする)
    strike: find_strikes の1件。clip に strike(時刻・部位)を記録し、台本の命中に合わせられるようにする
    flip=True で向きを逆。"""
    p = world_positions(b) if p is None else p
    ix = b.index
    f = heading_vector(b, p, heading, heading_frame, strike["t"] if strike else None, strike["joint"] if strike else None)
    if flip:
        f = -f
    up = np.array([0.0, 1.0, 0.0])

    def pf(j: str) -> np.ndarray:
        return p[:, ix[j]] @ f

    def pu(j: str) -> np.ndarray:
        return p[:, ix[j]] @ up

    def ang(a: str, c: str) -> np.ndarray:
        return _unwrap(_angle_down(pf(c) - pf(a), pu(c) - pu(a)))

    out: Dict[str, np.ndarray] = {}
    # 股関節の中点(骨盤の根元 Hips は股関節より高いので、股関節の高さを腰とする)
    hip_f = (pf("LeftUpLeg") + pf("RightUpLeg")) / 2
    hip_u = (pu("LeftUpLeg") + pu("RightUpLeg")) / 2
    # 胴の前傾: 腰から肩の中点へ。真上からの角度(前=+)
    sh_f = (pf("LeftArm") + pf("RightArm")) / 2
    sh_u = (pu("LeftArm") + pu("RightArm")) / 2
    out["lean"] = _unwrap(np.arctan2(sh_f - hip_f, sh_u - hip_u))
    swap = {"Right": "Left", "Left": "Right"} if mirror else {"Right": "Right", "Left": "Left"}
    for side, (u, e) in (("R", ("fa", "fe")), ("L", ("ra", "re"))):
        long = swap["Right" if side == "R" else "Left"]
        up_ang = ang(f"{long}Arm", f"{long}ForeArm")
        fo_ang = ang(f"{long}ForeArm", f"{long}Hand")
        out[u] = up_ang + out["lean"]                  # リグでは腕が胴の子。胴の傾きに合わせて回る(胴からの相対角)
        out[e] = _unwrap(fo_ang - up_ang)
    for side, (t, k) in (("R", ("fl", "fk")), ("L", ("rl", "rk"))):
        long = swap["Right" if side == "R" else "Left"]
        th = ang(f"{long}UpLeg", f"{long}Leg")
        sh = ang(f"{long}Leg", f"{long}Foot")
        out[t] = th
        out[k] = _unwrap(th - sh)
    # 腰の高さ(足首が最も低い所を地面として、脚の長さで自作の寸法に直す)
    leg = np.median(np.linalg.norm(p[:, ix["RightUpLeg"]] - p[:, ix["RightLeg"]], axis=1)
                    + np.linalg.norm(p[:, ix["RightLeg"]] - p[:, ix["RightFoot"]], axis=1))
    s = leg_len_m / leg
    ground = min(pu("LeftFoot").min(), pu("RightFoot").min())
    out["hz"] = (hip_u - ground) * s + 0.02
    out["dx"] = (hip_f - hip_f[0]) * s
    n = len(out["hz"])
    dt = b.frame_time
    ts = np.arange(n) * dt
    end = ts[-1] if t1 is None else min(t1, ts[-1])
    tt = np.arange(t0, end, 1.0 / out_fps)
    res = {k: np.interp(tt, ts, v).tolist() for k, v in out.items()}
    meta: Dict[str, object] = {}
    if strike is not None:
        side = strike["side"]
        if mirror:
            side = "L" if side == "R" else "R"
        meta["strike"] = dict(t=round(strike["t"] - t0, 4), kind=strike["kind"], front=(side == "R"))
    return dict(fps=out_fps, n=len(tt), scale=s, params={k: [round(x, 5) for x in v] for k, v in res.items()}, **meta)


LOOP_KEYS = ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean")


def find_loop(clip: dict, min_sec: float = 0.45, max_start: int = 8) -> Optional[dict]:
    """走りなどの周期運動で、姿勢と速度がいちばん合う区間を探し、ぴったり輪にした clip を返す。

    先頭の数コマは、データの継ぎ目の乱れがあるので始点に使わない。区間 [s, e) を切り出し、dx の1周期ぶんを dx_cycle に記録する。
    """
    P = {k: np.array(clip["params"][k]) for k in LOOP_KEYS}
    n, fps = clip["n"], clip["fps"]
    X = np.stack([P[k] for k in LOOP_KEYS], axis=1)
    V = np.gradient(X, axis=0)
    best = None
    for s0 in range(1, min(max_start, n)):
        for e in range(s0 + int(min_sec * fps), n):
            d = float(np.sum((X[s0] - X[e]) ** 2) + 4.0 * np.sum((V[s0] - V[e]) ** 2))
            if best is None or d < best[0]:
                best = (d, s0, e)
    if best is None:
        return None
    _, s0, e = best
    out = dict(clip)
    out["params"] = {k: v[s0:e] for k, v in clip["params"].items()}
    out["n"] = e - s0
    dx = clip["params"]["dx"]
    out["dx_cycle"] = round(float(dx[e] - dx[s0]), 5)
    out["loop"] = True
    out["loop_error"] = round(best[0], 5)
    return out


def save_clip(clip: dict, path) -> None:
    Path(path).write_text(json.dumps(clip), encoding="utf-8")


def load_clip(path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


class Clip:
    """clip(30fps の姿勢列)を、秒で引く。"""

    def __init__(self, data: dict):
        self.fps = data["fps"]
        self.n = data["n"]
        self.params = {k: np.array(v) for k, v in data["params"].items()}
        for k, v in self.params.items():          # 角度は 2π ずれても同じ姿勢。平均が ±π に入るよう整える(clip 同士のつなぎで 2π の飛びが出る)
            if k not in ("hz", "dx"):                # 角度は 2π ずれても同じ姿勢。clip の中では連続に(unwrap)、全体は平均が ±π に入るよう 2π の倍数だけずらす
                u = np.unwrap(np.asarray(v, dtype=float))
                self.params[k] = u - 2 * math.pi * round(float(u.mean()) / (2 * math.pi))
        self.duration = (self.n - 1) / self.fps
        self.strike = data.get("strike")
        self.loopable = bool(data.get("loop"))
        self.dx_cycle = data.get("dx_cycle")

    def sample(self, t: float, loop: bool = False) -> Dict[str, float]:
        if loop and self.loopable and self.n > 1:      # ぴったり輪にした clip は、最後のコマから最初のコマへ補間する
            x = (t * self.fps) % self.n
            i = int(math.floor(x))
            j = (i + 1) % self.n
            u = x - i
            return {k: float(v[i] * (1 - u) + v[j] * u) for k, v in self.params.items()}
        if loop and self.duration > 0:
            t = t % self.duration
        t = max(0.0, min(self.duration, t))
        x = t * self.fps
        i = int(math.floor(x))
        j = min(i + 1, self.n - 1)
        u = x - i
        return {k: float(v[i] * (1 - u) + v[j] * u) for k, v in self.params.items()}
