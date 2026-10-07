# -*- coding: utf-8 -*-
"""試作30秒ぶんの画面を作る（節02「一の断面」の冒頭）。

図（板）を背景の上に置いて 1920x1080 にする。字幕は動画を作るときに焼くので、
下 300px は空けておく。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image

from danmen import charts5, charts6, screens, sequence, talk, texture

ASSETS = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets")
OUT = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/screens")
PHOTO = str(ASSETS / "photos" / "pexels_18569250_A_contemporary_gas_station_wit.jpeg")

W, H = 1920, 1080
SAFE_BOTTOM = 250            # 字幕のために空ける


def place(panel: Image.Image, bg: Image.Image, width: int = 1430,
          align: str = "left") -> Image.Image:
    """板を背景の上に、**字幕と立ち絵の場所を避けて**置く。

    立ち絵は右下に常に出る（`cast: auto`）ので、板は左に寄せて幅を抑える。
    中央に置いて画面いっぱいに広げると、板の右下（出典）が立ち絵に隠れた
    （2026-10-08）。
    """
    out = bg.copy()
    # 立ち絵（右下）と字幕（下）の場所を空けるため、板は上に寄せる
    room_h = H - SAFE_BOTTOM - 110
    s = min(width / panel.width, room_h / panel.height, 1.0)
    p = panel.resize((int(panel.width * s), int(panel.height * s)), Image.LANCZOS)
    x = 40 if align == "left" else (W - p.width) // 2
    out.alpha_composite(p.convert("RGBA"), (x, 10 + (room_h - p.height) // 2))
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    bg = screens.backdrop(PHOTO, dark=0.34, blur=10).convert("RGBA")

    frames: list[Image.Image] = []

    # ① この節の数字（4枚）
    stats = dict(title="この節の数字", items=[
        {"icon": "pump", "value": "175円", "label": "レギュラー1リットル", "focus": True},
        {"icon": "money", "value": "70.6円", "label": "うち税金"},
        {"icon": "car", "value": "4万円", "label": "1台あたり年に払う税"},
        {"icon": "parliament", "value": "1974年", "label": "上乗せ分が始まった年"},
    ], credit="資源エネルギー庁・財務省の資料をもとに作成")
    frames += sequence.grow(charts6.icon_stats, stats)

    # ② レシート（6枚。1行ずつ増える）
    receipt = dict(title="ガソリン1リットルの中身", items=[
        {"label": "ガソリン本体", "value": "92円"},
        {"label": "ガソリン税（本則）", "value": "28.7円", "strong": True},
        {"label": "ガソリン税（上乗せ分）", "value": "25.1円", "strong": True},
        {"label": "石油石炭税", "value": "2.8円", "strong": True},
        {"label": "消費税", "value": "14.4円", "strong": True},
        {"label": "流通・利益", "value": "12円"},
    ], total_label="店頭価格", total_value="175円",
       credit="資源エネルギー庁の週次調査をもとに試算")
    grown = sequence.grow(charts5.receipt, receipt)
    frames += grown

    # ③ 書き込みが1つずつ増える（3枚）
    full = texture.finish(grown[-1].convert("RGB"), "panel")
    # 書き込みの座標は、板から計算で出す（手で書くと板の大きさを変えたときにずれる）
    lab = charts5.row_box(2, "label")        # 「ガソリン税（上乗せ分）」の行
    val = charts5.row_box(2, "value")
    marks = [
        {"kind": "highlight", "box": [lab[0] - 10, lab[1] + 6, lab[0] + 620, lab[3] - 4]},
        {"kind": "circle", "box": [val[0] + 10, val[1], val[2], val[3]], "seed": 3},
        {"kind": "arrow", "from": [val[0] - 340, val[1] - 96],
         "to": [val[0] + 30, val[1] + 24], "text": "2年だけの約束",
         "bend": -0.24, "seed": 5},
    ]
    marked = sequence.reveal(full, marks, keep_first=False)
    frames += marked

    # 板を背景に置いて書き出す
    for i, panel in enumerate(frames, 1):
        im = place(texture.finish(panel.convert("RGB"), "panel").convert("RGBA"), bg)
        texture.finish(im.convert("RGB"), "screen").save(OUT / "s{:02d}.png".format(i))

    # ④ 聞き手が割り込むときの画面。**立ち絵は入れない**。
    #    口を動かすために、立ち絵は動画を作るときに重ねる（danmen/movie.py）。
    #    ここでは板を縮めて左に寄せ、右に立ち絵の場所を空けるだけ。
    base = place(marked[-1].convert("RGBA"), bg)
    texture.finish(base.convert("RGB"), "screen").save(
        OUT / "s{:02d}.png".format(len(frames) + 1))

    print("画面 {} 枚を書き出しました: {}".format(len(frames) + 1, OUT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
