"""手付けの戦いの動作部品(2026-10-22「バトルをもっと激しくして、参考動画みてね」)。

これまでの手付け(fight01・bout_*)は、1 発ごとに絶対時刻でキーを書いていたので、密度の高い殴り合いを作るのに手間が掛かりすぎた。
ここでは「いつ・誰が・どの技で・誰に・どう受けるか」を並べるだけで、腰・足・手のトラックに組み立てる。

使い方(tools/shots/duel_*.py が見本):
    def script(F, T):
        A, B = F["A"], F["B"]
        T.exchange(A, B, "jab", 1.00, "stagger")          # 緑の左が当たり、青がよろける
        T.exchange(B, A, "round_kick", 1.60, "duck")        # 青の回し蹴りを緑がしゃがんでかわす(空振り)
        ...
    sc, rep, beats = moves.build_bout("duel_x", BG, 10.0, CAST, script)

決まり:
  - 動作は時刻順に置く。同じ人の動作が重なるとエラーで止まる(密度を上げるときは、間隔を詰めすぎない)
  - 当たる位置は相手の焼いた体から取り(3 回焼く)、打つ側の立ち位置は「腕・脚が届く距離」を解いて決める
  - 打つ前の溜め(hold)と一気(burst)は keyshot.warp_fn。1 発 = 溜め 2 コマ + 一気 3 コマ
  - すき間は構えて弾む(bounce)。止まって待つ時間を作らない
"""
from __future__ import annotations

import math
from typing import Callable, Dict, List, Optional, Tuple

from . import bout, fk, keyshot as ks
from .bout import FPS, GUARD_F, GUARD_R, H as hit_rec

HOLD, BURST = 2, 3
PRE = (HOLD + BURST) / FPS
SH = fk.SHOULDER_Z
ARM, LEG = fk.ARM_TOTAL, fk.LEG_TOTAL
Pt = Tuple[float, float]


def _r(v, n=4):
    return round(float(v), n)


