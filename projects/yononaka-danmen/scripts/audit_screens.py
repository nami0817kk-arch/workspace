# -*- coding: utf-8 -*-
"""全画面の様式（1920×1080 をまるごと作るもの）の文字を、まとめて測る。

板の図は `audit_type.py` が見る。こちらは画面そのもの。
画面は縮まないので、使った px がそのまま画面の px になる。
その代わり、**字幕の場所（下 250px）に中身が入っていないか**も見る。

    python scripts/audit_screens.py          # 全部
    python scripts/audit_screens.py talk     # 名前で絞る
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image

from danmen import fullscreen, news2, news3, news4, screens, studio, talk, typo

ASSETS = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets")
PHOTO = str(ASSETS / "photos" / "pexels_33741315_Cars_driving_on_a_highway_at_n.jpeg")
CREDIT = "資源エネルギー庁「石油製品価格調査」"


def spec_for(kind: str) -> dict:
    """その画面を1枚描かせるための中身。実際に使う分量に近づける。"""
    b = {"photo": PHOTO, "credit": CREDIT}
    if kind == "title":
        return {**b,
                "lines": [[("ガソリンはなぜ", "white")],
                          [("175円", "#E7B93F"), ("のうち", "white")],
                          [("70.6円", "#E7B93F"), ("が税金", "white")]],
                "sub": "175円の中身を分けてみる"}
    if kind == "chapter":
        return {**b, "no": "02", "name": "一の断面", "lead": "175円の中身を分ける"}
    if kind == "quote":
        return {**b, "text": "当分の間、揮発油税の税率は……とする",
                "source": "租税特別措置法 第89条"}
    if kind == "outro":
        return {**b, "next": "なぜ中古の家は22年で価値がゼロになるのか"}
    if kind == "thumbnail":
        return {**b,
                "big": [[("175円", "#E7B93F"), ("の", "white")],
                        [("中身", "white")]],
                "note": "4割が税金"}
    if kind == "flip":
        return {**b, "title": "ガソリン1リットルの中身",
                "rows": [[{"text": "本体", "kind": "gray"}, {"text": "92円", "kind": "red"}],
                         [{"text": "税金", "kind": "gray"}, {"text": "70.6円", "kind": "red"}]],
                "note": "2026年10月時点",
                "band": {"corner": "解説", "head": "ガソリン税", "sub": "なぜ下がらないのか"},
                "wipes": [{"name": "切島", "role": "語り手"}]}
    if kind == "breaking":
        return {**b, "tag": "速報", "head": "ガソリン175円に", "sub": "先週より2円高い",
                "channel": "日本のなぜ", "when": "2026年10月6日"}
    if kind == "lshape":
        return {**b, "head": "ガソリン175円", "sub": "4割が税金",
                "side_title": "いま分かっていること",
                "items": ["本体は92円", "税金は70.6円", "上乗せは1974年から"]}
    if kind == "voices":
        return {**b, "title": "街の声", "note": "都内の給油所で聞いた（2026年10月）",
                "items": [{"text": "高いとは思うけど、中身は知らない", "who": "40代・会社員"},
                          {"text": "通勤で毎日使うので効きます", "who": "30代・自営業"}]}
    if kind == "split":
        return {**b, "title": "この回の数字",
                "caption": "都内の給油所（2026年10月）",
                "items": [{"label": "1リットル", "value": "175円", "note": "レギュラー"},
                          {"label": "うち税金", "value": "70.6円", "note": "4割"}]}
    if kind == "qa":
        return {**b, "title": "よくある誤解", "sub": "広まっている説を1つだけ潰す",
                "items": [{"q": "ガソリン税は道路に使われている", "a": "2009年から使い道は自由"}]}
    if kind == "points":
        return {**b, "title": "きょうのポイント", "sub": "3つだけ覚えて帰ってください",
                "items": [{"label": "175円の4割が税金", "note": "70.6円"},
                          {"label": "上乗せは1974年から", "note": "2年だけの約束だった"},
                          {"label": "税に税がかかっている", "note": "消費税の計算に含む"}]}
    if kind == "glossary":
        return {**b, "word": "暫定税率", "read": "ざんていぜいりつ",
                "body": "当分の間だけ、本来の税率に上乗せする決まり。\n1974年に始まり、いまも続いている。"}
    if kind == "before":
        return {**b, "title": "上乗せが始まる前と後",
                "items": [{"label": "1973年", "value": "28.7円", "note": "本則だけ"},
                          {"label": "1974年", "value": "53.8円", "note": "上乗せが乗る"}]}
    if kind == "statement":
        return {**b, "text": "当分の間の措置として、やむを得ないものと考えている",
                "who": "大蔵大臣", "role": "1974年当時", "when": "1974年3月の国会答弁"}
    if kind == "poll":
        return {**b, "title": "ガソリン税をどうすべきか",
                "note": "全国の18歳以上1,042人に電話で聞いた（2026年9月）",
                "items": [{"label": "上乗せ分をやめるべきだ", "value": 58, "focus": True},
                          {"label": "いまのままでよい", "value": 21},
                          {"label": "分からない", "value": 21}]}
    if kind == "recap":
        return {**b, "title": "ここまでのおさらい",
                "items": [{"text": "店頭175円のうち、70.6円が税金", "note": "4割にあたる"},
                          {"text": "上乗せは1974年に始まった", "note": "2年だけの約束だった"}],
                "next": "誰が払い、誰が受け取っているか"}
    if kind == "live":
        return {**b, "tag": "現地", "place": "東京都内の給油所", "when": "2026年10月6日",
                "caption": "レギュラー1リットル175円。先週より2円高い"}
    if kind == "versus":
        return {**b, "title": "1リットルにかかる税",
                "left": {"name": "日本", "value": "56.6円", "focus": True,
                         "note": "うち25.1円は上乗せ分", "photo": PHOTO},
                "right": {"name": "ドイツ", "value": "86円",
                          "note": "上乗せという仕組みはない", "photo": PHOTO}}
    if kind == "talk":
        return {**b, "title": "きょうの問い",
                "left": {"who": "katari", "mood": "setsumei",
                         "say": "ガソリンが1リットル175円。どう思いますか"},
                "right": {"who": "kikite", "mood": "odoroki",
                          "say": "高いとは思っていましたけど"}}
    if kind == "reaction":
        return {**b, "who": "kikite", "mood": "odoroki", "lead": "175円のうち、税金は",
                "value": "70.6円", "say": "え、4割が税金ってことですか"}
    if kind in ("ranking", "change"):
        return {**b, "title": "1リットルにかかる税",
                "items": [{"label": "日本", "value": 56.6, "note": "上乗せ分あり"},
                          {"label": "ドイツ", "value": 86, "note": "1本"}]}
    if kind == "number":
        return {**b, "value": "70.6円", "label": "1リットルにかかる税", "note": "2026年10月時点"}
    return b


MODULES = [("screens", screens), ("studio", studio), ("news2", news2),
           ("news3", news3), ("news4", news4), ("talk", talk),
           ("fullscreen", fullscreen)]
SAFE_BOTTOM = 250        # 字幕の場所


def measure(mod, kind: str, spec: dict):
    """使った文字の大きさと、字幕の場所に中身が入っていないかを見る。"""
    sizes: list[int] = []
    orig = mod.F

    def spy(size, weight=900):
        sizes.append(int(size))
        return orig(size, weight)

    mod.F = spy
    try:
        im = mod.KINDS[kind](spec)
    except Exception as e:
        return ("error", str(e)[:60])
    finally:
        mod.F = orig
    if not sizes:
        return ("error", "文字を使っていません")
    return ("ok", min(sizes), sum(1 for z in sizes if z < typo.MIN_PX), im)


def main() -> int:
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    print("全画面の様式。画面は縮まないので、使った px がそのまま見える大きさになる。")
    print("（基準: {}px 以上 ＝ スマホで {:.1f}pt 以上）\n".format(
        typo.MIN_PX, typo.phone_pt(typo.MIN_PX)))
    bad: list[str] = []
    for name, mod in MODULES:
        for kind in sorted(mod.KINDS):
            if only and only not in kind:
                continue
            got = measure(mod, kind, spec_for(kind))
            if got[0] == "error":
                bad.append("{}.{}".format(name, kind))
                print("{:>5}  {:10s}.{:11s} {}".format("失敗", name, kind, got[1]))
                continue
            _, small, hits, im = got
            drawn = max(small, typo.MIN_PX)
            note = ""
            if hits:
                note += "  ← 下限に {} か所".format(hits)
            if im.size != (1920, 1080):
                note += "  ← 画面の大きさが {}x{}".format(*im.size)
            ok = hits == 0 and im.size == (1920, 1080)
            if not ok:
                bad.append("{}.{}".format(name, kind))
            print("{:>5}  {:10s}.{:11s} 最小 {:>3}px  スマホ {:>4.1f}pt{}".format(
                "OK" if ok else "直す", name, kind, drawn,
                typo.phone_pt(drawn), note))
    print()
    print("直すもの（{}件）: {}".format(len(bad), " / ".join(bad)) if bad
          else "すべて基準を満たしています。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
