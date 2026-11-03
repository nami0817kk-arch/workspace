"""試作: 人形が拳で球を打つ → 球が衝撃の輪と光の筋を残して飛ぶ → 先のマットに当たって止まる → 答え。

打ち出しの速さは拳と球の衝突を MuJoCo で解いて決める(physics.punch_launch)。
拳: 五輪ボクサー7人のストレートの平均 秒速9.14m・有効質量2.9kg(Walilko, Viano, Bir 2005, Br J Sports Med 39(10):710-719)。
はね返りの強さ e: ドッジボールの実測が無いので 0.5〜0.8 の真ん中 0.65(episodes/gon-dodge/research.md 3-3 と同じ置き方)。
球: ドッジボール大(直径21cm・330g。モルテン D3C5000-L 相当)。→ 秒速13.5m=時速49km(式 v=(1+e)MV/(M+m) と一致)。
"""

SCENE = dict(
    name="punch",
    question="五輪ボクサーの拳で打つと、球は【時速何km】？",
    counter_label="球の速さ",
    answer=dict(head="答え", note="五輪ボクサーの平均の拳(秒速9.14m・有効質量2.9kg)で打った場合"),
    # 人形: 原点に立ち、+x を向く(UAL のマネキンは -y 向きなので z まわりに 90°)
    character=dict(pos=(0.0, 0.0, 0.0), yaw_deg=90.0),
    # 動きの割り当て(動きの名前, 始まる時刻[秒], 速さ)。後ろのものが上に重なる
    clips=[("Idle_Loop", 0.0, 1.0), ("Punch_Cross", 1.5, 1.0)],
    punch=dict(clip="Punch_Cross", start=1.5, hand="r", window=0.45, contact_frac=0.82,
               fist_speed=9.14, eff_mass=2.9, e=0.65),
    # 少し下を打つので逆回転(-y まわり)。帯の模様が回って見える
    ball=dict(radius=0.105, mass=0.33, angle_deg=5.0, spin=(0.0, -25.0, 0.0)),
    # 止める壁(マット)。x は手前の面ではなく中心。柔らかさは physics の XML
    mat=dict(x=6.0, size=(0.40, 2.4, 2.0)),
    # 床の距離の目盛り(拳の当たった所から。細い線は minor m ごと、太い線と字は major m ごと)
    marks=dict(minor=1.0, major=5.0, label_every=1.0),
    # 時間の流れ(1=実時間)。拳の当たる前後と飛ぶ間をスローにする。tail は止まってからの秒数、answer は答えの画面の秒数
    timing=dict(pre=1.0, hit=0.05, hit_hold=0.03, fly=0.25, wall=0.12, wall_hold=0.05, after=1.0, tail=1.5, preroll=1.3, answer=2.2),
    # カメラの切り替え(球が拳から何 m 離れたら追う、マットの何 m 手前で固定に切り替える)。止まったら寄りに切り替える
    cut=dict(follow_after=0.3, fixed_before=2.2),
)
