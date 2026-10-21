"""アニメ調の点検(2026-10-21 定義。ユーザーの選択「Becker と日本のテレビアニメを混ぜる」)。

動きの流れは Alan Becker(1〜2 コマ打ちで途切れない)、溜め・止め・衝撃の演出は日本のテレビアニメ(長めの溜め、止め絵、急な寄り、強い衝撃)。
手付けのカット(keyshot)の台本(scene)と plan から、技ごと・全体の項目を測って合否を出す。

定義(DEFINITION の数字):
  1 溜め    技の前に打つ側が 2〜6 コマ止まる(Becker の溜め 3〜9 と日本の長い溜めの間)
  2 一気    溜めの終わりから当たりまで 2〜4 コマ
  3 止め    最後の決着のあと、勝った側が 0.5 秒以上ほぼ止まる(決めの止め絵)
  4 伸び    当たりの瞬間に打った腕・脚が 20〜40% 伸びる(派手なくらいでよい)
  5 反応    当たりから 0.3 秒で受けた側の頭が 0.45 以上動く(現実の 3 倍以上。派手なくらいでよい)
  6 コマ打ち 同じ絵が続くコマ 20〜40%(Becker 17〜33% と日本の 3 コマ打ちの間)
  7 衝撃    大技のヒットストップ 4〜6 コマ・小技 1〜3 コマ。大技は衝撃コマ(反転)かスピード線
  8 カット  山場(当たりの前後 1 秒)のカットの長さの中央値 0.15〜0.40 秒
  9 寄り    大技の溜めでカメラが打つ側に寄る(日本のアニメの急な寄り)
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional

from . import fk, pose as posemod

DEFINITION = dict(hold=(2, 6), burst=(2, 4), final_hold_s=0.5, stretch=(0.20, 0.40), react=0.45,   # 2026-10-21 ユーザー「動きは派手なくらいでちょうどいい」→ 伸び 0.12→0.20・反応 0.30→0.45 に引き上げ
                  dup=(0.20, 0.40), stop_big=(4, 6), stop_small=(1, 3), cut_median=(0.15, 0.40))
ANG = ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean", "hz", "ht", "rz", "roll")
STILL = 0.035          # 1 コマの姿勢の変化の合計(rad・単位)がこれ未満なら「止まっている」


def _track(scene: dict, who: str) -> posemod.KeyTrack:
    return posemod.KeyTrack(scene["keys"][who], posemod.STANCE_A)


def _change(a: dict, b: dict) -> float:
    return sum(abs(a[k] - b[k]) for k in ANG) + abs(a["dx"] - b["dx"]) * 2


def _head(scene, tr, who, t, part="head"):
    p = tr.at(t)
    a = scene["actors"][who]
    return fk.skeleton(p, fk.sign_of(a, p), a["base_x"] + p["dx"], a.get("scale", 1.0))[part]


def check(scene: dict, plan: Optional[dict] = None, beats: Optional[List[dict]] = None, video: Optional[str] = None) -> dict:
    """beats: [{t, by, to, big, limb: st|lst|rst|rlst}]。無ければ scene の hits(by の付いたもの)から作る。"""
    fps = scene.get("fps", 30)
    dt = 1.0 / fps
    trs = {w: _track(scene, w) for w in scene["actors"]}
    D = DEFINITION
    rows = []
    for b in beats or []:
        tc, by, to, big = float(b["t"]), b["by"], b["to"], bool(b.get("big"))
        tr = trs[by]
        ksb = scene["keys"][by]
        fc = int(round(tc * fps))

        def pose_at(i):                                     # コマごとのキー(keyshot は毎コマ焼く)。コマの時刻とずれた時刻で読むと止まりを見落とした
            if len(ksb) > fc + 1:
                k = ksb[max(0, min(len(ksb) - 1, i))]
                return dict(posemod.STANCE_A, **{n: float(v) for n, v in k.items() if n in posemod.NUM})
            return tr.at(i * dt)
        # 溜めと一気: 当たりのコマから前へたどり、最後に止まっていた区間を探す
        f = 0
        while f < 12 and _change(pose_at(fc - f), pose_at(fc - f - 1)) >= STILL:
            f += 1
        burst = f
        hold = 0
        while hold < 20 and _change(pose_at(fc - burst - hold), pose_at(fc - burst - hold - 1)) < STILL:
            hold += 1
        limb = b.get("limb")
        fc = int(round(tc * fps))
        ks_ = scene["keys"][by]
        stretch = max((float(ks_[min(len(ks_) - 1, max(0, fc + d))].get(k, 0.0)) for d in (-1, 0, 1) for k in ([limb] if limb else ("st", "lst", "rst", "rlst"))), default=0.0)
        react = 0.0
        for part in ("head", "hip"):                          # 頭か腰の大きい方(腹への打撃は体を折るので頭は殴った側へ寄り、押される動きと打ち消し合う)
            h0 = _head(scene, trs[to], to, tc, part)
            react = max(react, max(math.hypot(h[0] - h0[0], h[1] - h0[1]) for h in (_head(scene, trs[to], to, tc + i * dt, part) for i in range(1, int(0.3 * fps) + 1))))   # 0.3 秒の間に最も遠くまで動いた量(0.3 秒後だけで測ると、次の技に備えて戻る分が差し引かれた)
        hit = next((h for h in scene.get("hits", []) if abs(h["tau"] - tc) < 0.02), None)
        stop = round((hit or {}).get("hold", 0.0) * fps)
        lo, hi = D["stop_big"] if big else D["stop_small"]
        inv = set(scene.get("fx", {}).get("invert", []))
        speed = any(a <= tc <= b_ + 0.05 for a, b_ in scene.get("fx", {}).get("speed_lines", []))
        mark = (hit and hit["kind"] in inv) or speed
        zoom = any(tc - 0.5 <= s["t"] <= tc - 0.1 and s.get("follow") == by and s.get("scale", 9) <= 2.6 for s in scene.get("shots", []))
        side = (scene.get("fx") or {}).get("radial", True) is False      # 参考(Becker)の見せ方: 記号・寄りのカットは使わないので求めない
        if side:
            mark, zoom = True, True
            lo, hi = D["stop_small"]                                    # 参考のヒットストップは大技でも 1〜3 コマ
        miss = bool(b.get("miss"))                          # absorb: 当てても効かない(巨漢が受け止める筋書き)は反応だけ求めない。空振り: 受けた側の反応・ヒットストップは求めない(かわす動きで見せる)
        hold_lo = 1 if side else D["hold"][0]                            # 連打では前の戻りを詰めるので、溜めが 1 コマの打ちも許す
        ok = dict(hold=hold_lo <= hold <= D["hold"][1], burst=D["burst"][0] <= burst <= b.get("burst_max", D["burst"][1]),
                  stretch=stretch >= D["stretch"][0],
                  react=miss or bool(b.get("absorb")) or react >= D["react"], stop=miss or lo <= stop <= hi, mark=(mark if big else True), zoom=(zoom if big else True))
        rows.append(dict(t=round(tc, 2), by=by, big=big, hold=hold, burst=burst, stretch=round(stretch, 2), react=round(react, 2), stop=stop, mark=bool(mark), zoom=zoom, ok=ok))
    # 止め: 最後の当たりの 0.4 秒後から終わりまでで、勝った側が止まっている最長
    final = {}
    if beats:
        last = max(beats, key=lambda q: q["t"])
        tr = trs[last["by"]]
        t = last["t"] + 0.15
        best = run = 0
        while t < scene["tau_end"]:
            if _change(tr.at(t), tr.at(t + dt)) < STILL:
                run += 1
                best = max(best, run)
            else:
                run = 0
            t += dt
        final = dict(seconds=round(best * dt, 2), ok=best * dt >= D["final_hold_s"])
    # コマ打ち・カット(plan があれば)
    overall = {}
    if plan is not None:
        fr = plan["frames"]
        if video:                                           # 同じ絵の割合は動画で測る(2 コマ打ちは合成で入るので plan には出ない)
            from . import rhythm
            dup = rhythm.main(video)["dup_frame_ratio"]
            overall["dup"] = dict(value=round(dup, 2), ok=D["dup"][0] <= dup <= D["dup"][1])
        cuts = [i for i in range(1, len(fr)) if abs(fr[i]["cam"].get("yaw", 0) - fr[i - 1]["cam"].get("yaw", 0)) > 4 or abs(fr[i]["cam"].get("scale", 0) - fr[i - 1]["cam"].get("scale", 0)) > 0.6]
        ev = [e["frame"] for e in plan.get("events", []) if e.get("kind") not in ("land", "pose")]
        hot = [c for c in cuts if any(abs(c - e) <= fps for e in ev)]
        lens = sorted((b - a) / fps for a, b in zip(hot, hot[1:]) if b - a <= 2 * fps)
        med = lens[len(lens) // 2] if lens else 0.0
        if (scene.get("fx") or {}).get("radial", True) is not False:   # 参考の見せ方(長回し)ではカットの速さは測らない
            overall["cut_median"] = dict(value=round(med, 2), ok=D["cut_median"][0] <= med <= D["cut_median"][1])
    return dict(beats=rows, final=final, overall=overall)


INTENSE = dict(exchanges_per_s=1.2, max_gap_s=1.5, moving=0.60, dashes=2, aerial=1, knockdown=1)   # 2026-10-22「バトルをもっと激しく」。参考(Alan Becker の殴り合い)の動いているコマ 0.56 と、見て決めた目安


def intensity(scene: dict, beats: List[dict]) -> dict:
    """殴り合いの密度(激しさ)。打ち合いの数/秒・打ち合いの最長の間・動いているコマの割合・走り込み・空中の技・倒れ。
    戦いの区間 = 最初の当たりの 0.5 秒前から最後の当たりの 0.7 秒後まで。"""
    fps = scene.get("fps", 30)
    if not beats:
        return {}
    t0 = max(0.0, min(b["t"] for b in beats) - 0.5)
    t1 = min(scene["tau_end"], max(b["t"] for b in beats) + 0.7)
    n0, n1 = int(t0 * fps), int(t1 * fps)
    win = max(1e-6, t1 - t0)
    ts = sorted(b["t"] for b in beats)
    gaps = [b - a for a, b in zip(ts, ts[1:])] + [ts[0] - t0, t1 - ts[-1]]
    moving, total, dashes, aerial, down = 0, 0, 0, 0, 0
    names = list(scene["actors"])
    last_dash = {w: -9 for w in names}
    for w in names:
        ks_ = scene["keys"][w]
        a = scene["actors"][w]
        H = 1.9 * a.get("scale", 1.0)
        prev = None
        for f in range(n0, min(n1, len(ks_) - 1)):
            k = ks_[f]
            sk = fk.skeleton(dict(posemod.POSE0 if hasattr(posemod, "POSE0") else {}, **{n: float(v) for n, v in k.items() if n in posemod.NUM}), 1 if k["dir"] > 0 else -1, a["base_x"] + k["dx"], a.get("scale", 1.0))
            pts = [sk[n][-1] for n in ("front_arm", "rear_arm", "front_leg", "rear_leg")] + [sk["head"]]
            root = (a["base_x"] + k["dx"], k["rz"])
            if prev is not None:
                sp = max([math.hypot(p[0] - q[0], p[1] - q[1]) for p, q in zip(pts, prev[0])] + [math.hypot(root[0] - prev[1][0], root[1] - prev[1][1])]) / H
                total += 1
                moving += 1 if sp > 0.012 else 0
            prev = (pts, root)
            if f - last_dash[w] > 12 and f + 10 < len(ks_) and abs(ks_[f + 10]["dx"] - k["dx"]) >= 0.7 * H:
                dashes += 1
                last_dash[w] = f + 10
            if k["rz"] >= 0.4:
                aerial += 1
            if abs(k["roll"]) >= 1.4:
                down += 1
    D = INTENSE
    big = max(range(len(gaps) - 2), key=lambda i: gaps[i]) if len(gaps) > 2 else 0
    res = dict(max_gap_at=round(ts[big], 2) if len(ts) > 1 else 0.0, exchanges_per_s=round(len(beats) / win, 2), max_gap_s=round(max(gaps), 2), moving=round(moving / max(total, 1), 2), dashes=dashes,
               aerial=1 if aerial >= 3 else 0, knockdown=1 if down >= 3 else 0, window=round(win, 1))
    res["ok"] = dict(exchanges_per_s=res["exchanges_per_s"] >= D["exchanges_per_s"], max_gap_s=res["max_gap_s"] <= D["max_gap_s"], moving=res["moving"] >= D["moving"],
                     dashes=res["dashes"] >= D["dashes"], aerial=res["aerial"] >= D["aerial"], knockdown=res["knockdown"] >= D["knockdown"])
    return res


def intensity_report(r: dict) -> str:
    if not r:
        return ""
    D = INTENSE
    lab = dict(exchanges_per_s="打ち合い/秒", max_gap_s="打ち合いの最長の間(秒)", moving="動いているコマの割合", dashes="走り込み(回)", aerial="空中の技", knockdown="倒れ")
    rng = dict(exchanges_per_s=f"{D['exchanges_per_s']} 以上", max_gap_s=f"{D['max_gap_s']} 以下", moving=f"{D['moving']} 以上", dashes=f"{D['dashes']} 以上", aerial="1 以上", knockdown="1 以上")
    out = [f"## 激しさ(戦いの区間 {r['window']} 秒)"]
    ng = 0
    for k in lab:
        ok = r["ok"][k]
        ng += 0 if ok else 1
        out.append(f"- {lab[k]}: {r[k]}(目安 {rng[k]}){'' if ok else ' **NG**'}" + (f"  ← {r['max_gap_at']} 秒の当たりのあと" if (k == "max_gap_s" and not ok) else ""))
    out.append(f"激しさ: {'**合格**' if ng == 0 else f'**不足**({ng} 項目)'}")
    return chr(10).join(out)


NAMES = dict(hold="溜め(コマ)", burst="一気(コマ)", stretch="伸び", react="反応(頭の移動)", stop="ヒットストップ(コマ)", mark="衝撃コマかスピード線", zoom="溜めで寄る")


def report(res: dict) -> str:
    D = DEFINITION
    out = ["# アニメ調の点検", "", "| 時刻 | 打つ側 | 大技 | 溜め | 一気 | 伸び | 反応 | 止め | 記号 | 寄り |", "|---|---|---|---|---|---|---|---|---|---|"]
    ng = 0
    for r in res["beats"]:
        cell = lambda k, v: (f"{v}" if r["ok"][k] else f"**{v} NG**")
        ng += sum(1 for v in r["ok"].values() if not v)
        out.append(f"| {r['t']} | {r['by']} | {'○' if r['big'] else ''} | {cell('hold', r['hold'])} | {cell('burst', r['burst'])} | {cell('stretch', r['stretch'])} | {cell('react', r['react'])} | {cell('stop', r['stop'])} | {cell('mark', '○' if r['mark'] else '×')} | {cell('zoom', '○' if r['zoom'] else '×')} |")
    out.append("")
    if res["final"]:
        f = res["final"]
        ng += 0 if f["ok"] else 1
        out.append(f"- 決着後の止め: {f['seconds']} 秒(基準 {D['final_hold_s']} 秒以上){'' if f['ok'] else ' **NG**'}")
    for k, v in res["overall"].items():
        ng += 0 if v["ok"] else 1
        rng = D[k]
        out.append(f"- {'同じ絵が続くコマ' if k == 'dup' else '山場のカットの長さ(中央値)'}: {v['value']}(基準 {rng[0]}〜{rng[1]}){'' if v['ok'] else ' **NG**'}")
    out.append("")
    out.append(f"基準: 溜め {D['hold'][0]}〜{D['hold'][1]} コマ / 一気 {D['burst'][0]}〜{D['burst'][1]} コマ / 伸び {D['stretch'][0]} 以上 / 反応 {D['react']} 以上 / ヒットストップ 大技 {D['stop_big'][0]}〜{D['stop_big'][1]}・小技 {D['stop_small'][0]}〜{D['stop_small'][1]} コマ")
    out.append(f"合否: {'**合格**' if ng == 0 else f'**不合格**({ng} 項目)'}")
    return "\n".join(out)
