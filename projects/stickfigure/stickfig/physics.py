"""2D 物理シミュレーションで、棒人間どうしの接触を「本当に当たった結果」にする。

従来は、要の姿勢(キー)とモーションキャプチャを、そのまま姿勢として再生していた。2人の体は線として重なるだけで、
すり抜け(2026-10-19 に測定: 345 コマ中 234 コマで線が交差)、敵の反応も「その時刻に折れる」と決めてあるだけだった。
ここでは、棒人間を剛体(胴・頭・腕・脚)で作り、**姿勢の計画(キー・clip・走り)を目標として、関節のバネ(PD制御)で追従**させる。
2人の体は互いにすり抜けない。蹴りが当たると勢いが相手に伝わり、折れる・押される・飛ぶ・壁に当たる・落ちる。
命中の位置と強さは衝突から出る(ヒットストップ・放射線・カメラの揺れの元になる)。

座標: pymunk は y が上(= plan の z)。向き s=+1 は右向き。角度 φ(反時計回り、ラジアン):
  手足(下向きに垂れる)の絶対的な前方角 A = s·φ  /  胴(上向き)の前傾 lean = -s·φ
rig の姿勢パラメータとの対応(fk.py と同じ約束):
  fa = A_上腕 + lean(腕は胴の子。胴からの相対角)  fe = A_前腕 - A_上腕  fl = A_太もも  fk = A_太もも - A_すね
"""
from __future__ import annotations

import math
from typing import Callable, Dict, List, Optional, Tuple

import pymunk

DT = 1.0 / 240.0
GRAVITY = 14.0                      # 少し強め(動きが軽く見えすぎないように)
R_SEG = 0.035                       # 手足の太さ(半径)
HEAD_R = 0.20

# 部位: (長さ, 質量)。質量は scale² で増やす
TORSO_L, UA_L, FA_L, TH_L, SH_L = 0.66, 0.33, 0.33, 0.45, 0.45
M_TORSO, M_UA, M_FA, M_TH, M_SH = 3.2, 0.6, 0.45, 1.4, 0.9
SWORD_REACH = 1.515                 # 肩から剣先まで(fk.py の腕 0.55 + 剣 0.965)

CT = dict(A=1, B=2, ground=3, wall=4)


def _lims(s: int, lo: float, hi: float) -> Tuple[float, float]:
    a, b = s * lo, s * hi
    return (min(a, b), max(a, b))


