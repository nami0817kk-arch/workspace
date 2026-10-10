# -*- coding: utf-8 -*-
"""節の中で画面がどう切り替わるか。

図を1枚作って4分出しっぱなしにすると、どれだけ作り込んでも間が持たない。
ニュース番組は**10〜20秒で画面が変わる**。ただし毎回ぜんぶ差し替えるのではなく、
**同じ図の上に書き込みが1つずつ増える**。語りが「ここが」と言う所で赤が付く。

    grow(fn, fig)       … 項目が1つずつ増える画像の列を作る
    reveal(im, marks)   … 書き込みが1つずつ増える画像の列を作る
    PATTERNS            … 冒頭と9つの節それぞれの、画面の並びの型
    plan(kind)          … その節で出す画面と、1枚あたりの秒数の目安
    check(plan, secs)   … 節の長さに対して画面の数が足りているか見る

**1枚あたり22秒を超えたら、画面が足りない。** そのときは書き込みを足して割る。
"""
from __future__ import annotations

from PIL import Image

from danmen import annotate

# 1枚の画面が出ている時間の目安（秒）
HOLD_MIN, HOLD_GOOD, HOLD_MAX = 6, 14, 22


def grow(draw_fn, fig: dict, key: str = "items", start: int = 1) -> list[Image.Image]:
    """項目を1つずつ増やした画像の列。語りが1つずつ説明するのに合わせる。

    レシートの行、箇条書き、年表。ニュース番組はまず1行だけ出し、
    話しながら増やしていく。最初から全部出すと、見る人の目が先に行ってしまう。
    """
    items = list(fig[key])
    out = []
    # **表・比べる図・箇条書きは、全部の行を最初から薄く出す**（2026-10-10）。図の側が reveal を見る
    whole = getattr(draw_fn, "__name__", "") in ("compare", "bars", "table")
    for n in range(max(start, 1), len(items) + 1):
        f = dict(fig)
        if whole:
            f[key] = items
            f["reveal"] = n
            out.append(draw_fn(f))
            continue
        f[key] = items[:n]
        # 最終的な数を渡す。これが無いと、増えるたびに既に出ている項目が動いて
        # 映像で跳ねて見える（図の側が `slots` を見る）
        f["slots"] = len(items)
        out.append(draw_fn(f))
    return out


def reveal(im: Image.Image, marks: list[dict], keep_first: bool = True) -> list[Image.Image]:
    """書き込みを1つずつ足した画像の列を返す。

    1枚目は書き込みなし（図そのもの）。語りが説明を始めたところで出す。
    以降は marks の順に1つずつ増える。
    """
    out: list[Image.Image] = [im] if keep_first else []
    acc: list[dict] = []
    for m in marks:
        acc.append(m)
        out.append(annotate.apply(im, acc))
    return out


