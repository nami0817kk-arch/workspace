"""ショートをまとめて書き出す。**音声合成（VOICEVOX）と描画を重ねる**（2026-10-16 ユーザー「2もやろ」）。

    python tools/short_batch.py scripts/a.md scripts/b.md … [--out-root DIR]

1本ずつ `short` を回すと、合成（VOICEVOX）→ 描画（ffmpeg）が順に並ぶ。VOICEVOX は同時に何本も
投げると timeout するので、**合成は1本ずつ**のまま、前の本を描いているあいだに次の本を合成する。

やり方は、合成の結果が行ごとの wav として `<出力先>/audio/` に残る（文・声が同じなら再利用される）ことを使う。
  1. 本体（このスクリプト）が、台本を順に「ショートの形に切って」合成だけ回す（先読み）
  2. 描画は、合成が済んだ本から順に `python -m src.cli short` を別プロセスで回す。合成は wav が
     残っているので一瞬で終わり、描画だけが走る
実測（10/16、鎌田の例）は 1本あたり合成が約1分・描画が約1.5分。重ねれば2本目から合成の分が隠れる。

守ること:
- 承認の関門（`approve`）は `short` が見る。ここでも先に見て、控えが無ければその本は飛ばす
- `short` の戻り値は当てにならないので、出力ファイル（video.mp4）の有無で成否を見る
- 合成の途中で止まった本は飛ばして次へ進み、最後に失敗の一覧を出す
"""
from __future__ import annotations

import argparse
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, ".")


def _out_dir(script: str, root: Path | None) -> Path:
    from src import shorts

    default = shorts.default_path(script)
    return (root / default.name) if root else default


def _presynth(script: str, out_dir: Path) -> None:
    """ショートの形に切って、合成だけ回す（wav を out_dir/audio に残す）。"""
    from src import shorts
    from src.cli import load_config
    from src.pipeline import create_backend, synthesize_script
    from src.script_model import load_script

    config = load_config(None)
    short = shorts.trim(load_script(script), "")
    portrait = shorts.portrait(config)
    out_dir.mkdir(parents=True, exist_ok=True)
    synthesize_script(short, portrait, out_dir / "audio", backend=create_backend(portrait, True))


def _render(script: str, out_dir: Path, root: Path | None) -> tuple[int, float]:
    started = time.time()
    cmd = [sys.executable, "-m", "src.cli", "short", script]
    if root:
        cmd += ["--out", str(out_dir)]
    code = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                          env={**__import__("os").environ, "PYTHONIOENCODING": "utf-8"}).returncode
    return code, time.time() - started


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("scripts", nargs="+")
    parser.add_argument("--out-root", default=None, help="出力先の親（既定は output/）。試すときだけ")
    parser.add_argument("--no-overlap", action="store_true", help="重ねずに1本ずつ（比べる用）")
    args = parser.parse_args(argv)
    root = Path(args.out_root) if args.out_root else None

    from src import approval

    work: queue.Queue = queue.Queue()
    failures: list[str] = []
    timings: list[tuple[str, float, float]] = []
    begin = time.time()

    def renderer() -> None:
        while True:
            item = work.get()
            if item is None:
                return
            script, out_dir, synth_secs = item
            code, secs = _render(script, out_dir, root)
            ok = (out_dir / "video.mp4").exists()
            timings.append((script, synth_secs, secs))
            print(f"{'○' if ok else '×'} {Path(script).stem}　合成{synth_secs:.0f}秒・描画{secs:.0f}秒"
                  f"（戻り値{code}）", flush=True)
            if not ok:
                failures.append(script)

    worker = None if args.no_overlap else threading.Thread(target=renderer)
    if worker:
        worker.start()
    for script in args.scripts:
        if not approval.is_approved(script):
            print(f"× {Path(script).stem}　承認の控えが無いので飛ばします", flush=True)
            failures.append(script)
            continue
        out_dir = _out_dir(script, root)
        started = time.time()
        try:
            _presynth(script, out_dir)
        except Exception as error:  # 合成で止まった本は飛ばして次へ
            print(f"× {Path(script).stem}　合成で失敗: {error}", flush=True)
            failures.append(script)
            continue
        synth_secs = time.time() - started
        if worker:
            work.put((script, out_dir, synth_secs))
        else:
            code, secs = _render(script, out_dir, root)
            ok = (out_dir / "video.mp4").exists()
            print(f"{'○' if ok else '×'} {Path(script).stem}　合成{synth_secs:.0f}秒・描画{secs:.0f}秒", flush=True)
            if not ok:
                failures.append(script)
    if worker:
        work.put(None)
        worker.join()
    print(f"\n全体 {time.time() - begin:.0f}秒（{len(args.scripts)}本）。失敗 {len(failures)}本")
    for script in failures:
        print(f"  × {script}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
