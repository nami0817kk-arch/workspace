"""理の書の 3D の回: 顔のない人形＋物理計算(MuJoCo)＋Blender(EEVEE)。

流れ: probe(拳の位置を測る) → sim(球の物理) → plan(コマごとの時刻・カメラ・効果) → render(Blender) → check → compose(字・音・mp4・一覧)
`python -m three all punch [--grey]`。場面の中身は three/scenes/<名前>.py の SCENE。
"""
