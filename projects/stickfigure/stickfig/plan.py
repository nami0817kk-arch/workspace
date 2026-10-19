"""台本(YAML) → plan(コマごとの姿勢・カメラ・出来事の表)。純粋な Python。

plan は Blender(blender_player.py)と合成(compose.py)と点検(qa.py)が共通で読む。
接触(蹴り・斬りが相手の体に届くこと)は、順運動学で「届く高さ・位置」を逆算して合わせる(solve_contacts)。
"""
from __future__ import annotations

import copy
import json
import math
import os
from pathlib import Path
from typing import Dict, List, Optional

import yaml

from . import fk, mocap, physics
from .interp import build_timeline, smoothstep
from .interp import Spring
from .pose import KeyTrack, Smoother, STANCE_A, STANCE_B, apply_run

VIEW = dict(width=1280, height=720, ground_y=560, px_per_unit=150.0)
SHAKE = dict(kick=0.10, slash=0.10, wall=0.14, heel=0.18, hit=0.08)   # 命中の種類ごとのカメラの揺れ(単位)
EFFECTOR = dict(foot=("foot", "fl", (0.2, 2.6)), rear_foot=("rear_foot", "rl", (-0.8, 2.6)),
                hand=("hand", "fa", (-0.5, 3.0)), tip=("tip", "fa", (-0.5, 3.0)))


def load_scene(path) -> dict:
    scene = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    validate_scene(scene)
    return scene


def validate_scene(scene: dict) -> None:
    for k in ("fps", "tau_end", "actors", "keys", "camera"):
        if k not in scene:
            raise ValueError(f"台本に {k} がない")
    if set(scene["keys"]) != set(scene["actors"]):
        raise ValueError("keys と actors のキャラ名が合わない")
    for who, ks in scene["keys"].items():
        ts = [float(k["t"]) for k in ks]
        if ts != sorted(ts):
            raise ValueError(f"{who} のキーの時刻が昇順でない")
    for h in scene.get("hits", []):
        if "tau" not in h:
            raise ValueError("hits に tau がない")
        c = h.get("contact")
        if c and c.get("effector", "foot") not in EFFECTOR:
            raise ValueError(f"知らない effector: {c.get('effector')}")


def _stance(actor: dict) -> dict:
    return dict(STANCE_B if actor.get("heavy") else STANCE_A)


def make_tracks(scene: dict) -> Dict[str, KeyTrack]:
    return {who: KeyTrack(scene["keys"][who], _stance(a)) for who, a in scene["actors"].items()}


