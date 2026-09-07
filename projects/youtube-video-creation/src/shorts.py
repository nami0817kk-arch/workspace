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
    """縦向きの設定にする。文字は横幅が狭くなるぶん小さくする。

    **タイトルカードと章タイトルは出さない。** 本編では話の入口として要るが、
    ショートでは冒頭2.6秒が「無音の静止画」になり、そこで捨てられる。
    実測（2026-09-07）で、公開済みショートの視聴維持は
    「視聴を継続 9.4% / スワイプして消去 90.7%」だった。最初の2秒に
    音も動きも被写体も無いのが効いている（先頭フレームを抜いて確認済み）。
    尺の上限が58秒しかないショートでは、カードに使う4秒の価値も本編とは違う。
    """
    video = replace(
        config.video,
        width=SIZE[0],
        height=SIZE[1],
        telop_size=max(40, int(config.video.telop_size * 0.78)),
        # 見出しは縮めない。参考チャンネルは画面幅いっぱいの極太2行だった
        headline_size=max(44, int(config.video.headline_size * 0.70)),
        title_size=max(56, int(config.video.title_size * 0.62)),
    )
    titles = replace(config.titles, intro=0.0, chapter=0.0)
    return replace(config, video=video, titles=titles)


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
    """本編のサムネイル写真を、ショートの本文にも出す。

    **縦型は画面が余る。**実測（2026-09-06）で、カードが出ているのは
    22秒中5秒だけ、残りは背景だけだった。顔があるだけで持つ画面になる。
    すでに写真を持つ行があれば、そのままにする。
    """
    if any(getattr(line, "image", None) for line in script.lines):
        return
    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        return
    body = script.scenes[-1]
    for line in body.lines:
        # カードのある行は避ける。縦に積めるが、1行に詰め込むと窮屈になる
        if not line.card:
            line.image = photo
            return
    if body.lines:
        body.lines[0].image = photo


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
