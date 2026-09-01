#!/usr/bin/env python3
"""VOICEVOX CORE 一式を vendor/voicevox に用意する。

VOICEVOX アプリを起動しなくても音声合成できるようにするためのセットアップ。
公式ダウンローダを取得して ONNX Runtime・Open JTalk 辞書・音声モデルを落とし、
Python バインディングの wheel を入れて、style_id の索引を作るところまでやる。

    python scripts/setup_voicevox_core.py

VOICEVOX アプリを使う運用なら、このスクリプトは不要（config の backend は auto のままでよい）。
"""

from __future__ import annotations

import argparse
import json
import platform
import subprocess
import sys
import urllib.request
from pathlib import Path

CORE_VERSION = "0.16.4"
ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DIR = ROOT / "vendor" / "voicevox"
RELEASE = f"https://github.com/VOICEVOX/voicevox_core/releases/download/{CORE_VERSION}"

# (ダウンローダのアセット名, Python wheel のアセット名)
TARGETS = {
    ("Linux", "x86_64"): (
        "download-linux-x64",
        f"voicevox_core-{CORE_VERSION}-cp310-abi3-manylinux_2_34_x86_64.whl",
    ),
    ("Linux", "aarch64"): (
        "download-linux-arm64",
        f"voicevox_core-{CORE_VERSION}-cp310-abi3-manylinux_2_34_aarch64.whl",
    ),
    ("Windows", "AMD64"): (
        "download-windows-x64.exe",
        f"voicevox_core-{CORE_VERSION}-cp310-abi3-win_amd64.whl",
    ),
    ("Darwin", "arm64"): (
        "download-osx-arm64",
        f"voicevox_core-{CORE_VERSION}-cp310-abi3-macosx_11_0_arm64.whl",
    ),
    ("Darwin", "x86_64"): (
        "download-osx-x64",
        f"voicevox_core-{CORE_VERSION}-cp310-abi3-macosx_10_12_x86_64.whl",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="VOICEVOX CORE をローカルに用意する")
    parser.add_argument("--dir", default=str(DEFAULT_DIR), help="配置先")
    parser.add_argument(
        "--models-pattern",
        default="[0-9]*.vvm",
        help="落とす音声モデル。既定はトーク用のみ（ソング用を含めるなら '*.vvm'）",
    )
    parser.add_argument("--skip-wheel", action="store_true", help="wheel のインストールを飛ばす")
    args = parser.parse_args()

    key = (platform.system(), platform.machine())
    if key not in TARGETS:
        print(f"未対応の環境です: {key}", file=sys.stderr)
        print("https://github.com/VOICEVOX/voicevox_core/releases から手動で取得してください。")
        return 1
    downloader_name, wheel_name = TARGETS[key]

    target_dir = Path(args.dir)
    target_dir.mkdir(parents=True, exist_ok=True)

    # 1. 公式ダウンローダ
    downloader = target_dir / downloader_name
    if not downloader.exists():
        print(f"[1/4] ダウンローダを取得: {downloader_name}")
        _download(f"{RELEASE}/{downloader_name}", downloader)
        downloader.chmod(0o755)
    else:
        print("[1/4] ダウンローダは取得済み")

    # 2. ONNX Runtime / 辞書 / 音声モデル
    print("[2/4] ONNX Runtime・辞書・音声モデルを取得（数GBあるので時間がかかります）")
    result = subprocess.run(
        [
            str(downloader),
            "--only", "onnxruntime", "dict", "models",
            "--models-pattern", args.models_pattern,
            "-o", str(target_dir),
        ]
    )
    if result.returncode != 0:
        print("ダウンローダが失敗しました。", file=sys.stderr)
        return result.returncode

    # 3. Python バインディング
    if args.skip_wheel:
        print("[3/4] wheel のインストールはスキップ")
    else:
        print(f"[3/4] Python バインディングを導入: {wheel_name}")
        wheel = target_dir / wheel_name
        if not wheel.exists():
            _download(f"{RELEASE}/{wheel_name}", wheel)
        subprocess.run([sys.executable, "-m", "pip", "install", str(wheel)], check=True)

    # 4. style_id の索引
    print("[4/4] style_id の索引を作成")
    sys.path.insert(0, str(ROOT))
    from src.tts import CoreBackend

    backend = CoreBackend(target_dir)
    index = backend.build_index()
    print(f"  話者 {len(index['speakers'])} 人 / スタイル {len(index['vvms'])} 種類")

    print("\n完了しました。`python -m src.cli speakers` で話者一覧を確認できます。")
    print("VOICEVOX 音声モデルの利用規約（TERMS.txt）を必ず確認してください。")
    return 0


def _download(url: str, target: Path) -> None:
    with urllib.request.urlopen(url) as response, open(target, "wb") as out:
        total = int(response.headers.get("Content-Length", 0))
        done = 0
        while chunk := response.read(1 << 20):
            out.write(chunk)
            done += len(chunk)
            if total:
                print(f"\r  {done * 100 // total:3d}%  {done >> 20}MB / {total >> 20}MB", end="")
        print()


if __name__ == "__main__":
    raise SystemExit(main())
