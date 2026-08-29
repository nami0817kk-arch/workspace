"""ナレーション・BGM・効果音のミックス。

ナレーションの長さを基準に BGM をループさせ、喋っている間だけ BGM を自動で下げる
（サイドチェイン）。効果音は指定の時刻に重ねる。
"""

from __future__ import annotations

import wave
from dataclasses import dataclass
from pathlib import Path

from . import ffmpeg
from .config import AudioConfig, _resolve

STEREO = "aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo"


@dataclass
class SoundEffect:
    at: float
    path: Path


def collect_effects(script, config) -> list[SoundEffect]:
    """台本の `se:` 指定とシーン頭の効果音を時刻つきで集める。"""
    effects: list[SoundEffect] = []
    scene_se = _existing(config.audio.scene_se)

    for scene in script.scenes:
        if scene_se and scene.lines:
            effects.append(SoundEffect(scene.lines[0].start, scene_se))
        for line in scene.lines:
            path = _existing(line.se)
            if path:
                effects.append(SoundEffect(line.start, path))
    return effects


def mix(
    voice: Path,
    out_path: Path,
    work_dir: Path,
    config: AudioConfig,
    duration: float,
    effects: list[SoundEffect] | None = None,
    bgm: str | None = None,
) -> Path:
    """ナレーションに BGM と効果音を重ねた1本の音声を作る。

    BGM も効果音も無ければナレーションをそのまま返す（無駄な再エンコードを避ける）。
    """
    effects = effects or []
    bgm_path = _existing(bgm if bgm is not None else config.bgm)

    # 完全な無音に loudnorm を掛けると無限のゲインがかかって NaN になる。
    # --no-tts で BGM も無い場合に踏むので、信号があるときだけ正規化する。
    normalize = bool(config.loudness_target) and (
        bgm_path is not None or bool(effects) or _has_signal(voice)
    )
    if bgm_path is None and not effects and not normalize:
        return voice

    args = ["-i", str(voice)]
    filters: list[str] = []
    mix_inputs: list[str] = []
    index = 1

    # ナレーション。BGM を下げるためのサイドチェイン用に複製しておく。
    # モノラルを aformat でステレオにすると電力保存のため -3dB される。
    # 声はそのままの大きさで両チャンネルに置きたいので pan で複製する。
    spread = "pan=stereo|c0=c0|c1=c0" if _is_mono(voice) else STEREO
    voice_chain = f"[0:a]aformat=sample_fmts=fltp:sample_rates=44100,{spread}"
    if bgm_path is not None and config.duck:
        filters.append(f"{voice_chain},asplit=2[voice][sc]")
    else:
        filters.append(f"{voice_chain}[voice]")
    mix_inputs.append("[voice]")

    if bgm_path is not None:
        args += ["-stream_loop", "-1", "-i", str(bgm_path)]
        fade_out = max(0.0, duration - config.bgm_fade)
        chain = (
            f"[{index}:a]{STEREO},"
            f"atrim=0:{duration:.3f},asetpts=N/SR/TB,"
            f"afade=t=in:st=0:d={config.bgm_fade:.2f},"
            f"afade=t=out:st={fade_out:.3f}:d={config.bgm_fade:.2f},"
            f"volume={config.bgm_gain}dB"
        )
        if config.duck:
            filters.append(chain + "[bgmraw]")
            # 喋りが乗っている間だけ BGM を押し下げる
            filters.append(
                "[bgmraw][sc]sidechaincompress="
                f"threshold=0.03:ratio={config.duck_ratio}:attack=25:release=350[bgm]"
            )
        else:
            filters.append(chain + "[bgm]")
        mix_inputs.append("[bgm]")
        index += 1

    for number, effect in enumerate(effects):
        args += ["-i", str(effect.path)]
        delay = max(0, int(effect.at * 1000))
        filters.append(
            f"[{index}:a]{STEREO},volume={config.se_gain}dB,adelay={delay}|{delay}[se{number}]"
        )
        mix_inputs.append(f"[se{number}]")
        index += 1

    # normalize=0 にしないと入力数ぶん音量が下がる
    tail = (
        # YouTube の基準に合わせて音圧を揃える。トゥルーピークも同時に抑えられる
        f"loudnorm=I={config.loudness_target}:TP=-1.5:LRA=11"
        if normalize
        else "alimiter=limit=0.95"
    )
    filters.append(
        "".join(mix_inputs) + f"amix=inputs={len(mix_inputs)}:normalize=0:duration=first,{tail}[out]"
    )

    args += [
        "-filter_complex", ";".join(filters),
        "-map", "[out]",
        "-ar", "44100",
        "-ac", "2",
        str(out_path),
    ]
    ffmpeg.run(args)
    return out_path


SILENCE_DB = -90.0


def _has_signal(path: Path) -> bool:
    return ffmpeg.max_volume(path) > SILENCE_DB


def _is_mono(path: Path) -> bool:
    try:
        with wave.open(str(path), "rb") as handle:
            return handle.getnchannels() == 1
    except (wave.Error, OSError):
        return False


def _existing(value: str | Path | None) -> Path | None:
    if not value:
        return None
    path = _resolve(value)
    return path if path.exists() else None