class Fighter:
    def __init__(self, name: str, x: float, d: int, style: str, scale: float = 1.0, color=(0.5, 0.85, 0.3)):
        self.name, self.x, self.d, self.style, self.sc, self.color = name, float(x), int(d), style, float(scale), color
        self.lead, self.rear = x + d * 0.25 * scale, x - d * 0.30 * scale
        self.t = 0.0                                   # 最後の動作の終わり
        self.body = [dict(t=0.0, x=x, hz=0.80, lean=0.12, ht=0.0, dir=d, face="fight")]
        self.F = [dict(t=0.0, p=(_r(self.lead), 0))]
        self.R = [dict(t=0.0, p=(_r(self.rear), 0))]
        self.FH = [dict(t=0.0, ang=GUARD_F)]
        self.RH = [dict(t=0.0, ang=GUARD_R)]
        self.holds: List[dict] = []
        self._bounce = 0
        self._last_hit = -9.0            # 最後に当てた/当てられた時刻(戻りを切れるのはこの 0.08 秒後から)
        self._nocut = False              # 吹き飛びの途中などは切れない
        self._spans: List[Tuple[float, float]] = []   # 吹き飛び〜起き上がり(この間だけ rz・roll を補間のまま使う)
        self._lying = False
        self.hold, self.burst = HOLD, BURST      # 溜め・一気(コマ)。fast なら 1・2

    # ---------------- 下回り ----------------
    def _start(self, t0: float, what: str):
        """動作を t0 から始める。前の動作の戻り(最大 0.32 秒)は切って詰める(連打)。それ以上重なるならエラー。"""
        if t0 >= self.t - 1e-6:
            return
        if self._nocut or self.t - t0 > 0.32 + 1e-6 or t0 < self._last_hit + 0.08:
            raise ValueError(f"{self.name}: {what} の始まり {t0:.3f} が前の動作の終わり {self.t:.3f} より前(間隔を空ける。前の当たり {self._last_hit:.3f})")
        for tr in (self.body, self.F, self.R, self.FH, self.RH):
            while len(tr) > 1 and tr[-1]["t"] > t0 + 1e-6:
                tr.pop()
        self.t = t0

    def _planted(self, t, x=None, ease="inout", lift=None):
        """足を今の位置に置いたままにするキー(両足)。"""
        for tr, px in ((self.F, self.lead), (self.R, self.rear)):
            k = dict(t=_r(t), p=(_r(px), 0))
            if ease != "inout":
                k["ease"] = ease
            tr.append(k)

    def neutral(self, t, x=None, ease="inout"):
        """構えの姿勢に戻すキー(体・手)。足は呼び出し側。"""
        x = self.x if x is None else x
        k = dict(t=_r(t), x=_r(x), hz=0.80, lean=0.12, ht=0.0, rz=0.0, roll=0.0, st=0.0, lst=0.0, rst=0.0, rlst=0.0)
        if ease != "inout":
            k["ease"] = ease
        self.body.append(k)
        self.FH.append(dict(t=_r(t), ang=GUARD_F, **({"ease": ease} if ease != "inout" else {})))
        self.RH.append(dict(t=_r(t), ang=GUARD_R, **({"ease": ease} if ease != "inout" else {})))

    def bounce_until(self, t_to: float):
        """動作のすき間を、構えて弾んで埋める(止まって待たない)。0.17 秒ごとに腰を上下、足を小さく踏み替える。"""
        t = self.t
        while t + 0.17 <= t_to - 0.02:
            t += 0.17
            self._bounce += 1
            low = self._bounce % 2 == 1
            self.body.append(dict(t=_r(t), x=_r(self.x), hz=0.765 if low else 0.80, lean=0.12, ht=0.0, rz=0.0, roll=0.0))
            if self._bounce % 4 in (1, 3):                # 4 回に 2 回、足を前後に小さく(0.05)踏み替える
                sh = 0.05 * self.sc * (1 if self._bounce % 4 == 1 else -1) * self.d
                self.lead += sh
                self.rear += sh
                for tr, px in ((self.F, self.lead), (self.R, self.rear)):
                    tr.append(dict(t=_r(t), p=(_r(px), 0), lift=0.02))
                self.x += sh * 0.5
                self.body[-1]["x"] = _r(self.x)
        self.t = max(self.t, t)

    def _hold_to(self, t):
        """t まで、いまの構えを保つ(足・手のキーは進めない)。"""
        self.bounce_until(t)

    def _set_state(self, x, t_end):
        self.x = x
        self.lead, self.rear = x + self.d * 0.25 * self.sc, x - self.d * 0.30 * self.sc
        self.t = t_end

    # ---------------- 移動 ----------------
    def shuffle(self, t0: float, t1: float, x_new: float):
        """構えたまま、前か後ろへすり足(後ろの足が先、前の足が後)。"""
        self._start(t0, "すり足")
        self._hold_to(t0)
        dxs = x_new - self.x
        if abs(dxs) < 0.02:
            self.t = t1
            return
        fwd = dxs * self.d > 0
        tm = (t0 + t1) / 2
        lead_new, rear_new = x_new + self.d * 0.25 * self.sc, x_new - self.d * 0.30 * self.sc
        self.body.append(dict(t=_r(t0), x=_r(self.x), hz=0.80, lean=0.12, ht=0.0))
        self.body.append(dict(t=_r(t1), x=_r(x_new), hz=0.80, lean=0.12, ht=0.0))
        first, second = (self.R, self.F) if fwd else (self.F, self.R)
        old_f, old_r = self.lead, self.rear
        # 先に動く足
        if fwd:
            self.R.append(dict(t=_r(t0), p=(_r(old_r), 0))); self.R.append(dict(t=_r(tm), p=(_r(rear_new), 0), lift=0.06))
            self.F.append(dict(t=_r(tm), p=(_r(old_f), 0))); self.F.append(dict(t=_r(t1), p=(_r(lead_new), 0), lift=0.06))
        else:
            self.F.append(dict(t=_r(t0), p=(_r(old_f), 0))); self.F.append(dict(t=_r(tm), p=(_r(lead_new), 0), lift=0.06))
            self.R.append(dict(t=_r(tm), p=(_r(old_r), 0))); self.R.append(dict(t=_r(t1), p=(_r(rear_new), 0), lift=0.06))
        self.FH.append(dict(t=_r(t1), ang=GUARD_F))
        self.RH.append(dict(t=_r(t1), ang=GUARD_R))
        self._set_state(x_new, t1)

    def dash(self, t0: float, t1: float, x_new: float):
        """一気に走り込む/跳び退く(0.2 秒前後)。前傾・両足が浮く・腕を振る。"""
        self._start(t0, "ダッシュ")
        self._hold_to(t0)
        sgn = 1 if (x_new - self.x) * self.d >= 0 else -1          # 前へ(+1)か後ろへ(-1)
        tm = (t0 + t1) / 2
        xm = (self.x + x_new) / 2
        lean = 0.55 if sgn > 0 else -0.20
        self.body.append(dict(t=_r(t0), x=_r(self.x), hz=0.74, lean=0.30 * sgn if sgn > 0 else 0.05, ht=0.0, rz=0.0))
        self.body.append(dict(t=_r(tm), x=_r(xm), hz=0.84, lean=lean, ht=0.10 if sgn > 0 else 0.0, rz=0.14, ease="linear"))
        self.body.append(dict(t=_r(t1), x=_r(x_new), hz=0.76, lean=0.28 if sgn > 0 else 0.10, ht=0.0, rz=0.0, ease="out"))
        s = self.d * sgn
        self.F.append(dict(t=_r(t0), p=(_r(self.lead), 0)))
        self.R.append(dict(t=_r(t0), p=(_r(self.rear), 0)))
        self.F.append(dict(t=_r(tm), p=(_r(xm + s * 0.55), 0.22), ease="linear"))
        self.R.append(dict(t=_r(tm), p=(_r(xm - s * 0.55), 0.10), ease="linear"))
        lead_new, rear_new = x_new + self.d * 0.25 * self.sc, x_new - self.d * 0.30 * self.sc
        self.F.append(dict(t=_r(t1), p=(_r(lead_new), 0), ease="out"))
        self.R.append(dict(t=_r(t1), p=(_r(rear_new), 0), ease="out"))
        self.FH.append(dict(t=_r(t0), ang=GUARD_F))
        self.FH.append(dict(t=_r(tm), ang=(-0.3 * sgn, 0.7), ease="linear"))
        self.FH.append(dict(t=_r(t1), ang=GUARD_F, ease="out"))
        self.RH.append(dict(t=_r(t0), ang=GUARD_R))
        self.RH.append(dict(t=_r(tm), ang=(0.5 * sgn + 0.3, 0.7), ease="linear"))
        self.RH.append(dict(t=_r(t1), ang=GUARD_R, ease="out"))
        self._set_state(x_new, t1)

    def _x_pre(self, x_hit: float, adv: float) -> float:
        """打つ前の立ち位置。いまの位置から x_hit までが「踏み込み + 0.3」以内なら動かず、踏み込みで一気に詰める(連打)。"""
        gap = (x_hit - self.x) * self.d
        if -0.50 * self.sc <= gap <= (adv + 0.90) * self.sc:
            return self.x
        return x_hit - self.d * adv

    def _approach(self, x_pre: float, t_ready: float):
        """t_ready までに、x_pre へ移る(近ければすり足、遠ければダッシュ)。"""
        gap = (x_pre - self.x) * self.d
        if abs(gap) < 0.05:
            self._hold_to(t_ready)
            return
        try:
            if abs(gap) <= 0.80 * self.sc:
                dur = 0.14 + 0.25 * abs(gap)
                self.shuffle(t_ready - dur - 0.02, t_ready - 0.02, x_pre)
            else:
                dur = 0.20 if abs(gap) < 2.2 else 0.28
                self.dash(t_ready - dur - 0.02, t_ready - 0.02, x_pre)
        except ValueError as e:
            raise ValueError(f"{e}  [近づく距離 {gap:+.2f}。相手の押され(push)を小さくするか、間隔を空ける]") from None

    # ---------------- 打つ ----------------
    def _x_for_hand(self, T: Pt, hz: float, lean: float, rz: float = 0.0) -> float:
        """肩から目標まで腕がほぼ伸びる(0.92)立ち位置。"""
        sx = self.sc * SH * math.sin(lean)
        sz = rz + self.sc * (hz + SH * math.cos(lean))
        r = self.sc * ARM * 0.92
        dx = math.sqrt(max(0.0, r * r - (T[1] - sz) ** 2))
        return T[0] - self.d * (dx + sx)

    def _x_for_leg(self, T: Pt, hz: float, rz: float = 0.0) -> float:
        hz_w = rz + self.sc * hz
        r = self.sc * LEG * 0.96
        dx = math.sqrt(max(0.0, r * r - (T[1] - hz_w) ** 2))
        return T[0] - self.d * dx

    def _hold(self, t, burst=None, hold=None):
        burst = self.burst if burst is None else burst
        hold = self.hold if hold is None else hold
        self.holds.append(dict(kind="windup", t=_r(t), hold=hold, burst=burst))

    @property
    def pre(self) -> float:
        """打つ前の「溜め + 一気」の秒数(当たりのこの秒数前に、構えを止めて打つ)。"""
        return (self.hold + self.burst) / FPS

    def punch(self, kind: str, t: float, T: Pt, ret: Optional[float] = None):
        """kind: jab(前の手)・cross(後ろの手)・hook(大振り)・upper(しゃがみから)・palm(掌底)・belly(低い腹打ち)。T: 当てる点(世界)。"""
        d, sc = self.d, self.sc
        cfg = dict(jab=dict(hz=0.78, lean=0.42, adv=0.30, ret=0.32, hand="f"),
                   cross=dict(hz=0.80, lean=0.50, adv=0.22, ret=0.30, hand="r"),
                   hook=dict(hz=0.78, lean=0.55, adv=0.26, ret=0.30, hand="r"),
                   upper=dict(hz=0.86, lean=0.05, adv=0.55, ret=0.30, hand="r"),
                   palm=dict(hz=0.80, lean=0.20, adv=0.25, ret=0.25, hand="f"),
                   belly=dict(hz=0.52, lean=0.40, adv=0.40, ret=0.35, hand="r"))[kind]
        if ret is not None:
            cfg = dict(cfg, ret=ret)                     # 連打の途中は下がらない(ret=0)
        t0 = t - self.pre
        x_hit = self._x_for_hand(T, cfg["hz"], cfg["lean"])
        x_pre = self._x_pre(x_hit, cfg["adv"])
        self._approach(x_pre, t0)
        self._start(t0, kind)
        self._last_hit = t
        sk = "st" if cfg["hand"] == "f" else "rst"
        hand_tr, other_tr = (self.FH, self.RH) if cfg["hand"] == "f" else (self.RH, self.FH)
        hand_guard, other_guard = (GUARD_F, GUARD_R) if cfg["hand"] == "f" else (GUARD_R, GUARD_F)
        t_end = t + 0.30
        x_end = x_hit - d * cfg["ret"]
        # 体
        pre_hz, pre_lean = {"jab": (0.75, 0.06), "cross": (0.78, 0.20), "hook": (0.76, -0.20), "upper": (0.50, 0.40), "palm": (0.76, 0.06), "belly": (0.54, 0.28)}[kind]
        self.body.append(dict(t=_r(t0), x=_r(x_pre), hz=pre_hz, lean=pre_lean, **{sk: 0.0}))
        self.body.append(dict(t=_r(t), x=_r(x_hit), hz=cfg["hz"], lean=cfg["lean"], ht=0.15 if kind == "upper" else 0.0, **{sk: 0.30 if kind != "palm" else 0.32}, ease="in"))
        if kind == "upper":
            self.body.append(dict(t=_r(t + 0.11), hz=0.88, lean=-0.08, rz=0.10, **{sk: 0.0}, ease="out"))
        else:
            self.body.append(dict(t=_r(t + 0.12), lean=0.30, **{sk: 0.0}))
        self.body.append(dict(t=_r(t_end), x=_r(x_end), hz=0.80, lean=0.12, ht=0.0, rz=0.0, ease="out"))
        # 足: 前の足が踏み込み、後ろの足が追う
        lead_hit = x_hit + d * 0.28 * sc
        self.F.append(dict(t=_r(t0), p=(_r(self.lead), 0)))
        self.F.append(dict(t=_r(t), p=(_r(lead_hit), 0), lift=0.05, ease="out"))
        self.F.append(dict(t=_r(t + 0.20), p=(_r(lead_hit), 0)))
        lead_end, rear_end = x_end + d * 0.25 * sc, x_end - d * 0.30 * sc
        self.F.append(dict(t=_r(t_end), p=(_r(lead_end), 0), lift=0.03))
        self.R.append(dict(t=_r(t0), p=(_r(self.rear), 0)))
        self.R.append(dict(t=_r(t), p=(_r(x_hit - d * 0.35 * sc), 0), lift=0.06, ease="out"))     # 踏み込みに後ろの足が引き寄せられる(置いたままだと脚が伸び切って浮く)
        self.R.append(dict(t=_r(t_end), p=(_r(rear_end), 0), lift=0.03))
        # 手
        if kind == "hook":
            a = (T[0] - d * 0.45 * sc, T[1] + 0.15)
            hand_tr.append(dict(t=_r(t0), ang=(-0.9, 1.3)))
            hand_tr.append(dict(t=_r(t - 0.05), p=(_r(a[0]), _r(a[1])), ease="in"))
            hand_tr.append(dict(t=_r(t), p=(_r(T[0]), _r(T[1])), ease="linear"))
            hand_tr.append(dict(t=_r(t + 0.12), ang=(0.2, 0.4), ease="out"))
        elif kind == "upper":
            hand_tr.append(dict(t=_r(t0), ang=(0.1, 1.9)))
            hand_tr.append(dict(t=_r(t), p=(_r(T[0]), _r(T[1])), ease="in"))
        else:
            hand_tr.append(dict(t=_r(t0), ang=(0.95, 2.0) if cfg["hand"] == "f" else (-0.30, 1.9)))
            hand_tr.append(dict(t=_r(t), p=(_r(T[0]), _r(T[1])), ease="in"))
        hand_tr.append(dict(t=_r(t + 0.17), ang=hand_guard, ease="out"))
        other_tr.append(dict(t=_r(t0), ang=other_guard))
        other_tr.append(dict(t=_r(t), ang=(0.6, 2.2) if cfg["hand"] == "f" else (0.7, 1.6)))
        other_tr.append(dict(t=_r(t + 0.17), ang=other_guard, ease="out"))
        self._hold(t)
        self._set_state(x_end, t_end)
        return x_hit

    def kick(self, kind: str, t: float, T: Pt, ret: Optional[float] = None):
        """kind: front(前の脚)・round(後ろの脚で高く回す)・jump(跳び蹴り)・sweep(しゃがんで足払い)。"""
        d, sc = self.d, self.sc
        t0 = t - self.pre
        if kind == "front":
            hz, rz = 0.82, 0.0
            x_hit = self._x_for_leg(T, hz)
            x_pre = self._x_pre(x_hit, 0.30)
            self._approach(x_pre, t0)
            self._start(t0, kind)
            self._last_hit = t
            t_end = t + 0.32
            x_end = x_hit - d * (0.10 if ret is None else ret)
            self.body.append(dict(t=_r(t0), x=_r(x_pre), hz=0.82, lean=-0.12, lst=0.0))
            self.body.append(dict(t=_r(t), x=_r(x_hit), hz=0.82, lean=-0.32, lst=0.28, ease="in"))
            self.body.append(dict(t=_r(t + 0.10), lst=0.0, lean=-0.30))
            self.body.append(dict(t=_r(t_end), x=_r(x_end), hz=0.80, lean=0.12, ht=0.0, lst=0.0, ease="out"))
            self.F.append(dict(t=_r(t0), p=(_r(x_pre + d * 0.24 * sc), 0.45)))
            self.F.append(dict(t=_r(t), p=(_r(T[0]), _r(T[1])), ease="in"))
            self.F.append(dict(t=_r(t + 0.08), p=(_r(T[0] - d * 0.05), _r(T[1] - 0.10))))
            self.F.append(dict(t=_r(t + 0.20), p=(_r(x_hit + d * 0.36 * sc), 0.0), lift=0.0))
            rear_end = x_end - d * 0.30 * sc
            self.R.append(dict(t=_r(t0), p=(_r(self.rear), 0)))
            self.R.append(dict(t=_r(t), p=(_r(x_hit - d * 0.22 * sc), 0), lift=0.06, ease="out"))     # 軸足
            self.R.append(dict(t=_r(t + 0.20), p=(_r(x_hit - d * 0.22 * sc), 0)))
            self.R.append(dict(t=_r(t_end), p=(_r(rear_end), 0), lift=0.04))
            self.F.append(dict(t=_r(t_end), p=(_r(x_end + d * 0.25 * sc), 0), lift=0.03))
            self.FH.append(dict(t=_r(t0), ang=GUARD_F)); self.FH.append(dict(t=_r(t), ang=(0.8, 1.4))); self.FH.append(dict(t=_r(t_end), ang=GUARD_F, ease="out"))
            self.RH.append(dict(t=_r(t0), ang=GUARD_R)); self.RH.append(dict(t=_r(t), ang=(-0.6, 1.0))); self.RH.append(dict(t=_r(t_end), ang=GUARD_R, ease="out"))
        elif kind == "round":
            hz, rz = 0.83, 0.0
            x_hit = self._x_for_leg(T, hz)
            x_pre = self._x_pre(x_hit, 0.15)
            self._approach(x_pre, t0)
            self._start(t0, kind)
            self._last_hit = t
            t_end = t + 0.34
            x_end = x_hit - d * (0.30 if ret is None else ret)
            self.body.append(dict(t=_r(t0), x=_r(x_pre), hz=0.83, lean=-0.35, rlst=0.0))
            self.body.append(dict(t=_r(t), x=_r(x_hit), hz=0.83, lean=-0.60, rlst=0.34, ease="in"))
            self.body.append(dict(t=_r(t + 0.12), lean=-0.45, rlst=0.0))
            self.body.append(dict(t=_r(t_end), x=_r(x_end), hz=0.80, lean=0.12, ht=0.0, rlst=0.0, ease="out"))
            self.R.append(dict(t=_r(t0), p=(_r(x_pre + d * 0.22 * sc), 0.90)))
            self.R.append(dict(t=_r(t), p=(_r(T[0]), _r(T[1])), ease="in"))
            self.R.append(dict(t=_r(t + 0.14), p=(_r(x_hit + d * 0.30 * sc), 0.25)))       # 蹴り足は前を通って引き戻す(腰の真上を通る道だと脚が解けない)
            rear_end = x_end - d * 0.30 * sc
            self.R.append(dict(t=_r(t_end), p=(_r(rear_end), 0.0), lift=0.05))
            self.F.append(dict(t=_r(t0), p=(_r(self.lead), 0)))
            self.F.append(dict(t=_r(t), p=(_r(x_hit + d * 0.12 * sc), 0), lift=0.06, ease="out"))     # 軸足
            self.F.append(dict(t=_r(t + 0.20), p=(_r(x_hit + d * 0.12 * sc), 0)))
            self.F.append(dict(t=_r(t_end), p=(_r(x_end + d * 0.25 * sc), 0), lift=0.03))
            self.FH.append(dict(t=_r(t0), ang=GUARD_F)); self.FH.append(dict(t=_r(t), ang=(2.2, 0.5))); self.FH.append(dict(t=_r(t_end), ang=GUARD_F, ease="out"))
            self.RH.append(dict(t=_r(t0), ang=GUARD_R)); self.RH.append(dict(t=_r(t), ang=(-0.9, 0.6))); self.RH.append(dict(t=_r(t_end), ang=GUARD_R, ease="out"))
        elif kind == "sweep":
            hz = 0.50
            x_hit = self._x_for_leg(T, hz)
            x_pre = self._x_pre(x_hit, 0.30)
            self._approach(x_pre, t0)
            self._start(t0, kind)
            self._last_hit = t
            t_end = t + 0.45
            x_end = x_hit - d * (0.05 if ret is None else ret)
            self.body.append(dict(t=_r(t0), x=_r(x_pre), hz=0.54, lean=0.30, rlst=0.0))
            self.body.append(dict(t=_r(t), x=_r(x_hit), hz=hz, lean=0.40, rlst=0.34, ease="in"))
            self.body.append(dict(t=_r(t + 0.10), rlst=0.20))
            self.body.append(dict(t=_r(t + 0.25), hz=0.60, lean=0.30, rlst=0.0))
            self.body.append(dict(t=_r(t_end), x=_r(x_end), hz=0.80, lean=0.12, ht=0.0, rlst=0.0, ease="out"))
            self.R.append(dict(t=_r(t0), p=(_r(self.rear), 0)))
            self.R.append(dict(t=_r(t - 0.03), p=(_r(x_pre - d * 0.35 * sc), 0.10)))
            self.R.append(dict(t=_r(t), p=(_r(T[0]), _r(max(0.06, T[1]))), ease="in"))
            self.R.append(dict(t=_r(t + 0.10), p=(_r(T[0] + d * 0.25), 0.12)))
            self.R.append(dict(t=_r(t_end), p=(_r(x_end - d * 0.30 * sc), 0.0), lift=0.05))
            self.F.append(dict(t=_r(t0), p=(_r(self.lead), 0)))
            self.F.append(dict(t=_r(t), p=(_r(x_hit + d * 0.15 * sc), 0), lift=0.06, ease="out"))     # 軸足
            self.F.append(dict(t=_r(t + 0.25), p=(_r(x_hit + d * 0.15 * sc), 0)))
            self.F.append(dict(t=_r(t_end), p=(_r(x_end + d * 0.25 * sc), 0), lift=0.03))
            self.FH.append(dict(t=_r(t0), ang=GUARD_F)); self.FH.append(dict(t=_r(t), ang=(1.0, 1.4))); self.FH.append(dict(t=_r(t_end), ang=GUARD_F, ease="out"))
            self.RH.append(dict(t=_r(t0), ang=GUARD_R)); self.RH.append(dict(t=_r(t), ang=(-0.5, 1.2))); self.RH.append(dict(t=_r(t_end), ang=GUARD_R, ease="out"))
        elif kind == "jump":
            rz_hit, hz = 0.70, 0.83
            x_hit = self._x_for_leg(T, hz, rz_hit)
            burst = 6
            pre = (self.hold + burst) / FPS
            t0 = t - pre
            x_pre = x_hit - d * 1.2
            pass
            self._approach(x_pre, t0)
            self._start(t0, kind)
            self._last_hit = t
            t_land = t + 0.30
            x_land = x_hit + d * 0.25
            t_end = t + 0.55
            self.body.append(dict(t=_r(t0), x=_r(x_pre), hz=0.60, lean=0.30, rz=0.0, rlst=0.0))
            self.body.append(dict(t=_r(t - 0.10), x=_r(x_hit - d * 0.55), hz=0.83, lean=-0.10, rz=0.62, ease="out"))
            self.body.append(dict(t=_r(t), x=_r(x_hit), hz=hz, lean=-0.35, rz=rz_hit, rlst=0.34, ease="linear"))
            self.body.append(dict(t=_r(t + 0.10), x=_r(x_hit + d * 0.10), rz=0.55, rlst=0.0, ease="linear"))
            self.body.append(dict(t=_r(t_land), x=_r(x_land), hz=0.62, lean=0.35, rz=0.0, ease="in"))
            self.body.append(dict(t=_r(t_land + 0.12), hz=0.68, lean=0.25))
            self.body.append(dict(t=_r(t_end), x=_r(x_land), hz=0.80, lean=0.12, ht=0.0, rz=0.0, ease="out"))
            self.F.append(dict(t=_r(t0), p=(_r(self.lead), 0)))
            self.F.append(dict(t=_r(t - 0.10), ang=(0.3, 2.0)))
            self.F.append(dict(t=_r(t + 0.10), ang=(0.5, 0.8)))
            self.F.append(dict(t=_r(t_land), p=(_r(x_land + d * 0.30 * sc), 0), ease="in"))
            self.R.append(dict(t=_r(t0), p=(_r(self.rear), 0)))
            self.R.append(dict(t=_r(t - 0.10), ang=(1.0, 0.6)))
            self.R.append(dict(t=_r(t), p=(_r(T[0]), _r(T[1])), ease="linear"))
            self.R.append(dict(t=_r(t + 0.10), ang=(0.9, 0.4)))
            self.R.append(dict(t=_r(t_land), p=(_r(x_land - d * 0.25 * sc), 0), ease="in"))
            for tr, g in ((self.FH, GUARD_F), (self.RH, GUARD_R)):
                tr.append(dict(t=_r(t0), ang=g)); tr.append(dict(t=_r(t - 0.10), ang=(1.1, 1.8))); tr.append(dict(t=_r(t + 0.10), ang=(1.0, 2.0))); tr.append(dict(t=_r(t_end), ang=g, ease="out"))
            self._hold(t, burst=burst)
            self._set_state(x_land, t_end)
            return x_hit
        else:
            raise ValueError(kind)
        self._hold(t)
        self._set_state(x_end, t_end)
        return x_hit

    # ---------------- 受ける ----------------
    def _away(self):
        return -self.d                                 # 打ってくる相手から離れる向き(向き合っている前提)

    def _end_at(self, t_end, x_end):
        self.neutral(t_end, x_end, ease="out")
        self.F.append(dict(t=_r(t_end), p=(_r(x_end + self.d * 0.25 * self.sc), 0), lift=0.03))
        self.R.append(dict(t=_r(t_end), p=(_r(x_end - self.d * 0.30 * self.sc), 0), lift=0.03))
        self._set_state(x_end, t_end)

    def _pre_static(self, t):
        """当たりのコマまでは構えのまま(受ける側の最後の静止キー)。"""
        self.body.append(dict(t=_r(t), x=_r(self.x), hz=0.80, lean=0.12, ht=0.0, rz=0.0))
        self.F.append(dict(t=_r(t), p=(_r(self.lead), 0)))
        self.R.append(dict(t=_r(t), p=(_r(self.rear), 0)))
        self._last_hit = max(self._last_hit, t)

    def block(self, t: float, push: float = 0.35):
        """両腕で受けて、足を滑らせて下がる。"""
        a = self._away()
        self._start(t - 0.06, "block")
        self._hold_to(t - 0.06)
        x_end = self.x + a * push
        self.FH.append(dict(t=_r(t - 0.05), ang=(1.55, 1.95))); self.RH.append(dict(t=_r(t - 0.05), ang=(1.4, 1.95)))
        self._pre_static(t)
        self.body.append(dict(t=_r(t + 0.28), x=_r(x_end), hz=0.76, lean=0.0, ht=0.12, ease="out"))
        self.F.append(dict(t=_r(t + 0.28), p=(_r(self.lead + a * push), 0), lift=0.0, ease="out"))
        self.R.append(dict(t=_r(t + 0.28), p=(_r(self.rear + a * push), 0), lift=0.0, ease="out"))
        self.FH.append(dict(t=_r(t + 0.30), ang=(1.5, 1.9))); self.RH.append(dict(t=_r(t + 0.30), ang=(1.35, 1.9)))
        self._end_at(t + 0.40, x_end)

    def lean_dodge(self, t: float, back: float = 0.35):
        """上体を反らして(少し下がって)かわす。当たる前から動き始める。"""
        a = self._away()
        t_s = t - 0.14
        self._start(t_s, "lean_dodge")
        self._hold_to(t_s)
        x_end = self.x + a * back
        self.body.append(dict(t=_r(t_s), x=_r(self.x), lean=0.12, ht=0.0))
        self.body.append(dict(t=_r(t), x=_r(self.x + a * back * 0.6), lean=-0.55, ht=0.30, ease="out"))
        self.body.append(dict(t=_r(t + 0.16), x=_r(x_end), lean=-0.30, ht=0.10))
        self.F.append(dict(t=_r(t_s), p=(_r(self.lead), 0)))
        self.R.append(dict(t=_r(t_s), p=(_r(self.rear), 0)))
        self.F.append(dict(t=_r(t + 0.10), p=(_r(self.lead + a * back), 0), lift=0.03))
        self.R.append(dict(t=_r(t + 0.16), p=(_r(self.rear + a * back), 0), lift=0.03))
        self._end_at(t + 0.32, x_end)

    def duck(self, t: float, back: float = 0.15):
        """深くしゃがんでかわす(高い攻撃の下をくぐる)。当たる前に沈む。"""
        a = self._away()
        t_s = t - 0.16
        self._start(t_s, "duck")
        self._hold_to(t_s)
        x_end = self.x + a * back
        self.body.append(dict(t=_r(t_s), x=_r(self.x), hz=0.79, lean=0.12, ht=0.0))
        self.body.append(dict(t=_r(t), x=_r(x_end), hz=0.50, lean=0.30, ht=-0.10, ease="out"))
        self.body.append(dict(t=_r(t + 0.18), x=_r(x_end), hz=0.50, lean=0.30))
        self.F.append(dict(t=_r(t_s), p=(_r(self.lead), 0)))
        self.R.append(dict(t=_r(t_s), p=(_r(self.rear), 0)))
        self.F.append(dict(t=_r(t), p=(_r(self.lead + a * back + self.d * 0.12), 0), lift=0.03))
        self.R.append(dict(t=_r(t), p=(_r(self.rear + a * back - self.d * 0.18), 0), lift=0.03))
        self.FH.append(dict(t=_r(t_s), ang=GUARD_F)); self.FH.append(dict(t=_r(t), ang=(1.35, 1.9))); self.FH.append(dict(t=_r(t + 0.18), ang=(1.2, 1.8)))
        self.RH.append(dict(t=_r(t_s), ang=GUARD_R)); self.RH.append(dict(t=_r(t), ang=(1.1, 2.2))); self.RH.append(dict(t=_r(t + 0.18), ang=(1.1, 2.2)))
        self._end_at(t + 0.36, x_end)

    def hop(self, t: float):
        """低い攻撃(足払い)を、その場で跳んでかわす。"""
        t_s = t - 0.14
        self._start(t_s, "hop")
        self._hold_to(t_s)
        self.body.append(dict(t=_r(t_s), x=_r(self.x), hz=0.74, lean=0.12, rz=0.0))
        self.body.append(dict(t=_r(t), x=_r(self.x), hz=0.84, lean=0.05, rz=0.45, ease="out"))
        self.body.append(dict(t=_r(t + 0.16), rz=0.20, hz=0.82))
        self.F.append(dict(t=_r(t_s), p=(_r(self.lead), 0)))
        self.R.append(dict(t=_r(t_s), p=(_r(self.rear), 0)))
        self.F.append(dict(t=_r(t), ang=(0.5, 1.5)))
        self.R.append(dict(t=_r(t), ang=(-0.3, 1.2)))
        self.FH.append(dict(t=_r(t_s), ang=GUARD_F)); self.FH.append(dict(t=_r(t), ang=(0.9, 1.6)))
        self.RH.append(dict(t=_r(t_s), ang=GUARD_R)); self.RH.append(dict(t=_r(t), ang=(0.2, 1.4)))
        self.F.append(dict(t=_r(t + 0.30), p=(_r(self.lead), 0), ease="in"))
        self.R.append(dict(t=_r(t + 0.30), p=(_r(self.rear), 0), ease="in"))
        self._end_at(t + 0.40, self.x)

    def stagger(self, t: float, push: float = 0.45, high: bool = False):
        """殴られて頭がはね、よろける(軽い被弾)。high: 顎が上がって浮く(アッパー)。"""
        a = self._away()
        self._start(t, "stagger")
        self._hold_to(t)
        self._pre_static(t)
        x1, x_end = self.x + a * push * 0.6, self.x + a * push
        if high:
            self.body.append(dict(t=_r(t + 0.07), x=_r(x1), hz=0.86, rz=0.34, lean=-0.70, ht=0.95, ease="out"))
            self.body.append(dict(t=_r(t + 0.22), x=_r(x_end), hz=0.78, rz=0.0, lean=-0.30, ht=0.35))
        else:
            self.body.append(dict(t=_r(t + 0.07), x=_r(x1), hz=0.80, rz=0.04, lean=-0.40, ht=0.70, ease="out"))
            self.body.append(dict(t=_r(t + 0.20), x=_r(x_end), hz=0.78, rz=0.0, lean=-0.15, ht=0.25))
        self.F.append(dict(t=_r(t + 0.10), p=(_r(self.lead + a * push * 0.7), 0.0), lift=0.0))
        self.R.append(dict(t=_r(t + 0.22), p=(_r(self.rear + a * push), 0.0), lift=0.05))
        self.F.append(dict(t=_r(t + 0.24), p=(_r(self.lead + a * push), 0.0), lift=0.05))
        self.FH.append(dict(t=_r(t + 0.08), ang=(1.5, 0.8))); self.RH.append(dict(t=_r(t + 0.08), ang=(1.3, 0.7)))
        self._end_at(t + 0.38, x_end)

    def fold(self, t: float, push: float = 0.55):
        """腹を打たれて体を折る。"""
        a = self._away()
        self._start(t, "fold")
        self._hold_to(t)
        self._pre_static(t)
        x_end = self.x + a * push
        self.body.append(dict(t=_r(t + 0.08), x=_r(self.x + a * push * 0.9), hz=0.62, rz=0.0, lean=0.78, ht=-0.45, ease="out"))
        self.body.append(dict(t=_r(t + 0.30), x=_r(x_end), hz=0.68, lean=0.55, ht=-0.30))
        self.F.append(dict(t=_r(t + 0.12), p=(_r(self.lead + a * push), 0.0), lift=0.0))
        self.R.append(dict(t=_r(t + 0.30), p=(_r(self.rear + a * push), 0.0), lift=0.04))
        self.FH.append(dict(t=_r(t + 0.08), ang=(0.3, 1.4))); self.RH.append(dict(t=_r(t + 0.08), ang=(0.2, 1.6)))
        self._end_at(t + 0.50, x_end)

    def launch(self, t: float, dist: float = 2.0, lie: float = 0.25, getup: float = 0.55, stay: bool = False):
        """強く蹴られて吹き飛び、背中から落ちて跳ね、寝て、起き上がる。stay=True なら倒れたまま(決着)。"""
        a = self._away()
        self._start(t, "launch")
        self._hold_to(t)
        self._pre_static(t)
        self._nocut = True
        t_span0 = t
        x0 = self.x
        xe = x0 + a * dist
        T1 = t + 0.08
        self.body.append(dict(t=_r(T1), x=_r(x0 + a * dist * 0.18), rz=0.30, roll=0.40, lean=-0.55, ht=0.30, ease="out"))
        self.body.append(dict(t=_r(t + 0.22), x=_r(x0 + a * dist * 0.55), rz=0.60, roll=1.00))
        self.body.append(dict(t=_r(t + 0.42), x=_r(x0 + a * dist * 0.92), rz=0.30, roll=1.45))
        self.body.append(dict(t=_r(t + 0.50), x=_r(xe), rz=0.21, roll=1.57, lean=0.0, ht=0.0, ease="in"))
        self.body.append(dict(t=_r(t + 0.58), x=_r(xe + a * 0.12), rz=0.34, ease="out"))
        self.body.append(dict(t=_r(t + 0.66), x=_r(xe + a * 0.22), rz=0.21, ease="in"))
        t_l = t + 0.66 + lie
        self.body.append(dict(t=_r(t_l), x=_r(xe + a * 0.30), rz=0.21, roll=1.57, ease="out"))
        self.F.append(dict(t=_r(T1 + 0.04), ang=(0.9, 0.4))); self.F.append(dict(t=_r(t + 0.50), ang=(0.3, 0.2)))
        self.R.append(dict(t=_r(T1 + 0.04), ang=(-0.4, 0.6))); self.R.append(dict(t=_r(t + 0.50), ang=(0.1, 0.2)))
        self.FH.append(dict(t=_r(T1 + 0.04), ang=(2.4, 0.4))); self.FH.append(dict(t=_r(t + 0.50), ang=(2.6, 0.3)))
        self.RH.append(dict(t=_r(T1 + 0.04), ang=(2.2, 0.5))); self.RH.append(dict(t=_r(t + 0.50), ang=(2.4, 0.3)))
        xl = xe + a * 0.30
        if stay:
            self.t = t_l
            self.x = xl
            self._lying = True
            self._land_x = xe
            self._spans.append((t_span0, 1e9))
            return
        # 起き上がる(手をついて、膝を抱えて、立つ)
        g = t_l
        self.F.append(dict(t=_r(g), ang=(0.3, 0.2))); self.R.append(dict(t=_r(g), ang=(0.1, 0.2)))
        self.FH.append(dict(t=_r(g), ang=(2.6, 0.3))); self.RH.append(dict(t=_r(g), ang=(2.4, 0.3)))
        k = getup / 0.6
        self.body.append(dict(t=_r(g + 0.20 * k), x=_r(xl), rz=0.24, roll=1.05, hz=0.55, lean=0.20))
        self.F.append(dict(t=_r(g + 0.20 * k), ang=(1.2, 1.6))); self.R.append(dict(t=_r(g + 0.20 * k), ang=(1.0, 1.8)))
        self.FH.append(dict(t=_r(g + 0.20 * k), ang=(0.4, 0.4))); self.RH.append(dict(t=_r(g + 0.20 * k), ang=(0.3, 0.4)))
        self.body.append(dict(t=_r(g + 0.35 * k), x=_r(xl), rz=0.18, roll=0.40, hz=0.48, lean=0.55))
        self.F.append(dict(t=_r(g + 0.35 * k), p=(_r(xl + self.d * 0.25 * self.sc), 0))); self.R.append(dict(t=_r(g + 0.35 * k), p=(_r(xl - self.d * 0.30 * self.sc), 0)))
        self.body.append(dict(t=_r(g + 0.50 * k), x=_r(xl), rz=0.0, roll=0.0, hz=0.72, lean=0.30))
        self._end_at(g + getup, xl)
        self._nocut = False
        self._spans.append((t_span0, g + getup))

    def freeze(self, t0: float, dur: float = 0.6):
        """t0 から dur 秒、いまの姿勢で全身を止める(決めの止め絵)。以降のキーは dur 遅れて読まれる。"""
        self.holds.append(dict(kind="freeze", t0=_r(t0), t1=_r(t0 + dur)))

    def finish(self, t_end: float):
        if self._lying:                                   # 倒れたまま終わる(決着)。弾むと立ち上がってしまう
            return
        self.bounce_until(t_end)
        self.neutral(t_end)
        self.F.append(dict(t=_r(t_end), p=(_r(self.lead), 0)))
        self.R.append(dict(t=_r(t_end), p=(_r(self.rear), 0)))

    def tracks(self):
        def srt(tr):
            return sorted(tr, key=lambda k: k["t"])
        body = srt(self.body)
        for k in body:                                    # 書いていない項目は 0(そのままだと、前後のキーの間で値がだらだら補間されて、離れた時刻の体が傾く)
            if any(a - 1e-6 <= k["t"] <= b + 1e-6 for a, b in self._spans):
                continue
            for f in ("rz", "roll", "st", "lst", "rst", "rlst"):
                k.setdefault(f, 0.0)
        return dict(body=body, f_foot=srt(self.F), r_foot=srt(self.R), f_hand=srt(self.FH), r_hand=srt(self.RH))