class ClipBank:
    """台本の clips(キャラごとの clip の区間)を持ち、tau の姿勢に混ぜる。

    clips:
      A: [{file: run_09_01, start: 3.0, end: 4.0, loop: true, speed: 1.0, anchor_dx: 1.0, offset: 0.0,
           in: 0.1, out: 0.1, amp: {fa: 1.5, ra: 1.5}, flip: false}]
    clip の中身は mocap.py が作る姿勢の列。区間では、キーの姿勢と混ぜる(in/out 秒でなめらかに入り・出る)。
    """

    def __init__(self, scene: dict):
        self.scene = scene
        self.defs = scene.get("clips", {})
        self.cache: Dict[str, "mocap.Clip"] = {}
        self.dir = Path(scene.get("clips_dir") or os.environ.get("STICKFIG_CLIPS", Path(__file__).resolve().parents[1] / "clips"))
        # strike_at: clip の「突く・蹴る瞬間」を、台本の時刻に合わせる(start/end は区間。省略時は clip の全体)
        for who, lst in self.defs.items():
            for c in lst:
                if "strike_at" in c:
                    clip = self._clip(c["file"])
                    if clip.strike is None:
                        raise ValueError(f"{c['file']} には strike の記録がない(find_strikes で作った clip を使う)")
                    sp = c.get("speed", 1.0)
                    c.setdefault("start", c["strike_at"] - clip.strike["t"] / sp)
                    c.setdefault("end", c["start"] + clip.duration / sp)
                    c["offset"] = clip.strike["t"] - (c["strike_at"] - c["start"]) * sp

    def _clip(self, name: str) -> "mocap.Clip":
        if name not in self.cache:
            self.cache[name] = mocap.Clip(mocap.load_clip(self.dir / f"{name}.json"))
        return self.cache[name]

    def weight(self, c: dict, tau: float) -> float:
        a, b = c["start"], c["end"]
        w_in = smoothstep(tau, a - c.get("in", 0.1), a) if c.get("in", 0.1) > 0 else (1.0 if tau >= a else 0.0)
        w_out = 1.0 - (smoothstep(tau, b, b + c.get("out", 0.1)) if c.get("out", 0.1) > 0 else (1.0 if tau > b else 0.0))
        return max(0.0, min(1.0, w_in * w_out))

    def active(self, who: str, tau: float, min_w: float = 0.5) -> Optional[dict]:
        best = None
        for c in self.defs.get(who, []):
            w = self.weight(c, tau)
            if w >= min_w and (best is None or w > best[0]):
                best = (w, c)
        return best[1] if best else None

    def sample(self, c: dict, tau: float) -> Dict[str, float]:
        clip = self._clip(c["file"])
        speed = c.get("speed", 1.0)
        u = (tau - c["start"]) * speed + c.get("offset", 0.0)
        v = clip.sample(u, c.get("loop", False))
        if c.get("loop", False) and clip.loopable:
            cycles = math.floor(u * clip.fps / clip.n)
            v["dx"] += cycles * clip.dx_cycle
        elif c.get("loop", False) and clip.duration > 0:
            cycles = math.floor(u / clip.duration)
            v["dx"] += cycles * (clip.params["dx"][-1] - clip.params["dx"][0])
        v["hz"] = v["hz"] + c.get("hz_off", 0.0)
        v["dx"] = c.get("anchor_dx", 0.0) + (v["dx"] - clip.params["dx"][int(min(clip.n - 1, max(0.0, c.get("offset", 0.0)) * clip.fps))]) * c.get("dx_scale", 1.0)
        for k, amp in (c.get("amp") or {}).items():
            if k in v and k != "dx":
                mean = float(clip.params[k].mean())
                v[k] = mean + (v[k] - mean) * amp
        return v

    def apply(self, who: str, p: Dict[str, float], tau: float) -> Dict[str, float]:
        for c in self.defs.get(who, []):
            w = self.weight(c, tau)
            if w <= 0.0:
                continue
            v = self.sample(c, tau)
            p = dict(p)
            for k in mocap.CLIP_KEYS:
                if k in v:
                    p[k] = (1 - w) * p[k] + w * v[k]
        return p


def _sign(actor: dict) -> int:
    return 1 if actor.get("facing", 1) >= 0 else -1


def _root_x(actor: dict, p: Dict[str, float]) -> float:
    return actor["base_x"] + _sign(actor) * p["dx"]


def skeleton_at(scene: dict, tracks: Dict[str, KeyTrack], who: str, tau: float, pose: Optional[dict] = None) -> dict:
    a = scene["actors"][who]
    if pose is None:
        pose = apply_run(tracks[who].at(tau), tau, scene.get("run"))
        if scene.get("_bank") is not None:
            pose = scene["_bank"].apply(who, pose, tau)
    p = pose
    return fk.skeleton(p, _sign(a), _root_x(a, p), a.get("scale", 1.0))


def _set_key(track: KeyTrack, t: float, name: str, value: float) -> None:
    for i, tt in enumerate(track.ts):
        if abs(tt - t) < 1e-9:
            track.rows[i][name] = value
            from .interp import Curve
            track.curves[name] = Curve(track.ts, [r[name] for r in track.rows])
            return
    raise ValueError(f"t={t} にキーがない(接触の調整には、その時刻のキーが要る)")


