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


def report(plan: dict) -> str:
    m = metrics(plan)
    lines = ["# 動きの数字", "", f"- 攻防: {m['exchanges']}", f"- 接触の距離: {m['contacts']}"]
    for who in plan["actors"]:
        v = m[who]
        lines.append(f"- {who}: ひねり sd {v['spin_sd']} / 足滑り {v['slide']} / 歩数 {v['steps']} / 1コマの最大移動 {v['max_jump']}")
    return chr(10).join(lines)
