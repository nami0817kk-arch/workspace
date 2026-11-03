"""描いたコマの点検(毎回回す)。Blender が書いた check_frames.json と plan.json を突き合わせる。

見ること:
  向き      … 人形が球の飛ぶ向き(+x)を向いているか
  当たり    … 当たる直前まで拳が球にめり込まず、当たる瞬間に拳が球に触れているか(隙間 3 cm 以内)
  めり込み  … 人形のどの頂点も球の中に入らない・球がマットや床にめり込まない
  主役      … 場面A は人形と球、B は球が画面の中に収まっているか。C は球が入ってきたら外れないか
  字        … 問いとカウンターの箱が主役(球・場面A の人形)に重ならないか
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .compose import H, W, text_boxes


def _overlap(a, b) -> bool:
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])


def run(plan: dict, checks: dict, sc: dict, out_md: Path) -> list[str]:
    R = plan["radius"]
    th = plan["t_hit"]
    mf = plan["mat_front"]
    boxes = text_boxes(sc["question"])
    fails, notes = [], []
    rows = checks["frames"]
    by_i = {r["i"]: r for r in rows}
    # 向き
    bad = [r["i"] for r in rows if np.dot(r["facing"], [1, 0, 0]) < 0.95]
    if bad:
        fails.append(f"向き: 人形が +x を向いていないコマ {bad[:8]}")
    # 当たり(物理の時刻で当たる前のコマ)
    pre = [r for r in rows if th - 0.25 <= r["s"] <= th]
    if pre:
        mn = min(r["gap"] for r in pre)
        last = max(pre, key=lambda r: r["s"])
        notes.append(f"当たる前の拳と球の隙間: 最小 {mn * 100:.1f} cm、当たる直前のコマ(#{last['i']}, {th - last['s']:.4f} 秒前) {last['gap'] * 100:.1f} cm")
        if mn < -0.01:
            fails.append(f"めり込み: 当たる前に拳が球に {-mn * 100:.1f} cm 入っている")
        if last["gap"] > 0.03:
            fails.append(f"当たり: 当たる直前のコマでも拳と球が {last['gap'] * 100:.1f} cm 離れている")
    else:
        notes.append("当たる前のコマが点検に無い(step を細かく)")
    inside = [r["i"] for r in rows if r["body_in_ball"] > 0]
    if inside:
        fails.append(f"めり込み: 人形の頂点が球の中にあるコマ {inside[:8]}")
    wall = [r["i"] for r in rows if r["ball"][0] + R > mf + 0.05]
    if wall:
        fails.append(f"めり込み: 球がマットに 5 cm を超えて入るコマ {wall[:8]}")
    flo = [r["i"] for r in rows if r["ball"][2] - R < -0.02]
    if flo:
        fails.append(f"めり込み: 球が床に入るコマ {flo[:8]}")
    # 主役が画面に収まるか
    def ball_in(r, margin=0.0):
        x, y = r["ball_px"]
        rr = r["ball_rpx"]
        return r["ball_z"] > 0 and x - rr >= -margin and x + rr <= W + margin and y - rr >= 0 and y + rr <= H
    out_a = [r["i"] for r in rows if r["shot"] == "A" and r["s"] <= th + 0.02 and not ball_in(r)]
    body_out = [r["i"] for r in rows if r["shot"] == "A" and r["body_px"] and (r["body_px"][0] < 0 or r["body_px"][2] > W or r["body_px"][1] < 0)]   # 寄りなので足元が切れるのは許す
    out_b = [r["i"] for r in rows if r["shot"] == "B" and not ball_in(r, -0.1 * W)]
    seen, out_c = False, []
    for r in sorted((r for r in rows if r["shot"] == "C"), key=lambda r: r["i"]):
        if ball_in(r):
            seen = True
        elif seen:
            out_c.append(r["i"])
    for name, lst in (("場面A の球", out_a), ("場面A の人形", body_out), ("場面B の球(端から 1 割より内)", out_b), ("場面C の球", out_c)):
        if lst:
            fails.append(f"主役: {name}が画面から外れるコマ {lst[:8]}(計 {len(lst)})")
    # 字との重なり
    hits = []
    for r in rows:
        x, y = r["ball_px"]
        rr = r["ball_rpx"]
        bb = (x - rr, y - rr, x + rr, y + rr)
        for k, box in boxes.items():
            if r["ball_z"] > 0 and _overlap(bb, box):
                hits.append((r["i"], "球", k))
            if r["shot"] == "A" and r["body_px"] and _overlap(r["body_px"], box):
                hits.append((r["i"], "人形", k))
    if hits:
        fails.append(f"字: 主役と字が重なるコマ {hits[:6]}(計 {len(hits)})")
    lines = ["# 3D の回の点検", "", f"コマ数 {len(rows)} / 1コマ {checks.get('sec_per_frame', 0):.2f} 秒", ""]
    lines += ["## 結果", ""] + ([f"- ✗ {f}" for f in fails] or ["- すべて通った"]) + ["", "## メモ", ""] + [f"- {n}" for n in notes]
    out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return fails
