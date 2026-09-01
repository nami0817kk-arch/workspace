"""videogen コマンドラインインターフェース。

    videogen build 構成.yaml -o out.mp4    画像・音声・字幕から動画を書き出す
    videogen build 構成.yaml --dry-run     実行せず、組み上がった ffmpeg のコマンドを見る
    videogen srt 構成.yaml                 字幕（SRT）だけを書き出す
    videogen probe ファイル                長さを測る
    videogen doctor                        ffmpeg が使えるか確かめる
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import __version__, build, ffmpeg, subtitles
from . import timeline as timeline_module
from .errors import VideogenError


def ensure_utf8_streams() -> None:
    """Windows のコンソールでも日本語を出せるようにする。"""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):  # 付け替えられない環境では諦める
            pass


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="videogen",
        description="画像・音声・字幕を1本の動画にまとめる",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--version", action="version", version=f"videogen {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    make = sub.add_parser("build", help="動画を書き出す")
    make.add_argument("timeline", help="構成ファイル（YAML / JSON）")
    make.add_argument("-o", "--out", default=None, help="出力先 (既定: 構成ファイルと同じ名前の .mp4)")
    make.add_argument("--size", default=None, help="出力サイズを上書きする 例: 1080x1920（縦動画）")
    make.add_argument("--fps", type=int, default=None, help="フレームレートを上書きする")
    make.add_argument("--bgm", default=None, help="BGM を上書きする")
    make.add_argument(
        "--burn", action="store_true", help="字幕を映像に焼き込む（libass が要る）"
    )
    make.add_argument(
        "--dry-run", action="store_true", help="実行せず、組み上がった ffmpeg のコマンドを表示する"
    )

    srt = sub.add_parser("srt", help="字幕（SRT）だけを書き出す")
    srt.add_argument("timeline", help="構成ファイル（YAML / JSON）")
    srt.add_argument("-o", "--out", default=None, help="出力先 (既定: 構成ファイルと同じ名前の .srt)")

    probe = sub.add_parser("probe", help="メディアファイルの長さを測る")
    probe.add_argument("file", help="対象のファイル")

    sub.add_parser("doctor", help="ffmpeg が使えるか確かめる")
    return parser


def _load(args: argparse.Namespace):
    loaded = timeline_module.load(args.timeline)
    for name in ("size", "bgm"):
        value = getattr(args, name, None)
        if value:
            setattr(loaded, name, value)
    if getattr(args, "fps", None):
        loaded.fps = args.fps
    timeline_module.parse_size(loaded.size)  # 上書きされた size をここで検査する
    return loaded


def _default_output(args: argparse.Namespace, suffix: str) -> Path:
    if getattr(args, "out", None):
        return Path(args.out)
    return Path(args.timeline).with_suffix(suffix)


def cmd_build(args: argparse.Namespace) -> int:
    loaded = _load(args)
    output = _default_output(args, ".mp4")
    result = build.render(loaded, output, dry_run=args.dry_run, burn=args.burn)

    if args.dry_run:
        print(f"{result.describe()}")
        print("ffmpeg " + " ".join(result.command))
        if result.srt:
            print(f"字幕: {result.srt}")
        return 0

    print(f"書き出しました: {result.describe()}")
    if result.srt:
        print(f"字幕: {result.srt}" + ("（映像に焼き込み済み）" if args.burn else ""))
    return 0


def cmd_srt(args: argparse.Namespace) -> int:
    loaded = timeline_module.load(args.timeline)
    durations = loaded.durations()
    path = subtitles.write_srt(
        [scene.text for scene in loaded.scenes], durations, _default_output(args, ".srt")
    )
    if path is None:
        print("字幕のあるシーンがありません（text を書いてください）")
        return 1
    print(f"書き出しました: {path}")
    return 0


def cmd_probe(args: argparse.Namespace) -> int:
    print(f"{args.file}: {ffmpeg.probe_seconds(args.file):.3f}秒")
    return 0


def cmd_doctor(_args: argparse.Namespace) -> int:
    if not ffmpeg.is_available():
        print("NG  ffmpeg が見つかりません", file=sys.stderr)
        print('    pip install -e ".[video]" で用意できます', file=sys.stderr)
        return 1
    print(f"OK  {ffmpeg.find_ffmpeg()}")
    print(f"    {ffmpeg.version()}")
    return 0


def main(argv: list[str] | None = None) -> int:
    ensure_utf8_streams()
    args = build_parser().parse_args(argv)
    handlers = {
        "build": cmd_build,
        "srt": cmd_srt,
        "probe": cmd_probe,
        "doctor": cmd_doctor,
    }
    try:
        return handlers[args.command](args)
    except VideogenError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1
    except (ValueError, OSError) as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
