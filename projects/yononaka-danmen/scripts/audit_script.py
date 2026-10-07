# -*- coding: utf-8 -*-
"""台本と、画面の並びを点検する。

画面の見た目はこれまでの点検（文字・色）で見てきたが、**台本そのもの**と
**通しの並び**は見ていなかった。119 枚を人が目で見るのは無理なので、機械で見る。

    python scripts/audit_script.py 台本.yaml

見るのは6つ。

  1. 同じ語尾が続いていないか（「〜です。」が3回続くと耳に付く）
  2. 聞き手の相づちが単調でないか（同じ言い回しの繰り返し）
  3. 専門の言葉が、説明なしで出ていないか
  4. 同じ画面が続きすぎていないか
  5. 画面の種類が偏っていないか
  6. 1行が長すぎないか（字幕が2行に収まるか）

**どれも「必ず直す」ではない。** 偏りを見つけて、作る側が判断するための道具。
"""
from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import yaml

# 説明なしで出すと置いていかれる言葉。出たら「説明したか」を見る
TERMS = [
    "暫定税率", "本則税率", "特例税率", "租税特別措置", "揮発油税", "地方揮発油税",
    "一般財源", "特定財源", "可処分所得", "名目", "実質", "物価連動",
    "日銀短観", "基準金利", "政策金利", "長期金利", "実効為替レート",
    "減価償却", "法定耐用年数", "固定資産税評価額", "路線価",
    "社会保険料", "標準報酬月額", "所得代替率", "マクロ経済スライド",
]
# 相づちとみなす短い返し
AIZUCHI = re.compile(r"^(え|えっ|へえ|なるほど|そうなんですか|ほんとですか|たしかに)[、。！？]?")

MAX_SAME_TAIL = 3        # 同じ語尾がこれ以上続いたら挙げる
MAX_SAME_SCREEN = 4      # 同じ画面がこれ以上続いたら挙げる
MAX_SHARE = 0.34         # ひとつの画面の種類が、全体のこれを超えたら挙げる
MAX_CHARS = 42           # 1行の字数（字幕が2行に収まる目安）


def tail(text: str) -> str:
    """その行の語尾。活用の形までを見る。"""
    t = text.rstrip("。！？!?　 ")
    for k in ("ました", "ません", "でしょう", "ください", "います", "あります",
              "します", "なります", "ですが", "ですね", "です", "ます", "だった",
              "である", "のです", "んです"):
        if t.endswith(k):
            return k
    return t[-2:] if len(t) >= 2 else t


def read(path: Path) -> list[dict]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    out = []
    for sec in data.get("sections", []):
        for line in sec.get("lines", []):
            if not isinstance(line, dict) or len(line) != 1:
                continue
            key, val = next(iter(line.items()))
            if key in ("screen", "cast"):
                out.append({"kind": key, "value": str(val), "section": sec.get("id", "")})
                continue
            m = re.match(r"^(?P<who>[^\s(（]+)\s*(?:[（(](?P<tone>[^）)]+)[）)])?$", key)
            if m:
                out.append({"kind": "line", "who": m["who"], "tone": m["tone"] or "ふつう",
                            "text": str(val), "section": sec.get("id", "")})
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print("使い方: python scripts/audit_script.py 台本.yaml")
        return 1
    steps = read(Path(sys.argv[1]))
    lines = [s for s in steps if s["kind"] == "line"]
    screens = [s["value"] for s in steps if s["kind"] == "screen"]
    found: list[str] = []

    print("■ 台本の点検　（行 {}、画面の切り替え {}）\n".format(len(lines), len(screens)))

    # ① 同じ語尾が続く
    run, last = 1, None
    for i, ln in enumerate(lines):
        t = tail(ln["text"])
        if t == last:
            run += 1
            if run == MAX_SAME_TAIL:
                found.append("語尾「{}」が {} 行続く（{} 行目から）".format(
                    t, MAX_SAME_TAIL, i - MAX_SAME_TAIL + 2))
        else:
            run, last = 1, t

    # ② 相づちが単調
    aiz = [ln["text"] for ln in lines if ln["who"] == "聞き" and AIZUCHI.match(ln["text"])]
    if aiz:
        c = Counter(a[:6] for a in aiz)
        for word, k in c.most_common(3):
            if k >= 3:
                found.append("聞き手の「{}…」が {} 回".format(word, k))

    # ③ 専門の言葉が説明なしで出る
    body = "".join(ln["text"] for ln in lines)
    for term in TERMS:
        if term in body:
            # 「とは」「というのは」「つまり」が近くにあれば説明しているとみなす
            i = body.find(term)
            near = body[max(0, i - 40):i + 80]
            if not any(k in near for k in ("とは", "というのは", "つまり", "言いかえる",
                                           "意味します", "のことです")):
                found.append("「{}」が説明なしで出ている".format(term))

    # ④ 同じ画面が続く
    run, last = 1, None
    for sc in screens:
        if sc == last:
            run += 1
            if run == MAX_SAME_SCREEN:
                found.append("画面「{}」が {} 回続く".format(sc, MAX_SAME_SCREEN))
        else:
            run, last = 1, sc

    # ⑤ 画面の種類の偏り
    if screens:
        c = Counter(screens)
        for sc, k in c.most_common(3):
            share = k / len(screens)
            if share > MAX_SHARE:
                found.append("画面「{}」が全体の {:.0%}（{}回）".format(sc, share, k))

    # ⑥ 1行が長い
    for i, ln in enumerate(lines, 1):
        if len(ln["text"]) > MAX_CHARS:
            found.append("{} 行目が {} 字（{} 字まで）: {}…".format(
                i, len(ln["text"]), MAX_CHARS, ln["text"][:22]))

    if found:
        print("気になるところ（{}件）\n".format(len(found)))
        for f in found:
            print("  ・" + f)
        print("\n※ どれも「必ず直す」ではない。偏りを見つけるための道具。")
    else:
        print("気になるところはありません。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