# 節ごとの、画面の並びの型。
#   (画面の種類, 枚数, 役割)。枚数は「その図から何枚ぶん作るか」。
#   `+` で始まるものは**前の画面に重ねる**もの（別の図を作らない）
PATTERNS: dict[str, list[tuple[str, int, str]]] = {
    "hook": [                         # 冒頭の10秒。**ここで離脱が決まる**
        ("fullscreen.number", 1, "いちばん強い数字を、理由を言わずに出す"),
        ("screens.title", 1, "その数字から問いを立てる。これが題名になる"),
    ],
    "surface": [                      # 00 表面（2分）
        ("breaking", 2, "報じられたことを速報の帯で。見出しと添えを順に"),
        ("newspaper", 3, "どう報じられたか。本文を増やしながら"),
        ("talk", 3, "2人が素朴に反応する。吹き出しを順に"),
    ],
    "question": [                     # 01 問い（30秒）
        ("chapter", 1, "節の中扉"),
        ("reaction", 1, "問いを大きく出す。聞き手が驚く"),
    ],
    "cut1": [                         # 02 一の断面（4分）
        ("chapter", 1, "節の中扉"),
        ("icon_stats", 4, "この節の数字。1つずつ出す"),
        ("receipt", 6, "内訳を1行ずつ増やす"),
        ("+書き込み", 3, "蛍光ペン → 丸 → 矢印の順に足す"),
        ("+aside", 1, "聞き手が割り込む"),
        ("donut", 2, "割合で見せ直す"),
    ],
    "cut2": [                         # 03 二の断面（5分）
        ("chapter", 1, "節の中扉"),
        ("timeline", 6, "年を1つずつ増やす"),
        ("+書き込み", 2, "決まった年に丸と下線"),
        ("quote", 3, "原文をそのまま。行を増やしながら"),
        ("schedule", 4, "これからどうなるか。1行ずつ"),
        ("+aside", 1, "聞き手が割り込む"),
        ("glossary", 2, "出てきた言葉の意味"),
        ("statement", 2, "公式の発言を引く"),
    ],
    "cut3": [                         # 04 三の断面（5分）
        ("chapter", 1, "節の中扉"),
        ("icon_flow", 4, "誰から誰へ。1つずつつないでいく"),
        ("+書き込み", 2, "金額のところに丸"),
        ("waterfall", 5, "増減を1本ずつ積む"),
        ("flowchart", 4, "自分は当てはまるのか。分岐を1つずつ"),
        ("+aside", 1, "聞き手が割り込む"),
        ("receipt", 3, "払っている側から見直す"),
    ],
    "world": [                        # 05 四の断面（4分）
        ("chapter", 1, "節の中扉"),
        ("versus", 2, "日本と1国を全画面で比べる"),
        ("numberline", 5, "各国の位置を1つずつ打つ"),
        ("+書き込み", 2, "日本の位置に丸と書き込み"),
        ("world", 3, "地図で見せる。色を段階で"),
        ("icon_compare", 2, "仕組みの違いを並べる"),
    ],
    "myth": [                         # 06 よくある誤解（4分）
        ("chapter", 1, "節の中扉"),
        ("qa", 2, "広まっている説をQで出す"),
        ("+書き込み", 2, "説に取り消し線を引く"),
        ("calc", 3, "数字で確かめる。式を1行ずつ"),
        ("verdict", 5, "案を並べて比べる。1行ずつ"),
        ("+aside", 1, "聞き手が言い直す"),
    ],
    "reading": [                      # 07 見立て（4分）
        ("chapter", 1, "節の中扉"),
        ("icon_list", 5, "理由を番号で。1つずつ"),
        ("+書き込み", 3, "1つずつ書き込みで強める"),
        ("matrix", 3, "2つの軸で置き直す"),
        ("points", 3, "きょうのポイント3つ。1つずつ"),
    ],
    "close": [                        # 08 締め（1分30秒）
        ("recap", 4, "ここまでのおさらい。1つずつ"),
        ("talk", 2, "聞き手が次回の問いを振る"),
        ("outro", 1, "締めの画面"),
    ],
}

# 節の名前と、台本での長さの目安（秒）
SECTIONS = {
    "hook": 10, "surface": 120, "question": 30, "cut1": 240, "cut2": 300, "cut3": 300,
    "world": 240, "myth": 240, "reading": 240, "close": 90,
}


def plan(kind: str) -> list[tuple[str, str]]:
    """その節で出す画面の並び。枚数のぶんだけ開いて返す。"""
    if kind not in PATTERNS:
        raise SystemExit("知らない節です: {}（使えるのは {}）".format(
            kind, " / ".join(PATTERNS)))
    out: list[tuple[str, str]] = []
    for name, count, role in PATTERNS[kind]:
        for i in range(max(count, 1)):
            label = name if count == 1 else "{} {}/{}".format(name, i + 1, count)
            out.append((label, role))
    return out


def check(kind: str, seconds: int | None = None) -> str:
    """節の長さに対して画面の数が足りているか。足りなければ何枚足すか言う。"""
    secs = SECTIONS.get(kind, 0) if seconds is None else seconds
    n = len(plan(kind))
    hold = secs / n if n else 0
    if hold > HOLD_MAX:
        need = int(secs / HOLD_GOOD) - n + 1
        return "1枚あたり{:.0f}秒。長すぎます（上限{}秒）。あと{}枚ぶん刻んでください。".format(
            hold, HOLD_MAX, need)
    if hold < HOLD_MIN and kind != "hook":
        # 冒頭だけは例外。掴みなので、ゆっくり出さない
        return "1枚あたり{:.0f}秒。短すぎます（下限{}秒）。画面を減らしてください。".format(
            hold, HOLD_MIN)
    return "1枚あたり{:.0f}秒。ちょうどよい幅です。".format(hold)


def report() -> str:
    """9つの節ぜんぶを見て、画面の数が足りているかの一覧を返す。"""
    lines, total = [], 0
    for kind, secs in SECTIONS.items():
        n = len(plan(kind))
        total += n
        lines.append("{:9s} {:>4}秒 / {:>3}枚 … {}".format(kind, secs, n, check(kind)))
    lines.append("")
    lines.append("1本ぶんの画面は {} 枚（{}秒）。".format(total, sum(SECTIONS.values())))
    return chr(10).join(lines)
