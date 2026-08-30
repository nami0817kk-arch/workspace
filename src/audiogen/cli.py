"""コマンドラインインターフェース。

    python -m audiogen sfx coin -o output/coin.wav
    python -m audiogen bgm --style battle --key A --bars 16 --seed 7
    python -m audiogen list
    python -m audiogen demo -d output/demo
"""

from __future__ import annotations

import argparse
import inspect
import os
import sys
from typing import Sequence

from . import bgm as bgm_module
from . import drums, notes, sfx
from .core import SAMPLE_RATE, duration_of, write_wav


def _default_path(directory: str, name: str) -> str:
    return os.path.join(directory, f"{name}.wav")


def _report(path: str, samples: Sequence[float], sr: int, channels: int) -> None:
    seconds = duration_of(samples, sr, channels)
    label = "stereo" if channels == 2 else "mono"
    print(f"wrote {path} ({seconds:.2f}s, {sr}Hz, {label})")


def cmd_sfx(args: argparse.Namespace) -> int:
    if args.name not in sfx.PRESETS:
        print(f"unknown sfx preset: {args.name}", file=sys.stderr)
        print(f"available: {', '.join(sfx.available())}", file=sys.stderr)
        return 2

    params = {}
    if args.pitch != 1.0:
        if "pitch" not in inspect.signature(sfx.PRESETS[args.name]).parameters:
            print(f"error: preset {args.name!r} does not support --pitch", file=sys.stderr)
            return 2
        params["pitch"] = args.pitch
    samples = sfx.generate(args.name, sr=args.rate, seed=args.seed, **params)

    path = args.output or _default_path(args.dir, args.name)
    write_wav(path, samples, sr=args.rate, channels=1)
    _report(path, samples, args.rate, 1)
    return 0


def cmd_bgm(args: argparse.Namespace) -> int:
    parts = [part for part in ("chords", "bass", "lead", "drums") if part not in args.without]
    config = bgm_module.BGMConfig(
        style=args.style,
        key=args.key,
        scale=args.scale,
        bpm=args.bpm,
        bars=args.bars,
        seed=args.seed,
        sr=args.rate,
        progression=args.progression,
        drum_pattern=args.drums,
        parts=parts,
        loop=not args.no_loop,
        stereo=args.stereo,
    )
    try:
        if args.stereo:
            samples = bgm_module.generate_stereo(config)
            channels = 2
        else:
            samples = bgm_module.generate(config)
            channels = 1
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    name = args.name or f"bgm_{args.style}"
    path = args.output or _default_path(args.dir, name)
    write_wav(path, samples, sr=args.rate, channels=channels)
    _report(path, samples, args.rate, channels)
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    print("SFX presets:")
    for name in sfx.available():
        print(f"  {name}")
    print("\nBGM styles:")
    for name in bgm_module.style_names():
        style = bgm_module.STYLES[name]
        print(f"  {name:<10} scale={style.scale} bpm={style.bpm} progression={style.progression}")
    print("\nDrum patterns:")
    print("  " + ", ".join(drums.pattern_names()))
    print("\nScales:")
    print("  " + ", ".join(sorted(notes.SCALES)))
    return 0


def cmd_demo(args: argparse.Namespace) -> int:
    os.makedirs(args.dir, exist_ok=True)
    for name in sfx.available():
        samples = sfx.generate(name, sr=args.rate, seed=args.seed)
        path = _default_path(args.dir, f"sfx_{name}")
        write_wav(path, samples, sr=args.rate)
        _report(path, samples, args.rate, 1)

    for name in bgm_module.style_names():
        config = bgm_module.BGMConfig(style=name, bars=args.bars, seed=args.seed, sr=args.rate)
        samples = bgm_module.generate(config)
        path = _default_path(args.dir, f"bgm_{name}")
        write_wav(path, samples, sr=args.rate)
        _report(path, samples, args.rate, 1)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="audiogen",
        description="BGM と効果音を生成して WAV に書き出す。",
    )
    parser.add_argument("--rate", type=int, default=SAMPLE_RATE, help=f"サンプリング周波数 (既定: {SAMPLE_RATE})")
    subparsers = parser.add_subparsers(dest="command", required=True)

    sfx_parser = subparsers.add_parser("sfx", help="効果音を1つ生成する")
    sfx_parser.add_argument("name", help=f"プリセット名 ({', '.join(sfx.available())})")
    sfx_parser.add_argument("-o", "--output", help="出力先の WAV パス")
    sfx_parser.add_argument("-d", "--dir", default="output", help="出力ディレクトリ (既定: output)")
    sfx_parser.add_argument("--seed", type=int, default=None, help="乱数シード(ノイズ系の再現用)")
    sfx_parser.add_argument("--pitch", type=float, default=1.0, help="音程の倍率 (既定: 1.0)")
    sfx_parser.set_defaults(func=cmd_sfx)

    bgm_parser = subparsers.add_parser("bgm", help="BGM を1曲生成する")
    bgm_parser.add_argument(
        "--style", default="calm", help=f"曲想 ({', '.join(bgm_module.style_names())})"
    )
    bgm_parser.add_argument("--key", default="C", help="キー(例: C, F#, A)")
    bgm_parser.add_argument("--scale", default=None, help=f"音階 ({', '.join(sorted(notes.SCALES))})")
    bgm_parser.add_argument("--bpm", type=int, default=None, help="テンポ")
    bgm_parser.add_argument("--bars", type=int, default=8, help="小節数 (既定: 8)")
    bgm_parser.add_argument("--seed", type=int, default=None, help="乱数シード(同じ値なら同じ曲)")
    bgm_parser.add_argument("--progression", default=None, help='コード進行(例: "I-V-vi-IV")')
    bgm_parser.add_argument(
        "--drums", default=None, help=f"ドラムパターン ({', '.join(drums.pattern_names())})"
    )
    bgm_parser.add_argument(
        "--without", nargs="*", default=[], choices=["chords", "bass", "lead", "drums"],
        help="外すパート",
    )
    bgm_parser.add_argument("--stereo", action="store_true", help="ステレオで書き出す")
    bgm_parser.add_argument("--no-loop", action="store_true", help="末尾の残響を切らずに残す")
    bgm_parser.add_argument("-n", "--name", default=None, help="出力ファイル名(拡張子なし)")
    bgm_parser.add_argument("-o", "--output", help="出力先の WAV パス")
    bgm_parser.add_argument("-d", "--dir", default="output", help="出力ディレクトリ (既定: output)")
    bgm_parser.set_defaults(func=cmd_bgm)

    list_parser = subparsers.add_parser("list", help="使えるプリセットを一覧する")
    list_parser.set_defaults(func=cmd_list)

    demo_parser = subparsers.add_parser("demo", help="全プリセットをまとめて書き出す")
    demo_parser.add_argument("-d", "--dir", default="output/demo", help="出力ディレクトリ")
    demo_parser.add_argument("--bars", type=int, default=4, help="BGM の小節数 (既定: 4)")
    demo_parser.add_argument("--seed", type=int, default=0, help="乱数シード (既定: 0)")
    demo_parser.set_defaults(func=cmd_demo)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
