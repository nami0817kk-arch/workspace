# -*- coding: utf-8 -*-
"""色の見やすさを測る。

点検は2つ。

1. **系列の色**（棒や円で隣り合う色）が、色覚の違いでも見分けられるか
   → `dataviz` スキルの `validate_palette.js` に投げる（node が要る）
2. **文字と背景のコントラスト**が足りているか
   → WCAG の式で自分で測る

このチャンネルの図の文字は **28px 以上・太字**なので、WCAG では「大きい文字」に
あたり **3:1** が下限。本文の 4.5:1 ではない。ただし 3:1 ちょうどは読みにくいので、
**4:1 を目安**にして、それを切るものを挙げる。

    python scripts/audit_color.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from danmen import figures, news

VALIDATOR = Path(r"C:/Users/なみ/AppData/Local/Temp/claude/bundled-skills/2.1.280"
                 r"/5eca7f648e02df324693647390acda88/dataviz")
GOOD = 4.0          # これを切ったら挙げる（大きい文字の下限 3:1 に余裕を持たせた値）


def rgb(c) -> tuple[int, int, int]:
    if isinstance(c, str):
        c = c.lstrip("#")
        return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))      # type: ignore
    return tuple(c[:3])                                            # type: ignore


def hexs(c) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb(c))


def luminance(c) -> float:
    def ch(v: float) -> float:
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(c)
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(fg, bg) -> float:
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


# 画面で実際に使っている「文字 × 背景」の組み合わせ
BAND = (20, 34, 64)             # 板の見出しの帯
AMBER_TXT = news.AMBER_TXT      # 強調した行の文字（レシートなど）
TEAL_TXT = news.TEAL_TXT
DARK_BG = (16, 18, 24)          # 暗く落とした写真のうえ（おおよそ）


def over(fg, bg, alpha: int):
    """半透明の色を重ねたあとの、実際の色。蛍光ペンの上の文字を測るのに要る。"""
    a = alpha / 255
    f, b = rgb(fg), rgb(bg)
    return tuple(int(b[i] * (1 - a) + f[i] * a) for i in range(3))


# 蛍光ペン（黄・alpha 120）を白い板に塗ったあとの色
MARKED = over((255, 226, 86), (252, 251, 246), 120)

PAIRS = [
    ("板の本文", news.INK, news.PANEL),
    ("板の添え", news.INK_SUB, news.PANEL),
    ("板の強調（琥珀）", AMBER_TXT, news.PANEL),
    ("板の強調（緑）", TEAL_TXT, news.PANEL),
    ("蛍光ペンの上の本文", news.INK, MARKED),
    ("蛍光ペンの上の強調", AMBER_TXT, MARKED),
    ("見出しの白", (255, 255, 255), BAND),
    ("見出しの金の線", news.GOLD, BAND),
    ("全画面の添え", "#9FB0C9", DARK_BG),
    ("全画面の本文", "#C8D3E4", DARK_BG),
    ("字幕の白", (255, 255, 255), (6, 10, 18)),
    ("字幕の金", (255, 206, 72), (6, 10, 18)),
    ("棒のうえの白", (255, 255, 255), figures.SERIES[0]),
    # 琥珀の棒のうえは 3.5:1 しかないので、文字に黒い細縁を足して担保している
    ("棒のうえの白（琥珀）", (255, 255, 255), figures.SERIES[1], "縁あり"),
]


def check_series(name: str, colors: list[str]) -> bool:
    if not VALIDATOR.exists():
        print("  （dataviz の検証ツールが見つかりません）")
        return True
    r = subprocess.run(["node", "scripts/validate_palette.js", ",".join(colors),
                        "--mode", "light"],
                       cwd=str(VALIDATOR), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    ok = True
    for line in r.stdout.splitlines():
        t = line.strip()
        if t.startswith("[PASS]") or t.startswith("[WARN]") or t.startswith("[FAIL]"):
            print("    " + t)
            if t.startswith("[FAIL]"):
                ok = False
    return ok


def main() -> int:
    print("■ 系列の色（色覚の違いでも見分けられるか）\n")
    print("  figures の3色")
    ok1 = check_series("figures", [hexs(c) for c in figures.SERIES])
    print("\n  news の3色（棒のグラデーションの明るい側）")
    ok2 = check_series("news", [hexs(p[1]) for p in news.PAIRS])

    print("\n■ 文字と背景のコントラスト")
    print("  （図の文字は 28px 以上の太字＝「大きい文字」。WCAG の下限は 3:1、"
          "ここでは {:.1f}:1 を目安にする）\n".format(GOOD))
    bad = []
    for row in PAIRS:
        label, fg, bg = row[0], row[1], row[2]
        edged = len(row) > 3            # 黒い縁で担保しているもの
        c = contrast(fg, bg)
        # 縁があるものは、縁が背景の代わりになるので下限を WCAG の 3:1 に置く
        need = 3.0 if edged else GOOD
        mark = "OK" if c >= need else ("あやうい" if c >= 3.0 else "足りない")
        if c < need:
            bad.append("{}（{:.1f}:1）".format(label, c))
        print("  {:>6}  {:22s} {} on {}  {:>5.1f}:1{}".format(
            mark, label, hexs(fg), hexs(bg), c, "  （縁あり）" if edged else ""))
    print()
    if bad:
        print("見直すもの: " + " / ".join(bad))
    else:
        print("すべて目安を満たしています。")
    return 0 if (ok1 and ok2) else 1


if __name__ == "__main__":
    raise SystemExit(main())
