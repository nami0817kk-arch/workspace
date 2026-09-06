"""ショート動画（縦9:16）の書き出し。

本編は2〜3分だが、YouTube ショートは60秒まで。全部は入らないので、
どこを切るかを決める必要がある。

切り方は「冒頭 + 1つの節」。冒頭で何の話かを言い、1つだけ掘って、
続きは本編へ送る。まとめまで入れると60秒に収まらないし、
入れたところで本編を見る理由がなくなる。
"""

from __future__ import annotations

import copy
from dataclasses import replace
from pathlib import Path

from .config import ProjectConfig
from .script_model import Scene, Script

# ショートの上限。ぎりぎりを狙うと音声の長さのぶれで超える
MAX_SECONDS = 58.0
SIZE = (1080, 1920)


class ShortError(Exception):
    pass


def portrait(config: ProjectConfig) -> ProjectConfig:
    """縦向きの設定にする。文字は横幅が狭くなるぶん小さくする。"""
    video = replace(
        config.video,
        width=SIZE[0],
        height=SIZE[1],
        telop_size=max(40, int(config.video.telop_size * 0.78)),
        headline_size=max(44, int(config.video.headline_size * 0.72)),
        title_size=max(56, int(config.video.title_size * 0.62)),
    )
    return replace(config, video=video)


def trim(script: Script, section: str = "", max_seconds: float = MAX_SECONDS) -> Script:
    """冒頭と、掘る節を1つだけ残す。

    section を指定しなければ、冒頭の次にある最初の中身の節を使う。
    尺に収まらなければ、その節の後ろのセリフから落とす。
    """
    if len(script.scenes) < 2:
        raise ShortError("節が1つしかありません。ショートにする意味がありません")

    opening = script.scenes[0]
    body = _pick(script, section)

    short = copy.deepcopy(script)
    short.scenes = [copy.deepcopy(opening), copy.deepcopy(body)]
    _fit(short, max_seconds)
    _add_face(short)
    if not short.scenes[-1].lines:
        raise ShortError(f"『{body.title}』は冒頭だけで尺を使い切ります。節を選び直してください")
    return short


# 語りを担当する声。ここに無い話者は「誰かの言葉を代弁している」
NARRATORS = ("キャスター", "解説", "ナレーター")


def strength(scene: Scene, cards: dict) -> int:
    """その節の強さ。**いちばん強い場面をショートに使う**（2026-09-06 ユーザー）。

    11本を振り返ると、残ったのは全部「誰かの言葉」だった
    （アルテタ「欠かせない選手だった」／モウリーニョ「なぜ負けたのか分からない」）。
    **事実の説明より、本人の口から出た一言が強い。**
    数字も次点で効く（枠内8本・xG3.16のような、それ自体が語るもの）。
    """
    score = 0
    for line in scene.lines:
        who = (getattr(line, "speaker", "") or "").strip()
        if who and who not in NARRATORS:
            score += 3          # 代弁。いちばん強い
        name = getattr(line, "card", None)
        kind = str((cards.get(name) or {}).get("type", "")).lower() if name else ""
        if kind == "quote":
            score += 3          # 原文の引用が画面に出る
        elif kind in ("bars", "table"):
            score += 2          # 数字が語る
        elif kind:
            score += 1
        if getattr(line, "image", None):
            score += 1
    return score


def _pick(script: Script, section: str) -> Scene:
    if section:
        for scene in script.scenes:
            if section in (scene.title, getattr(scene, "key", "")):
                return scene
        known = " / ".join(scene.title for scene in script.scenes[1:])
        raise ShortError(f"『{section}』という節がありません（{known}）")

    # **冒頭の次を機械的に取らない。**そこは前置きであることが多い。
    # まとめは答えを先に言ってしまうので外す
    body = [s for s in script.scenes[1:] if s.title != "まとめ"]
    if not body:
        return script.scenes[1]
    cards = script.cards or {}
    best = max(body, key=lambda s: (strength(s, cards), -body.index(s)))
    return best


def _add_face(script: Script) -> None:
    """顔写真を**最初の行から最後まで、全部の行に置く**。

    実測（2026-09-06）で、写真が出るのは平均12秒目、映っているのは全体の
    2割だけだった（ミランは10%、レアルは23秒目から）。
    **ショートは数秒で見るか決められる。**顔が12秒後では、その前に離脱される。

    **写真は「指定した行以降そのまま残る」わけではない。**残るのは
    カードとテロップで、写真は指定した行だけ。最初そう思い込んで先頭にだけ
    置いたところ、5秒出て消えた（実測して分かった）。全部の行に置く。
    """
    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        photo = next((str(line.image) for line in script.lines if line.image), "")
    if not photo:
        return
    for line in script.lines:
        if not line.image:
            line.image = photo


# ショートは数秒で見るか決められる。**顔が出るのが遅いと、その前に離脱する**
FACE_BY_SECONDS = 3.0
FACE_SHARE = 0.6


def face_timing(script: Script) -> tuple[float | None, float]:
    """(顔が最初に出る秒, 出ている割合)。顔が無ければ (None, 0)。"""
    at = None
    shown = 0.0
    total = 0.0
    for line in script.lines:
        span = line.duration or line.estimated_duration()
        if getattr(line, "image", None):
            if at is None:
                at = total
            shown += span
        total += span
    return at, (shown / total if total else 0.0)


def face_problems(script: Script) -> list[str]:
    """顔の出し方の問題。**実測（2026-09-06）で平均12秒目・全体の2割だった。**

    ミランは10%、レアルは23秒目からで、30秒の動画では終盤に一度出るだけ。
    """
    at, share = face_timing(script)
    if at is None:
        return ["顔が1枚も出ていません"]
    out = []
    if at > FACE_BY_SECONDS:
        out.append(f"顔が出るのが{at:.0f}秒目です（{FACE_BY_SECONDS:.0f}秒までに出す）")
    if share < FACE_SHARE:
        out.append(f"顔が出ているのは{share * 100:.0f}%です（{FACE_SHARE * 100:.0f}%以上）")
    return out


def _fit(script: Script, max_seconds: float) -> None:
    """後ろのセリフから落として尺に収める。冒頭は削らない。"""
    while _estimate(script) > max_seconds and len(script.scenes[-1].lines) > 1:
        script.scenes[-1].lines.pop()


def _estimate(script: Script) -> float:
    """ビルド前は実尺が分からないので、文字数からの見積もりを使う。"""
    return sum(line.duration or line.estimated_duration() for line in script.lines)


def outro_line(script: Script) -> str:
    """ショートの締め。本編へ送る。"""
    return "続きは本編で。チャンネル登録してお待ちください。"


def default_path(script_path: str | Path) -> Path:
    return Path(f"output/{Path(script_path).stem}_short")
