"""試作: 人形が拳で球を殴る → 球が衝撃の輪と光の筋を残して飛ぶ → 遠くのマットに当たって止まる。

数字は仮(作品名は出さない)。球はドッジボール大(直径 21 cm・350 g)、打ち出しの速さは v0 で決める。
"""

SCENE = dict(
    name="punch",
    question="この拳の一撃、球は【時速何km】？",
    counter_label="球の速さ",
    # 人形: 原点に立ち、+x を向く(UAL のマネキンは -y 向きなので z まわりに 90°)
    character=dict(pos=(0.0, 0.0, 0.0), yaw_deg=90.0),
    # 動きの割り当て(動きの名前, 始まる時刻[秒], 速さ)。後ろのものが上に重なる
    clips=[("Idle_Loop", 0.0, 1.0), ("Punch_Cross", 1.5, 1.0)],
    punch=dict(clip="Punch_Cross", start=1.5, hand="r", window=0.45, contact_frac=0.82),
    ball=dict(radius=0.105, mass=0.35, v0=40.0, angle_deg=4.0, spin=(0.0, 0.0, 0.0)),
    # 止める壁(マット)。x は手前の面ではなく中心
    mat=dict(x=15.0, size=(0.40, 3.6, 2.6)),
    # 時間の流れ(1=実時間)。拳の当たる前後と飛ぶ間をスローにする
    timing=dict(pre=1.0, hit=0.05, hit_hold=0.04, fly=0.2, wall=0.12, wall_hold=0.06, after=1.0, tail=2.2, preroll=1.3),
    # カメラの切り替え(球が拳から何 m 離れたら追う、マットの何 m 手前で固定に切り替える)
    cut=dict(follow_after=0.4, fixed_before=5.0),
)