def solve_contact(scene: dict, tracks: Dict[str, KeyTrack], hit: dict) -> dict:
    """命中 hit の contact を満たすよう、攻める側のキーを調整する。結果(距離など)を返す。"""
    c = hit["contact"]
    tau = hit["tau"]
    striker, tgt = c["striker"], c["target"]["actor"]
    eff_key, param, (lo, hi) = EFFECTOR[c.get("effector", "foot")]
    sa = scene["actors"][striker]
    s = _sign(sa)
    off = c.get("offset", [0.0, 0.0])      # 当て先の点から (x, z) ずらした所を狙う(体に少しめり込ませるなど)
    adj = c.get("adjust_keys", [tau])
    bank = scene.get("_bank")
    clip = bank.active(striker, tau) if bank is not None else None
    if clip is not None:       # clip(モーションキャプチャ)は高さを変えられない。位置だけ anchor_dx で合わせる
        if c.get("height", True):          # 高さは腰の上げ下げで合わせる(±0.3 まで)
            eff = skeleton_at(scene, tracks, striker, tau)[eff_key]
            tp = fk.target_point(skeleton_at(scene, tracks, tgt, tau), c["target"].get("point", "hip"))
            clip["hz_off"] = max(-0.3, min(0.3, clip.get("hz_off", 0.0) + (tp[1] + off[1]) - eff[1]))
        for _ in range(8):
            eff = skeleton_at(scene, tracks, striker, tau)[eff_key]
            tp = fk.target_point(skeleton_at(scene, tracks, tgt, tau), c["target"].get("point", "hip"))
            dxw = (tp[0] + off[0]) - eff[0]
            clip["anchor_dx"] = clip.get("anchor_dx", 0.0) + dxw / s
            if abs(dxw) < 1e-4:
                break
        eff = skeleton_at(scene, tracks, striker, tau)[eff_key]
        sk_t = skeleton_at(scene, tracks, tgt, tau)
        tp = fk.target_point(sk_t, c["target"].get("point", "hip"))
        return dict(tau=tau, striker=striker, target=tgt, effector=c.get("effector", "foot"),
                    distance_to_point=math.hypot(eff[0] - tp[0] - off[0], eff[1] - tp[1] - off[1]),
                    distance_to_body=fk.dist_to_body(eff, sk_t), effector_pos=list(eff), target_pos=list(tp))
    # 1) 高さ: 角度パラメータを二分法で合わせる(height: false なら飛ばす)
    for _ in range(40 if c.get("height", True) else 0):
        mid = 0.5 * (lo + hi)
        _set_key(tracks[striker], tau, param, mid)
        eff = skeleton_at(scene, tracks, striker, tau)[eff_key]
        tp = fk.target_point(skeleton_at(scene, tracks, tgt, tau), c["target"].get("point", "hip"))
        if eff[1] < tp[1] + off[1]:
            lo = mid
        else:
            hi = mid
    if c.get("height", True):
        ang = 0.5 * (lo + hi)
        for t in adj:
            _set_key(tracks[striker], t, param, ang)
    # 2) 位置: 根元の前進量 dx を合わせる(複数回で収束)
    for _ in range(6):
        eff = skeleton_at(scene, tracks, striker, tau)[eff_key]
        tp = fk.target_point(skeleton_at(scene, tracks, tgt, tau), c["target"].get("point", "hip"))
        dxw = (tp[0] + off[0]) - eff[0]
        track = tracks[striker]
        cur = track.at(tau)["dx"]
        for t in adj:
            i = track.ts.index(min(track.ts, key=lambda x: abs(x - t)))
            _set_key(track, track.ts[i], "dx", track.rows[i]["dx"] + dxw / s)
        if abs(dxw) < 1e-4:
            break
    eff = skeleton_at(scene, tracks, striker, tau)[eff_key]
    sk_t = skeleton_at(scene, tracks, tgt, tau)
    tp = fk.target_point(sk_t, c["target"].get("point", "hip"))
    return dict(tau=tau, striker=striker, target=tgt, effector=c.get("effector", "foot"),
                distance_to_point=math.hypot(eff[0] - tp[0] - off[0], eff[1] - tp[1] - off[1]),
                distance_to_body=fk.dist_to_body(eff, sk_t), effector_pos=list(eff), target_pos=list(tp))


class Planter:
    """足の接地: 腰を低くした姿勢で足が地面の下に潜るとき、膝の曲げを足して足を地面に合わせる。

    しゃがむ・かわす・着地の姿勢を、腰の高さだけで指定しても、脚が伸びたまま潜らないようにする。
    脚がほぼ伸びた所では、足の高さのわずかな差で膝の角度が急変するため、補正量にバネを掛けてなめらかにする
    (それでも潜る分は、根元を持ち上げて必ず地面の上に収める)。
    倒れている(roll が大きい)人物は変えない。
    """

    def __init__(self, actor: dict):
        self.actor = actor
        self.sp = {"fk": Spring(0.0, 1500, 0.9), "rk": Spring(0.0, 1500, 0.9)}

    def _foot_z(self, q: Dict[str, float], ang: str, knee: str, k: float) -> float:
        t = dict(q)
        t[knee] = k
        sk = fk.skeleton(t, _sign(self.actor), 0.0, self.actor.get("scale", 1.0))
        leg = sk["front_leg"] if ang == "fl" else sk["rear_leg"]
        return min(pt[1] for pt in leg)

    def apply(self, p: Dict[str, float], dtau: float) -> Dict[str, float]:
        sc = self.actor.get("scale", 1.0)
        tol = -0.005 * sc
        q = dict(p)
        if abs(p["roll"]) > 0.5:
            for knee in ("fk", "rk"):
                self.sp[knee].x = 0.0
            return q
        lift = 0.0
        for ang, knee in (("fl", "fk"), ("rl", "rk")):
            base = p[knee]
            need = 0.0
            if self._foot_z(q, ang, knee, base) < tol:
                lo, hi = base, 2.8
                if self._foot_z(q, ang, knee, hi) < tol:
                    need = hi - base
                else:
                    for _ in range(30):
                        mid = 0.5 * (lo + hi)
                        if self._foot_z(q, ang, knee, mid) < tol:
                            lo = mid
                        else:
                            hi = mid
                    need = hi - base
            d = self.sp[knee].step(need, dtau) if dtau > 0 else self.sp[knee].x
            q[knee] = base + max(0.0, d)
        for ang, knee in (("fl", "fk"), ("rl", "rk")):
            z = self._foot_z(q, ang, knee, q[knee])
            if z < tol:
                lift = max(lift, -z)
        q["rz"] = q["rz"] + lift
        return q