# ---------------- 組み立て ----------------
POINT = {"face": lambda sk, tw: bout.face(sk, tw), "chin": lambda sk, tw: bout.chin(sk, tw), "chest": lambda sk, tw: bout.surface(bout.chest(sk), tw, 0.10),
         "belly": lambda sk, tw: bout.surface(bout.belly(sk), tw, 0.12), "arm": lambda sk, tw: (sk["front_arm"][-3][0] + tw * 0.06, sk["front_arm"][-3][1]),
         "ankle": lambda sk, tw: (sk["front_leg"][-1][0] - tw * 0.04, 0.08), "head": lambda sk, tw: (sk["head"][0] + tw * 0.1, sk["head"][1])}

ATTACK = dict(jab="face", cross="face", hook="face", upper="chin", palm="face", belly="belly",
              front="chest", round="face", jump="chest", sweep="ankle")
REACT_FOR = dict(  # 受け方の既定(結果 → 動作)
    stagger=lambda dfn, t, kind: dfn.stagger(t, high=(kind == "upper")), fold=lambda dfn, t, kind: dfn.fold(t),
    block=lambda dfn, t, kind: dfn.block(t), launch=lambda dfn, t, kind: dfn.launch(t))
MISS_FOR = dict(lean=lambda dfn, t: dfn.lean_dodge(t), duck=lambda dfn, t: dfn.duck(t), hop=lambda dfn, t: dfn.hop(t))
BIG_KINDS = {"upper", "jump", "round", "sweep"}
KICK_KINDS = {"front", "round", "jump", "sweep"}
LIMB = dict(jab="st", cross="rst", hook="rst", upper="rst", palm="st", belly="rst", front="lst", round="rlst", jump="rlst", sweep="rlst")
HAND_KINDS = {"jab", "cross", "hook", "upper", "palm", "belly"}


