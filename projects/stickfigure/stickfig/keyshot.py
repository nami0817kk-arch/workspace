"""手付けのカット(keyshot): アニメーターが IK の人形で付けるように、腰・足・手を別々のトラックで付け、
コマごとに関節の角度を逆算して keys に焼き込む。2026-10-20「質が低い、参考と同じにするには」→ 1 カットずつ手で付ける方式の試作。

自動の台本(fight / skit)との違い:
  - 足は世界座標に置く(踏んでいる間は滑らない)。足の目標を横に動かすと山なり(lift)に運ぶ
  - 手は世界座標に置く(箱の側面をつかむ)か、角度で振る。角度⇄置き場所の間は世界座標で混ぜてつなぐ
  - トラックごとにキーと緩急(ease)を持つ: inout / in(溜めて一気) / out(勢いが抜ける) / linear / hold
  - 震え(shake)・物の位置も同じ時間軸で書く
  - 毎コマ焼き込むので、バネ(springs)と足の固定(plant)は使わない(actor に springs: false, plant: false)

トラック(例は tools/shots/heavy_box.py):
  body:   [{t, x, hz, lean, ht, spin, rz, roll, dir, shake, face, ease}]
  f_foot / r_foot: [{t, p: (x, z), ease, lift}]
  f_hand / r_hand: [{t, p: (x, z)} か {t, ang: (肩, 肘)}, ease]
  prop:   [{t, x, z, shake, ease}]
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional, Tuple

from . import fk

Pt = Tuple[float, float]
POSE0 = dict(fa=0.4, fe=0.6, ra=0.3, re=0.6, fl=0.1, fk=0.1, rl=-0.1, rk=0.1, lean=0.0, hz=0.8, dx=0.0, rz=0.0, roll=0.0,
             ht=0.0, spin=0.0, st=0.0, lst=0.0, run=0.0, walk=0.0, hold=0.0, dir=1.0)
LIMBS = dict(f_foot=("fl", "fk", "front_leg", (-2.2, 2.2), (0.0, 2.7)),
             r_foot=("rl", "rk", "rear_leg", (-2.2, 2.2), (0.0, 2.7)),
             f_hand=("fa", "fe", "front_arm", (-3.3, 3.3), (-0.05, 2.9)),
             r_hand=("ra", "re", "rear_arm", (-3.3, 3.3), (-0.05, 2.9)))
ZERO_BEFORE = ("rz", "roll", "spin", "st", "lst", "rst", "rlst", "shake")   # 書く前の時間は 0 とみなす項目
BODY = ("x", "hz", "lean", "ht", "spin", "rz", "roll", "st", "lst", "rst", "rlst")   # st/lst/rst/rlst: 前/後ろの腕・脚の伸び(当たりの瞬間の「伸び」。骨格の計算には入れない)


def ease(u: float, kind: str) -> float:
    u = max(0.0, min(1.0, u))
    if kind == "linear":
        return u
    if kind == "in":                      # ゆっくり出て速く着く(溜めから一気に)
        return u * u * u
    if kind == "out":                     # 速く出てゆっくり止まる(勢いが抜ける)
        return 1 - (1 - u) ** 3
    if kind == "hold":
        return 0.0 if u < 1.0 else 1.0
    return u * u * (3 - 2 * u)            # inout


def _end(pose: dict, s: int, x: float, chain: str) -> Pt:
    return fk.skeleton(pose, s, x, 1.0)[chain][-1]


def solve_limb(pose: dict, s: int, x: float, limb: str, target: Pt, iters: int = 30) -> float:
    """pose の limb の端が target に来るよう、2 つの角を減衰つきガウス・ニュートンで解く(pose を書き換える)。残差を返す。"""
    a_k, b_k, chain, (alo, ahi), (blo, bhi) = LIMBS[limb]
    h = 1e-4
    err = 9.9
    for _ in range(iters):
        e = _end(pose, s, x, chain)
        rx, rz = target[0] - e[0], target[1] - e[1]
        err = math.hypot(rx, rz)
        if err < 5e-4:
            break
        J = []
        for k in (a_k, b_k):
            v = pose[k]
            pose[k] = v + h
            e2 = _end(pose, s, x, chain)
            pose[k] = v
            J.append(((e2[0] - e[0]) / h, (e2[1] - e[1]) / h))
        (j11, j21), (j12, j22) = J
        lam = 1e-3 + 0.05 * err
        a11, a12, a22 = j11 * j11 + j21 * j21 + lam, j11 * j12 + j21 * j22, j12 * j12 + j22 * j22 + lam
        g1, g2 = j11 * rx + j21 * rz, j12 * rx + j22 * rz
        det = a11 * a22 - a12 * a12
        if abs(det) < 1e-12:
            break
        d1 = (a22 * g1 - a12 * g2) / det
        d2 = (-a12 * g1 + a11 * g2) / det
        step = max(1.0, math.hypot(d1, d2) / 0.4)
        pose[a_k] = max(alo, min(ahi, pose[a_k] + d1 / step))
        pose[b_k] = max(blo, min(bhi, pose[b_k] + d2 / step))
    return err


def solve_leg(pose: dict, s: int, x: float, limb: str, target: Pt) -> float:
    """脚は解析で解き、膝が前(向いている側)に出る解を選ぶ(数値解は膝が後ろに折れる解に落ちることがあった)。
    届かないときはまっすぐ伸ばして向ける。近すぎるときは数値解に任せる。"""
    a_k, b_k = LIMBS[limb][:2]
    hip = (0.0, pose["hz"])
    rho = -pose["roll"] * s                       # 根元の座標系へ(体が傾いて・浮いていても合うように。fk.leg_ik と同じ変換。前は回転を入れておらず、起き上がりで足が地面に 0.1 潜った)
    cr, sr = math.cos(rho), math.sin(rho)
    X0, Z0 = target[0] - x, target[1] - pose["rz"]
    X, Z = X0 * cr - Z0 * sr, X0 * sr + Z0 * cr
    dx, dz = X - hip[0], Z - hip[1]
    r = math.hypot(dx, dz)
    L = fk.LEG_TOTAL

    def end(tt, kk):
        return fk.chain_points(hip, 0.0, -tt * s, (-tt + kk) * s, L)

    if r < L * 0.17:
        return solve_limb(pose, s, x, limb, target)
    aT = math.atan2(dx, -dz)                     # 股から目標への向き(真下 0、前 +)
    if r >= L * 0.999:                           # 届かない: 伸ばして向ける
        pose[a_k], pose[b_k] = aT * s, 0.0
        e = end(pose[a_k], 0.0)[-1]
        return math.hypot(e[0] - X, e[1] - Z)
    lo, hi = 0.0, 2.7
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        e = end(0.0, mid)[-1]
        if math.hypot(e[0] - hip[0], e[1] - hip[1]) > r:
            lo = mid
        else:
            hi = mid
    k = 0.5 * (lo + hi)
    e0 = end(0.0, k)[-1]
    a0 = math.atan2(e0[0] - hip[0], -(e0[1] - hip[1]))
    best = None
    for tt in ((aT - a0) * s, (a0 - aT) * s):
        pts = end(tt, k)
        err = math.hypot(pts[-1][0] - X, pts[-1][1] - Z)
        knee = pts[len(pts) // 2]
        fwd = (knee[0] - (hip[0] + X) / 2) * s           # 膝が股と足の中点より前に出ている量
        score = (err > 0.02, -fwd)
        if best is None or score < best[0]:
            best = (score, tt, err)
    pose[a_k], pose[b_k] = best[1], k
    return best[2]


def _lerp(a, b, u):
    if isinstance(a, (tuple, list)):
        return tuple(_lerp(x, y, u) for x, y in zip(a, b))
    return a + (b - a) * u


def _seg(track: List[dict], t: float):
    if t <= track[0]["t"]:
        return track[0], track[0], 0.0
    for k0, k1 in zip(track, track[1:]):
        if k0["t"] <= t <= k1["t"]:
            return k0, k1, (t - k0["t"]) / max(1e-9, k1["t"] - k0["t"])
    return track[-1], track[-1], 1.0


def _body_at(track: List[dict], t: float) -> dict:
    """腰トラック: 各項目は、その項目を書いた前後のキーで補間(書いていないキーは飛ばす)。"""
    out: Dict[str, object] = {}
    for key in BODY + ("shake",):
        ks = [k for k in track if key in k]
        if not ks:
            continue
        if key in ZERO_BEFORE and ks[0]["t"] > track[0]["t"]:      # 初めて書いたキーより前は既定値(0)。前は最初の値が冒頭まで使われ、アッパーで浮く値 0.12 のまま最初から浮いていた
            t_prev = max(k["t"] for k in track if k["t"] < ks[0]["t"])   # 0 から動き出すのは直前のキーから(冒頭から少しずつ浮いていくのを防ぐ)
            ks = [dict(t=track[0]["t"], **{key: 0.0}), dict(t=t_prev, **{key: 0.0})] + ks
        k0, k1, u = _seg(ks, t)
        out[key] = _lerp(float(k0[key]), float(k1[key]), ease(u, k1.get("ease", "inout")))
    for key in ("dir", "face"):
        ks = [k for k in track if key in k]
        if ks:
            cur = ks[0][key]
            for k in ks:
                if k["t"] <= t + 1e-9:
                    cur = k[key]
            out[key] = cur
    return out


def warp_fn(holds: Optional[List[dict]], fps: int = 30):
    """アニメの時間の伸び縮み。実時間 t → トラックを読む時刻 s。
      windup: {kind: windup, t: 当たり, hold: 止めるコマ, burst: 打つコマ} 当たりの (hold+burst) コマ前で全身を止め、
              そこから当たりまでの動きを burst コマに縮めて一気に打つ(当たりの時刻は動かない)
      freeze: {kind: freeze, t0, t1} t0〜t1 で全身を止め、その後は (t1−t0) 遅れて続ける(決めの止め絵)"""
    dt = 1.0 / fps
    hs = sorted(holds or [], key=lambda h: h.get("t", h.get("t0", 0.0)))

    def w(t: float) -> float:
        shift = 0.0
        for h in hs:
            if h.get("kind", "windup") == "windup":
                tc = float(h["t"])
                t1 = tc - h.get("burst", 3) * dt
                t0 = t1 - h.get("hold", 3) * dt
                if t0 <= t < t1:
                    return t0 - shift
                if t1 <= t < tc:
                    return t0 + (t - t1) * (tc - t0) / max(1e-9, tc - t1) - shift
            else:
                t0, t1 = float(h["t0"]), float(h["t1"])
                if t0 <= t < t1:
                    return t0 - shift
                if t >= t1:
                    shift += t1 - t0
        return t - shift
    return w


def bake(tracks: Dict[str, List[dict]], actor: dict, fps: int = 30, t_end: Optional[float] = None, report: Optional[list] = None, holds: Optional[List[dict]] = None) -> List[dict]:
    """トラックを毎コマの姿勢キーに焼き込む。actor は base_x を持つ(facing は +1 で置き、向きは body の dir)。
    holds: アニメの溜め・一気・止め(warp_fn)。キーは「止めない」つもりで書き、止めはここで入れる。"""
    warp = warp_fn(holds, fps)
    base_x = float(actor.get("base_x", 0.0))
    sc = float(actor.get("scale", 1.0))                  # 体の大きさ(巨漢など)。IK は体の寸法(1.0)で解き、世界の目標を根元から 1/sc に縮めて渡す
    t_end = t_end if t_end is not None else max(k["t"] for tr in tracks.values() for k in tr)
    pose = dict(POSE0)
    keys = []
    worst = 0.0
    for f in range(int(round(t_end * fps)) + 1):
        t_real = f / fps
        t = warp(t_real)                                  # 溜め・止めの間は同じ時刻を読む(全身が止まる)
        b = _body_at(tracks["body"], t)
        s = 1 if float(b.get("dir", 1)) >= 0 else -1
        sh = float(b.get("shake", 0.0))
        x = float(b.get("x", base_x)) + (sh * (1 if (f // 2) % 2 == 0 else -1) if sh else 0.0)   # 震え: 2 コマごとに左右・上下に小さく(力んでいる)
        for key in ("hz", "lean", "ht", "spin", "rz", "roll", "st", "lst", "rst", "rlst"):
            if key in b:
                pose[key] = float(b[key])
        if sh:
            pose["hz"] += sh * 0.5 * (1 if (f // 2) % 2 else -1)
        pose["dir"] = float(s)
        for limb in ("f_foot", "r_foot", "f_hand", "r_hand"):
            tr = tracks.get(limb)
            if not tr:
                continue
            k0, k1, u = _seg(tr, t)
            ue = ease(u, k1.get("ease", "inout"))
            a_k, b_k, chain = LIMBS[limb][:3]

            def world(k):                      # キーの手足の世界座標(角度で書いたキーは、今の体での先端)
                if "p" in k:
                    return tuple(k["p"])
                tmp = dict(pose, **{a_k: k["ang"][0], b_k: k["ang"][1]})
                e_ = _end(tmp, s, x, chain)
                return (x + (e_[0] - x) * sc, pose["rz"] + (e_[1] - pose["rz"]) * sc)

            if "ang" in k0 and "ang" in k1:
                pose[a_k], pose[b_k] = _lerp(k0["ang"][0], k1["ang"][0], ue), _lerp(k0["ang"][1], k1["ang"][1], ue)
                continue
            p0, p1 = world(k0), world(k1)
            tgt = _lerp(p0, p1, ue)
            if limb.endswith("foot") and abs(p1[0] - p0[0]) > 0.04:          # 踏み替え: 山なり
                tgt = (tgt[0], tgt[1] + float(k1.get("lift", 0.10)) * math.sin(math.pi * ue))
            if u >= 1.0 and "ang" in k1:
                pose[a_k], pose[b_k] = k1["ang"]
                continue
            if sc != 1.0:
                tgt = (x + (tgt[0] - x) / sc, pose["rz"] + (tgt[1] - pose["rz"]) / sc)
            e = (solve_leg(pose, s, x, limb, tgt) if limb.endswith("foot") else solve_limb(pose, s, x, limb, tgt)) * sc
            worst = max(worst, e)
            if report is not None and e > 0.02:
                report.append((round(t, 2), limb, round(e, 3)))
        keys.append(dict(t=round(t_real, 4), dx=round(x - base_x, 5), abs=True, face=b.get("face", "fight"),
                         **{kk: round(float(pose.get(kk, 0.0)), 5) for kk in ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean", "hz", "ht", "spin", "rz", "roll", "dir", "st", "lst", "rst", "rlst")}))
    if report is not None:
        report.insert(0, ("worst", round(worst, 4)))
    return keys


def widen_stance(tracks: Dict[str, List[dict]], front_min: float = 0.90, rear_min: float = 0.96, cap: float = 0.985, scale: float = 1.0) -> Dict[str, List[dict]]:
    """腰の高さに合わせて、踏んでいる足の幅を広げる(2026-10-21 ユーザー「足が変」「空気椅子みたい」)。
    腰を下げても足幅が同じだと、前後の脚が両方 85° 折れて空気椅子に見えた。実際の構えは腰が低いほど足幅が広く、
    後ろ脚はほぼ伸びて斜め後ろ、膝の曲がりは前脚が受け持つ。
    後ろ足は脚が rear_min 以上、前足は front_min 以上伸びる位置まで開く。同じ位置で踏んでいる一続きのキーは同じだけ動かす(滑らない)。
    どの時刻でも脚が cap を超えて伸びない範囲に抑える(届かず浮くのを防ぐ)。倒れ・空中の時刻は見ない。"""
    L = fk.LEG_TOTAL * scale                             # 巨漢は脚も腰の高さ(世界)も scale 倍
    body = tracks["body"]
    for limb in ("f_foot", "r_foot"):
        ks_ = tracks.get(limb) or []
        groups, cur = [], []
        for k in ks_:
            if "p" in k and abs(k["p"][1]) < 0.01 and (not cur or tuple(cur[-1]["p"]) == tuple(k["p"])):
                cur.append(k)
            else:
                if cur:
                    groups.append(cur)
                cur = [k] if ("p" in k and abs(k["p"][1]) < 0.01) else []
        if cur:
            groups.append(cur)
        for g in groups:
            need, lo, hi = [], -9.0, 9.0                  # 足の x を動かす量: 必要量の候補と、伸びすぎない範囲
            ok = True
            for k in g:
                b = _body_at(body, k["t"])
                if abs(b.get("roll", 0.0)) > 0.3 or b.get("rz", 0.0) > 0.05:
                    ok = False
                    break
                s = 1 if float(b.get("dir", 1)) >= 0 else -1
                x, hz = float(b.get("x", 0.0)), float(b.get("hz", 0.8)) * scale
                rel = (g[0]["p"][0] - x) * s                 # 腰から見た足の前後(前が +)
                reach_cap = math.sqrt(max(0.0, (cap * L) ** 2 - hz * hz))
                if rel < 0:                                   # 後ろ足: もっと後ろへ
                    want = -math.sqrt(max(0.0, (rear_min * L) ** 2 - hz * hz))
                    if rel > want:
                        need.append((want - rel) * s)
                    lo_, hi_ = (-reach_cap - rel) * s, 9.0 * s
                else:                                         # 前足: もっと前へ
                    want = math.sqrt(max(0.0, (front_min * L) ** 2 - hz * hz))
                    if rel < want:
                        need.append((want - rel) * s)
                    lo_, hi_ = -9.0 * s, (reach_cap - rel) * s
                lo, hi = max(lo, min(lo_, hi_)), min(hi, max(lo_, hi_))
            if not ok or not need:
                continue
            d = max(need, key=abs)
            d = max(lo, min(hi, d))
            for k in g:
                k["p"] = (round(k["p"][0] + d, 4), k["p"][1])
    return tracks


def cut_plan(beats: List[dict], base: List[dict], wide: float = 3.4, min_gap: float = 0.16) -> List[dict]:
    """当たりごとのカット割りを足す(アニメの戦いの「寄り → 当たりの角度 → 反応 → 引き」)。
    beats: [{t: 当たりの時刻, by: 打つ側, to: 受ける側, big: 大技なら True}]。base: 台本のカット(当たりの周りは置き換える)。
    角度は当たりごとに左右を入れ替える(同じ側から続けて撮らない)。カットは min_gap 秒より短くしない。"""
    cuts = []
    side = 1
    for i, b in enumerate(sorted(beats, key=lambda q: q["t"])):
        tc, by, to, big = float(b["t"]), b["by"], b["to"], bool(b.get("big"))
        side = -side
        n0 = len(cuts)
        cuts.append(dict(t=round(tc - (0.34 if big else 0.24), 3), follow=by, scale=2.1 if big else 2.4, yaw=24.0 * side, pitch=3.0, lens=34.0, target_z=1.05, lag=0.0, role="windup"))   # 溜め: 打つ側に寄る
        cuts.append(dict(t=round(tc - 2 / 30, 3), follow="mid", scale=2.5 if big else 2.8, yaw=-32.0 * side, pitch=(-7.0 if big else 2.0), lens=30.0, target_z=1.1, lag=0.0, role="hit"))   # 当たり: 反対側・大技は下から
        cuts.append(dict(t=round(tc + (0.22 if big else 0.16), 3), follow=to, scale=2.9 if big else 3.0, yaw=14.0 * side, pitch=3.0, lens=36.0, target_z=0.95, lag=0.15, role="react"))     # 反応: 受けた側
        cuts.append(dict(t=round(tc + (0.55 if big else 0.40), 3), follow="mid", scale=wide, yaw=-5.0, pitch=3.0, lens=40.0, target_z=0.95, lag=0.25, role="wide"))                         # 引き
        for c in cuts[n0:]:
            c["big"] = big
    spans = [(c["t"] - 0.05, c["t"] + 0.6) for c in cuts]
    keep = [c for c in base if not any(a <= c["t"] <= b for a, b in spans)]
    out = sorted(keep + cuts, key=lambda c: c["t"])
    res = []
    rank = dict(wide=0, react=1, windup=2, hit=3)          # 短すぎて重なるときは、引き → 反応 → 溜め → 当たり の順に消す(大技の溜めの寄りが引きに押し出されて消えていた)。大技のカットは +2(小技の当たりより大技の溜めの寄りを残す)
    pri = lambda c: rank.get(c.get("role"), -1) + (2 if c.get("big") else 0)
    for c in out:
        if res and c["t"] - res[-1]["t"] < min_gap:
            if pri(res[-1]) <= pri(c):
                res.pop()
            else:
                continue
        res.append(c)
    return res


def bake_prop(track: List[dict], fps: int = 30, t_end: Optional[float] = None) -> List[list]:
    """物の位置 [{t, x, z, ease, shake}] を毎コマの [t, x, z] に焼き込む。"""
    t_end = t_end if t_end is not None else track[-1]["t"]
    out = []
    for f in range(int(round(t_end * fps)) + 1):
        t = f / fps
        k0, k1, u = _seg(track, t)
        ue = ease(u, k1.get("ease", "inout"))
        x, z = _lerp(float(k0["x"]), float(k1["x"]), ue), _lerp(float(k0["z"]), float(k1["z"]), ue)
        sh = _lerp(float(k0.get("shake", 0.0)), float(k1.get("shake", 0.0)), ue)
        if sh:
            x += sh * (1 if (f // 2) % 2 == 0 else -1)
        out.append([round(t, 4), round(x, 4), round(z, 4)])
    return out
