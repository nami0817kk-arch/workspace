"""手付けの 1 カット「重い箱」(約 7.4 秒)。stickfig.keyshot で腰・足・手のトラックを書き、毎コマの IK で焼き込む。

絵コンテ:
  0.00-1.32 歩いて来る(3 歩 + 止まる 1 歩)。接地で腰が沈み、中間で上がる。腕は脚と逆に振る
  1.32-1.85 箱に気づく: 頭が箱へ下がり、一瞬のけぞる(小さな驚き)
  1.85-2.70 興味を持って 3 歩寄る(ゆっくり)
  2.70-3.10 溜め(少し伸び上がる)→ しゃがんで箱の側面をつかむ
  3.10-3.95 持ち上げようとする: 腰が少し上がり、背が反り、全身が震える。箱は動かない
  3.95-4.75 諦める: 手を離して立ち上がる(反り返って戻る)→ 手を振る → 箱を見下ろす
  4.75-5.35 決心: 後ろ足を引いて足を開き、深くしゃがんで構え直す
  5.35-5.95 力む(0.25 秒震える)→ 一気に持ち上げる。箱は胸の前へ。体は後ろへ反る
  5.95-6.70 重さで後ろへ 2 歩よろけ、前へ戻して踏ん張る。箱が重さで沈んで戻る
  6.70-7.40 抱えたまま小さく弾む(どうだ)

使い方: python tools/shots/heavy_box.py --out out/shot_heavy_box [--preview]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from stickfig import keyshot as ks  # noqa: E402

FPS = 30
T_END = 7.4
BOX = dict(size=0.62, color=[205, 150, 80])
BOX_X0 = 1.55


def tracks():
    body = [
        # 歩き(接地 0.76・中間 0.81。前傾 0.08)
        dict(t=0.00, x=-1.72, hz=0.84, lean=0.08, ht=0.0, dir=1, face="fight", ease="linear"),
        dict(t=0.18, hz=0.88), dict(t=0.36, x=-1.27, hz=0.84, ease="linear"),
        dict(t=0.54, hz=0.88), dict(t=0.72, x=-0.82, hz=0.84, ease="linear"),
        dict(t=0.90, hz=0.88), dict(t=1.08, x=-0.37, hz=0.84, ease="linear"),
        dict(t=1.32, x=-0.22, hz=0.86, lean=0.03, ease="out"),                       # 止まる(勢いが抜ける)
        # 気づく
        dict(t=1.45, ht=0.0), dict(t=1.56, ht=-0.38, ease="out"),                     # 頭が箱へ
        dict(t=1.62, hz=0.88, lean=-0.08, ease="out"), dict(t=1.85, hz=0.86, lean=0.04, ht=-0.30),
        # 寄る(ゆっくり 3 歩)
        dict(t=2.15, x=0.08, hz=0.84, lean=0.10, ease="inout"), dict(t=2.30, hz=0.87),
        dict(t=2.45, x=0.47, hz=0.84, ease="inout"), dict(t=2.58, hz=0.87),
        dict(t=2.70, x=0.90, hz=0.85, lean=0.05, ht=-0.25, ease="out"),
        # 溜め → しゃがんでつかむ
        dict(t=2.82, hz=0.88, lean=-0.02, ease="out"),
        dict(t=3.10, x=0.92, hz=0.50, lean=0.65, ht=-0.15, ease="inout"),
        # 力む(震える)
        dict(t=3.20, shake=0.0), dict(t=3.40, hz=0.55, lean=0.50, ht=0.22, shake=0.012, ease="out"),
        dict(t=3.92, hz=0.55, lean=0.50, ht=0.22, shake=0.012), dict(t=3.95, shake=0.0),
        # 諦める: 立ち上がって反り返り、戻る
        dict(t=4.20, x=0.88, hz=0.86, lean=-0.14, ht=0.10, ease="out"),
        dict(t=4.40, lean=0.03, ht=-0.05), dict(t=4.62, ht=-0.30, ease="inout"),
        # 決心: 後ろ足を引いて構える → 深くしゃがむ
        dict(t=4.75, x=0.88, hz=0.86, lean=0.03), dict(t=5.00, x=0.80, hz=0.80, lean=0.10, ht=-0.10),
        dict(t=5.35, x=0.88, hz=0.46, lean=0.70, ht=-0.10, ease="in"),
        # 力んで → 一気に持ち上げる
        dict(t=5.38, shake=0.0), dict(t=5.45, shake=0.010), dict(t=5.58, hz=0.47, lean=0.66, ht=0.18, shake=0.010), dict(t=5.62, shake=0.0),
        dict(t=5.95, x=0.80, hz=0.80, lean=-0.15, ht=0.05, ease="in"),
        # よろける → 踏ん張る
        dict(t=6.12, x=0.58, lean=-0.26, hz=0.78, ease="out"),
        dict(t=6.35, x=0.42, lean=-0.08, hz=0.76, ease="out"),
        dict(t=6.52, lean=0.08, hz=0.80, ease="out"), dict(t=6.70, lean=0.0, hz=0.82),
        # 抱えて弾む
        dict(t=6.95, hz=0.85, ht=0.12, ease="inout"), dict(t=7.20, hz=0.82, ease="inout"), dict(t=7.40, hz=0.83),
    ]
    f_foot = [
        dict(t=0.00, p=(-1.50, 0)), dict(t=0.36, p=(-1.50, 0)), dict(t=0.72, p=(-0.60, 0), lift=0.12),
        dict(t=1.08, p=(-0.60, 0)), dict(t=1.32, p=(-0.25, 0), lift=0.06),
        dict(t=1.85, p=(-0.25, 0)), dict(t=2.15, p=(0.30, 0), lift=0.08),
        dict(t=2.45, p=(0.30, 0)), dict(t=2.70, p=(1.10, 0), lift=0.08),
        dict(t=6.15, p=(1.10, 0)), dict(t=6.35, p=(0.62, 0), lift=0.05, ease="out"),
        dict(t=7.40, p=(0.62, 0)),
    ]
    r_foot = [
        dict(t=0.00, p=(-1.95, 0)), dict(t=0.36, p=(-1.05, 0), lift=0.12),
        dict(t=0.72, p=(-1.05, 0)), dict(t=1.08, p=(-0.15, 0), lift=0.12),
        dict(t=2.15, p=(-0.15, 0)), dict(t=2.45, p=(0.74, 0), lift=0.08),
        dict(t=4.75, p=(0.74, 0)), dict(t=5.00, p=(0.50, 0), lift=0.06),
        dict(t=5.95, p=(0.50, 0)), dict(t=6.12, p=(0.12, 0), lift=0.05, ease="out"),
        dict(t=7.40, p=(0.12, 0)),
    ]
    # 腕: 歩きは脚と逆に振る(前足が前 → 前の腕は後ろ)
    back, fwd = (-0.35, 0.30), (0.45, 0.55)
    hang = (0.15, 0.25)
    f_hand = [dict(t=0.00, ang=back), dict(t=0.36, ang=fwd), dict(t=0.72, ang=back), dict(t=1.08, ang=fwd), dict(t=1.32, ang=hang, ease="out"),
              dict(t=1.56, ang=hang), dict(t=1.64, ang=(0.65, 0.9), ease="out"), dict(t=1.85, ang=(0.35, 0.7)),
              dict(t=2.15, ang=fwd), dict(t=2.45, ang=back), dict(t=2.70, ang=(0.30, 0.5)), dict(t=2.85, ang=(0.10, 0.4)),
              dict(t=3.10, p=(1.34, 0.45), ease="out"), dict(t=3.95, p=(1.34, 0.45)),
              dict(t=4.12, ang=(0.45, 1.6), ease="out"),                                               # 離して手を振る
              dict(t=4.24, ang=(0.55, 2.2)), dict(t=4.32, ang=(0.40, 1.3)), dict(t=4.40, ang=(0.55, 2.2)), dict(t=4.48, ang=(0.40, 1.3)),
              dict(t=4.62, ang=hang), dict(t=4.80, ang=hang), dict(t=5.00, ang=(-0.30, 0.9)),            # 決心: 腕を引く
              dict(t=5.35, p=(1.34, 0.45), ease="in")]
    r_hand = [dict(t=0.00, ang=fwd), dict(t=0.36, ang=back), dict(t=0.72, ang=fwd), dict(t=1.08, ang=back), dict(t=1.32, ang=hang, ease="out"),
              dict(t=1.56, ang=hang), dict(t=1.64, ang=(0.55, 0.8), ease="out"), dict(t=1.85, ang=(0.30, 0.6)),
              dict(t=2.15, ang=back), dict(t=2.45, ang=fwd), dict(t=2.70, ang=(0.20, 0.5)), dict(t=2.85, ang=(0.05, 0.4)),
              dict(t=3.10, p=(1.46, 0.38), ease="out"), dict(t=3.95, p=(1.46, 0.38)),
              dict(t=4.12, ang=(0.35, 1.5), ease="out"),
              dict(t=4.24, ang=(0.45, 0.9)), dict(t=4.32, ang=(0.30, 2.0)), dict(t=4.40, ang=(0.45, 0.9)), dict(t=4.48, ang=(0.30, 2.0)),
              dict(t=4.62, ang=hang), dict(t=4.80, ang=hang), dict(t=5.00, ang=(-0.40, 0.8)),
              dict(t=5.35, p=(1.46, 0.38), ease="in")]
    # 箱: 5.62 まで床、5.95 で胸の前、よろけに合わせて動き、重さで沈んで戻る
    prop = [dict(t=0.0, x=BOX_X0, z=0.0), dict(t=3.20, x=BOX_X0, z=0.0), dict(t=3.40, x=BOX_X0, z=0.0, shake=0.004), dict(t=3.92, x=BOX_X0, z=0.0, shake=0.004),
            dict(t=3.95, x=BOX_X0, z=0.0), dict(t=5.62, x=BOX_X0, z=0.0),
            dict(t=5.95, x=1.20, z=0.55, ease="in"), dict(t=6.12, x=0.96, z=0.52, ease="out"), dict(t=6.35, x=0.82, z=0.48, ease="out"),
            dict(t=6.52, x=0.84, z=0.56, ease="out"), dict(t=6.70, x=0.82, z=0.54), dict(t=6.95, x=0.82, z=0.57), dict(t=7.20, x=0.82, z=0.54), dict(t=7.40, x=0.82, z=0.55)]
    # 持っている間の手は箱に付ける(箱のキーと同じ時刻・同じ緩急)
    off_f, off_r = (-0.18, 0.37), (-0.10, 0.31)
    for k in prop:
        if k["t"] >= 5.95 - 1e-6:
            f_hand.append(dict(t=k["t"], p=(k["x"] + off_f[0], k["z"] + off_f[1]), ease=k.get("ease", "inout")))
            r_hand.append(dict(t=k["t"], p=(k["x"] + off_r[0], k["z"] + off_r[1]), ease=k.get("ease", "inout")))
    f_hand.insert(len(f_hand) - len([k for k in prop if k["t"] >= 5.95 - 1e-6]), dict(t=5.62, p=(1.34, 0.45)))
    r_hand.insert(len(r_hand) - len([k for k in prop if k["t"] >= 5.95 - 1e-6]), dict(t=5.62, p=(1.46, 0.38)))
    return dict(body=body, f_foot=f_foot, r_foot=r_foot, f_hand=f_hand, r_hand=r_hand), prop


def build_scene():
    from stickfig import skit
    base = skit.build_skit(dict(name="shot_heavy_box", stage="field", mood="calm",
                                background=dict(image="assets/bg/meadow.png", x0=-7.0, x1=15.0, ground=0.69),
                                actors=dict(A=dict(color=[0.5, 0.85, 0.3], x=0.0)), props={}, beats=[dict(act="wait", dur=T_END)]))
    tr, prop = tracks()
    rep = []
    actor = dict(base["actors"]["A"], springs=False, plant=False)
    keys = ks.bake(tr, actor, FPS, T_END, report=rep)
    base["actors"]["A"] = actor
    base["keys"] = dict(A=keys)
    base["tau_end"] = T_END
    base["footwork"] = None
    base["fx"]["props"] = [dict(name="box", kind="box", size=BOX["size"], h=BOX["size"], color=BOX["color"], keys=ks.bake_prop(prop, FPS, T_END), attach=[], arc=0.0)]
    base["hits"] = [dict(tau=3.10, hold=0.0, kind="grab", pos=[1.45, 0.4]), dict(tau=5.35, hold=0.0, kind="grab", pos=[1.45, 0.4]),
                    dict(tau=6.12, hold=0.0, kind="land", pos=[0.12, 0.0]), dict(tau=6.35, hold=0.03, kind="land", pos=[0.62, 0.0])]
    base["puffs"] = [dict(tau=6.12, kind="land2", pos=[0.12, 0.0]), dict(tau=6.35, kind="land2", pos=[0.62, 0.0])]
    base["shots"] = [dict(t=0.0, follow="A", scale=3.6, yaw=-6.0, pitch=3.0, lens=40.0, target_z=0.9, lag=0.25),
                     dict(t=3.05, follow="A", scale=2.3, yaw=20.0, pitch=2.0, lens=36.0, target_z=0.6, lag=0.0),      # 力む: 寄り
                     dict(t=4.15, follow="A", scale=3.1, yaw=-4.0, pitch=3.0, lens=40.0, target_z=0.85, lag=0.2),
                     dict(t=5.50, follow="A", scale=2.7, yaw=-16.0, pitch=-3.0, lens=34.0, target_z=0.75, lag=0.0),   # 持ち上げ: 下から
                     dict(t=6.08, follow="A", scale=3.6, yaw=-5.0, pitch=3.0, lens=40.0, target_z=0.85, lag=0.3)]
    base["name"] = "shot_heavy_box"
    return base, rep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="out/shot_heavy_box")
    ap.add_argument("--preview", action="store_true")
    a = ap.parse_args()
    from stickfig import cli
    sc, rep = build_scene()
    print("IK の残差:", rep[:12])
    out = Path(a.out)
    if a.preview:
        from stickfig import preview
        print(preview.preview_scene(sc, out / "preview.mp4", cli.find_ffmpeg()))
    else:
        print(cli.build_scene(sc, out))


if __name__ == "__main__":
    main()
