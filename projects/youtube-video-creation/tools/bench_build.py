# -*- coding: utf-8 -*-
"""本編の書き出しにかかる時間を、内訳つきで測る（2026-10-08）。

    python tools/bench_build.py scripts/20261007_messi_farewell.md --out <一時ディレクトリ>
    python tools/bench_build.py scripts/<名前>.md --out <dir> --short     # ショート（縦）

**本番の output/<名前>/ には書かない。**`--out` は必須で、output/ の下は断る。
声の控え（output/<名前>/audio/*.wav）を先に写すので、声の合成はほぼ0秒で済む。

内訳は「声」「音の混ぜ」「絵を描く（frame_entries。保存を含む）」「画像の保存」
「ffmpeg（呼び出し元ごと）」「サムネ」「字幕・概要欄」。結果は <out>/bench.json にも残す。
"""
from __future__ import annotations

import argparse
import inspect
import json
import shutil
import sys
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from PIL import Image  # noqa: E402

from src import audio, ffmpeg, pipeline, subtitles  # noqa: E402
from src.render import Renderer  # noqa: E402

TIMES: dict[str, float] = defaultdict(float)
COUNTS: dict[str, int] = defaultdict(int)


def _timed(label: str, func):
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        try:
            return func(*args, **kwargs)
        finally:
            TIMES[label] += time.perf_counter() - start
            COUNTS[label] += 1
    return wrapper


def _patch() -> None:
    pipeline.synthesize_script = _timed("声の合成", pipeline.synthesize_script)
    pipeline.build_thumbnail = _timed("サムネ", pipeline.build_thumbnail)
    audio.mix = _timed("音の混ぜ", audio.mix)
    subtitles.write_outputs = _timed("字幕・概要欄", subtitles.write_outputs)
    Renderer.frame_entries = _timed("絵を描く(保存込み)", Renderer.frame_entries)

    original_run = ffmpeg.run

    def run(args, quiet=True):
        caller = inspect.stack()[1].function
        start = time.perf_counter()
        try:
            return original_run(args, quiet)
        finally:
            TIMES[f"ffmpeg:{caller}"] += time.perf_counter() - start
            COUNTS[f"ffmpeg:{caller}"] += 1

    ffmpeg.run = run

    original_save = Image.Image.save

    def save(self, fp, *args, **kwargs):
        start = time.perf_counter()
        try:
            return original_save(self, fp, *args, **kwargs)
        finally:
            folder = Path(str(fp)).parent.name if isinstance(fp, (str, Path)) else "?"
            suffix = Path(str(fp)).suffix if isinstance(fp, (str, Path)) else ""
            label = f"保存:{folder}{suffix}/{self.mode}"
            TIMES[label] += time.perf_counter() - start
            COUNTS[label] += 1

    Image.Image.save = save


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("script")
    parser.add_argument("--out", required=True, help="書き出し先（output/ の下は不可）")
    parser.add_argument("--short", action="store_true", help="ショート（縦）を測る")
    parser.add_argument("--keep-work", action="store_true", help="中間フレームを残す")
    args = parser.parse_args(argv)

    out = Path(args.out).resolve()
    if (ROOT / "output").resolve() in out.parents or out == (ROOT / "output").resolve():
        print("output/ の下には書きません（本番の出力を上書きしないため）", file=sys.stderr)
        return 2
    script_path = Path(args.script)
    stem = script_path.stem
    cached = ROOT / "output" / (f"{stem}_short" if args.short else stem) / "audio"
    if cached.is_dir():
        (out / "audio").mkdir(parents=True, exist_ok=True)
        for wav in cached.glob("*.wav"):
            target = out / "audio" / wav.name
            if not target.exists():
                shutil.copy2(wav, target)

    from src.config import load_config
    from src.assets import ensure_assets
    from src.script_model import load_script

    config = load_config()
    ensure_assets(config)
    _patch()
    start = time.perf_counter()
    if args.short:
        from src import shorts

        short = shorts.trim(load_script(script_path), "")
        crest_bg = shorts.crest_background(short, out)
        if crest_bg:
            short.background = crest_bg
            for scene in short.scenes:
                scene.background = crest_bg
        result = pipeline.build_script(short, shorts.portrait(config), out,
                                       keep_work=args.keep_work, max_seconds=shorts.MAX_SECONDS)
    else:
        result = pipeline.build(script_path, config, out_dir=out, keep_work=args.keep_work)
    total = time.perf_counter() - start

    size = Path(result.video).stat().st_size
    report = {
        "script": str(script_path),
        "total_seconds": round(total, 1),
        "video_seconds": round(result.duration, 1),
        "video_bytes": size,
        "backend": result.backend,
        "parts": {k: {"seconds": round(v, 2), "count": COUNTS[k]}
                  for k, v in sorted(TIMES.items(), key=lambda kv: -kv[1])},
    }
    (out / "bench.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"全体 {total:.1f}秒　動画 {result.duration:.1f}秒　{size / 1e6:.1f}MB　声={result.backend}")
    for key, value in report["parts"].items():
        print(f"  {value['seconds']:8.2f}秒  ×{value['count']:<5d} {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
