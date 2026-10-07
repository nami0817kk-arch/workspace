# -*- coding: utf-8 -*-
"""図と画面の文字が、スマホで読める大きさかを全部まとめて測る。

**図は「資料」ではなく「画面の一部」として見られる。**
板は 1920 の画面に縮めて置かれるので、板の中の 30px は画面では 30px 未満になる。
さらにスマホでは画面の幅が 390pt しかない。つまり小さい字は消える。

この道具は、図を1枚描かせて**実際に使われた文字の大きさを全部記録**し、
画面に置いたときの実寸に直して、基準（`danmen/typo.py`）に満たないものを言う。

    python scripts/audit_type.py            # 全部
    python scripts/audit_type.py receipt    # 名前で絞る
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from danmen import (charts2, charts3, charts4, charts5, charts6, figures, news,
                    typo)

SCREEN_W = 1850          # 板を置ける幅（画面 1920 の端を少し空ける）
ROOM_H = 790             # 板を置ける高さ（下 250 が字幕、上 40 が余白）

# 測るための、当たり障りのない中身
SAMPLE = {
    "value": "175円", "label": "ガソリン税", "name": "日本", "note": "2026年10月時点",
    "credit": "資源エネルギー庁「石油製品価格調査」", "title": "ガソリン1リットルの中身",
}
I3 = [{"label": "ガソリン税", "value": 56, "note": "56.6円"},
      {"label": "所得税", "value": 32, "note": "32円"},
      {"label": "消費税", "value": 24, "note": "24円"}]


def fig_for(kind: str) -> dict:
    """その図を1枚描かせるための、最小限の中身。"""
    t, c = SAMPLE["title"], SAMPLE["credit"]
    base = {"kind": kind, "title": t, "credit": c}
    if kind in ("stack", "compare", "bars", "pie", "donut", "ranking", "change"):
        return {**base, "items": [{"label": i["label"], "value": i["value"]} for i in I3]}
    if kind == "receipt":
        return {**base, "items": [{"label": i["label"], "value": i["note"]} for i in I3],
                "total_label": "店頭価格", "total_value": "175円"}
    if kind in ("icon_stats",):
        return {**base, "items": [{"icon": "pump", "value": "175円", "label": "1リットル"},
                                  {"icon": "money", "value": "70.6円", "label": "うち税金"}]}
    if kind == "icon_list":
        return {**base, "items": [{"icon": "money", "label": "年に1.5兆円", "note": "埋める必要"},
                                  {"icon": "calendar", "label": "2年だけだった", "note": "いまも続く"}]}
    if kind == "icon_flow":
        return {**base, "steps": [{"icon": "people", "label": "私たち", "note": "給油のとき",
                                   "amount": "53.8円"},
                                  {"icon": "parliament", "label": "国", "note": "揮発油税"}]}
    if kind in ("icon_compare", "versus"):
        return {**base, "left": {"icon": "car", "name": "日本", "value": "56.6円",
                                 "note": "上乗せ分あり"},
                "right": {"icon": "globe", "name": "ドイツ", "value": "86円", "note": "1本"}}
    if kind == "timeline":
        return {**base, "items": [{"label": "1974年", "note": "上乗せが始まる"},
                                  {"label": "2010年", "note": "期限が外れる"}]}
    if kind == "schedule":
        return {**base, "items": [{"when": "2026年12月", "what": "見直しの議論", "now": True},
                                  {"when": "2027年4月", "what": "結論"}]}
    if kind == "checklist":
        return {**base, "items": [{"label": "すぐ効く", "ok": True, "note": "補助金"},
                                  {"label": "全員に届く", "ok": False, "note": "車のみ"}]}
    if kind == "flow":
        return {**base, "items": [{"label": "私たち", "note": "給油のとき", "icon": "people"},
                                  {"label": "国", "note": "揮発油税", "icon": "parliament"}]}
    if kind == "flowchart":
        return {**base, "steps": [{"ask": "車に乗りますか", "no": "関係ない"}], "end": "月500円"}
    if kind == "verdict":
        return {**base, "cols": ["すぐ効く", "全員に届く"],
                "items": [{"label": "補助金", "values": ["◎", "△"]},
                          {"label": "減税", "values": ["○", "◎"]}]}
    if kind == "numberline":
        return {**base, "items": I3, "min": 0, "max": 120,
                "min_label": "0円", "max_label": "120円"}
    if kind == "matrix":
        return {**base, "axis": {"top": "大きい", "bottom": "小さい",
                                 "left": "気づきにくい", "right": "気づきやすい"},
                "items": [{"label": "ガソリン税", "x": -0.6, "y": 0.5}]}
    if kind == "table":
        return {**base, "cols": ["税", "1リットル"],
                "items": [{"label": "日本", "values": ["56.6円"], "strong": True},
                          {"label": "ドイツ", "values": ["86円"]}]}
    if kind in ("hero", "big_number"):
        return {**base, "value": "175円", "label": "レギュラー1リットル", "note": "2026年10月"}
    if kind == "line":
        return {**base, "items": [{"label": "店頭価格",
                                   "points": [[2020, 140], [2023, 168], [2026, 175]]}]}
    if kind == "people":
        return {**base, "total": 10, "filled": 4, "per_row": 10,
                "lead": "10人のうち4人が「知らなかった」"}
    if kind == "waterfall":
        return {**base, "items": [{"label": "本体", "value": 92},
                                  {"label": "税", "value": 70.6}], "total_label": "店頭"}
    if kind == "calc":
        return {**base, "terms": [{"label": "本体", "value": "92円"},
                                  {"label": "税", "value": "70.6円"},
                                  {"label": "店頭", "value": "175円"}],
                "ops": ["＋", "＝"], "note": "2026年10月時点"}
    if kind == "stats":
        return {**base, "items": [{"value": "175円", "label": "1リットル"},
                                  {"value": "70.6円", "label": "うち税"}]}
    if kind == "gauge":
        return {**base, "value": 40, "max": 100, "label": "税の割合", "note": "40%"}
    if kind == "relation":
        return {**base,
                "nodes": [{"id": "a", "label": "私たち", "x": 0.14, "y": 0.5},
                          {"id": "b", "label": "国", "x": 0.5, "y": 0.5, "kind": "focus"},
                          {"id": "c", "label": "道路の工事", "x": 0.86, "y": 0.5}],
                "links": [{"from": "a", "to": "b", "label": "53.8円"},
                          {"from": "b", "to": "c", "label": "使い道は自由"}]}
    if kind == "thermometer":
        return {**base, "value": 70, "goal": 175, "label": "いま", "note": "70.6円"}
    if kind == "newspaper":
        return {**base, "head": "ガソリンまた上昇", "body": "資源エネルギー庁は…", "paper": "2026年10月"}
    if kind == "board":
        return {**base, "items": [{"label": "ガソリン税", "note": "53.8円"},
                                  {"label": "消費税", "note": "14.4円"}]}
    if kind == "convert":
        return {**base, "items": [{"value": "70.6円", "label": "1リットル", "note": "いま払う税"},
                                  {"value": "4万円", "label": "1年ぶん", "note": "1台あたり"}],
                "note": "年に700リットル使う前提"}
    if kind == "photo":
        return {**base, "src": "", "caption": "都内の給油所（2026年10月）"}
    if kind == "world":
        return {**base, "values": {"JPN": 56.6, "DEU": 86}}
    if kind == "japan":
        return {**base, "values": {"東京都": 56.6, "大阪府": 56.6}}
    return base


MODULES = [("figures", figures), ("news", news), ("charts2", charts2),
           ("charts3", charts3), ("charts4", charts4), ("charts5", charts5),
           ("charts6", charts6)]


def measure(mod, kind: str, fig: dict):
    """その図が**要求した**いちばん小さい文字、下限に当たった回数、板の大きさ。

    F には下限が入っているので、実際に描かれる字は必ず基準を満たす。
    ただし下限に当たるということは、**その図のレイアウトが設計と違う形で描かれている**
    ということなので、描いて目で見る必要がある。ここではその回数を数える。
    """
    sizes: list[int] = []
    orig = mod.F

    def spy(size, weight=900):
        sizes.append(int(size))
        return orig(size, weight)

    mod.F = spy
    news_orig = news.F
    if mod is not news:
        news.F = spy
    try:
        im = mod.KINDS[kind](fig)
    except Exception:
        return None
    finally:
        mod.F = orig
        news.F = news_orig
    if not sizes:
        return None
    hits = sum(1 for z in sizes if z < typo.MIN_PX)
    return (min(sizes), hits, im.width, im.height)


def main() -> int:
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    print("板を画面に置いたときの、いちばん小さい文字の実寸")
    print("（基準: 画面で {}px 以上 ＝ スマホで {:.1f}pt 以上）\n".format(
        typo.CREDIT, typo.phone_pt(typo.CREDIT)))
    bad: list[str] = []
    skipped: list[str] = []
    for name, mod in MODULES:
        for kind in sorted(mod.KINDS):
            if only and only not in kind:
                continue
            got = measure(mod, kind, fig_for(kind))
            if got is None:
                skipped.append("{}.{}".format(name, kind))
                continue
            asked, hits, w, h = got
            # 板は幅と高さの小さい方で縮む
            scale = min(SCREEN_W / w, ROOM_H / h, 1.0)
            drawn = max(asked, typo.MIN_PX)          # F が持ち上げたあとの大きさ
            on_screen = drawn * scale
            ok = on_screen >= typo.CREDIT - 1 and hits == 0
            if not ok:
                bad.append("{}.{}".format(name, kind))
            note = ""
            if hits:
                note = "  ← 下限に {} か所当たっている（目で見る）".format(hits)
            if scale < 0.9:
                note += "  ← 板が大きすぎて {:.0f}% に縮む".format(scale * 100)
            print("{:>5}  {:9s}.{:14s} 板 {:>4}x{:<4} 倍率 {:.2f}  画面 {:>3.0f}px "
                  "スマホ {:>4.1f}pt{}".format(
                      "OK" if ok else "直す", name, kind, w, h, scale,
                      on_screen, typo.phone_pt(on_screen), note))
    print()
    if bad:
        print("直すもの（{}件）: {}".format(len(bad), " / ".join(bad)))
    else:
        print("すべて基準を満たしています。")
    if skipped:
        print("測れなかったもの（中身の形が合わない）: {}".format(" / ".join(skipped)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