class Table:
    """打つ・受けるを 1 組にして並べる係。当たる位置は前の焼き込み(prev)の相手の体から取る。"""

    def __init__(self, fighters: Dict[str, Fighter], actors: Dict[str, dict], prev: Optional[Dict[str, List[dict]]]):
        self.F, self.actors, self.prev = fighters, actors, prev        # prev は使わない(解析的に当て先を出す)
        self.hits: List[dict] = []
        self.beats: List[dict] = []
        self.puffs: List[dict] = []
        self.fast = False                                  # True なら以降の打ちは溜め 1 コマ・一気 2 コマ(速い連打)

    def _skel(self, dfn: Fighter, miss_kind: Optional[str]) -> dict:
        """守る側の、当たる(かわす)瞬間の体。いまの立ち位置(compile の状態)と、構えの型・かわす姿勢から解析的に出す。
        前は前回焼いた体から取っていたが、前の当たりの位置が変わるたびに後ろの当たりがずれて、3 回では収束しなかった。"""
        st = bout.STYLES[dfn.style]
        pose = dict(ks.POSE0, hz=0.78 - st["hz_drop"], lean=st["lean"], ht=st["ht"])
        shift = 0.0
        if miss_kind == "lean":
            pose.update(lean=-0.55, ht=0.30)
            shift = dfn._away() * 0.21
        elif miss_kind == "duck":
            pose.update(hz=0.50, lean=0.30, ht=-0.10)
            shift = dfn._away() * 0.15
        elif miss_kind == "hop":
            pose.update(hz=0.84, lean=0.05, ht=0.0, rz=0.45)
        return fk.skeleton(pose, dfn.d, dfn.x + shift, dfn.sc)

    def point(self, att: Fighter, dfn: Fighter, kind: str, t: float, miss_kind: Optional[str] = None, part: Optional[str] = None) -> Pt:
        part = part or ATTACK[kind]
        sk = self._skel(dfn, miss_kind)
        tw = dfn.d                                         # 打つ側のいる向き = 守る側から見て前
        P = POINT[part](sk, tw)
        if miss_kind:                                      # 空振り: かわした体の手前で止まる
            P = (P[0] + tw * 0.16, P[1] - 0.04)
        return P

    def exchange(self, att: Fighter, dfn: Fighter, kind: str, t: float, result: str = "stagger", **kw):
        """att が kind の技を t に当て(または空振りし)、dfn が result で応える。
        result: stagger / fold / block / launch(当たる)、lean / duck / hop(かわす=空振り)。
        kw: push・dist・lie・getup・stay・ret(打ったあと下がる量)・part(当てる所: face/chin/chest/belly/arm/ankle。背の高い相手の顔には腕が届かないので chest にする)"""
        t = round(t * FPS) / FPS                              # 当たりはコマの時刻(n/30)にそろえる(そろっていないと、当たりのコマで腕が届かない)
        miss = result in MISS_FOR
        # かわす側は当たる前から動くので、先に受けを置く(かわした体の位置から空振りの位置を取るため、動作の置く順は受け→打ちではなく打ち→受けのまま、時刻で並ぶ)
        T = self.point(att, dfn, kind, t, result if miss else None, kw.get("part"))
        ret = kw.get("ret")
        fast = kw.get("fast", self.fast)
        att.hold, att.burst = (1, 2) if fast else (HOLD, BURST)
        if kind in HAND_KINDS:
            att.punch(kind, t, T, ret=ret)
        elif kind == "jump":
            att.kick(kind, t, T)
        else:
            att.kick(kind, t, T, ret=ret)
        if miss:
            getattr(dfn, {"lean": "lean_dodge"}.get(result, result))(t, **{k: v for k, v in kw.items() if k in ("back",)})
        else:
            if result == "launch":
                dfn.launch(t, **{k: v for k, v in kw.items() if k in ("dist", "lie", "getup", "stay")})
            elif result == "stagger":
                dfn.stagger(t, push=kw.get("push", 0.45), high=(kind == "upper"))
            elif result == "fold":
                dfn.fold(t, push=kw.get("push", 0.55))
            elif result == "block":
                dfn.block(t, push=kw.get("push", 0.35))
            else:
                raise ValueError(result)
        big = kind in BIG_KINDS and result in ("launch", "stagger", "fold")
        kindfx = "miss" if miss else ("clash" if result == "block" else ("kick" if kind in KICK_KINDS else "hit"))
        hold = 0.0 if miss else (0.10 if big or result == "launch" else (0.07 if result == "block" else 0.06))
        if fast and not miss and hold <= 0.07:
            hold = 0.04                                    # 速い連打のヒットストップは 1 コマ
        self.hits.append(hit_rec(round(t, 4), kindfx, T, hold, by=att.name if not miss else None))
        self.beats.append(dict(t=round(t, 4), by=att.name, to=dfn.name, big=big, limb=LIMB[kind], miss=miss, absorb=(result == "block"), **({"burst_max": 6} if kind == "jump" else {})))
        if result == "launch":
            lx = round(dfn.x - dfn._away() * 0.30, 3)
            self.hits.append(hit_rec(round(t + 0.50, 4), "land", (lx, 0.2), 0.04))
            self.puffs.append(dict(tau=round(t + 0.50, 4), kind="land2", pos=[lx, 0.0]))


