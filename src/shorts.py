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
    if not short.scenes[-1].lines:
        raise ShortError(f"『{body.title}』は冒頭だけで尺を使い切ります。節を選び直してください")
    return short


def _pick(script: Script, section: str) -> Scene:
    if not section:
        return script.scenes[1]
    for scene in script.scenes:
        if section in (scene.title, getattr(scene, "key", "")):
            return scene
    known = " / ".join(scene.title for scene in script.scenes[1:])
    raise ShortError(f"『{section}』という節がありません（{known}）")


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
