#!/bin/bash
# VOICEVOX CORE 一式を、GitHub API を使わずに直接URLで組み立てる（Linux x64 用）。
#
# ふつうのPCなら scripts/setup_voicevox_core.py（公式ダウンローダ）でよい。
# これは Claude Code のクラウド環境のためのもの。そこでは
#   ・認証つき API → コンテナのトークンが GitHub 本体に通らない（Bad credentials）
#   ・匿名 API     → 共有IPのレート制限で弾かれる
# が、リリースの「ファイル本体」は直接URLで落ちる。API が要るのは
# ファイル名を聞くためだけなので、名前を先に確かめて（git ls-remote と
# ダウンローダのソースから）、本体を直接取る。
#
# 落とし終わると `python -m src.cli speakers` が backend: core で答える。
# モデルの利用規約は vendor/voicevox/models/TERMS.txt を必ず読むこと。
set -euo pipefail
DIR=/home/user/youtube-video-creation/vendor/voicevox
mkdir -p "$DIR/models/vvms" "$DIR/onnxruntime" "$DIR/dict"

get() { curl -sSL --retry 3 --max-time 600 -o "$2" "$1"; }

echo "[1/4] 辞書"
get "https://github.com/r9y9/open_jtalk/releases/download/v1.11.1/open_jtalk_dic_utf_8-1.11.tar.gz" /tmp/dic.tar.gz
tar -xzf /tmp/dic.tar.gz -C "$DIR/dict"

echo "[2/4] ONNX Runtime"
get "https://github.com/VOICEVOX/onnxruntime-builder/releases/download/voicevox_onnxruntime-1.17.3/voicevox_onnxruntime-linux-x64-1.17.3.tgz" /tmp/ort.tgz
tar -xzf /tmp/ort.tgz -C "$DIR/onnxruntime"

echo "[3/4] 音声モデル 25本（トーク用のみ）+ 利用規約"
for n in $(seq 0 24); do echo "$n.vvm"; done | xargs -P 4 -I{} \
  curl -sSL --retry 3 --max-time 600 -o "$DIR/models/vvms/{}" \
  "https://github.com/VOICEVOX/voicevox_vvm/releases/download/0.16.4/{}"
get "https://github.com/VOICEVOX/voicevox_vvm/releases/download/0.16.4/TERMS.txt" "$DIR/models/TERMS.txt"
get "https://github.com/VOICEVOX/voicevox_vvm/releases/download/0.16.4/README.txt" "$DIR/models/README.txt" || true

echo "[4/4] Python バインディング"
get "https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.4/voicevox_core-0.16.4-cp310-abi3-manylinux_2_34_x86_64.whl" /tmp/vv.whl
pip install -q /tmp/vv.whl

echo "--- 索引 ---"
python - <<'PYEOF'
import sys; sys.path.insert(0, ".")
from pathlib import Path
from src.tts import CoreBackend
index = CoreBackend(Path("vendor/voicevox")).build_index()
print(f"話者 {len(index['speakers'])} 人 / vvm {len(index['vvms'])} 種類")
PYEOF

echo "--- 検収 ---"
ls "$DIR/models/vvms" | wc -l
find "$DIR" -name "libvoicevox_onnxruntime.so*" | head -2
find "$DIR" -name "open_jtalk_dic_utf_8*" -maxdepth 3 -type d | head -1
du -sh "$DIR"