def _chain(self: Table, att: Fighter, dfn: Fighter, steps: list, t: float, gap: float = 0.26, fast: bool = True) -> float:
    """連続技。steps=[(技, 結果, kw), ...] を gap 秒おきに速い打ち(溜め 1・一気 2)で並べる。途中は下がらず(ret=0)押しも小さく、最後だけ kw のまま。
    最後の当たりの時刻を返す。"""
    for i, st in enumerate(steps):
        kind, result = st[0], st[1]
        kw = dict(st[2]) if len(st) > 2 else {}
        if i < len(steps) - 1:
            kw.setdefault("ret", 0.0)
            kw.setdefault("push", 0.15)
        kw.setdefault("fast", fast)
        self.exchange(att, dfn, kind, t + i * gap, result, **kw)
    return t + (len(steps) - 1) * gap


Table.chain = _chain


def _clash(self: Table, a: Fighter, b: Fighter, kind: str, t: float, ret: float = 0.35, z: float = 1.40):
    """2 人が同時に打ち、拳が真ん中でぶつかる(鍔迫り合いの素手版)。ぶつかった点に火花。どちらも ret だけ弾かれて下がる。"""
    t = round(t * FPS) / FPS
    mx = (a.x + b.x) / 2
    M = (mx, z)
    a.punch(kind, t, M, ret=ret)
    b.punch(kind, t, M, ret=ret)
    self.hits.append(hit_rec(round(t, 4), "clash", M, 0.10))
    self.beats.append(dict(t=round(t, 4), by=a.name, to=b.name, big=False, limb=LIMB[kind], miss=False, absorb=True))
    self.beats.append(dict(t=round(t, 4), by=b.name, to=a.name, big=False, limb=LIMB[kind], miss=False, absorb=True))