def _lift_to_ground(scene: dict, frames: List[dict]) -> None:
    """物理は2節の折れ線、rig は6節の曲線なので、深く折れた姿勢で曲線が地面に潜ることがある。
    潜る分だけ根元を持ち上げる。持ち上げは急に変えず(戻りは1コマ0.02まで)、ぴくつかせない。"""
    for who, a in scene["actors"].items():
        sc, s = a.get("scale", 1.0), _sign(a)
        lift = 0.0
        for fr in frames:
            p = fr["actors"][who]
            sk = fk.skeleton(dict(p, rz=p["rz"]), s, p["root_x"], sc)
            low = min(min(pt[1] for pt in ln) for ln in fk.body_lines(sk))
            low = min(low, sk["head"][1] - sk["head_r"])
            need = max(0.0, -low + 0.01 * sc)
            lift = max(need, lift - 0.02)
            p["rz"] = p["rz"] + lift
            p["root_z"] = p["root_z"] + lift


def run_physics(scene: dict, tracks: Dict[str, KeyTrack]) -> dict:
    """姿勢の計画(キー・clip・走り)を目標に、物理で動かす。命中は衝突から出す。

    scene['physics']: {wall はstage.wall_x, knockable: [倒される側], knock_seconds, holds: {kick: 0.09, ...}, thresholds: {...}}
    戻り値: states/taus(細かい時間の姿勢の列), hits(命中を timeline 用に整えたもの), puffs(着地など)
    """
    ph = scene["physics"] or {}
    planters = {w: Planter(a) for w, a in scene["actors"].items() if a.get("plant", True)}
    memo: Dict[tuple, dict] = {}
    last_tau: Dict[str, float] = {}

    def target(who: str, tau: float) -> dict:
        key = (who, round(tau / physics.DT))
        if key in memo:
            return dict(memo[key])
        p = apply_run(tracks[who].at(tau), tau, scene.get("run"))
        if scene.get("_bank") is not None:
            p = scene["_bank"].apply(who, p, tau)
        if who in planters:
            dt = tau - last_tau.get(who, tau)
            p = planters[who].apply(p, dt)
            last_tau[who] = tau
        memo[key] = dict(p)
        if len(memo) > 4000:
            memo.pop(next(iter(memo)))
        return dict(p)

    res = physics.simulate(scene, target, scene["tau_end"] + 0.5)
    holds = dict(kick=0.09, slash=0.04, hit=0.06, wall=0.06)
    holds.update(ph.get("holds", {}))
    hits, puffs = [], []
    for e in res["events"]:
        if e.kind in holds:
            hits.append(dict(tau=round(e.tau, 4), hold=holds[e.kind], kind=e.kind, pos=[e.pos[0], e.pos[1]], impulse=round(e.impulse, 2)))
        else:
            puffs.append(dict(tau=round(e.tau, 4), kind=e.kind, pos=[e.pos[0], 0.0]))
    res["hits"], res["puffs"] = hits, puffs
    return res


