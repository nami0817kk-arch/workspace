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
