"""姿勢の定義・キー列からの補間・バネ・走りの周期。純粋な Python。

姿勢のパラメータ(角度はラジアン。「前」は人物が向いている側、0=真下):
  fa/fe  前の腕の上腕の角度 / 肘の曲げ(前方へ)    ra/re  後ろの腕
  fl/fk  前の脚の太ももの角度 / 膝の曲げ(後ろへ)    rl/rk  後ろの脚
  lean   胴の前傾    hz  腰の高さ    dx  前進量(ワールド x へは向きの符号を掛ける)
  rz     人物の根元の高さ(空中)  roll  倒れる角度(根元を軸に、後ろへ)  ht  頭の傾き  spin  胴のひねり
  st/lst 前の腕/脚の伸び(つぶれと伸び)   run  走りの周期に切り替える割合(0〜1)
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional, Sequence

from .interp import Curve, Spring

NUM = ("fa", "fe", "ra", "re", "fl", "fk", "rl", "rk", "lean", "hz", "dx", "rz", "roll", "ht", "spin", "st", "lst", "run")

STANCE_A: Dict[str, float] = dict(fa=0.7, fe=1.6, ra=0.5, re=1.7, fl=0.35, fk=0.3, rl=-0.35, rk=0.4, lean=0.1, hz=0.84,
                                  dx=0.0, rz=0.0, roll=0.0, ht=0.0, spin=0.0, st=0.0, lst=0.0, run=0.0)
STANCE_B: Dict[str, float] = dict(STANCE_A, fa=0.9, fe=1.4, ra=0.7, re=1.5, hz=0.80, lean=0.05, fl=0.45, rl=-0.45)

# バネ: 項目 → (剛性 k, 減衰比 zeta)。腕・脚は硬め、体の傾きと頭は柔らかく遅れて付いてくる。
SPRINGS: Dict[str, tuple] = {
    "fa": (520, 0.50), "ra": (520, 0.50), "fe": (700, 0.45), "re": (700, 0.45),
    "fl": (600, 0.62), "rl": (600, 0.62), "fk": (800, 0.58), "rk": (800, 0.58),
    "lean": (260, 0.55), "ht": (320, 0.45), "hz": (420, 0.50),
}
LEAD = 0.03  # バネの遅れの分だけ目標を先取りして、命中のタイミングを保つ

# 走りの周期。2026-10-18、参考(Alan Becker 「Cave Spider」83秒付近の緑の人)の連続コマを
# 分度器を重ねて目で読み取った値(誤差 ±10°)。reference/run_reading.md に根拠を残す。
RUN = dict(
    cadence=1.5,        # 1秒あたりの周期数
    leg_bias=0.25, leg_amp=0.95,      # 太もも: 前 +70° 〜 後ろ -40°
    knee_base=0.15, knee_gain=1.6,    # 前へ出す脚は膝を約100°曲げ、後ろへ蹴る脚は伸ばす
    arm_bias=-0.20, arm_amp=1.95,     # 腕: 前 +100° 〜 後ろ -125°(後ろ上へ高く振る)
    elbow_base=1.5, elbow_amp=0.3,
    bounce=0.11,        # 両足が浮く瞬間に腰が上がる量
    lean_osc=0.05,
)


class KeyTrack:
    """あるキャラのキー列(時刻と姿勢の上書き)から、任意の tau の姿勢を返す。

    keys: [{t: 秒, 値...}, ...]。書かなかった項目は直前のキーの値を引き継ぐ(最初は stance)。
    face は区間の後半から切り替わる(補間しない)。
    """

    def __init__(self, keys: Sequence[dict], stance: Dict[str, float]):
        if not keys:
            raise ValueError("キーが空")
        cur = dict(stance)
        face = "fight"
        self.ts: List[float] = []
        self.rows: List[Dict[str, float]] = []
        self.faces: List[str] = []
        for k in keys:
            cur = dict(cur, **{n: float(v) for n, v in k.items() if n in NUM})
            face = k.get("face", face)
            self.ts.append(float(k["t"]))
            self.rows.append(dict(cur))
            self.faces.append(face)
        if any(b < a for a, b in zip(self.ts, self.ts[1:])):
            raise ValueError("キーの時刻は昇順でなければならない")
        self.curves = {n: Curve(self.ts, [r[n] for r in self.rows]) for n in NUM}

    def at(self, tau: float) -> Dict[str, float]:
        out = {n: self.curves[n](tau) for n in NUM}
        idx = 0
        for i, t in enumerate(self.ts):
            if t <= tau:
                idx = i
        nxt = min(idx + 1, len(self.ts) - 1)
        if nxt != idx and tau > 0.5 * (self.ts[idx] + self.ts[nxt]):
            idx = nxt
        out["face"] = self.faces[idx]
        return out


class Smoother:
    """キャラ1体ぶんのバネ。tau が進まないコマ(ヒットストップ中)は動かさない。"""

    def __init__(self, track: KeyTrack):
        self.track = track
        p0 = track.at(0.0 + LEAD)
        self.springs = {n: Spring(p0[n], *SPRINGS[n]) for n in SPRINGS}

    def step(self, tau: float, dtau: float) -> Dict[str, float]:
        tgt = self.track.at(tau + LEAD)
        out = dict(tgt)
        for n, sp in self.springs.items():
            out[n] = sp.step(tgt[n], dtau)
        return out


def apply_run(p: Dict[str, float], tau: float, run: Optional[dict] = None) -> Dict[str, float]:
    """p['run'] の割合だけ、腕・脚・腰・傾きを走りの周期に置き換える。"""
    r = p.get("run", 0.0)
    if r <= 0.01:
        return p
    c = dict(RUN, **(run or {}))
    ph = tau * 2 * math.pi * c["cadence"]
    sw, cw = math.sin(ph), math.cos(ph)
    q = dict(p)

    def mix(a: float, b: float) -> float:
        return r * a + b * (1 - r)

    q["fl"] = mix(c["leg_bias"] + c["leg_amp"] * sw, p["fl"])
    q["rl"] = mix(c["leg_bias"] - c["leg_amp"] * sw, p["rl"])
    q["fk"] = mix(c["knee_base"] + c["knee_gain"] * max(0.0, cw), p["fk"])
    q["rk"] = mix(c["knee_base"] + c["knee_gain"] * max(0.0, -cw), p["rk"])
    q["fa"] = mix(c["arm_bias"] - c["arm_amp"] * sw, p["fa"])
    q["ra"] = mix(c["arm_bias"] + c["arm_amp"] * sw, p["ra"])
    q["fe"] = mix(c["elbow_base"] - c["elbow_amp"] * sw, p["fe"])
    q["re"] = mix(c["elbow_base"] + c["elbow_amp"] * sw, p["re"])
    q["hz"] = p["hz"] + c["bounce"] * abs(sw) * r
    q["lean"] = p["lean"] + c["lean_osc"] * math.sin(2 * ph) * r
    return q
