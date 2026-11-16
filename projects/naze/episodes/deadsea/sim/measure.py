"""死海の水面と昔の岸を、標高データ(Terrain Tiles。死海のあたりは SRTM、2000 年 2 月の撮影)から自分で測る。
SRTM の水面は平らに写るので、いちばん低い平らな高さが 2000 年の水面。その上の等高線は、干上がった昔の湖の底。
1978 年ごろの岸: 環境保護省(2018)「40 年で 30m 下がった」と Vey ほか(2021)の 2018 年 -433m から、-403m の等高線とした。
出力: shores.json(名前 → 点の列のリスト)と、面積。"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402

BOX = (35.25, 30.95, 35.7, 31.85)
Z = 12
PPD = 256 * 2 ** Z / 360


def rings(mask):
    cs, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    out = []
    for c in cs:
        if cv2.contourArea(c) < 400:
            continue
        c = cv2.approxPolyDP(c, 1.0, True)[:, 0, :]
        out.append([(round(BOX[0] + x / PPD, 5), round(BOX[3] - y / PPD, 5)) for x, y in c])
    return out


def main():
    e = worldmap.heights(BOX, Z, PPD).astype(np.float32)
    kx = np.cos(np.radians(31.4))
    px_km2 = (111.32 / PPD) ** 2 * kx
    lo = float(np.nanpercentile(e, 1))
    vals, cnt = np.unique(np.round(e[e < -380]), return_counts=True)
    surf = float(vals[np.argmax(cnt)])                      # いちばん多い高さ = 平らな水面
    print("格子", e.shape, "1%点", lo, "水面とみた高さ", surf, "その画素数", int(cnt.max()))
    north = (np.arange(e.shape[0])[:, None] < (BOX[3] - 31.2) * PPD)   # 北の湖(リサン半島より北)
    res, area = {}, {}
    for name, lv in (("2000", surf + 0.6), ("1978", -403.0)):
        m = (e < lv) & north
        n, lab, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), 4)
        big = np.argmax(st[1:, cv2.CC_STAT_AREA]) + 1
        m = lab == big
        res[name], area[name] = rings(m), round(float(m.sum() * px_km2))
        print(name, lv, "北の湖の面積 約", area[name], "km2")
    # 岸の坂: エンゲディの沖へ東西に切って、水位 1m あたり岸が何 m 動くか(2000 年の水面から -403m まで)
    y = int((BOX[3] - 31.46) * PPD)
    row = e[y]
    xs = [i for i in range(len(row)) if surf + 0.6 <= row[i] <= -403]
    if xs:
        w_m = (max(xs) - min(xs)) / PPD * 111320 * kx
        print("エンゲディの沖: -403m から水面まで 岸の幅", round(w_m), "m / 高さ", round(-403 - surf, 1), "m → 1m あたり", round(w_m / (-403 - surf)), "m")
    (Path(__file__).parent / "shores.json").write_text(json.dumps(dict(surface2000=surf, area=area, shores=res)), encoding="utf-8")


if __name__ == "__main__":
    main()