class Fighter:
    """棒人間1体ぶんの剛体と関節。"""

    def __init__(self, space: pymunk.Space, who: str, actor: dict, ctype: int, group: int):
        self.who, self.actor, self.space = who, actor, space
        self.s = 1 if actor.get("facing", 1) >= 0 else -1
        self.sc = sc = actor.get("scale", 1.0)
        self.ctype, self.group = ctype, group
        self.bodies: Dict[str, pymunk.Body] = {}
        self.shapes: List[pymunk.Shape] = []
        self.springs: Dict[str, Tuple[pymunk.DampedRotarySpring, float, float]] = {}
        self.knock = 0.0                # 0=自力で立つ 1=力が抜けた
        k = sc * sc

        def limb(name: str, L: float, mass: float, tag: str):
            L *= sc
            m = mass * k
            cog = (0.0, -L / 2)
            mom = pymunk.moment_for_segment(m, (0, L / 2), (0, -L / 2), R_SEG * sc)
            b = pymunk.Body(m, mom)
            b.center_of_gravity = cog
            sh = pymunk.Segment(b, (0, 0), (0, -L), R_SEG * sc)
            self._add(b, sh, name, tag)
            return b

        # 胴(原点=腰)。頭は円で胴に付ける
        Lt = TORSO_L * sc
        m_t = M_TORSO * k
        mom_t = (pymunk.moment_for_segment(m_t * 0.72, (0, -0.4 * sc), (0, Lt - 0.4 * sc), R_SEG * sc)
                 + pymunk.moment_for_circle(m_t * 0.28, 0, HEAD_R * sc, (0, (TORSO_L + 0.24) * sc - 0.4 * sc)))
        torso = pymunk.Body(m_t, mom_t)
        torso.center_of_gravity = (0, 0.4 * sc)
        self._add(torso, pymunk.Segment(torso, (0, 0), (0, Lt), R_SEG * sc), "torso", "torso")
        head = pymunk.Circle(torso, HEAD_R * sc, (0, (TORSO_L + 0.24) * sc))
        self._shape(head, "head")
        # 腕・脚(F=前、R=後ろ)
        for sd in ("F", "R"):
            ua = limb("ua" + sd, UA_L, M_UA, "arm")
            fa = limb("fa" + sd, FA_L, M_FA, "forearm")
            th = limb("th" + sd, TH_L, M_TH, "thigh")
            sh = limb("sh" + sd, SH_L, M_SH, "shin")
            self._pivot(torso, ua, (0, 0.6 * sc), (0, 0))
            self._pivot(ua, fa, (0, -UA_L * sc), (0, 0))
            self._pivot(torso, th, (0, 0), (0, 0))
            self._pivot(th, sh, (0, -TH_L * sc), (0, 0))
            s = self.s
            self._limit(torso, ua, *_lims(s, -2.8, 3.3))                 # 肩: fa の範囲
            self._limit(ua, fa, *_lims(s, -0.2, 2.9))                    # 肘: fe の範囲
            self._limit(torso, th, *_lims(s, -2.4, 3.4))                 # 腰: fl+lean の範囲
            self._limit(th, sh, *_lims(s, -2.8, 0.15))                   # 膝: rel = -s·fk
            for name, (a, b) in dict(shoulder=(torso, ua), elbow=(ua, fa), hip=(torso, th), knee=(th, sh)).items():
                om = 70.0 if name in ("shoulder", "elbow") else 55.0
                self._spring(f"{name}{sd}", a, b, om)
        self._spring("torso", self.space.static_body, torso, 30.0)
        # 前の前腕に剣
        if actor.get("weapon") == "sword":
            fa = self.bodies["faF"]
            sw = pymunk.Segment(fa, (0, -FA_L * sc), (0, -(SWORD_REACH - UA_L) * sc), 0.025 * sc)
            self._shape(sw, "sword")
        self.mass = sum(b.mass for b in self.bodies.values())

    # ---- 組み立ての小道具 ----
    def _shape(self, sh: pymunk.Shape, tag: str) -> None:
        sh.filter = pymunk.ShapeFilter(group=self.group)
        sh.collision_type = self.ctype
        sh.friction = 0.9
        sh.elasticity = 0.05
        sh.tag = f"{self.who}.{tag}"
        self.shapes.append(sh)
        self.space.add(sh)

    def _add(self, body: pymunk.Body, shape: pymunk.Shape, name: str, tag: str) -> None:
        self.bodies[name] = body
        self.space.add(body)
        self._shape(shape, tag)

    def _pivot(self, a: pymunk.Body, b: pymunk.Body, anchor_a, anchor_b) -> None:
        pj = pymunk.PivotJoint(a, b, (anchor_a[0], anchor_a[1]), (anchor_b[0], anchor_b[1]))
        pj.collide_bodies = False
        self.space.add(pj)

    def _limit(self, a: pymunk.Body, b: pymunk.Body, lo: float, hi: float) -> None:
        self.space.add(pymunk.RotaryLimitJoint(a, b, lo, hi))

    def _spring(self, name: str, a: pymunk.Body, b: pymunk.Body, omega: float) -> None:
        inertia = b.moment
        k, c = inertia * omega * omega, 2.0 * 1.0 * omega * inertia
        sp = pymunk.DampedRotarySpring(a, b, 0.0, k, c)
        self.space.add(sp)
        self.springs[name] = (sp, k, c)

    # ---- 目標姿勢への追従 ----
    def set_target(self, p: Dict[str, float], gain: float, leash: float, dt: float) -> None:
        s = self.s
        lean = p["lean"]
        t = self.bodies
        tgt = {"torso": -s * lean}
        for sd, (fa, fe, fl, fk) in (("F", (p["fa"], p["fe"], p["fl"], p["fk"])), ("R", (p["ra"], p["re"], p["rl"], p["rk"]))):
            tgt["shoulder" + sd] = s * fa
            tgt["elbow" + sd] = s * fe
            tgt["hip" + sd] = s * (fl + lean)
            tgt["knee" + sd] = -s * fk
        g = max(0.0, min(1.0, gain))
        for name, (sp, k, c) in self.springs.items():
            sp.rest_angle = -tgt[name]            # Chipmunk の回転バネは角度を a - b で測る(RotaryLimitJoint は b - a)
            sp.stiffness = k * g
            sp.damping = c * (0.35 + 0.65 * g)       # 力が抜けても、ばたつき続けないよう減衰は残す
        # 腰の位置を目標へ引く(命中されると力が抜けて、leash=0 になる)
        torso = t["torso"]
        tx = self.actor["base_x"] + s * p["dx"]
        tz = p["hz"] * self.sc + p["rz"]
        hip = torso.position
        vel = torso.velocity
        M = self.mass
        wx, wz, zeta = 10.0, 18.0, 0.9
        fx = M * wx * wx * (tx - hip.x) - 2 * zeta * M * wx * vel.x
        fz = M * wz * wz * (tz - hip.y) - 2 * zeta * M * wz * vel.y
        cap = M * 45.0
        fx, fz = max(-cap, min(cap, fx)) * leash, max(-cap, min(cap, fz)) * leash
        torso.apply_force_at_world_point((fx, fz), (hip.x, hip.y))

    def place(self, p: Dict[str, float]) -> None:
        """目標の姿勢に、剛体を最初から合わせる(開始時に崩れないように)。"""
        s, sc = self.s, self.sc
        t = self.bodies
        torso = t["torso"]
        torso.position = (self.actor["base_x"] + s * p["dx"], p["hz"] * sc + p["rz"])
        torso.angle = -s * p["lean"]
        for sd, (fa, fe, fl, fk) in (("F", (p["fa"], p["fe"], p["fl"], p["fk"])), ("R", (p["ra"], p["re"], p["rl"], p["rk"]))):
            ua, fo, th, sh = t["ua" + sd], t["fa" + sd], t["th" + sd], t["sh" + sd]
            ua.angle = torso.angle + s * fa
            fo.angle = ua.angle + s * fe
            th.angle = s * fl
            sh.angle = th.angle - s * fk
            ua.position = torso.local_to_world((0, 0.6 * sc))
            fo.position = ua.local_to_world((0, -UA_L * sc))
            th.position = torso.position
            sh.position = th.local_to_world((0, -TH_L * sc))
        for b in t.values():
            b.velocity = (0, 0)
            b.angular_velocity = 0

    def snapshot(self) -> Dict[str, Tuple[float, float, float]]:
        return {n: (b.position.x, b.position.y, b.angle) for n, b in self.bodies.items()}

    def read(self, base_params: Dict[str, float]) -> Dict[str, float]:
        """剛体の姿勢から、rig の姿勢パラメータを作る。"""
        s = self.s
        t = self.bodies
        out = dict(base_params)
        torso = t["torso"]
        lean = -s * torso.angle
        out["lean"] = lean
        for sd, (a, e, l, k) in (("F", ("fa", "fe", "fl", "fk")), ("R", ("ra", "re", "rl", "rk"))):
            A_up = s * t["ua" + sd].angle
            A_fo = s * t["fa" + sd].angle
            A_th = s * t["th" + sd].angle
            A_sh = s * t["sh" + sd].angle
            out[a] = A_up + lean
            out[e] = A_fo - A_up
            out[l] = A_th
            out[k] = A_th - A_sh
        hip = torso.position
        out["hz"] = hip.y / self.sc
        out["rz"] = 0.0
        out["roll"] = 0.0
        out["dx"] = (hip.x - self.actor["base_x"]) * s
        out["root_x"] = hip.x
        out["root_z"] = 0.0
        return out


