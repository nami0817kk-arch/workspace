#!/bin/sh
# 電子レンジのセット 10 本(計算の回)を動画にして点検し、本編をつなぐ。projects/naze で sh episodes/renji/build_all.sh
set -u
export PYTHONIOENCODING=utf-8
for e in ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5; do
  log="out/_renji_build_$e.log"
  python -m naze compose "episodes/renji/$e" > "$log" 2>&1 && python -m naze qc "episodes/renji/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/renji --skip-build > out/_renji_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
