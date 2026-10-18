"""clips/ にある clip を順に再生する確認用の台本(scenes/_gallery.yaml)を作る。

  python scripts/make_gallery.py run_09_01:2 135_04:3.2 ...   # 名前:秒(省略時は clip の長さ)
clip は mocap.py が作る(元の BVH は CMU のもの。clips/ はリポジトリに入れない)。
"""
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from stickfig import mocap  # noqa: E402


def main(argv):
    segs = []
    for a in argv:
        name, _, dur = a.partition(":")
        clip = mocap.Clip(mocap.load_clip(ROOT / "clips" / f"{name}.json"))
        segs.append((name, float(dur) if dur else clip.duration, clip))
    t, dx = 0.5, 0.0
    clips, cam = [], [[0.0, -3.0, 8.0]]
    for name, dur, clip in segs:
        loop = dur > clip.duration + 1e-6
        end_dx = float(clip.params["dx"][-1] - clip.params["dx"][0])
        if loop:
            end_dx *= dur / clip.duration
        else:
            end_dx = float(clip.params["dx"][min(clip.n - 1, int(dur * clip.fps))] - clip.params["dx"][0])
        clips.append(dict(file=name, start=round(t, 3), end=round(t + dur, 3), loop=loop, anchor_dx=round(dx, 3), **{"in": 0.08, "out": 0.08}))
        cam.append([round(t + dur / 2, 3), round(-3.0 + dx + end_dx / 2 + 1.0, 3), 8.0])
        t += dur + 0.2
        dx += end_dx
    scene = dict(
        name="gallery", fps=30, tau_end=round(t, 2),
        actors={"A": {"color": [0.30, 0.68, 0.10], "scale": 1.0, "base_x": -3.0, "facing": 1, "weapon": "sword"}},
        stage={}, camera=cam, clips={"A": clips}, keys={"A": [{"t": 0.0, "dx": 0.0}]})
    out = ROOT / "scenes" / "_gallery.yaml"
    out.write_text("# 自動生成(make_gallery.py)。clip の確認用\n" + yaml.safe_dump(scene, allow_unicode=True, sort_keys=False, default_flow_style=None, width=140), encoding="utf-8")
    print(out, "tau_end", scene["tau_end"])


if __name__ == "__main__":
    main(sys.argv[1:])