def _l2w(snap: Tuple[float, float, float], v: Tuple[float, float]) -> Tuple[float, float]:
    x, y, a = snap
    c, s_ = math.cos(a), math.sin(a)
    return (x + v[0] * c - v[1] * s_, y + v[0] * s_ + v[1] * c)


def _solve_end(fn: Callable[[float, float], Tuple[float, float]], target: Tuple[float, float], x0: Tuple[float, float],
               lo: Tuple[float, float], hi: Tuple[float, float], iters: int = 12) -> Tuple[float, float]:
    """2変数(上の角度, 曲げ)を、鎖の先端が target に着くよう、ガウス・ニュートン法で解く。"""
    a, b = x0
    for _ in range(iters):
        px, pz = fn(a, b)
        rx, rz = target[0] - px, target[1] - pz
        if rx * rx + rz * rz < 1e-8:
            break
        h = 1e-4
        ax, az = fn(a + h, b)
        bx, bz = fn(a, b + h)
        j11, j21 = (ax - px) / h, (az - pz) / h
        j12, j22 = (bx - px) / h, (bz - pz) / h
        det = j11 * j22 - j12 * j21
        if abs(det) < 1e-6:
            break
        da = (rx * j22 - rz * j12) / det
        db = (j11 * rz - j21 * rx) / det
        a = max(lo[0], min(hi[0], a + max(-0.6, min(0.6, da))))
        b = max(lo[1], min(hi[1], b + max(-0.6, min(0.6, db))))
    return a, b


