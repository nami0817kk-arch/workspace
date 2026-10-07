# -*- coding: utf-8 -*-
"""文字の大きさの基準。

**図は「資料」ではなく「画面の一部」として見られる。**
1920×1080 の動画をスマホで見ると、画面の幅は 390pt ほどしかない。
つまり **1920 の画面での 48px が、スマホでは 10pt**。これより小さい字は読めない。

2026-10-07 に、作った動画をスマホの実寸（390×219）に落として確かめたところ、
板の中の文字（30px 前後）はほとんど読めなかった。そこで基準を決めた。

### 決め方

- 板は **1700 幅**で作り、画面に**等倍で**置く（板の px ＝ 画面の px）
- 板の高さは **730 まで**（影が 56 付くので 786。画面の下 250 が字幕、上 40 が余白）
- いちばん小さい字（出典）でも **28px**。これがスマホで 5.7pt、読める下限

| 役 | px | スマホでの見え |
|---|---|---|
| `TITLE` 板の見出し | 58 | 11.8pt |
| `BODY` 本文（行のラベル） | 48 | 9.8pt |
| `VALUE` 数字 | 46 | 9.3pt |
| `NOTE` 添え | 32 | 6.5pt |
| `CREDIT` 出典 | 28 | 5.7pt |
| `HERO` 主役の数字 | 150 | 30pt |

**添えと出典は「読めなくてもよい」ものだけに使う。**
大事なことを NOTE で書かない。
"""
from __future__ import annotations

# 板の大きさ
PANEL_W = 1700
PANEL_H_MAX = 730
BAND_H = 100              # 見出しの色帯

# 文字の大きさ
TITLE = 58
BODY = 48
VALUE = 46
NOTE = 32
CREDIT = 28
HERO = 150

# これより小さい字は作らない（F が自動で持ち上げる）
MIN_PX = 28

# 1行の高さ（本文が入る最小）
ROW = 66

# スマホ（390pt 幅）で見たときの pt に直す
PHONE = 390 / 1920


def phone_pt(px: int) -> float:
    """その大きさが、スマホでは何 pt に見えるか。"""
    return px * PHONE


def rows_fit(n: int, row: int = ROW, band: int = BAND_H, pad: int = 60) -> bool:
    """その行数が板に収まるか（収まらなければ、行を減らすか2画面に割る）。"""
    return band + pad * 2 + n * row <= PANEL_H_MAX


def max_rows(row: int = ROW, band: int = BAND_H, pad: int = 60) -> int:
    """板に入る行の数。"""
    return max((PANEL_H_MAX - band - pad * 2) // row, 1)


# ---- 日本語の折り返し ----------------------------------------------------

# 行頭に置いてはいけない字（前の行にぶら下げる）
NG_HEAD = "、。，．）」』】〉》！？‼⁇・ー々ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ…"
# 行末に置いてはいけない字（次の行へ送る）
NG_TAIL = "（「『【〈《"


def wrap(d, text: str, font, width: float, max_lines: int | None = None) -> list[str]:
    """日本語の決まりを守って折り返す。

    文字数だけで切ると、**行頭に「、」が来る**。実際に試作の字幕で起きた
    （2026-10-07）。読む速さが落ちるので、次の5つを守る。

      ・行頭に「、」「。」「）」などを置かない（前の行にぶら下げる）
      ・折り返す位置から**2文字以内に読点があれば、そこまで入れる**
        （「…始まりました／が、半世紀…」のような切れ方を防ぐ）
      ・行末に「（」「「」を置かない（次の行へ送る）
      ・**数字の途中で切らない**（「17」と「5円」に分かれない）
      ・切れるなら**読点・句点のあと**で切る（2行目が1語だけになるのを防ぐ）

    ぶら下げたぶん少しだけ幅を超えるが、中央寄せの字幕では気づかれない。
    `d` は ImageDraw、`font` は測るためのフォント。
    """
    out: list[str] = []
    cur = ""
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == chr(10):
            out.append(cur)
            cur = ""
            i += 1
            continue
        if not cur or d.textlength(cur + ch, font=font) <= width:
            cur += ch
            i += 1
            continue
        # --- ここで折り返す ---
        # ① この先2文字以内に読点があれば、そこまで前の行に入れてしまう
        look = text[i:i + 3]
        k = -1
        for mark in ("、", "。"):
            j = look.find(mark)
            if j >= 0 and (k < 0 or j < k):
                k = j
        if 0 <= k <= 2:
            out.append(cur + text[i:i + k + 1])
            cur = ""
            i += k + 1
            continue
        # ② 行頭に来てはいけない字は、前の行にぶら下げる
        if ch in NG_HEAD:
            out.append(cur + ch)
            cur = ""
            i += 1
            continue
        # ③ 前の行に読点があれば、そこで切り直す（2行目が1語だけになるのを防ぐ）
        cut = max(cur.rfind("、"), cur.rfind("。"))
        if cut >= len(cur) * 0.45:
            out.append(cur[:cut + 1])
            cur = cur[cut + 1:] + ch
            i += 1
            continue
        # ④ 数字の途中なら、その数字の先頭まで戻す
        if ch.isdigit() and cur[-1].isdigit():
            m = len(cur)
            while m > 0 and (cur[m - 1].isdigit() or cur[m - 1] in ".,"):
                m -= 1
            if m > len(cur) * 0.3:            # 戻しすぎない
                out.append(cur[:m])
                cur = cur[m:] + ch
                i += 1
                continue
        # ⑤ 行末に来てはいけない字は、次の行へ送る
        if cur[-1] in NG_TAIL:
            out.append(cur[:-1])
            cur = cur[-1] + ch
            i += 1
            continue
        out.append(cur)
        cur = ch
        i += 1
    if cur:
        out.append(cur)
    return out[:max_lines] if max_lines else out
