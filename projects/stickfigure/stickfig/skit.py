"""物語の台本(skit): 戦いでなく、棒人間たちが物で遊び・いたずら・失敗する無言の小話を、動作の並びから組む。

参考は Alan Becker「Animation vs. Minecraft」系(2026-10-20 ユーザー提示)。色違いの棒人間、箱や玉などの小道具、
歩く・拾う・運ぶ・投げる・驚く・笑う・転ぶ、の積み重ねで笑わせる。台詞は無し。

台本(yaml):
  skit:
    stage: field            # 舞台の色味(fight と同じ theme)
    mood: calm              # BGM の気分
    actors: {A: {color: [0.5, 0.85, 0.3], x: -3.0}, B: {color: [0.9, 0.3, 0.25], x: 8.0, dir: -1}}
    props:  {box: {kind: box, x: 2.0, size: 0.6, color: [210, 160, 90]}, ball: {kind: ball, x: 4.5, size: 0.4, color: [240, 90, 80]}}
    beats:
      - {who: A, act: walk, to: 1.2}
      - {who: A, act: surprised}
      - {who: A, act: pickup, prop: box}
      - {who: A, act: carry, to: 4.0}
      - {who: A, act: put, prop: box}
      - {who: B, act: run, to: 5.5, at: with}     # at: with = 直前の動作と同時に始める
      - {who: B, act: throw, prop: box, to: 1.0, hit: A}
      - {who: A, act: fall}
      - {act: wait, dur: 0.6}

位置は世界の x(fight と同じ単位、人物の身長≒1.7)。全員 facing=+1 で置き、向きは姿勢の dir で変える(絵だけ反転)。
動作ごとの時間は省略できる(既定あり)。`to` は世界の x。`prop` は props の名前。
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional

WALK_SPEED = 1.7      # 単位/秒
RUN_SPEED = 4.2
ARM_REACH = 0.55      # 物を拾う・置くときの、根元から物までの距離
FPS = 30
WIDE, CLOSE = 5.0, 3.6   # 引き・寄りの倍率(6.2/4.2 だと引きで人物が小さかった。参考は画面の 1/3〜1/2)


def _r(x: float) -> float:
    return round(float(x), 3)


IDLE = dict(fa=0.45, fe=1.0, ra=0.35, re=1.0, fl=0.12, fk=0.1, rl=-0.12, rk=0.12, lean=0.02, hz=0.86, ht=0.0, run=0.0, rz=0.0, roll=0.0, spin=0.0)
CARRY = dict(IDLE, fa=1.35, fe=0.85, ra=1.3, re=0.9, lean=0.06)                  # 両手を前に出して箱を抱える
CROUCH = dict(IDLE, hz=0.6, lean=0.55, fa=1.3, fe=0.25, ra=1.2, re=0.3, fl=0.9, fk=1.5, rl=-0.3, rk=1.2)   # しゃがんで手を伸ばす
WINDUP = dict(IDLE, lean=-0.18, fa=-0.7, fe=0.9, ra=0.6, re=1.4, hz=0.82)
RELEASE = dict(IDLE, lean=0.38, fa=1.55, fe=0.0, ra=-0.2, re=1.1, hz=0.8, fl=0.9, fk=0.4, rl=-0.6, rk=0.2)
SURPRISE = dict(IDLE, lean=-0.35, fa=2.6, fe=0.3, ra=2.4, re=0.35, ht=-0.5, hz=0.9, fl=0.5, fk=0.4, rl=-0.5, rk=0.4)
LAUGH = dict(IDLE, lean=-0.22, ht=-0.45, fa=0.9, fe=2.2, ra=0.8, re=2.2, hz=0.84)
ANGRY = dict(IDLE, lean=0.2, fa=0.5, fe=2.3, ra=-0.4, re=2.0, ht=0.15, hz=0.82)
POINT = dict(IDLE, fa=1.57, fe=0.0, lean=0.08, ht=0.0)
THINK = dict(IDLE, ra=2.3, re=2.6, ht=0.25, lean=0.05)
WAVE_A = dict(IDLE, fa=2.8, fe=0.6)
WAVE_B = dict(IDLE, fa=2.8, fe=0.15)
CHEER = dict(IDLE, fa=2.7, fe=0.3, ra=2.7, re=0.3, lean=-0.1, hz=0.9)
SAD = dict(IDLE, lean=0.3, ht=0.6, fa=0.1, fe=0.2, ra=0.1, re=0.2, hz=0.8)
PUSH = dict(IDLE, lean=0.5, fa=1.25, fe=0.3, ra=1.2, re=0.35, hz=0.78, fl=0.9, fk=0.5, rl=-0.7, rk=0.2)
SIT = dict(IDLE, hz=0.5, lean=0.1, fl=1.5, fk=1.5, rl=1.4, rk=1.5, fa=0.6, fe=1.2, ra=0.5, re=1.2)
CLOSEUP_ACTS = {"surprised", "laugh", "angry", "think", "fall", "cry", "cheer", "nod", "shake"}


class _Actor:
    def __init__(self, name: str, spec: dict):
        self.name = name
        self.color = spec.get("color", [0.5, 0.85, 0.3])
        self.scale = float(spec.get("scale", 1.0))
        self.base_x = float(spec.get("x", 0.0))
        self.x = self.base_x
        self.dir = int(spec.get("dir", 1))
        self.pose = dict(IDLE)
        self.keys: List[dict] = []
        self.free = 0.0                       # この時刻まで動作中
        self.holding: Optional[str] = None

    def key(self, t: float, pose: Optional[dict] = None, x: Optional[float] = None, **extra) -> dict:
        if pose is not None:
            self.pose = dict(self.pose, **pose)
        if x is not None:
            self.x = float(x)
        k = dict(t=_r(t), dx=_r(self.x - self.base_x), dir=self.dir, abs=True, **self.pose, **extra)
        self.keys.append(k)
        return k


class _Prop:
    def __init__(self, name: str, spec: dict):
        self.name = name
        self.kind = spec.get("kind", "box")
        self.size = float(spec.get("size", 0.6))
        self.h = float(spec.get("h", self.size if self.kind == "box" else self.size))
        self.color = list(spec.get("color", [210, 160, 90] if self.kind == "box" else [240, 90, 80]))
        self.x = float(spec.get("x", 0.0))
        self.z = float(spec.get("z", 0.0))
        self.keys: List[list] = [[0.0, self.x, self.z]]
        self.attach: List[list] = []
        self.arc = 0.0

    def hold(self, t0: float, who: str, d: int) -> None:
        self.attach.append([_r(t0), 1e9, who, d * 0.12, -self.h * 0.55])

    def release(self, t1: float, x: float, z: float) -> None:
        if self.attach and self.attach[-1][1] == 1e9:
            self.attach[-1][1] = _r(t1)
        self.keys.append([_r(t1), _r(x), _r(z)])
        self.x, self.z = x, z

    def move(self, t0: float, t1: float, x1: float, z1: float = 0.0, arc: float = 0.0) -> None:
        self.keys.append([_r(t0), _r(self.x), _r(self.z)])
        self.keys.append([_r(t1), _r(x1), _r(z1)])
        self.arc = max(self.arc, arc)
        self.x, self.z = x1, z1

    def out(self) -> dict:
        ks = sorted(self.keys, key=lambda k: k[0])
        return dict(name=self.name, kind=self.kind, size=self.size, h=self.h, color=self.color, keys=ks, attach=self.attach, arc=self.arc)


def build_skit(spec: dict) -> dict:
    actors = {n: _Actor(n, a or {}) for n, a in (spec.get("actors") or {"A": {}}).items()}
    props = {n: _Prop(n, p or {}) for n, p in (spec.get("props") or {}).items()}
    hits: List[dict] = []
    puffs: List[dict] = []
    shots: List[dict] = [dict(t=0.0, follow="mid", scale=WIDE, yaw=-6.0, pitch=4.0, lens=40.0, target_z=1.0, lag=0.5)]
    flashes: List[float] = []
    for a in actors.values():
        a.key(0.0, IDLE)
    cursor = 0.0                              # 直前の動作の終わり(次の動作の既定の開始)
    last_start = 0.0

    def hand_xz(a: _Actor) -> tuple:
        return a.x + a.dir * 0.45, 1.05

    def face_to(a: _Actor, x: float, t: float) -> None:
        d = 1 if x >= a.x else -1
        if d != a.dir:
            a.dir = d
            a.key(t, {})                      # 向きの切り替え(絵だけ反転。1 コマで変わる)

    def closeup(a: _Actor, t0: float, t1: float) -> None:
        shots.append(dict(t=_r(t0), follow=a.name, scale=CLOSE, yaw=(14.0 if a.dir > 0 else -14.0), pitch=3.0, lens=36.0, target_z=1.05, lag=0.0))
        shots.append(dict(t=_r(t1), follow="mid", scale=WIDE, yaw=-6.0, pitch=4.0, lens=40.0, target_z=1.0, lag=0.5))

    for b in spec.get("beats") or []:
        act = b["act"]
        if "t" in b:
            t = float(b["t"])
        elif b.get("at") == "with":
            t = last_start
        else:
            t = cursor
        last_start = t
        if act == "wait":
            cursor = t + float(b.get("dur", 0.5))
            continue
        a = actors[b.get("who", "A")]
        t = max(t, a.free)
        dur = float(b.get("dur", 0.0) or 0.0)
        end = t
        if act in ("walk", "run", "carry"):
            to = float(b["to"])
            dist = abs(to - a.x)
            face_to(a, to, t)
            speed = RUN_SPEED if act == "run" else WALK_SPEED
            dur = dur or max(0.25, dist / speed)
            if act == "run":
                a.key(t, dict(IDLE, lean=0.3, hz=0.8))
                a.key(t + 0.1, dict(run=1.0, lean=0.25))
                a.key(t + dur - 0.1, dict(run=1.0, lean=0.25), x=to - a.dir * 0.15)
                a.key(t + dur, dict(IDLE, lean=0.1, hz=0.82), x=to)         # 止まる(踏ん張り)
                puffs.append(dict(tau=_r(t + dur), kind="land2", pos=[_r(to), 0.0]))
                a.key(t + dur + 0.15, IDLE)
                end = t + dur + 0.15
            else:
                base = CARRY if act == "carry" else dict(IDLE, lean=0.08)
                n = max(1, int(dur / 0.32))
                x0 = a.x
                for i in range(n + 1):
                    tt = t + dur * i / n
                    swing = (0.0 if act == "carry" else (0.55 if i % 2 == 0 else -0.35))     # 腕を交互に振る(脚は footwork が運ぶ)
                    a.key(tt, dict(base, fa=base["fa"] + swing, ra=base["ra"] - swing), x=x0 + (to - x0) * i / n)
                a.key(t + dur + 0.1, dict(base, fa=base["fa"], ra=base["ra"]))
                end = t + dur + 0.1
        elif act in ("turn", "face", "look"):
            if "dir" in b:
                a.dir = int(b["dir"])
                a.key(t, {})
            else:
                tx = float(b["to"]) if "to" in b else (actors[b["at"]].x if b.get("at") in actors else props[b["at"]].x)
                face_to(a, tx, t)
                if act == "look":
                    a.key(t + 0.12, dict(ht=0.25 if tx > a.x + 2 else 0.0))
            end = t + (dur or 0.25)
        elif act == "jump":
            h = float(b.get("h", 0.8))
            dur = dur or 0.6
            to = float(b.get("to", a.x))
            a.key(t, dict(IDLE, hz=0.7, lean=0.25, fl=0.8, fk=1.3, rl=-0.3, rk=1.0))
            a.key(t + 0.1, dict(IDLE, hz=0.92, rz=0.15, lean=-0.05, fa=2.2, fe=0.3, ra=2.0, re=0.3))
            a.key(t + 0.1 + dur * 0.45, dict(rz=h, fl=0.9, fk=1.4, rl=0.3, rk=1.2), x=(a.x + to) / 2)
            a.key(t + 0.1 + dur * 0.9, dict(IDLE, rz=0.0, hz=0.72, lean=0.3, fl=0.8, fk=1.3, rl=-0.3, rk=1.0), x=to)
            puffs.append(dict(tau=_r(t + 0.1 + dur * 0.9), kind="land2", pos=[_r(to), 0.0]))
            a.key(t + 0.3 + dur, IDLE)
            end = t + 0.3 + dur
        elif act == "pickup":
            p = props[b["prop"]]
            face_to(a, p.x, t)
            stand_x = p.x - a.dir * ARM_REACH
            if abs(stand_x - a.x) > 0.15:                                      # 届かなければ寄る
                dist = abs(stand_x - a.x)
                a.key(t + dist / WALK_SPEED, dict(IDLE, lean=0.08), x=stand_x)
                t += dist / WALK_SPEED
            a.key(t + 0.3, CROUCH)
            a.key(t + 0.42, CROUCH)
            p.hold(t + 0.42, a.name, a.dir)
            a.holding = p.name
            a.key(t + 0.75, CARRY)
            end = t + 0.85
        elif act == "put":
            p = props[b["prop"]]
            on = props.get(b.get("on")) if b.get("on") else None
            tx = float(b["at"]) if "at" in b else (on.x if on else a.x + a.dir * ARM_REACH)
            tz = (on.z + on.h) if on else 0.0
            if on is not None:
                stand_x = on.x - a.dir * ARM_REACH
                if abs(stand_x - a.x) > 0.15:
                    dist = abs(stand_x - a.x)
                    a.key(t + dist / WALK_SPEED, CARRY, x=stand_x)
                    t += dist / WALK_SPEED
            pose = dict(CROUCH) if tz < 0.4 else dict(CARRY, fa=1.1, fe=0.6, ra=1.05, re=0.65, lean=0.2)
            a.key(t + 0.3, pose)
            p.release(t + 0.35, tx, tz)
            a.holding = None
            a.key(t + 0.45, pose)
            a.key(t + 0.8, IDLE)
            end = t + 0.9
        elif act == "throw":
            p = props[b["prop"]]
            to = float(b["to"])
            face_to(a, to, t)
            if a.holding != p.name:                                             # 持っていなければ拾う所から
                stand_x = p.x - a.dir * ARM_REACH
                dist = abs(stand_x - a.x)
                a.key(t + max(0.05, dist / WALK_SPEED), dict(IDLE, lean=0.08), x=stand_x)
                t += max(0.05, dist / WALK_SPEED)
                a.key(t + 0.3, CROUCH)
                p.hold(t + 0.4, a.name, a.dir)
                a.key(t + 0.65, CARRY)
                t += 0.65
            a.key(t + 0.25, WINDUP)
            a.key(t + 0.33, dict(WINDUP, fa=-0.9, lean=-0.25))
            t_rel = t + 0.4
            a.key(t_rel, RELEASE, x=a.x + a.dir * 0.12)
            hx, hz = hand_xz(a)
            flight = max(0.35, abs(to - hx) / 7.0)
            p.release(t_rel, hx, hz)
            p.move(t_rel, t_rel + flight, to, 0.0, arc=0.9)
            a.holding = None
            hits.append(dict(tau=_r(t_rel), hold=0.0, kind="throw", pos=[_r(hx), _r(hz)]))
            t_land = t_rel + flight
            if b.get("hit") in actors:
                v = actors[b["hit"]]
                hits.append(dict(tau=_r(t_land), hold=0.06, kind="hit", pos=[_r(to), 1.3]))
                flashes.append(_r(t_land))
                v.key(t_land - 0.02, {})
                v.key(t_land + 0.05, dict(SURPRISE, lean=-0.6, ht=-0.7), x=v.x - (1 if to >= v.x - 0.01 and a.x < v.x else -1) * 0.2)
                v.key(t_land + 0.35, dict(SURPRISE, lean=-0.3))
                v.free = t_land + 0.4
                if p.kind == "ball":
                    p.move(t_land, t_land + 0.4, to - a.dir * 0.8, 0.0, arc=0.35)   # 玉は跳ね返る
                else:
                    p.move(t_land, t_land + 0.3, to - a.dir * 0.7, 0.0, arc=0.3)    # 箱は相手の手前に落ちる(相手は後ろへ倒れるので重ならない)
            else:
                puffs.append(dict(tau=_r(t_land), kind="land2", pos=[_r(to), 0.0]))
            a.key(t_rel + 0.3, dict(RELEASE, lean=0.25))
            a.key(t_rel + 0.7, IDLE)
            end = t_rel + 0.75
        elif act == "push":
            p = props[b["prop"]]
            to = float(b["to"])
            face_to(a, to, t)
            stand_x = p.x - a.dir * (p.size / 2 + 0.35)
            dist = abs(stand_x - a.x)
            if dist > 0.15:
                a.key(t + dist / WALK_SPEED, dict(IDLE, lean=0.08), x=stand_x)
                t += dist / WALK_SPEED
            a.key(t + 0.3, PUSH)
            dur = dur or max(0.6, abs(to - p.x) / 1.2)
            p.move(t + 0.3, t + 0.3 + dur, to, p.z)
            a.key(t + 0.3 + dur, PUSH, x=to - a.dir * (p.size / 2 + 0.35))
            a.key(t + 0.6 + dur, IDLE)
            end = t + 0.7 + dur
        elif act == "kick":
            p = props[b["prop"]]
            to = float(b["to"])
            face_to(a, to, t)
            stand_x = p.x - a.dir * 0.75
            dist = abs(stand_x - a.x)
            if dist > 0.15:
                a.key(t + max(0.1, dist / RUN_SPEED), dict(IDLE, lean=0.2), x=stand_x)
                t += max(0.1, dist / RUN_SPEED)
            a.key(t + 0.15, dict(IDLE, fl=-0.6, fk=0.9, lean=0.1, hz=0.84))           # 引く
            a.key(t + 0.25, dict(IDLE, fl=1.5, fk=0.1, lean=-0.1, hz=0.86, fa=-0.3, ra=1.0))   # 蹴り抜く
            flight = max(0.3, abs(to - p.x) / 8.0)
            p.move(t + 0.25, t + 0.25 + flight, to, 0.0, arc=0.8)
            hits.append(dict(tau=_r(t + 0.25), hold=0.03, kind="kick", pos=[_r(p.x), 0.4]))
            puffs.append(dict(tau=_r(t + 0.25 + flight), kind="land2", pos=[_r(to), 0.0]))
            a.key(t + 0.6, IDLE)
            end = t + 0.7
        elif act == "surprised":
            dur = dur or 0.9
            a.key(t, {})
            a.key(t + 0.08, dict(SURPRISE, rz=0.22), x=a.x - a.dir * 0.2)
            a.key(t + 0.2, dict(SURPRISE, rz=0.0, hz=0.86))
            puffs.append(dict(tau=_r(t + 0.2), kind="land2", pos=[_r(a.x), 0.0]))
            a.key(t + dur, SURPRISE)
            a.key(t + dur + 0.25, IDLE)
            closeup(a, t, t + dur + 0.25)
            end = t + dur + 0.25
        elif act == "laugh":
            dur = dur or 1.4
            n = int(dur / 0.16)
            for i in range(n + 1):
                a.key(t + 0.16 * i, dict(LAUGH, hz=0.84 + (0.03 if i % 2 else -0.02), lean=-0.22 + (0.06 if i % 2 else 0.0)))
            a.key(t + dur + 0.3, IDLE)
            closeup(a, t, t + dur + 0.3)
            end = t + dur + 0.3
        elif act == "angry":
            dur = dur or 1.2
            n = int(dur / 0.3)
            for i in range(n + 1):
                a.key(t + 0.3 * i, dict(ANGRY, hz=0.78 if i % 2 else 0.86, fl=0.6 if i % 2 else 0.12, fk=0.9 if i % 2 else 0.1))
                if i % 2:
                    puffs.append(dict(tau=_r(t + 0.3 * i), kind="land2", pos=[_r(a.x), 0.0]))
            a.key(t + dur + 0.3, IDLE)
            closeup(a, t, t + dur + 0.3)
            end = t + dur + 0.3
        elif act == "fall":
            dur = dur or 0.9
            back = b.get("back", True)
            sgn = 1.0 if back else -1.0
            a.key(t, {})
            a.key(t + 0.12, dict(IDLE, lean=-0.3 * sgn, hz=0.84, fa=2.2, fe=0.4, ra=2.0, re=0.4), x=a.x - a.dir * (0.15 if back else -0.15))
            a.key(t + 0.3, dict(IDLE, roll=1.1 * sgn, rz=0.35, hz=0.9, fa=1.5, fe=0.3, ra=1.4, re=0.3, fl=0.6, fk=0.5, rl=-0.2, rk=0.4), x=a.x - a.dir * (0.3 if back else -0.3))
            a.key(t + 0.42, dict(roll=1.57 * sgn, rz=0.21, hz=0.9, fa=0.4, fe=0.3, ra=0.4, re=0.3, fl=0.0, fk=0.0, rl=0.0, rk=0.0), x=a.x - a.dir * (0.2 if back else -0.2))
            puffs.append(dict(tau=_r(t + 0.42), kind="land2", pos=[_r(a.x), 0.0]))
            hits.append(dict(tau=_r(t + 0.42), hold=0.04, kind="land", pos=[_r(a.x), 0.2]))
            a.key(t + dur, dict(roll=1.57 * sgn, rz=0.21))
            closeup(a, t, t + dur)
            end = t + dur
        elif act == "getup":
            dur = dur or 0.8
            roll0 = a.pose.get("roll", 1.57)
            a.key(t, {})
            a.key(t + dur * 0.3, dict(roll=roll0 * 0.7, rz=0.45, hz=0.7, lean=0.2, fa=1.0, fe=0.5, ra=0.9, re=0.6, fl=0.9, fk=1.5, rl=-0.2, rk=1.0))   # 起き上がりは根元を上げながら回す(rz 0.1 のまま回すと体が地面に 0.25 潜った)
            a.key(t + dur * 0.6, dict(roll=roll0 * 0.3, rz=0.25, hz=0.62, lean=0.4, fa=1.0, fe=0.5, ra=0.9, re=0.6, fl=0.9, fk=1.5, rl=-0.2, rk=1.0))
            a.key(t + dur, IDLE)
            end = t + dur + 0.1
        elif act in ("point", "think", "cheer", "cry", "sit", "stand"):
            dur = dur or 1.0
            pose = dict(point=POINT, think=THINK, cheer=CHEER, cry=SAD, sit=SIT, stand=IDLE)[act]
            if act == "point" and ("at" in b or "to" in b):
                tx = float(b["to"]) if "to" in b else (actors[b["at"]].x if b["at"] in actors else props[b["at"]].x)
                face_to(a, tx, t)
            a.key(t + 0.2, pose)
            if act == "cheer":
                for i in range(int(dur / 0.25)):
                    a.key(t + 0.2 + 0.25 * i, dict(pose, rz=0.25 if i % 2 else 0.0, hz=0.9))
            elif act == "cry":
                for i in range(int(dur / 0.2)):
                    a.key(t + 0.2 + 0.2 * i, dict(pose, lean=0.3 + (0.05 if i % 2 else 0.0)))
            a.key(t + dur, pose)
            if act not in ("sit",):
                a.key(t + dur + 0.25, IDLE)
            if act in CLOSEUP_ACTS:
                closeup(a, t, t + dur + 0.25)
            end = t + dur + 0.25
        elif act in ("wave", "nod", "shake"):
            dur = dur or 1.0
            n = max(2, int(dur / 0.25))
            for i in range(n + 1):
                if act == "wave":
                    a.key(t + 0.25 * i, WAVE_A if i % 2 == 0 else WAVE_B)
                elif act == "nod":
                    a.key(t + 0.25 * i, dict(IDLE, ht=0.35 if i % 2 else 0.0))
                else:
                    a.key(t + 0.25 * i, dict(IDLE, ht=0.3 if i % 2 else -0.3, spin=0.3 if i % 2 else -0.3))
            a.key(t + dur + 0.25, IDLE)
            end = t + dur + 0.25
        else:
            raise ValueError(f"知らない動作: {act}")
        a.free = end
        if b.get("at") != "with":
            cursor = max(cursor, end)
        else:
            cursor = max(cursor, end)
    end_all = max([a.free for a in actors.values()] + [cursor]) + 1.0
    for a in actors.values():
        a.key(end_all, {})
    xs = [a.x for a in actors.values()] + [p.x for p in props.values()]
    wall_x = round(max(xs) + 6.0, 2)
    scene = dict(
        name=spec.get("name", "skit"), fps=FPS, tau_end=_r(end_all),
        actors={n: dict(color=a.color, scale=a.scale, base_x=a.base_x, facing=1) for n, a in actors.items()},
        stage=dict(wall_x=wall_x, style="flat", theme=spec.get("stage", "field"), **(dict(image=spec["background"]["image"], image_x0=float(spec["background"].get("x0", -8.0)), image_x1=float(spec["background"].get("x1", 16.0)), ground=float(spec["background"].get("ground", 0.8))) if spec.get("background") else {})),   # background: {image, x0, x1, ground} で描いた背景を貼る
        slow=[], hits=hits, puffs=puffs,
        camera=[[0.0, -0.4, 8.4], [_r(end_all), 3.2, 8.6]],
        keys={n: sorted(a.keys, key=lambda k: k["t"]) for n, a in actors.items()},
        fx=dict(trails=[], glide=[], speed_lines=[], invert=[], flashes=sorted(set(flashes)), charge=[], color_script=[], weapon_glow=False,
                beams=[], orbs=[], projectiles=[], waves=[], afterimages=[], cuts=[], shields=[], props=[p.out() for p in props.values()]),
        clips={}, snaps=[],
        qa=dict(max_cross_frames=4000, max_stops=9999, max_anticipation_frames=999, max_jerk=9.0, max_teleport_frames=4),
        tempo=1.0, anime=dict(trails=False, sfx=True, zoom_blur=False, grade=True, roll=False, smear=True),
        shots=sorted(shots, key=lambda s: s["t"]), stepping=dict(hold=2, ones_around_hits=3, hold_camera=True),
        impact_cuts=None, flurry=[], body_drive=None, footwork={}, style="flat2d", clip_timing=None, cam_zoom=1.25,
        limb=dict(base=0.055, tip=0.03, tip_color=[0.08, 0.08, 0.1]), captions=[], audio=dict(mood=spec.get("mood", "calm")), _marks={})
    return scene


def expand(data: dict) -> dict:
    """台本の dict に skit: があれば、組んだ台本を土台にしてほかのキーで上書きする(fight.expand と同じ形)。"""
    if "skit" not in data:
        return data
    spec = dict(data["skit"] or {})
    spec.setdefault("name", data.get("name", "skit"))
    base = build_skit(spec)
    for k, v in data.items():
        if k == "skit":
            continue
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            base[k] = dict(base[k], **v)
        else:
            base[k] = v
    return base
