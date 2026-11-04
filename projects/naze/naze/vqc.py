"""映像の点検(世界の地図の回)。描く前に、場面の並び(ep.py の行の scene)と時間割から、見た目の質を数えて確かめる。

python -m naze vqc episodes/<題材>/<章>   … 声を作る前でも使える(時間割が無ければ 1 秒 7 字で見積もる)
qc の中でも自動で走る(題材の ep.py が MAP を持つとき)。

見るもの:
  足す間隔   画面に何も足されず、カメラも動かない区間。参考(ビジュアル各国史)は 7〜8 秒に 1 回 → 10 秒で △、15 秒で ✖
  ぼけ       寄りすぎて下地が引き伸ばされる所(下地の 1 画素を何画素に広げるか)。1.8 倍で △、2.6 倍で ✖
  カメラ     行のつなぎ目で 1.4 秒のうちに動く量。画面 1.2 枚ぶん以上の横移動か 4 倍以上の寄り引きで △
  札の数     同時に出ている字(label・pin)が 6 つ以上で △
  1 分の数   1 分あたりに足した数(参考に合わせて 6 回以上が目安。下回れば △)
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import List, Tuple

GAP_WARN, GAP_FAIL = 10.0, 15.0
BLUR_WARN, BLUR_FAIL = 1.8, 2.6
MOVE_WARN, ZOOM_WARN = 1.2, 4.0
LABELS_WARN = 6
PER_MIN_WARN = 6


def _timeline(ep: dict, out: Path) -> List[dict]:
    p = out / "timeline.json"
    if p.exists():
        return json.loads(p.read_text(encoding="utf-8"))["lines"]
    t, res = 0.0, []                                          # 声がまだ無いときの見積もり
    for l in ep["lines"]:
        d = max(1.5, len(l.get("say") or l["text"]) / 7.0)
        res.append(dict(id=l["id"], start=t, end=t + d))
        t += d + 0.25
    return res


def check(ep: dict, out: Path, mp) -> Tuple[list, list, dict]:
    """mp は worldmap.Map。返り値は (✖, △, 数字)。"""
    tl = _timeline(ep, out)
    L = {l["id"]: l for l in tl}
    defs = [d for d in ep["lines"] if d["id"] in L and d["id"] != "cta"]
    fails, warns = [], []
    events: List[float] = []
    prev = None
    total = max(l["end"] for l in tl)
    for d in defs:
        sc = d.get("scene")
        l = L[d["id"]]
        dur = l["end"] - l["start"]
        if d.get("compare"):
            events.append(l["start"] + d["compare"].get("at", 0.0) * dur)
        if d.get("style") in ("question", "end"):
            events.append(l["start"])
        if sc is None:
            continue
        prev_ids = {x.get("id") for x in (prev or {}).get("layers", [])} if prev else set()
        if prev is None or tuple(sc["view"]) != tuple(prev["view"]):
            events.append(l["start"])
            if prev is not None:                                # カメラの動く量
                a, b = prev["view"], sc["view"]
                move = math.hypot((b[0] - a[0]) * mp.kx, b[1] - a[1]) / min(a[2], b[2]) / mp.kx
                zoom = max(a[2], b[2]) / min(a[2], b[2])
                if move > MOVE_WARN or zoom > ZOOM_WARN:
                    warns.append(f"カメラが速い {l['start']:.1f}秒（{d['id']}）横 {move:.1f} 画面・寄り引き {zoom:.1f} 倍")
        for x in sc.get("layers", []):
            if x.get("id") not in prev_ids or x.get("id") is None:
                events.append(l["start"] + x.get("at", 0.0) * dur)
        P = sc.get("panel")
        if P and (prev is None or prev.get("panel") is not P):
            events.append(l["start"] + P.get("at", 0.0) * dur)
        # ぼけ: いちばん細かい下地で何倍に広げるか
        v = mp.view(*sc["view"])
        bs = [b for b in mp.bases if b.covers(v.lon, v.lat, v.span * 0.6)] or mp.bases[:1]
        k = max(v.s / bs[-1].ppd, 0.0) * (1.5 if v.tilt > 20 else 1.0)       # 傾けると手前は広がる
        if k >= BLUR_FAIL:
            fails.append(f"寄りすぎてぼける {l['start']:.1f}秒（{d['id']}）下地の {k:.1f} 倍")
        elif k >= BLUR_WARN:
            warns.append(f"少しぼける {l['start']:.1f}秒（{d['id']}）下地の {k:.1f} 倍")
        n_lab = sum(1 for x in sc.get("layers", []) if x["kind"] in ("label", "pin"))
        if n_lab >= LABELS_WARN:
            warns.append(f"字が多い {l['start']:.1f}秒（{d['id']}）{n_lab} 個")
        prev = sc
    events = sorted(set(round(e, 2) for e in events))
    pts = [0.0] + events + [total]
    for a, b in zip(pts, pts[1:]):
        g = b - a
        if g >= GAP_FAIL:
            fails.append(f"何も足されない {a:.1f}〜{b:.1f}秒（{g:.1f}秒）")
        elif g >= GAP_WARN:
            warns.append(f"足す間が長い {a:.1f}〜{b:.1f}秒（{g:.1f}秒）")
    per_min = len(events) / max(1e-6, total / 60)
    if per_min < PER_MIN_WARN:
        warns.append(f"1 分に足す数が少ない（{per_min:.1f} 回。目安 {PER_MIN_WARN} 回以上）")
    gaps = [b - a for a, b in zip(pts, pts[1:])]
    stats = {"足した数": len(events), "1分あたり": round(per_min, 1), "いちばん長い間(秒)": round(max(gaps), 1),
             "平均の間(秒)": round(sum(gaps) / len(gaps), 1)}
    return fails, warns, stats


def run(ep: dict, out: Path, mp) -> bool:
    F, Wn, st = check(ep, out, mp)
    md = [f"# 映像の点検 {out.name}", "", f"結果: {'通過' if not F else '✖ 直すものがある'}", "",
          "## ✖ 直すもの", *(f"- {x}" for x in F or ["なし"]), "", "## △ 目で確かめるもの", *(f"- {x}" for x in Wn or ["なし"]), "",
          "## 数字", *(f"- {k}: {v}" for k, v in st.items())]
    (out / "vqc.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print("\n".join(md))
    return not F
