#!/usr/bin/env bash
# 広告付きアプリの公開サイト（ストアのマーケティング URL のホスト）を外から叩いて、
# AdMob が app-ads.txt を確かめられる状態かを点検する。
#
#   scripts/check-app-site.sh <host> [pub-id]
#   例) scripts/check-app-site.sh goso-boat.pages.dev pub-6409014819339195
#
# 2026-10-02 に、サカマネと護送ボートで AdMob の「アプリを確認」が
# 「詳細情報が一致しません」で通らなかった。原因は /robots.txt に実体が無く、
# Cloudflare Pages がトップページの HTML を 200 で返していたこと。AdMob のクローラは
# robots.txt を読めず、app-ads.txt の確認まで止まる（docs/app-pitfalls.md 項目8）。
# 「200 が返る」だけでは見逃すので、中身がテキストかまで見る。
#
# どれか1つでも外れたら exit 1。アプリのサイト公開・リリースのワークフローから呼ぶ。
set -u
host="${1:?ホスト名を渡す（例: goso-boat.pages.dev）}"
pub="${2:-pub-6409014819339195}"
base="https://${host}"
bad=0

fail() { echo "::error::${host}: $1"; bad=1; }
ok() { echo "  OK  $1"; }

# 1) robots.txt がテキストで返る（HTML ではない）
code=$(curl -s -o /tmp/robots.txt -w "%{http_code}" "$base/robots.txt")
type=$(curl -s -o /dev/null -w "%{content_type}" "$base/robots.txt")
if [ "$code" != "200" ]; then
  fail "/robots.txt が $code。site/robots.txt を実体として置く"
elif grep -qi "<!doctype\|<html" /tmp/robots.txt || [[ "$type" != text/plain* ]]; then
  fail "/robots.txt に HTML が返っている（$type）。site/robots.txt を実体として置く。無いと AdMob が app-ads.txt を確かめられない"
else
  ok "/robots.txt はテキスト"
  grep -qi "Google-adstxt" /tmp/robots.txt || echo "  注意 robots.txt に Google-adstxt の行が無い（AdMob のヘルプの推奨）"
fi

# 2) app-ads.txt がテキストで、自分の発行元の行がある
code=$(curl -s -o /tmp/app-ads.txt -w "%{http_code}" "$base/app-ads.txt")
if [ "$code" != "200" ]; then
  fail "/app-ads.txt が $code"
elif grep -qi "<!doctype\|<html" /tmp/app-ads.txt; then
  fail "/app-ads.txt に HTML が返っている"
elif ! grep -q "google.com, ${pub}, DIRECT, f08c47fec0942fa0" /tmp/app-ads.txt; then
  fail "/app-ads.txt に「google.com, ${pub}, DIRECT, f08c47fec0942fa0」の行が無い"
else
  ok "/app-ads.txt に ${pub} の行がある"
fi

# 3) 無いパスはトップページではなく 404（SPA の代わりに中身を返すと、ほかのファイルでも同じ取り違えが起きる）
code=$(curl -s -o /tmp/missing.html -w "%{http_code}" "$base/no-such-file-$(date +%s).txt")
if [ "$code" = "404" ]; then
  ok "無いパスは 404"
else
  # Flutter の Web版を出しているサイト（サカマネ）は 200 で画面を返す作りなので、ここは注意にとどめる
  echo "  注意 無いパスが $code を返す（site/404.html を置くと 404 になる）"
fi

exit $bad