def convert(snap: Dict[str, Tuple[float, float, float]], actor: dict, base: Dict[str, float]) -> Dict[str, float]:
    """剛体の姿勢(位置・角度)から、rig の姿勢パラメータを作る。

    rig の腕・脚は、曲がりを6節に配った曲線(fk.chain_points)。物理の2節の折れ線と、曲がった時に先端の位置がずれるので、
    先端が物理と同じ位置に来るよう、(上の角度, 曲げ)を解き直す。"""
    from . import fk
    s = 1 if actor.get("facing", 1) >= 0 else -1
    sc = actor.get("scale", 1.0)
    out = dict(base)
    tx, ty, tang = snap["torso"]
    lean = -s * tang
    out["lean"] = lean
    hz = ty / sc
    chi = lean * s
    sh_l = (0.0 + fk.SHOULDER_Z * math.sin(chi), hz + fk.SHOULDER_Z * math.cos(chi))
    hip_l = (0.0, hz)

    def to_local(w: Tuple[float, float]) -> Tuple[float, float]:
        return ((w[0] - tx) / sc, w[1] / sc)

    for sd, (a_k, e_k, l_k, k_k) in (("F", ("fa", "fe", "fl", "fk")), ("R", ("ra", "re", "rl", "rk"))):
        # 腕
        A_up, A_fo = s * snap["ua" + sd][2], s * snap["fa" + sd][2]
        a0, e0 = A_up + lean, A_fo - A_up
        hand = to_local(_l2w(snap["fa" + sd], (0.0, -FA_L * sc)))
        out[a_k], out[e_k] = _solve_end(
            lambda a, e: fk.chain_points(sh_l, chi, -a * s, -(a + e) * s, fk.ARM_TOTAL)[-1], hand, (a0, e0), (-3.2, -0.3), (3.6, 3.2))
        # 脚
        A_th, A_sh = s * snap["th" + sd][2], s * snap["sh" + sd][2]
        foot = to_local(_l2w(snap["sh" + sd], (0.0, -SH_L * sc)))
        out[l_k], out[k_k] = _solve_end(
            lambda t, k: fk.chain_points(hip_l, 0.0, -t * s, (-t + k) * s, fk.LEG_TOTAL)[-1], foot, (A_th, A_th - A_sh), (-1.6, -0.3), (3.0, 3.0))
    out["hz"] = hz
    out["rz"] = 0.0
    out["roll"] = 0.0
    out["dx"] = (tx - actor["base_x"]) * s
    out["root_x"] = tx
    out["root_z"] = 0.0
    return out