Table.clash = _clash


def build_bout(name: str, bg: dict, t_end: float, cast: Dict[str, dict], script: Callable, passes: int = 1, cam_scale: float = 3.4):
    """cast: {名前: dict(color, scale, style, x, d)}。script(F, T) が動作を並べる。(場面, IK 残差, 点検用の beats) を返す。"""
    base = bout.new_scene(name, bg, t_end, {w: dict(color=c["color"], scale=(c.get("scale") if c.get("scale", 1.0) != 1.0 else None)) for w, c in cast.items()})
    actors = base["actors"]
    prev = None
    rep: list = []
    for it in range(passes):
        F = {w: Fighter(w, c["x"], c["d"], c["style"], c.get("scale", 1.0), c["color"]) for w, c in cast.items()}
        T = Table(F, actors, prev)
        script(F, T)
        keys = {}
        for w, f in F.items():
            f.finish(t_end)
            tr = ks.widen_stance(bout.stylize(f.tracks(), f.style), scale=f.sc)
            keys[w] = ks.bake(tr, actors[w], FPS, t_end, report=(rep if it == passes - 1 else None), holds=f.holds)
        prev = keys
    base["keys"] = keys
    base["hits"] = T.hits
    base["puffs"] = T.puffs
    base["fx"]["flashes"] = []
    base["slow"] = []
    base["shots"] = [dict(t=0.0, follow="mid", scale=cam_scale, yaw=0.0, pitch=0.0, lens=40.0, target_z=1.0, lag=0.30)]
    base["fx"]["invert"], base["fx"]["speed_lines"], base["fx"]["radial"] = [], [], False        # 参考の見せ方(side_view と同じ)。animecheck は記号・寄りを求めない
    base["stepping"] = dict(hold=2, ones_around_hits=3, hold_camera=True)
    base["anime"] = dict(base["anime"], trails=False, sfx=False, zoom_blur=False, roll=False)      # 擬音の文字は出さない(音は sfx.py が付ける)
    return base, rep, T.beats
