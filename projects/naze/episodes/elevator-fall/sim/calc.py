"""落ちていくエレベーターで跳ぶ計算。python episodes/elevator-fall/sim/calc.py > episodes/elevator-fall/sim/calc.txt

前提（台本の数字はここから）:
- 1 階 = 3 m。10 階から落ちる = 30 m の自由落下（空気・ガイドの摩擦なし）
- 人 60 kg、かご 1,000 kg、かごの天井まで 2.3 m、頭の高さ 1.7 m
- 跳ぶ: 地上の垂直跳び 50 cm、膝を伸ばす距離 0.4 m で踏み切る
- 反応時間 0.16 秒（音）
- 着地: 止まるまでの距離（立ったまま 5 cm、膝を曲げて 50 cm）
MuJoCo で、落ちているかごの中で人が床を蹴る場面を解いて、手の計算と突き合わせる。
"""
import math

import mujoco

G = 9.81
FLOOR = 3.0
M_CAR, M_MAN = 1000.0, 60.0
HEAD, CEIL = 1.7, 2.3
JUMP_H, PUSH_D = 0.50, 0.40
REACT = 0.16  # 音への単純反応（Jain ほか 2015）


def kmh(v):
    return v * 3.6


def floors_from_speed(v):
    return v * v / (2 * G) / FLOOR


v_jump = math.sqrt(2 * G * JUMP_H)
# 地上: v^2 = 2 (F/m - g) d → 脚の力 F/m
a_leg = v_jump**2 / (2 * PUSH_D) + G
# 落ちている箱の中は重さがないので g を引かない。かごも押し返されて下がるので、離れる加速は a_leg (1 + m/M)
a_rel = a_leg * (1 + M_MAN / M_CAR)
v_rel = math.sqrt(2 * a_rel * PUSH_D)
v_man = v_rel * M_CAR / (M_CAR + M_MAN)  # 人が地面に対して遅くなる分
v_car = v_rel * M_MAN / (M_CAR + M_MAN)

print("== 1. 着地の直前に跳べたとしたら ==")
print(f"地上の垂直跳び {JUMP_H*100:.0f}cm の踏み切り {v_jump:.2f} m/s。脚の力は体重の {a_leg/G:.2f} 倍")
print(f"落ちている箱の中で同じ脚の力で蹴ると、人は {v_man:.2f} m/s 遅くなる（地上より強い。重さに逆らわないから）")
print(f"  かごは押し返されて {v_car:.2f} m/s 速くなる")
for n in (5, 10, 20, 30, 75):
    h = n * FLOOR
    v = math.sqrt(2 * G * h)
    rest = v - v_man
    print(f"{n:>2}階({h:.0f}m) 床に当たる {v:.1f} m/s = {kmh(v):.0f} km/h → 跳ぶと {rest:.1f} m/s = {kmh(rest):.0f} km/h"
          f" = {floors_from_speed(rest):.1f}階から落ちたのと同じ")

print("\n== 2. 跳ぶ瞬間の窓 ==")
h = 10 * FLOOR
v = math.sqrt(2 * G * h)
t_fall = math.sqrt(2 * h / G)
t_push = math.sqrt(2 * PUSH_D / a_rel)
head_off = HEAD + 0.1  # 踏み切りの終わりはつま先立ちで頭が 10cm 上がる
gap_after = CEIL - head_off
t_ceil = gap_after / v_rel
print(f"10階の落下は {t_fall:.2f} 秒。最後の {REACT} 秒で {v*REACT - G*REACT**2/2:.2f} m 落ちる")
print(f"しゃがんだ姿勢から蹴り終わるまで {t_push:.3f} 秒")
print(f"蹴り終わってから天井まで {gap_after:.2f} m を {t_ceil:.3f} 秒（離れる速さ {v_rel:.2f} m/s）")
print(f"  蹴り終わりが床に当たる前 {t_ceil:.3f} 秒より早いと、先に頭が天井に当たり、かごと同じ速さに戻る（得は消える）")
print(f"  蹴り終わりが床に当たったあとだと、蹴りきれない")
print(f"  → 蹴り始めは床に当たる {t_push+t_ceil:.3f}〜{t_push:.3f} 秒前。窓の幅 {t_ceil:.3f} 秒 = {t_ceil*1000:.0f} ミリ秒")
print(f"  頭が天井に当たる速さ {v_rel:.1f} m/s = {kmh(v_rel):.0f} km/h（{v_rel**2/(2*G)*100:.0f}cm の高さから頭を落とすのと同じ）")
print(f"  合図は無い。反応時間 {REACT} 秒は窓の {REACT/t_ceil:.1f} 倍")
print("\n== 4. 着地（10階、30m）。止まるまでの距離で力が変わる ==")
for name, d in (("立ったまま(5cm)", 0.05), ("膝を曲げて(50cm)", 0.50)):
    a = v * v / (2 * d)
    print(f"{name}: {a/G:.0f} G、止まるまで {2*d/v*1000:.0f} ミリ秒")
