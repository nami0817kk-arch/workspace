#!/bin/sh
# 富士山のセット 10 本を書き出して点検し、本編をつなぐ。projects/naze で sh episodes/fuji/build_all.sh [始める回]
# 地形は Blender で描くので 1 本ずつ。途中で止まっても再開できる(できた mp4 が点検に通っていれば飛ばす)。
# コマの画像は 1 章 11GB になるので、動画にできたら消す(2026-10-27 にディスクが満杯になって止まった)
set -u
export PYTHONIOENCODING=utf-8
start=${1:-ch1}
go=0
for e in ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5; do
  [ "$e" = "$start" ] && go=1
  [ $go = 0 ] && continue
  out="out/fuji_$e"
  if [ -f "$out/qc.json" ] && grep -q '"passed": true' "$out/qc.json" && [ ! -d "$out/frames" ]; then echo "$e 済み"; continue; fi
  log="out/_fuji_build_$e.log"
  python -m naze prep "episodes/fuji/$e" > "$log" 2>&1 \
    && python -m naze render "episodes/fuji/$e" >> "$log" 2>&1 \
    && python -m naze compose "episodes/fuji/$e" >> "$log" 2>&1 \
    && { python -m naze qc "episodes/fuji/$e" >> "$log" 2>&1 && rm -rf "$out/frames"; echo "$e 点検 $?(✖ ならコマを残す)"; }
  echo "$e 終了 $? $(date +%H:%M) 空き $(df -h /c | tail -1 | awk '{print $4}')"
done
python -m naze long episodes/fuji --skip-build > out/_fuji_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