class Event:
    __slots__ = ("tau", "kind", "pos", "impulse", "who")

    def __init__(self, tau, kind, pos, impulse, who):
        self.tau, self.kind, self.pos, self.impulse, self.who = tau, kind, pos, impulse, who


def simulate(scene: dict, target_fn: Callable[[str, float], Dict[str, float]], tau_end: float,
             on_step: Optional[Callable[[float], None]] = None) -> Dict[str, object]:
    """目標(target_fn(who, tau) → 姿勢パラメータ)に追従させながら、tau_end まで物理で進める。

    戻り値: dict(taus=[...], states={who: [姿勢パラメータ, ...]}, events=[Event...], knock={who: [...]})
    scene['physics']: {wall_x, knockable: [B], knock_seconds, thresholds: {hit, wall, land}, gravity}
    """
    ph = scene.get("physics", {})
    space = pymunk.Space()
    space.gravity = (0, -ph.get("gravity", GRAVITY))
    space.iterations = 20
    # 地面と壁
    ground = pymunk.Segment(space.static_body, (-60, 0), (60, 0), 0.05)
    ground.friction, ground.collision_type, ground.elasticity = 1.0, CT["ground"], 0.0
    space.add(ground)
    wall_x = scene.get("stage", {}).get("wall_x")
    if wall_x is not None:
        wall = pymunk.Segment(space.static_body, (wall_x, 0), (wall_x, 12), 0.05)
        wall.friction, wall.collision_type, wall.elasticity = 0.6, CT["wall"], 0.05
        space.add(wall)
    names = list(scene["actors"])
    fighters = {w: Fighter(space, w, scene["actors"][w], CT["A"] if i == 0 else CT["B"], i + 1) for i, w in enumerate(names)}
    knockable = set(ph.get("knockable", []))
    boost = dict(ph.get("boost", {}))
    knock_seconds = ph.get("knock_seconds", 3.0)
    thr = dict(hit=ph.get("thresholds", {}).get("hit", 1.2), wall=ph.get("thresholds", {}).get("wall", 3.0),
               land=ph.get("thresholds", {}).get("land", 5.0), knock=ph.get("thresholds", {}).get("knock", 2.5))
    cur = {"tau": 0.0}
    events: List[Event] = []
    last_ev: Dict[str, float] = {}
    knocked_until: Dict[str, float] = {}

    def kind_of(tags: List[str]) -> str:
        if any(t.endswith(".sword") for t in tags):
            return "slash"
        if any(t.endswith((".shin", ".thigh")) for t in tags):
            return "kick"
        return "hit"

    def record(arb: pymunk.Arbiter, kind: Optional[str], who_hit: Optional[str] = None) -> None:
        imp = arb.total_impulse.length
        tags = [getattr(s, "tag", "") for s in arb.shapes]
        k = kind or kind_of(tags)
        limit = thr["hit"] if k in ("kick", "hit", "slash") else (thr["wall"] if k == "wall" else thr["land"])
        if imp < limit:
            return
        if cur["tau"] - last_ev.get(k, -9.0) < 0.22:
            return
        pts = arb.contact_point_set.points
        pos = (pts[0].point_a.x, pts[0].point_a.y) if pts else (0.0, 0.0)
        events.append(Event(cur["tau"], k, pos, imp, who_hit))
        last_ev[k] = cur["tau"]
        if k in ("kick", "hit", "slash") and imp >= thr["knock"]:
            for t in tags:
                w = t.split(".")[0]
                if w in knockable:
                    knocked_until[w] = cur["tau"] + knock_seconds
                    # 威力の上乗せ(演出): 倒される側の全身に、相手から離れる向きの速度を足す。物理の衝突だけだと、蹴り1発では軽く押されるだけ
                    power = boost.get(k, 0.0)
                    if power > 0:
                        others = [fighters[o] for o in names if o != w]
                        dirx = 1.0 if (not others or fighters[w].bodies["torso"].position.x >= others[0].bodies["torso"].position.x) else -1.0
                        for b in fighters[w].bodies.values():
                            b.velocity = (b.velocity.x + dirx * power, b.velocity.y + power * 0.35)

    def fighter_hit(arb, sp, data):
        record(arb, None)

    def wall_hit(arb, sp, data):
        record(arb, "wall")

    def ground_hit(arb, sp, data):
        tags = [getattr(s, "tag", "") for s in arb.shapes]
        if any(t.endswith(".torso") or t.endswith(".head") for t in tags):
            record(arb, "land")

    space.on_collision(CT["A"], CT["B"], post_solve=fighter_hit)
    space.on_collision(CT["A"], CT["wall"], post_solve=wall_hit)
    space.on_collision(CT["B"], CT["wall"], post_solve=wall_hit)
    space.on_collision(CT["A"], CT["ground"], post_solve=ground_hit)
    space.on_collision(CT["B"], CT["ground"], post_solve=ground_hit)

    for w, f in fighters.items():
        f.place(target_fn(w, 0.0))
    n = int(round(tau_end / DT))
    taus: List[float] = []
    states: Dict[str, List[Dict[str, float]]] = {w: [] for w in names}
    knock_log: Dict[str, List[float]] = {w: [] for w in names}
    for i in range(n + 1):
        tau = i * DT
        cur["tau"] = tau
        for w, f in fighters.items():
            p = target_fn(w, tau)
            ku = knocked_until.get(w)
            # 命中されたら、力が抜ける(0.12秒で)。knock_seconds 後に、ゆっくり立ち直る
            if ku is not None and tau < ku + 2.0:
                start = ku - knock_seconds
                dn = min(1.0, max(0.0, (tau - start) / 0.12))
                up = min(1.0, max(0.0, (tau - ku) / 2.0))
                f.knock = max(0.0, dn - up)
            else:
                f.knock = 0.0
            gain = 1.0 - 0.92 * f.knock
            f.set_target(p, gain, 1.0 - f.knock, DT)
            knock_log[w].append(f.knock)
        space.step(DT)
        taus.append(tau)
        for w, f in fighters.items():
            states[w].append(dict(snap=f.snapshot(), base=target_fn(w, tau)))
        if on_step:
            on_step(tau)
    return dict(taus=taus, states=states, events=events, knock=knock_log, fighters=fighters)


def sample(states: List[Dict[str, object]], taus: List[float], tau: float, actor: dict) -> Dict[str, float]:
    """細かい時間の列から、tau の姿勢を引く(剛体の位置・角度を線形補間 → rig のパラメータへ変換)。"""
    x = tau / DT
    i = int(max(0, min(len(taus) - 2, math.floor(x))))
    u = max(0.0, min(1.0, x - i))
    a, b = states[i], states[i + 1]
    snap = {}
    for name, (ax, ay, aa) in a["snap"].items():
        bx, by, ba = b["snap"][name]
        snap[name] = (ax * (1 - u) + bx * u, ay * (1 - u) + by * u, aa * (1 - u) + ba * u)
    base = {k: (v * (1 - u) + b["base"][k] * u if isinstance(v, float) else v) for k, v in a["base"].items()}
    return convert(snap, actor, base)
