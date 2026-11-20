"""3D の回(人形＋物理)の置き場所と既定の設定。素材のパスはここだけに書く。

素材は git の外(C:/Users/なみ/dev/assets3d、出どころは同じ場所の SOURCES.md)。
NAZE_ASSETS3D で置き場所を変えられる。
"""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]          # projects/naze
OUT = ROOT / "out" / "three"                        # 書き出し(gitignore 済みの out/ の下)
ASSETS = Path(os.environ.get("NAZE_ASSETS3D", r"C:\Users\なみ\dev\assets3d"))

ASSET = dict(
    # Quaternius Universal Animation Library [Standard] (CC0)。顔のないマネキン1体＋動き43本
    mannequin=ASSETS / "quaternius" / "ual_standard" / "Universal Animation Library[Standard]" / "Unreal-Godot" / "UAL1_Standard.glb",
    # Poly Haven Kloofendal 43d Clear (Pure Sky) 2k (CC0)
    sky=ASSETS / "polyhaven" / "kloofendal_43d_clear_puresky_2k.hdr",
)

BLENDER = os.environ.get("NAZE_BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
FPS = 30
SIZE = (1920, 1080)
ANIM_FPS = 24          # UAL の動きは 24 コマ/秒で作られている

# 見た目(単色。特定の作品の人物を思わせない)
LOOK = dict(
    body=(0.62, 0.66, 0.74),        # 人形: 薄い青みの灰
    ball=(0.86, 0.18, 0.10),        # 球: 赤
    ball_band=(0.95, 0.95, 0.92),
    mat=(0.12, 0.32, 0.78),         # 止める壁(マット): 青
    ground=((0.88, 0.88, 0.86), (0.70, 0.72, 0.73)),  # 白っぽい床の市松(1 m)。追う場面で流れが見える濃さ
    fx=(1.0, 0.93, 0.70),           # 衝撃の輪・光の筋
    sun_dir=(0.35, -1.0),           # 日差しの来る向き(水平。-y が追うカメラの側)
    exposure=-0.25,
)
