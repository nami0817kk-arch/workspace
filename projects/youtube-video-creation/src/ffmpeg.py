"""ffmpeg の実行まわり。バイナリはシステム優先、無ければ imageio-ffmpeg 同梱を使う。"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path


VIDEO_SUFFIXES = {".mp4", ".mov", ".webm", ".mkv", ".m4v"}


class FfmpegError(RuntimeError):
    pass


def is_video(name: str | Path | None) -> bool:
    return bool(name) and Path(name).suffix.lower() in VIDEO_SUFFIXES


def ffmpeg_exe() -> str:
    system = shutil.which("ffmpeg")
    if system:
        return system
    try:
        import imageio_ffmpeg
    except ImportError as exc:  # pragma: no cover - 依存が入っていれば通らない
        raise FfmpegError(
            "ffmpeg が見つかりません。`pip install imageio-ffmpeg` を実行してください。"
        ) from exc
    return imageio_ffmpeg.get_ffmpeg_exe()


# ffmpeg は UTF-8 で書く。text=True だけだと、読む側がロケールの文字コード
# （Windows の日本語環境なら cp932）を使うので、エラー文の中身によっては
# 読み取りそのものが落ちる。本当の失敗の理由が見えなくなるのがまずい。
CAPTURE = {"capture_output": True, "text": True, "encoding": "utf-8", "errors": "replace"}


def run(args: list[str], quiet: bool = True) -> None:
    """ffmpeg を1回実行する。失敗したら stderr 末尾を添えて例外にする。"""
    command = [ffmpeg_exe(), "-y"]
    if quiet:
        command += ["-loglevel", "error"]
    command += args
    result = subprocess.run(command, **CAPTURE)
    if result.returncode != 0:
        tail = "\n".join(result.stderr.strip().splitlines()[-15:])
        raise FfmpegError(f"ffmpeg が失敗しました（exit {result.returncode}）:\n{tail}")


def max_volume(path: Path) -> float:
    """ファイルのピーク音量(dB)。完全な無音なら -inf を返す。"""
    result = subprocess.run(
        [ffmpeg_exe(), "-nostats", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        **CAPTURE,
    )
    for line in result.stderr.splitlines():
        if "max_volume:" in line:
            try:
                return float(line.split("max_volume:")[1].strip().split()[0])
            except (IndexError, ValueError):
                break
    return float("-inf")


def write_concat_list(entries: list[tuple[Path, float]], list_path: Path) -> Path:
    """concat demuxer 用のリストを書き出す。

    entries は (ファイル, 表示秒数) の並び。静止画を並べて可変長の動画にするために使う。
    最後の1枚は duration 無しでもう一度書くのが concat demuxer の作法。
    """
    if not entries:
        raise FfmpegError("concat する要素がありません")
    # **続けて同じ絵ならまとめる**（2026-10-08）。口パクを止めた回・写真を出したままの回は
    # 同じ1枚が何十行も並ぶ。絵と秒は変わらないが、ffmpeg が読むコマ数が桁で減る
    merged: list[list] = []
    for path, duration in entries:
        if merged and merged[-1][0] == path:
            merged[-1][1] += duration
        else:
            merged.append([path, duration])
    lines = []
    for path, duration in merged:
        lines.append(f"file '{Path(path).resolve().as_posix()}'")
        lines.append(f"duration {duration:.3f}")
    lines.append(f"file '{Path(merged[-1][0]).resolve().as_posix()}'")
    list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return list_path


def concat_audio(paths: list[Path], out_path: Path, work_dir: Path) -> Path:
    """同じフォーマットの wav を順につないで1本にする。"""
    list_path = work_dir / "audio_concat.txt"
    list_path.write_text(
        "\n".join(f"file '{p.resolve().as_posix()}'" for p in paths) + "\n",
        encoding="utf-8",
    )
    run(["-f", "concat", "-safe", "0", "-i", str(list_path), "-c", "copy", str(out_path)])
    return out_path


def build_background_track(
    segments: list[tuple[Path, float]],
    out_path: Path,
    size: tuple[int, int],
    fps: int = 30,
) -> Path:
    """シーンごとの背景（静止画でも動画でもよい）を、指定の秒数ずつつないだ1本の動画にする。

    静止画はその秒数だけ止め、動画は足りなければループさせる。どちらも画面いっぱいに
    拡大して中央を切り出すので、素材の比率が違っても混ぜられる。
    """
    if not segments:
        raise FfmpegError("背景トラックの素材がありません")

    # 無いまま ffmpeg に渡すと、生のエラー出力だけが出て原因が分からない。
    # 台本の bg に、まだ作っていない mp4 を書いてあるのがだいたいの原因
    missing = sorted({str(path) for path, _ in segments if not Path(path).exists()})
    if missing:
        raise FfmpegError(
            "背景の素材がありません:\n  "
            + "\n  ".join(missing)
            + "\n台本の bg / @bg を見直してください。"
            "`python -m src.cli init-assets` で静止画を作れます。"
            "動く背景は `python -m src.cli make-clip <画像>` で作ります"
        )

    width, height = size

    args: list[str] = []
    for path, duration in segments:
        if is_video(path):
            args += ["-stream_loop", "-1", "-t", f"{duration:.3f}", "-i", str(path)]
        else:
            args += ["-loop", "1", "-t", f"{duration:.3f}", "-i", str(path)]

    chains = [
        f"[{index}:v]scale={width}:{height}:force_original_aspect_ratio=increase,"
        f"crop={width}:{height},setsar=1,fps={fps},"
        f"trim=duration={duration:.3f},setpts=PTS-STARTPTS[b{index}]"
        for index, (_, duration) in enumerate(segments)
    ]
    chains.append(
        "".join(f"[b{i}]" for i in range(len(segments)))
        + f"concat=n={len(segments)}:v=1:a=0[bg]"
    )
    args += [
        "-filter_complex", ";".join(chains),
        "-map", "[bg]",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "18",
        "-pix_fmt", "yuv420p",
        str(out_path),
    ]
    run(args)
    return out_path


# 寄りの速さを測る基準の秒数。zoom は「この秒数あたりどれだけ寄るか」
REFERENCE_SECONDS = 10.0
# 寄りの総量の上限。これ以上寄せると絵が荒れる
MAX_ZOOM = 1.45


def still_to_clip(
    image: Path,
    out_path: Path,
    seconds: float = 10.0,
    size: tuple[int, int] = (1920, 1080),
    zoom: float = 1.18,
    fps: int = 30,
    max_zoom: float = MAX_ZOOM,
) -> Path:
    """静止画から、ゆっくり寄っていく背景クリップを作る。

    フリー素材の写真1枚でも、止まった絵より動画らしくなる。

    **寄る速さは秒あたりで一定にする。**総量を固定にしていたため、長い場面ほど
    1秒あたりの動きが小さくなり、**長い場面ほど止まって見えていた**
    （2026-09-05 実測。20秒の場面はほぼ静止していた）。長い場面こそ動きが要る。

    `zoom` は「10秒あたりどれだけ寄るか」として読む。長い場面では総量が増えるので、
    寄りすぎて絵が荒れないよう上限で止める。
    """
    width, height = size
    frames = max(1, int(seconds * fps))
    per_second = (zoom - 1.0) / REFERENCE_SECONDS
    total = min(max_zoom, 1.0 + per_second * seconds)
    step = (total - 1.0) / frames
    zoom = total
    run([
        "-loop", "1", "-i", str(image), "-t", f"{seconds:.2f}",
        "-vf",
        f"zoompan=z='min(zoom+{step:.6f},{zoom})':d={frames}"
        f":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={width}x{height}:fps={fps},"
        "format=yuv420p",
        "-c:v", "libx264", "-preset", "medium", "-crf", "22",
        str(out_path),
    ])
    return out_path


def grab_frame(clip: Path, out_path: Path, at: float = 1.0) -> Path:
    """動画から静止画を1枚取り出す。サムネイルの下地に使う。"""
    run(["-ss", f"{at:.2f}", "-i", str(clip), "-frames:v", "1", str(out_path)])
    return out_path


PROGRESS_COLOR = "0xffd54a"   # 進捗バーの色（チャンネルの黄）


def progress_chains(source: str, size: tuple[int, int], fps: int,
                    progress: tuple[float, int] | None) -> tuple[list[str], str]:
    """画面下端の進捗バー（2026-09-28）。**overlay の x を時間で動かす**ので、フレームは増えない。

    drawbox は式を最初に1回しか評価しないので動かない。黄色い帯を色の源から作り、
    左の画面外から t/T の割合だけ滑り込ませる。返すのは (追加のチェーン, 出力ラベル)。
    """
    if not progress:
        return [], source
    total, height = progress
    width, _ = size
    chains = [
        f"[{source}]drawbox=x=0:y=ih-{height}:w=iw:h={height}:color=white@0.25:t=fill[pbase]",
        f"color=c={PROGRESS_COLOR}:s={width}x{height}:r={fps}[pbar]",
        f"[pbase][pbar]overlay=x='-w+W*min(1\\,t/{total:.3f})':y=H-{height}:eval=frame:shortest=1[pv]",
    ]
    return chains, "pv"


def encode_video_over_clip(
    frame_list: Path,
    clip: Path,
    audio_path: Path | None,
    out_path: Path,
    size: tuple[int, int],
    fps: int = 30,
    progress: tuple[float, int] | None = None,
) -> Path:
    """背景動画の上に、透過PNGのフレーム列を重ねて書き出す。

    背景クリップは尺に足りなければループし、画面いっぱいになるよう拡大して中央を切り出す。
    """
    width, height = size
    args = [
        "-stream_loop", "-1", "-i", str(clip),
        "-f", "concat", "-safe", "0", "-i", str(frame_list),
    ]
    if audio_path is not None:
        args += ["-i", str(audio_path)]

    chains = [
        f"[0:v]scale={width}:{height}:force_original_aspect_ratio=increase,"
        f"crop={width}:{height},setsar=1,fps={fps}[bg]",
        f"[1:v]format=rgba,fps={fps},setsar=1[fg]",
        "[bg][fg]overlay=shortest=1:format=auto[v]",
    ]
    extra, label = progress_chains("v", size, fps, progress)
    chains += extra
    args += [
        "-filter_complex", ";".join(chains),
        "-map", f"[{label}]",
        *(["-map", "2:a"] if audio_path is not None else []),
        "-c:v", "libx264",
        # **preset だけ速くする**（2026-10-08）。crf は 20 のまま＝絵の細かさは変えない。
        # 実測で書き出しが 348秒 → 222秒、mp4 は 42.6MB → 40.4MB
        "-preset", "veryfast",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-r", str(fps),
        "-movflags", "+faststart",
    ]
    if audio_path is not None:
        args += ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest"]
    args.append(str(out_path))
    run(args)
    return out_path


def encode_video(
    frame_list: Path,
    audio_path: Path | None,
    out_path: Path,
    fps: int = 30,
    size: tuple[int, int] | None = None,
    progress: tuple[float, int] | None = None,
) -> Path:
    """静止画リスト（+音声）を YouTube 向けの MP4 にエンコードする。"""
    args = ["-f", "concat", "-safe", "0", "-i", str(frame_list)]
    if audio_path is not None:
        args += ["-i", str(audio_path)]
    video_map = ["-map", "0:v"]
    if progress and size:
        chains, label = progress_chains("0:v", size, fps, progress)
        chains[0] = chains[0].replace("[0:v]", "[0:v]fps=" + str(fps) + ",")
        args += ["-filter_complex", ";".join(chains)]
        video_map = ["-map", f"[{label}]"]
    args += [
        *video_map,
        *(["-map", "1:a"] if audio_path is not None else []),
        "-c:v", "libx264",
        # preset だけ速くする（crf は 20 のまま）。上の encode_video_over_clip と同じ
        "-preset", "veryfast",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-r", str(fps),
        "-fps_mode", "cfr",
        "-movflags", "+faststart",
    ]
    if audio_path is not None:
        args += ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest"]
    args.append(str(out_path))
    run(args)
    return out_path


# --- 出来上がった動画を点検するための読み取り（2026-10-08、tools/qc.py が使う） --------------

SCAN_SCENE_FPS = 5        # 画面の変化を見るときの1秒あたりのコマ数（溶け合いもこれで拾える）
SCAN_SCENE_BASE = 0.001   # これを超えた変化だけ記録する（判定のしきい値は後から当てる）
SCAN_WINDOW = 0.5         # 音の大きさを測る刻み（秒）


def probe(path: Path) -> dict | None:
    """動画の尺・幅・高さ・音の有無。**絵は読み込まない**（`ffmpeg -i` の表示を読むだけ）。

    一覧に並べるコマの大きさは、縦型（ショート）と横型（本編）で変えないと潰れる。
    それを決めるためだけに動画を丸ごと読むのは無駄なので、ここだけ先に軽く見る。
    読めなければ None（点検そのものは落とさない）。
    """
    path = Path(path)
    if not path.exists():
        return None
    result = subprocess.run([ffmpeg_exe(), "-i", str(path)], **CAPTURE)
    err = result.stderr or ""
    found = re.search(r"Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", err)
    if not found:
        return None
    hours, minutes, seconds = found.groups()
    size = re.search(r"Video:[^\n]*?\s(\d{2,5})x(\d{2,5})", err)
    return {
        "duration": int(hours) * 3600 + int(minutes) * 60 + float(seconds),
        "width": int(size.group(1)) if size else 0,
        "height": int(size.group(2)) if size else 0,
        "audio": "Audio:" in err,
    }


def scan(
    path: Path,
    *,
    step: float,
    thumb: tuple[int, int],
    scene_fps: int = SCAN_SCENE_FPS,
    scene_base: float = SCAN_SCENE_BASE,
    window: float = SCAN_WINDOW,
    audio: bool = True,
) -> tuple[str, bytes]:
    """**動画を1回だけ読んで**、点検に要るものをまとめて取る。

    返すのは (ffmpeg の出力, 一定間隔のコマの生データ)。読み解くのは tools/qc.py。
    1本の mp4 は 40〜50MB あるので、scene 検出・音の大きさ・コマ抜きで3回起こすと
    その回数ぶん丸ごと読み直すことになる。filter_complex で枝を分けて1回で済ませる。

    枝は4つ:
      [s] 画面の変化（scene の点数を metadata で出す。しきい値は後から当てる）
      [t] `step` 秒ごとのコマ（`thumb` の大きさの生データを pipe:1 に流す。
          何秒のコマなのかは showinfo が出す＝番号×step と決め打ちにしない）
      [x] 音の大きさ（loudnorm の測定値）
      [y] `window` 秒ごとの音の大きさ（astats の RMS。語りの切れ目を後から探す）
    """
    width, height = thumb
    chains = [
        "[0:v]split=2[sv][tv]",
        f"[sv]fps={scene_fps},scale=320:-2,select='gt(scene,{scene_base})',metadata=mode=print[s]",
        # **`fps=1/step` は使わない。**あれは区間ごとに「最後に来たコマ」を残すので、
        # 出てくる絵が区間の終わりのもの（＝1つ後ろ）になる。select なら狙った時刻の
        # コマがそのまま出て、showinfo が**元の動画での時刻**を出す
        f"[tv]select='isnan(prev_selected_t)+gte(t-prev_selected_t,{step:g})',"
        f"scale={width}:{height}:flags=bicubic,format=rgb24,showinfo[t]",
    ]
    maps = ["-map", "[s]", "-f", "null", "-"]
    if audio:
        samples = max(1, int(48000 * window))
        chains += [
            "[0:a]asplit=2[la][sa]",
            "[la]loudnorm=print_format=json[x]",
            f"[sa]aresample=48000,asetnsamples=n={samples},"
            "astats=metadata=1:reset=1:measure_perchannel=none:measure_overall=RMS_level,"
            "ametadata=mode=print:key=lavfi.astats.Overall.RMS_level[y]",
        ]
        maps += ["-map", "[x]", "-f", "null", "-", "-map", "[y]", "-f", "null", "-"]
    # **`-fps_mode passthrough` が要る。**rawvideo は既定で元のコマ数に合わせて
    # 同じ絵を水増しするので、14枚のつもりが8,399枚（1.4GB）流れてくる
    maps += ["-map", "[t]", "-fps_mode", "passthrough", "-f", "rawvideo", "pipe:1"]
    command = [
        ffmpeg_exe(), "-hide_banner", "-nostats", "-i", str(path),
        "-filter_complex", ";".join(chains), *maps,
    ]
    done = subprocess.run(command, capture_output=True)
    err = (done.stderr or b"").decode("utf-8", errors="replace")
    if done.returncode != 0:
        tail = "\n".join(err.strip().splitlines()[-15:])
        raise FfmpegError(f"ffmpeg が失敗しました（点検の読み取り、exit {done.returncode}）:\n{tail}")
    return err, done.stdout or b""
