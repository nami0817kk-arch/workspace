#!/usr/bin/env bash
# リモートデバッグを有効にした Chrome を起動する(macOS / Linux)。
#
# src/browser/local_chrome.py の接続先になる Chrome を立ち上げる。
# 既定では専用プロファイルを使うため、普段使いの Chrome を閉じる必要はない。
# 普段のプロファイルを使いたい場合は --default-profile を付ける(先に Chrome を終了しておくこと)。
#
#   ./scripts/start-chrome-debug.sh
#   ./scripts/start-chrome-debug.sh --port 9333 --default-profile
set -euo pipefail

PORT=9222
START_URL="about:blank"
USE_DEFAULT_PROFILE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --url) START_URL="$2"; shift 2 ;;
    --default-profile) USE_DEFAULT_PROFILE=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "不明な引数: $1" >&2; exit 1 ;;
  esac
done

CANDIDATES=(
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  "$(command -v google-chrome || true)"
  "$(command -v google-chrome-stable || true)"
  "$(command -v chromium || true)"
)

CHROME=""
for c in "${CANDIDATES[@]}"; do
  if [[ -n "$c" && -x "$c" ]]; then CHROME="$c"; break; fi
done

if [[ -z "$CHROME" ]]; then
  echo "Chrome が見つかりません。CHROME 環境変数で実行ファイルを指定してください。" >&2
  exit 1
fi

ARGS=("--remote-debugging-port=$PORT")

if [[ "$USE_DEFAULT_PROFILE" -eq 1 ]]; then
  echo "既定プロファイルで起動します(ログイン状態と拡張機能を引き継ぎます)。"
  echo "Chrome が起動中だとデバッグポートが開きません。先に完全に終了してください。"
else
  PROFILE_DIR="${HOME}/.cache/ai-lab/chrome-debug-profile"
  mkdir -p "$PROFILE_DIR"
  ARGS+=("--user-data-dir=$PROFILE_DIR")
  echo "専用プロファイルで起動します: $PROFILE_DIR"
fi

ARGS+=("$START_URL")

"$CHROME" "${ARGS[@]}" >/dev/null 2>&1 &

echo
echo "Chrome をデバッグポート $PORT で起動しました。"
echo "接続確認: http://127.0.0.1:$PORT/json/version"
echo "操作するには: python -m src.browser.local_chrome --list"