print("寝そべる: 止まる距離は数 cm のまま。力を背中全体に分ける（頭と首を守る）")

print("\n== MuJoCo: 落ちているかごの中で床を蹴る ==")
XML = f"""
<mujoco><option timestep="0.0005" gravity="0 0 -{G}"/>
<worldbody>
 <body name="car" pos="0 0 0"><joint name="jc" type="slide" axis="0 0 1"/>
  <geom type="box" size="0.8 0.8 0.02" mass="{M_CAR}" contype="0" conaffinity="0"/></body>
 <body name="man" pos="0 0 0.9"><joint name="jm" type="slide" axis="0 0 1"/>
  <geom type="box" size="0.2 0.2 0.85" mass="{M_MAN}" contype="0" conaffinity="0"/></body>
</worldbody></mujoco>"""
m = mujoco.MjModel.from_xml_string(XML)
d = mujoco.MjData(m)
car, man = m.body("car").id, m.body("man").id
pushed, t0 = 0.0, None
while d.time < 1.0:
    d.xfrc_applied[:] = 0
    rel = d.qpos[1] - d.qpos[0]
    if d.time >= 0.5 and t0 is None:  # 0.5 秒落ちてから蹴る（脚の力は一定）
        t0, rel0 = d.time, rel
    if t0 is not None:
        pushed = rel - rel0
        if pushed >= PUSH_D:
            break
        f = M_MAN * a_leg
        d.xfrc_applied[man, 2] += f
        d.xfrc_applied[car, 2] -= f
    mujoco.mj_step(m, d)
vc, vm = d.qvel[0], d.qvel[1]
print(f"蹴る前の落ちる速さ {G*0.5:.2f} m/s、蹴り終わり: かご {vc:.2f} m/s 人 {vm:.2f} m/s、離れる速さ {vm-vc:.2f} m/s（手の計算 {v_rel:.2f}）")
print(f"人の遅くなった分 {vm-(-G*d.time):.2f} m/s（手の計算 {v_man:.2f}）、踏み切り {d.time-t0:.3f} 秒（手の計算 {t_push:.3f}）")

print("\n== 台本用の追加 ==")
print("[1章] 地上と同じ跳び（3.13 m/s）で、割合も")
for n in (10, 30, 75):
    h = n * FLOOR
    v = math.sqrt(2 * G * h)
    rest = v - v_jump
    print(f"  {n}階 → {floors_from_speed(rest):.1f}階（{(1-rest*rest/(v*v))*100:.0f}% 減、{n-floors_from_speed(rest):.1f}階ぶん得）")
h = 10 * FLOOR
v = math.sqrt(2 * G * h)
print(f"[2章] 消せる速さ {v_man:.2f} m/s = 時速 {kmh(v_man):.1f} km。脚の力のうち重さに取られる割合 {1/(a_leg/G)*100:.0f}%")
print(f"  地上の踏み切り {math.sqrt(2*PUSH_D/(a_leg-G)):.3f} 秒、落ちる箱の中 {t_push:.3f} 秒（脚の力は一定と仮置き）")
print(f"[3章] 蹴り始めの窓（床の {t_push+t_ceil:.3f}〜{t_push:.3f} 秒前）のあいだにかごが落ちる距離:"
      f" {(v*(t_push+t_ceil) - G*(t_push+t_ceil)**2/2) - (v*t_push - G*t_push**2/2):.2f} m")
for early in (0.10, 0.15):
    gain = a_rel * early * M_CAR / (M_CAR + M_MAN)
    print(f"  遅れて床の {early:.2f} 秒前に蹴り始めると、遅くなるのは {gain:.2f} m/s（全部なら {v_man:.2f}）")
cue = t_push + t_ceil + REACT
print(f"  反応 {REACT} 秒で窓の頭に間に合わせるには、合図は床の {cue:.2f} 秒前＝底の {v*cue - G*cue**2/2:.1f} m 上")
print(f"  反応 {REACT} 秒は窓の {REACT/t_ceil:.1f} 倍")
print(f"[4章] 跳んで脚が伸びきったまま 5cm で着く: {(v-v_man)**2/(2*0.05)/G:.0f} G（跳ばずに膝で受けると {v*v/(2*0.5)/G:.0f} G）")
print(f"  寝そべって 3cm で止まる: {v*v/(2*0.03)/G:.0f} G")
print(f"[3版] 600G を体重 {M_MAN:.0f}kg で重さに直すと {M_MAN*v*v/(2*0.05)/G/1000:.0f} トン")
for h_esb in (270, 290):
    print(f"  ESB {h_esb}m: 10階の {h_esb/30:.1f} 倍、空気なしなら底で時速 {kmh(math.sqrt(2*G*h_esb)):.0f} km")
print(f"[5章] 時速 {kmh(v):.0f} km を 1G で止めるのに要る距離 {v*v/(2*G):.0f} m。分速45m の 1.35倍（秒速{45/60*1.35:.2f}m）を 1G で止めると {(45/60*1.35)**2/(2*G)*100:.1f} cm")