def build_plan(scene: dict, solve: bool = True) -> dict:
    scene = copy.deepcopy(scene)
    fps = int(scene["fps"])
    tracks = make_tracks(scene)
    scene["_bank"] = ClipBank(scene) if scene.get("clips") else None
    contacts = []
    if solve:
        for h in scene.get("hits", []):
            if h.get("contact"):
                contacts.append(solve_contact(scene, tracks, h))
    phys = None
    if scene.get("physics") is not None:
        phys = run_physics(scene, tracks)
        scene["hits"], scene["puffs"] = phys["hits"], phys["puffs"]
        contacts = []
    taus, events = build_timeline(scene["tau_end"], fps, scene.get("hits", []), scene.get("slow", []), scene.get("puffs", []))
    smoothers = {who: Smoother(tr) for who, tr in tracks.items()}
    planters = {who: Planter(a) for who, a in scene["actors"].items() if a.get("plant", True)}
    cam_keys = scene["camera"]
    from .interp import Curve
    cx_curve = Curve([k[0] for k in cam_keys], [k[1] for k in cam_keys])
    cs_curve = Curve([k[0] for k in cam_keys], [k[2] for k in cam_keys])
    camx, cams = cx_curve(0.0), cs_curve(0.0)
    hold_frames = set()
    for e in events:
        for i in range(e["frame"] + 1, e["frame"] + e.get("hold_frames", 0)):
            hold_frames.add(i)
    frames = []
    for f, tau in enumerate(taus):
        dtau = tau - taus[f - 1] if f > 0 else 0.0
        fr = dict(tau=tau, actors={})
        for who, a in scene["actors"].items():
            if phys is not None:
                p = physics.sample(phys["states"][who], phys["taus"], min(tau, phys["taus"][-1]), a)
                p["face"] = tracks[who].at(tau)["face"]
            else:
                p = smoothers[who].step(tau, dtau)
                p = apply_run(p, tau, scene.get("run"))
                if scene["_bank"] is not None:
                    p = scene["_bank"].apply(who, p, tau)
                    act = scene["_bank"].active(who, tau, 0.3)
                    if act is not None and act.get("loop"):
                        p = dict(p, periodic=1.0)          # 周期運動(走り)の区間。点検の「途中で止まる」から外す
                if who in planters:
                    p = planters[who].apply(p, dtau)
            s = _sign(a)
            jit = 0.0
            if f > 0 and dtau == 0.0:
                jit = (0.014 if a.get("heavy") else 0.007) * math.sin(f * 7.3)
            p = dict(p)
            p["jit"] = jit
            p["root_x"] = (p["root_x"] if phys is not None else _root_x(a, p)) + jit
            p["root_z"] = p["rz"] + abs(jit) * 0.5
            fr["actors"][who] = {k: (round(v, 6) if isinstance(v, float) else v) for k, v in p.items()}
        # カメラ: 目標へなめらかに追従 + 命中の揺れ
        tx, ts = cx_curve(tau), cs_curve(tau)
        camx += (tx - camx) * 0.22
        cams += (ts - cams) * 0.30
        shake = 0.0
        for e in events:
            d = f - e["frame"]
            amp = SHAKE.get(e["kind"], 0.0)
            if amp and 0 <= d < 10:
                shake += amp * (1 - d / 10)
        sx, sz = shake * math.sin(f * 2.9), shake * math.cos(f * 2.3)
        pxu = VIEW["width"] / cams
        fr["cam"] = dict(x=round(camx + sx, 5), scale=round(cams, 5), pxu=round(pxu, 4), sx=round(sx, 5), sz=round(sz, 5),
                         z=round((VIEW["ground_y"] - VIEW["height"] / 2) / pxu + sz, 5))
        frames.append(fr)
    if phys is not None:
        _lift_to_ground(scene, frames)
    # 出来事の位置(世界座標)
    hit_by_tau = {h["tau"]: h for h in scene.get("hits", [])}
    for e in events:
        h = hit_by_tau.get(e["tau"], {})
        if "pos" in h:
            e["pos"] = list(h["pos"])
        elif h.get("contact"):
            c = h["contact"]
            sk = skeleton_at(scene, tracks, c["target"]["actor"], e["tau"])
            e["pos"] = list(fk.target_point(sk, c["target"].get("point", "hip")))
        else:
            p = next((x for x in scene.get("puffs", []) if x["tau"] == e["tau"]), {})
            e["pos"] = list(p.get("pos", [0.0, 0.0]))
        e["fx"] = dict(h.get("fx", {}))
    return dict(version=1, fps=fps, n=len(frames), view=VIEW, actors=scene["actors"], stage=scene.get("stage", {}),
                events=events, contacts=contacts, frames=frames, scene={k: scene[k] for k in ("hits", "slow", "camera", "fx") if k in scene})


def save_plan(plan: dict, path) -> None:
    Path(path).write_text(json.dumps(plan, ensure_ascii=False), encoding="utf-8")


def load_plan(path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))
