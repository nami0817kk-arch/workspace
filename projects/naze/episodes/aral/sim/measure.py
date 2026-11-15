"""アラル海の岸の線を、標高データ(Terrain Tiles)の等高線から自分で引く。
年ごとの水面の高さは Micklin ほか(2020)の表 4.1(バルト海基準の m): 1960 年 53.4・1971 年 51.1・1976 年 48.3・1989 年 39.1(大アラル)。
干上がった湖の底は、標高データの上では陸として測られているので、その高さの等高線が、その年の岸になる。
出力: shores.json(年 → 点の列のリスト。(経度, 緯度))。"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from naze import worldmap  # noqa: E402

BOX = (57.6, 43.0, 62.4, 47.2)
Z = 9
PPD = 256 * 2 ** Z / 360
LEVELS = {"1960": 53.4, "1971": 51.1, "1976": 48.3, "1989": 39.1}


def main():
    e = worldmap.heights(BOX, Z, PPD).astype(np.float32)
    h, w = e.shape
    print("格子", e.shape, "高さの範囲", float(np.nanmin(e)), float(np.nanmax(e)))
    e = cv2.GaussianBlur(e, (0, 0), 1.2)
    out, area = {}, {}
    kx = np.cos(np.radians((BOX[1] + BOX[3]) / 2))
    for yr, lv in LEVELS.items():
        m = (e < lv).astype(np.uint8)
        n, lab, st, _ = cv2.connectedComponentsWithStats(m, 4)
        cx, cy = int((60.0 - BOX[0]) * PPD), int((BOX[3] - 45.0) * PPD)    # 湖の真ん中あたり(60E, 45N)とつながる低地だけ
        keep = np.zeros_like(m)
        big = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] > 2000]
        for i in big:
            keep[lab == i] = 1
        cs, _ = cv2.findContours(keep, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        cs = [c for c in cs if cv2.contourArea(c) > 2000]
        polys = []
        for c in cs:
            c = cv2.approxPolyDP(c, 1.0, True)[:, 0, :]
            polys.append([(round(BOX[0] + x / PPD, 4), round(BOX[3] - y / PPD, 4)) for x, y in c])
        km2 = keep.sum() * (111.32 / PPD) ** 2 * kx
        out[yr], area[yr] = polys, round(float(km2))
        print(yr, lv, "m: 塊", len(polys), "面積 約", area[yr], "km2")
    (Path(__file__).parent / "shores.json").write_text(json.dumps(dict(levels=LEVELS, area=area, shores=out)), encoding="utf-8")


if __name__ == "__main__":
    main()
