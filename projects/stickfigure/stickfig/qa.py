"""合否の点検(ゲート)。plan と順運動学だけで、動きの不具合を数字で見つける。純粋な Python。

見る項目(参考: Alan Becker「Cave Spider」の測定値と、2026-10 に自作で見つけた不具合から):
  contact      命中の瞬間に、攻める側の先端(足・手・剣先)が相手の体に届いているか
  hit_stop     ヒットストップのコマ数(参考は1〜3コマが9割。長いと間延びする)
  anticipation 静止から命中までの溜めのコマ数(参考は中央値9コマ、速い4分の1は3コマ以内)
  impact_speed 命中の直前の先端の速さ(身長/コマ)。遅いと「当てた」感じが出ない
  stops        関節の動きが途中で止まる回数(区間ごとのイーズが原因の「カクカク」)
  jerk         1コマで角度が不連続に飛ぶ(ワープ・ガタつき)
  ground       人物が地面より下に出る(めり込み)
  run_range    走りの腕・脚の振りが、参考から読み取った範囲に届いているか
  interpenetration  2人の線が交差している(すり抜けている)コマ数。接触が不自然に見える主な原因
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional

from . import fk
from .pose import RUN

ANGLE_KEYS = ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean")

DEFAULTS = dict(
    contact_tol=0.12,
    max_hold_frames=4,
    max_anticipation_frames=12,
    min_impact_speed=0.05,       # 身長/コマ
    max_stops=0,
    max_jerk=0.9,                # ラジアン/コマ²(ヒット直後を除く)
    ground_tol=0.06,             # 人物の大きさに対する割合
    ground_max_frames=3,
    max_cross_frames=2,          # 2人の線が交差してよいコマ数(命中の一瞬の接触を除く)
    run_arm_swing=3.5,           # 腕の振り(最大-最小)。参考は約3.9(-125°〜+100°)
    run_leg_swing=1.6,           # 太ももの振り。参考は約1.9(-40°〜+70°)
    max_teleport=0.9,            # 1コマで根元が動いてよい距離(単位)。clip の継ぎ目で位置が飛ぶと、滑って見える(2コマ撮りで 1 コマ分が倍になるので 0.45/コマ相当)
    max_teleport_frames=0,
)


def _check(name: str, ok: bool, value, threshold, message: str) -> dict:
    return dict(name=name, passed=bool(ok), value=value, threshold=threshold, message=message)


def _scale(plan: dict, who: str) -> float:
    return plan["actors"][who].get("scale", 1.0)


def _sign(plan: dict, who: str) -> int:
    return 1 if plan["actors"][who].get("facing", 1) >= 0 else -1


def _skel(plan: dict, who: str, f: int) -> dict:
    p = plan["frames"][f]["actors"][who]
    return fk.skeleton(p, _sign(plan, who), p["root_x"], _scale(plan, who))


def hold_frames_set(plan: dict) -> set:
    """命中の前後(溜めの解放・ヒットストップ・直後)は、急な加速・折り返しが意図なので、カクつきの点検から外す。"""
    out = set()
    for e in plan["events"]:
        for i in range(e["frame"] - 5, e["frame"] + max(e.get("hold_frames", 0), 1) + 3):
            out.add(i)
    return out


def check_contacts(plan: dict, cfg: dict) -> List[dict]:
    res = []
    scene_hits = {h["tau"]: h for h in plan["scene"].get("hits", [])}
    for c in plan.get("contacts", []):
        if c.get("kind") == "miss":            # かわし: 位置を決めるためだけに解いた接触。当たらないのが正しい
            continue
        tol = scene_hits.get(c["tau"], {}).get("contact", {}).get("tol", cfg["contact_tol"])
        ok = c["distance_to_body"] <= tol
        res.append(_check(f"contact@{c['tau']}", ok, round(c["distance_to_body"], 3), tol,
                          f"tau={c['tau']} の {c['effector']} が相手の体まで {c['distance_to_body']:.3f} 単位"
                          + ("" if ok else f"(許容 {tol})。当たっていない")))
    return res


def check_hit_stop(plan: dict, cfg: dict) -> List[dict]:
    res = []
    ic = plan["scene"].get("impact_cuts") or {}
    for e in plan["events"]:
        hf = e.get("hold_frames", 0)
        if hf == 0:
            continue
        limit = cfg["max_hold_frames"]
        if e["kind"] in ic.get("kinds", []):       # 多角度のカットを入れる命中は、止めている間もカメラが動くので、長くてよい
            limit = max(limit, int(round(ic.get("hold", 0.2) * plan["fps"])) + 1)
        if e["kind"] == "pose":                    # 溜めの止め絵(決めポーズ)は、少し長くてよい
            limit = max(limit, 6)
        ok = hf <= limit
        res.append(_check(f"hit_stop@{e['tau']}", ok, hf, limit,
                          f"{e['kind']} のヒットストップ {hf} コマ" + ("" if ok else "。長すぎる(参考は1〜3コマが9割)")))
    return res


def effector_speeds(plan: dict, who: str, eff: str) -> List[float]:
    h = 1.9 * _scale(plan, who)
    pts = [_skel(plan, who, f)[eff] for f in range(plan["n"])]
    return [0.0] + [math.hypot(b[0] - a[0], b[1] - a[1]) / h for a, b in zip(pts, pts[1:])]


def check_anticipation_and_speed(plan: dict, cfg: dict) -> List[dict]:
    res = []
    scene_hits = {h["tau"]: h for h in plan["scene"].get("hits", [])}
    frame_of = {e["tau"]: e["frame"] for e in plan["events"]}
    for c in plan.get("contacts", []):
        who, eff = c["striker"], c["effector"]
        f0 = frame_of.get(c["tau"])
        if f0 is None:
            continue
        sp = effector_speeds(plan, who, {"foot": "foot", "rear_foot": "rear_foot", "hand": "hand", "tip": "tip"}[eff])
        # 命中の直前の速さ(最大値)
        pre = max(sp[max(1, f0 - 4): f0 + 1] or [0.0])
        ok_s = pre >= cfg["min_impact_speed"]
        res.append(_check(f"impact_speed@{c['tau']}", ok_s, round(pre, 3), cfg["min_impact_speed"],
                          f"命中直前の {eff} の速さ {pre:.3f} 身長/コマ" + ("" if ok_s else "。遅い(当てた感じが出ない)")))
        # 溜め: 命中から遡って、静止(速さ<0.02)だった最後のコマまで
        n = 0
        j = f0
        while j > 1 and sp[j] >= 0.02:
            j -= 1
            n += 1
            if n > 60:
                break
        lim = scene_hits.get(c["tau"], {}).get("contact", {}).get("max_anticipation", cfg["max_anticipation_frames"])
        ok_a = n <= lim or n > 60
        res.append(_check(f"anticipation@{c['tau']}", ok_a, n, lim,
                          f"静止から命中まで {n} コマ" + ("" if ok_a else "。溜めが長い(参考は中央値9コマ)")))
    return res


def check_stops_and_jerk(plan: dict, cfg: dict) -> List[dict]:
    skip = hold_frames_set(plan)
    stops_total, jerk_bad = 0, []
    tempo = float(plan["scene"].get("tempo", 1.0))
    max_jerk = cfg["max_jerk"] * tempo * tempo          # 倍速にすると、1コマあたりの角度の変化も加速度も大きくなる
    detail = []
    for who in plan["actors"]:
        for k in ANGLE_KEYS:
            ys = [plan["frames"][f]["actors"][who][k] for f in range(plan["n"])]
            v = [ys[i + 1] - ys[i] for i in range(len(ys) - 1)]
            pk = max((abs(x) for x in v), default=0.0)
            if pk < 0.02:
                continue
            for i in range(2, len(v) - 2):
                if i in skip or (i + 1) in skip:
                    continue
                if any(plan["frames"][j]["actors"][who].get("stepped") for j in (i - 1, i, i + 1, i + 2) if 0 <= j < plan["n"]):
                    continue          # n コマ撮りは、同じ絵を続けるのが意図(速度0・更新時の大きな変化が出る)
                if plan["frames"][i]["actors"][who].get("run", 0) > 0.3 or plan["frames"][i]["actors"][who].get("periodic"):
                    continue          # 走りは周期運動で、折り返しに速度0が出るのが自然
                slow = abs(v[i]) < 0.06 * pk
                moving = abs(v[i - 1]) > 0.25 * pk and abs(v[i + 1]) > 0.25 * pk
                if slow and moving:
                    stops_total += 1
                    detail.append(f"{who}.{k}@{i}")
                acc = abs(v[i] - v[i - 1])
                if acc > max_jerk:
                    jerk_bad.append(f"{who}.{k}@{i}({acc:.2f})")
    return [
        _check("stops", stops_total <= cfg["max_stops"], stops_total, cfg["max_stops"],
               f"動きが途中で止まる回数 {stops_total}" + (f"(例: {', '.join(detail[:3])})" if detail else "")),
        _check("jerk", not jerk_bad, len(jerk_bad), 0,
               f"角度が1コマで不連続に飛んだ所 {len(jerk_bad)}" + (f"(例: {', '.join(jerk_bad[:3])})" if jerk_bad else "")),
    ]


def check_ground(plan: dict, cfg: dict) -> dict:
    bad_frames = []
    for f in range(plan["n"]):
        for who in plan["actors"]:
            sc = _scale(plan, who)
            sk = _skel(plan, who, f)
            low = min(min(p[1] for p in ln) for ln in fk.body_lines(sk))
            low = min(low, sk["head"][1] - sk["head_r"])
            if low < -cfg["ground_tol"] * sc:
                bad_frames.append(f)
                break
    # 連続して続いたものだけ数える
    longest, cur, last = 0, 0, -2
    for f in bad_frames:
        cur = cur + 1 if f == last + 1 else 1
        longest = max(longest, cur)
        last = f
    return _check("ground", longest <= cfg["ground_max_frames"], len(bad_frames), cfg["ground_max_frames"],
                  f"人物が地面より下に出たコマ {len(bad_frames)}(最長の連続 {longest})")


def check_interpenetration(plan: dict, cfg: dict) -> List[dict]:
    """2人の体(胴・腕・脚・剣)が、すり抜けて交差しているコマの数。物理で動かすと0に近づく。"""
    who = list(plan["actors"])
    if len(who) < 2:
        return []
    a, b = who[0], who[1]
    bad = []
    for f in range(plan["n"]):
        ska, skb = _skel(plan, a, f), _skel(plan, b, f)
        la, lb = list(fk.body_lines(ska)), list(fk.body_lines(skb))
        if plan["actors"][a].get("weapon"):
            la.append(ska["sword"])
        if plan["actors"][b].get("weapon"):
            lb.append(skb["sword"])
        if fk.lines_cross(la, lb) > 0:
            bad.append(f)
    ok = len(bad) <= cfg["max_cross_frames"]
    first = f"(最初は {bad[0] / plan['fps']:.2f}秒)" if bad else ""
    return [_check("interpenetration", ok, len(bad), cfg["max_cross_frames"],
                   f"2人の線がすり抜けて交差したコマ {len(bad)}{first}" + ("" if ok else "。接触が不自然に見える")) ]


def check_run_range(plan: dict, cfg: dict) -> List[dict]:
    keys = plan["scene"].get("camera") is not None
    uses_run = any(f["actors"][w].get("run", 0) > 0.5 for f in plan["frames"] for w in f["actors"])
    if not uses_run:
        return []
    spec = dict(RUN, **(plan.get("run") or {}))
    arm = 2 * spec["arm_amp"]
    leg = 2 * spec["leg_amp"]
    return [
        _check("run_arm_swing", arm >= cfg["run_arm_swing"], round(arm, 2), cfg["run_arm_swing"],
               f"走りの腕の振り {arm:.2f} rad(参考は約3.9)"),
        _check("run_leg_swing", leg >= cfg["run_leg_swing"], round(leg, 2), cfg["run_leg_swing"],
               f"走りの太ももの振り {leg:.2f} rad(参考は約1.9)"),
    ]


def run_gate(plan: dict, cfg: Optional[dict] = None) -> dict:
    cfg = dict(DEFAULTS, **(cfg or {}))
    checks: List[dict] = []
    checks += check_contacts(plan, cfg)
    checks += check_hit_stop(plan, cfg)
    checks += check_anticipation_and_speed(plan, cfg)
    checks += check_stops_and_jerk(plan, cfg)
    checks.append(check_ground(plan, cfg))
    checks += check_interpenetration(plan, cfg)
    checks += check_run_range(plan, cfg)
    checks += check_teleport(plan, cfg)
    failed = [c for c in checks if not c["passed"]]
    return dict(passed=not failed, checks=checks, failed=[c["name"] for c in failed])


def format_report(result: dict) -> str:
    lines = ["# 点検の結果", "", f"- 合否: **{'合格' if result['passed'] else '不合格'}**({len(result['checks']) - len(result['failed'])}/{len(result['checks'])} 項目)", ""]
    for c in result["checks"]:
        lines.append(f"- {'OK ' if c['passed'] else 'NG '} {c['message']}")
    return "\n".join(lines)


def check_teleport(plan: dict, cfg: dict) -> List[dict]:
    """瞬間移動: tau が進んだコマで、根元(root_x)が 1 コマに max_teleport 以上動いた所。
    clip とキーの位置の食い違い(anchor_dx とキーの dx)が原因で、混ぜる数コマのあいだに 1〜2 単位すべって見えた(2026-10-19)。"""
    bad = []
    fr = plan["frames"]
    for who in plan["actors"]:
        for f in range(1, plan["n"]):
            if fr[f - 1]["tau"] == fr[f]["tau"]:
                continue
            d = abs(fr[f]["actors"][who]["root_x"] - fr[f - 1]["actors"][who]["root_x"])
            if d > cfg["max_teleport"]:
                bad.append(f"{who}@{f}({d:.2f})")
    ok = len(bad) <= cfg["max_teleport_frames"]
    return [_check("teleport", ok, len(bad), cfg["max_teleport_frames"],
                   f"1コマで根元が {cfg['max_teleport']} 以上動いた所 {len(bad)}" + (f"(例: {', '.join(bad[:3])})" if bad else "") + ("" if ok else "。clip の継ぎ目で位置が飛んでいる"))]
