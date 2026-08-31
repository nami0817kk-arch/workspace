"""広告枠の挿入。

ここは「たくさん出すほど儲かる」場所ではない。広告が多いページは
Core Web Vitals が落ちて検索順位が下がり、結果として総収益が減る。
さらにAdSenseはポリシー違反（誤クリック誘発・コンテンツのないページへの掲載）で
アカウントごと停止するので、機械的に守れる制約はコード側に持たせている。
"""

from __future__ import annotations

import html
import re

from .config import AdsConfig
from .content import Page

# ツールUIを含むブロック。この直前・直後には広告を置かない（誤クリック誘発の防止）。
_INTERACTIVE = re.compile(r"data-tool=|<button|<input|<form")


def is_interactive(block: str) -> bool:
    return bool(_INTERACTIVE.search(block))


def ads_allowed(page: Page, ads: AdsConfig) -> tuple[bool, str]:
    """このページに広告を出してよいかと、その理由を返す。"""
    if not ads.enabled:
        return False, "AdSenseクライアントIDが未設定"
    if not page.ads:
        return False, "ページ側で ads: false を指定"
    if page.noindex:
        return False, "noindexページには掲載しない"
    if page.word_count < ads.min_words_for_ads:
        return False, f"本文量が不足 ({page.word_count} < {ads.min_words_for_ads})"
    return True, ""


def ad_unit(slot: str, ads: AdsConfig, position: str) -> str:
    """1枠分のHTML。

    高さを先に確保しているのは、広告読み込みで本文が飛ぶ(CLS)のを防ぐため。
    CLSはCore Web Vitalsの評価対象なので、これは体裁ではなく収益の問題。
    """
    return (
        f'<aside class="ad-slot ad-{html.escape(position, quote=True)}"'
        f' style="min-height:{ads.reserved_height_px}px" aria-label="広告">'
        '<span class="ad-label">広告</span>'
        '<ins class="adsbygoogle" style="display:block"'
        f' data-ad-client="{html.escape(ads.client, quote=True)}"'
        f' data-ad-slot="{html.escape(slot, quote=True)}"'
        ' data-ad-format="auto" data-full-width-responsive="true"></ins>'
        "<script>(adsbygoogle=window.adsbygoogle||[]).push({});</script>"
        "</aside>"
    )


def place_ads(blocks: list[str], page: Page, ads: AdsConfig) -> list[str]:
    """本文ブロックの隙間に広告を挿入する。

    配置は「最初のセクションを読ませてから」「中盤」「末尾」の最大3枠。
    ファーストビュー直上には置かない（離脱率が上がり、結局PVあたり収益が落ちる）。
    """
    allowed, _ = ads_allowed(page, ads)
    if not allowed or not blocks:
        return list(blocks)

    slots = [(i, s) for i, s in enumerate((ads.slot_top, ads.slot_inline, ads.slot_bottom)) if s]
    slots = slots[: max(0, ads.max_units_per_page)]
    if not slots:
        return list(blocks)

    names = {0: "top", 1: "inline", 2: "bottom"}
    # 挿入位置（ブロック番号）を決める。末尾枠は常に最後。
    candidates: list[tuple[int, str, str]] = []
    if len(slots) >= 1 and len(blocks) >= 3:
        candidates.append((_safe_index(blocks, 2), slots[0][1], names[slots[0][0]]))
    if len(slots) >= 2 and len(blocks) >= 8:
        candidates.append((_safe_index(blocks, len(blocks) * 3 // 5), slots[1][1], names[slots[1][0]]))
    if len(slots) >= 3:
        candidates.append((len(blocks), slots[2][1], names[slots[2][0]]))

    out = list(blocks)
    for offset, (index, slot, position) in enumerate(sorted(candidates, key=lambda c: c[0])):
        out.insert(index + offset, ad_unit(slot, ads, position))
    return out


def _bad_position(blocks: list[str], index: int) -> bool:
    """そこに挿入すると具合が悪い位置か。

    - インタラクティブ要素の隣: 誤クリックを誘発する（ポリシー違反になりうる）
    - 見出しの直後: 見出しと本文が広告で分断され、読み手が迷子になる
    """
    if index >= len(blocks):
        return False
    previous = blocks[index - 1]
    return (
        is_interactive(blocks[index])
        or is_interactive(previous)
        or previous.startswith(("<h2", "<h3", "<h4"))
    )


def _safe_index(blocks: list[str], index: int) -> int:
    """挿入して問題のない位置まで後ろへずらす。"""
    index = max(1, min(index, len(blocks)))
    while index < len(blocks) and _bad_position(blocks, index):
        index += 1
    return index


def head_scripts(ads: AdsConfig) -> str:
    """<head> に入れる広告関連のタグ。"""
    if not ads.enabled:
        return ""
    parts = []
    if ads.consent_required and ads.consent_cmp_script:
        # EU/UK向けにはGoogle認定CMPが必須。自前のバナーでは要件を満たさない。
        parts.append(ads.consent_cmp_script)
    parts.append(
        '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'
        f'?client={html.escape(ads.client, quote=True)}" crossorigin="anonymous"></script>'
    )
    return "\n".join(parts)
