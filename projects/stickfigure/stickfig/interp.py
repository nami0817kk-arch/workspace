"""補間・バネ・時間の写像(スローモーションとヒットストップ)。純粋な Python。

- 姿勢の間は「単調3次エルミート(PCHIP)」で通す。区間ごとのイーズだと、要の姿勢ごとに速度が0になり
  「カクカク」して見える(2026-10-18 に判明)。PCHIP は速度がつながり、行き過ぎもしない。
- 関節には2次のバネを掛け、遅れて追いつき少し行き過ぎて戻る動き(オーバーラップ)を出す。
- 時間は「設計時間 tau」と「実時間(コマ)」を分ける。スローとヒットストップは tau の進み方で表す。
"""
from __future__ import annotations

import math
from typing import Dict, List, Sequence, Tuple


def pchip_tangents(ts: Sequence[float], ys: Sequence[float]) -> List[float]:
    """Fritsch–Carlson。区間の傾きの符号が変わる所は接線 0、それ以外は調和平均で単調を保つ。"""
    n = len(ts)
    if n < 2:
        return [0.0] * n
    h = [ts[k + 1] - ts[k] for k in range(n - 1)]
    d = [(ys[k + 1] - ys[k]) / h[k] if h[k] > 0 else 0.0 for k in range(n - 1)]
    if n == 2:
        return [d[0], d[0]]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for k in range(1, n - 1):
        if d[k - 1] * d[k] <= 0:
            m[k] = 0.0
        else:
            w1, w2 = 2 * h[k] + h[k - 1], h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k])
    return m


class Curve:
    """時刻つきの値の列を PCHIP で通す1本の曲線。"""

    def __init__(self, ts: Sequence[float], ys: Sequence[float]):
        if len(ts) != len(ys) or not ts:
            raise ValueError("ts と ys の長さが合わない、または空")
        if any(b < a for a, b in zip(ts, ts[1:])):
            raise ValueError("時刻は昇順でなければならない")
        self.ts = list(ts)
        self.ys = list(ys)
        self.m = pchip_tangents(self.ts, self.ys)

    def __call__(self, t: float) -> float:
        ts, ys, m = self.ts, self.ys, self.m
        if t <= ts[0]:
            return ys[0]
        if t >= ts[-1]:
            return ys[-1]
        lo, hi = 0, len(ts) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if ts[mid] <= t:
                lo = mid
            else:
                hi = mid
        h = ts[hi] - ts[lo]
        if h <= 0:
            return ys[hi]
        u = (t - ts[lo]) / h
        u2, u3 = u * u, u * u * u
        return ((2 * u3 - 3 * u2 + 1) * ys[lo] + (u3 - 2 * u2 + u) * h * m[lo]
                + (-2 * u3 + 3 * u2) * ys[hi] + (u3 - u2) * h * m[hi])


def smoothstep(x: float, a: float, b: float) -> float:
    u = max(0.0, min(1.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


class Spring:
    """2次バネ(剛性 k、減衰比 zeta)。目標に遅れて追いつき、zeta<1 なら少し行き過ぎる。"""

    def __init__(self, x0: float, k: float, zeta: float):
        self.x, self.v, self.k, self.zeta = x0, 0.0, k, zeta

    def step(self, target: float, dt: float, substeps: int = 4) -> float:
        if dt <= 0:
            return self.x
        h = dt / substeps
        c = 2 * self.zeta * math.sqrt(self.k)
        for _ in range(substeps):
            self.v += (self.k * (target - self.x) - c * self.v) * h
            self.x += self.v * h
        return self.x


def build_timeline(tau_end: float, fps: int, hits: Sequence[dict], slow: Sequence[dict] = (),
                   puffs: Sequence[dict] = (), tempo: float = 1.0) -> Tuple[List[float], List[dict]]:
    """実時間のコマごとに設計時間 tau を返す。

    hits: [{tau, hold(秒), kind}] その tau に達したら hold 秒だけ止める(ヒットストップ)
    slow: [{start, end, rate}] その tau の区間は rate 倍速(出入りは滑らか)
    puffs: [{tau, kind}] 止めずに印だけ付ける(砂ぼこりなど)
    tempo: 全体の再生の速さ(1.3 なら 1.3 倍速。ヒットストップの長さは変えない)
    戻り値: (tau の列, events) events は {frame, kind, tau, hold_frames}
    """
    dt = 1.0 / fps
    tau, hold = 0.0, 0.0
    done = set()
    out: List[float] = []
    events: List[dict] = []
    guard = int((tau_end * 6 + 10) * fps)
    while tau < tau_end and len(out) < guard:
        f = len(out)
        for h in hits:
            key = ("h", h["tau"])
            if key not in done and tau >= h["tau"]:
                tau = h["tau"]
                hold = h.get("hold", 0.0)
                done.add(key)
                events.append(dict(frame=f, kind=h.get("kind", "hit"), tau=h["tau"],
                                   hold_frames=max(0, int(round(hold * fps))), by=h.get("by")))
        for p in puffs:
            key = ("p", p["tau"])
            if key not in done and tau >= p["tau"]:
                done.add(key)
                events.append(dict(frame=f, kind=p.get("kind", "puff"), tau=p["tau"], hold_frames=0))
        if hold > 1e-9:
            rate = 0.0
            hold -= dt
        else:
            rate = tempo
            for s in slow:
                r = s["rate"]
                a, b = s["start"], s["end"]
                rate = min(rate, tempo * (1.0 - (1.0 - r) * smoothstep(tau, a - 0.12, a + 0.04)
                           * (1.0 - smoothstep(tau, b - 0.04, b + 0.14))))
        out.append(tau)
        tau += rate * dt
    return out, events
