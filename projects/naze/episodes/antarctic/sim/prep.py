"""下地(高さ・衛星写真)と、海につながる高さを先に 1 つずつ作って cache に置く(並べて作ると落ちるため)。python episodes/antarctic/sim/prep.py"""
import os
import sys
import time
from pathlib import Path

os.environ.setdefault("NAZE_ASPECT", "landscape")
HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import scene  # noqa: E402

for b in scene.MAP.bases:
    t = time.time()
    scene.MAP._fill(b)
    print(b.bbox, b.z, b.e.shape, f"{time.time() - t:.0f}s", flush=True)
scene.polar_maps(900)
print("polar ok")
