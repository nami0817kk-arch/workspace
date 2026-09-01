"""filter_complex の組み立て。

ffmpeg のフィルタ文字列は読みにくく、間違えても実行するまで分からない。
組み立てだけをここに切り出して、**ffmpeg を呼ばずにテストできる**ようにしてある。
"""

from __future__ import annotations

from .errors import TimelineError

#: Ken Burns の寄り引きの幅（1.0 = 等倍）
ZOOM_MAX = 1.15
#: パンのときの拡大率（動かす余地を作るため少しだけ寄せる）
PAN_ZOOM = 1.08


def scene_video(
    index: int, *, width: int, height: int, fps: int, seconds: float, motion: str = "none"
) -> str:
    """1シーンぶんの映像フィルタ。`[v{index}]` を出力する。"""
    frames = max(1, int(round(seconds * fps)))
    if motion == "none":
        # 動かさないときは画の全体を見せる（図やサムネイルを切りたくない）
        chain = (
            f"scale={width}:{height}:force_original_aspect_ratio=decrease,"
            f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=black"
        )
    else:
        # 動かすときは画面を埋める。zoompan のがたつきを抑えるため一度大きく作る
        canvas_w, canvas_h = width * 2, height * 2
        chain = (
            f"scale={canvas_w}:{canvas_h}:force_original_aspect_ratio=increase,"
            f"crop={canvas_w}:{canvas_h},"
            + zoompan(motion, width=width, height=height, fps=fps, frames=frames)
        )
    return f"[{index}:v]{chain},setsar=1,fps={fps},format=yuv420p[v{index}]"


def zoompan(motion: str, *, width: int, height: int, fps: int, frames: int) -> str:
    """Ken Burns（寄り引き・パン）の zoompan。"""
    step = (ZOOM_MAX - 1.0) / max(1, frames)
    center_x = "iw/2-(iw/zoom/2)"
    center_y = "ih/2-(ih/zoom/2)"

    if motion == "zoom_in":
        zoom = f"min(1+{step:.6f}*on,{ZOOM_MAX})"
        x, y = center_x, center_y
    elif motion == "zoom_out":
        zoom = f"max({ZOOM_MAX}-{step:.6f}*on,1.0)"
        x, y = center_x, center_y
    elif motion in ("pan_left", "pan_right"):
        zoom = f"{PAN_ZOOM}"
        progress = f"on/{frames}" if motion == "pan_right" else f"(1-on/{frames})"
        x = f"(iw-iw/zoom)*{progress}"
        y = center_y
    else:
        raise TimelineError(f"motion に {motion!r} は指定できません")

    return (
        f"zoompan=z='{zoom}':x='{x}':y='{y}':"
        f"d={frames}:s={width}x{height}:fps={fps}"
    )


def scene_audio(index: int, output_index: int, seconds: float) -> str:
    """1シーンぶんの音声フィルタ。長さをシーンぴったりに揃える。

    音声がシーンより短ければ無音で埋め、長ければ切る。ここを揃えておかないと
    concat したときに映像と音がずれていく。
    """
    return (
        f"[{index}:a]aresample=48000,"
        f"aformat=sample_fmts=fltp:channel_layouts=stereo,"
        f"apad,atrim=0:{seconds},asetpts=N/SR/TB[a{output_index}]"
    )


def concat(count: int) -> str:
    """各シーンをつなぐ。"""
    pairs = "".join(f"[v{index}][a{index}]" for index in range(count))
    return f"{pairs}concat=n={count}:v=1:a=1[vc][ac]"


def bgm_mix(input_index: int, gain_db: float) -> str:
    """BGM をナレーションの下に敷く。

    amix は既定で入力の音量を等分に下げてしまい、ナレーションが小さくなる。
    normalize=0 にして、下げるのは BGM 側だけにする。
    """
    return (
        f"[{input_index}:a]volume={gain_db}dB,"
        f"aformat=sample_fmts=fltp:channel_layouts=stereo[bgm];"
        f"[ac][bgm]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[amixed]"
    )


def fade_video(label_in: str, label_out: str, seconds: float, total: float) -> str:
    start = max(0.0, round(total - seconds, 3))
    return f"[{label_in}]fade=t=in:st=0:d={seconds},fade=t=out:st={start}:d={seconds}[{label_out}]"


def fade_audio(label_in: str, label_out: str, seconds: float, total: float) -> str:
    start = max(0.0, round(total - seconds, 3))
    return f"[{label_in}]afade=t=in:st=0:d={seconds},afade=t=out:st={start}:d={seconds}[{label_out}]"


def burn_subtitles(label_in: str, label_out: str, srt_path: str, font: str = "") -> str:
    """字幕を焼き込む（libass が要る）。"""
    from .subtitles import escape_for_filter

    style = f":force_style='FontName={font}'" if font else ""
    return f"[{label_in}]subtitles='{escape_for_filter(srt_path)}'{style}[{label_out}]"
