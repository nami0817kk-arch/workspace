"""戦いの「動き」の数字(plan から)。「手だけ動いている」を数字で見つけるための物差し。

  python -m stickfig motion scenes/x.yaml      # 計算だけ(Blender 不要)

- 体のひねり spin の標準偏差(0 なら体をひねっていない。fight の既定で 0.4 前後)
- 足滑り: 接地した足が 1 コマに 0.035 以上横に動く割合(20〜30% まで。走りの周期は含む)
- 歩数: 足が浮いて下りた回数
- 瞬間移動: 1 コマの根元の最大移動
- 攻防: by:A / by:B の命中の種類と数
- 接触: 命中の瞬間の、先端から相手の体までの距離(出来上がりのコマで測った値)
"""
from __future__ import annotations

import statistics as st
from typing import Dict

from . import fk


def metrics(plan: dict) -> Dict[str, object]:
    fr = plan["frames"]
    out: Dict[str, object] = {}
    kinds: Dict[str, int] = {}
    for e in plan["events"]:
        if e.get("by"):
            k = f"{e['by']}:{e['kind']}"
            kinds[k] = kinds.get(k, 0) + 1
    out["exchanges"] = kinds
    out["contacts"] = [("miss" if c.get("kind") == "miss" else round(c["distance_to_body"], 2)) for c in plan.get("contacts", [])]   # かわし(miss)は当たらないのが正しい
    for who, a in plan["actors"].items():
        s = 1 if a.get("facing", 1) >= 0 else -1
        spin = [x["actors"][who]["spin"] for x in fr]
        prev = None
        slide = ground = steps = 0
        lifted = False
        mx = 0.0
        for f, x in enumerate(fr):
            if f > 0 and fr[f - 1]["tau"] == x["tau"]:
                continue
            pa = x["actors"][who]
            sk = fk.skeleton(pa, s, pa["root_x"], a.get("scale", 1.0))
            feet = [sk["foot"], sk["rear_foot"]]
            if prev is not None:
                for i in range(2):
                    if feet[i][1] < 0.06 and prev[i][1] < 0.06:
                        ground += 1
                        if abs(feet[i][0] - prev[i][0]) > 0.035:
                            slide += 1
                up = min(feet[0][1], feet[1][1]) > 0.08
                if up and not lifted:
                    steps += 1
                lifted = up
                mx = max(mx, abs(pa["root_x"] - prevx))
            prev = feet
            prevx = pa["root_x"]
        out[who] = dict(spin_sd=round(st.pstdev(spin), 2), slide=f"{slide / max(1, ground) * 100:.0f}%", steps=steps, max_jump=round(mx, 2))
    return out


def snap(plan: dict) -> Dict[str, object]:
    """キレ: 命中(by 付き)ごとに、先端の速さの山(命中の 5 コマ前〜命中の最大)÷ 溜めの区間(16〜7 コマ前)の平均。
    アニメは溜めてから一気に振るので大きい(目安 4 以上)。あわせて、溜めの区間のうち先端がほぼ止まっているコマ数(待ち)。"""
    fr = plan["frames"]
    out = []
    for e in plan["events"]:
        if not e.get("by") or e["kind"] not in ("slash", "hit", "kick", "clash", "heel", "miss"):
            continue
        who = e["by"]
        a = plan["actors"][who]
        s = 1 if a.get("facing", 1) >= 0 else -1
        key = "foot" if e["kind"] in ("kick", "heel") else ("tip" if a.get("weapon") else "hand")
        f0 = e["frame"]
        pts = []
        for f in range(max(0, f0 - 14), min(len(fr) - 1, f0 + 1) + 1):
            p = fr[f]["actors"][who]
            sk = fk.skeleton(p, s, p["root_x"], a.get("scale", 1.0))
            pts.append((f, sk[key]))
        sp = {}
        for (fa_, pa), (fb_, pb) in zip(pts, pts[1:]):
            if fr[fb_]["tau"] == fr[fa_]["tau"]:
                continue
            sp[fb_] = ((pb[0] - pa[0]) ** 2 + (pb[1] - pa[1]) ** 2) ** 0.5
        pre = [sp[f] for f in range(f0 - 16, f0 - 6) if f in sp]              # 溜めの区間(命中の 16〜7 コマ前)
        peak = max([sp[f] for f in range(f0 - 5, f0 + 1) if f in sp] or [0.0])   # 振りの区間(命中の 5 コマ前〜命中。伸び切りの命中は f0 で速さ 0 に近い)
        mean = sum(pre) / len(pre) if pre else 0.0
        waiting = sum(1 for v in pre if v < 0.012)
        other = next((w2 for w2 in ("A", "B") if w2 != who and w2 in plan["actors"]), None)
        sep = None
        if other is not None and e["kind"] in ("hit", "kick", "slash", "heel"):   # 命中後 10 コマの 2 人の根元の距離の最小(0.55 を切ると胴が重なって見える)
            sep = round(min(abs(fr[f]["actors"][who]["root_x"] - fr[f]["actors"][other]["root_x"]) for f in range(f0, min(len(fr), f0 + 11))), 2)
        out.append(dict(kind=e["kind"], by=who, frame=f0, snap=round(peak / mean, 1) if mean > 1e-6 else None, peak=round(peak, 3), wait=waiting, sep=sep))
    return dict(strikes=out)


def report(plan: dict) -> str:
    m = metrics(plan)
    lines = ["# 動きの数字", "", f"- 攻防: {m['exchanges']}", f"- 接触の距離: {m['contacts']}"]
    for who in plan["actors"]:
        v = m[who]
        lines.append(f"- {who}: ひねり sd {v['spin_sd']} / 足滑り {v['slide']} / 歩数 {v['steps']} / 1コマの最大移動 {v['max_jump']}")
    sn = snap(plan)["strikes"]
    if sn:
        lines.append("- キレ(山÷直前の平均。目安 4 以上)と待ち(直前 12 コマで止まっているコマ数):")
        for x in sn:
            lines.append(f"    {x['by']}:{x['kind']}@{x['frame']}  キレ {x['snap']}  山 {x['peak']}  待ち {x['wait']}" + (f"  間合い {x['sep']}" if x.get('sep') is not None else ""))
    return chr(10).join(lines)
