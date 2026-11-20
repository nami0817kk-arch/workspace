#!/bin/sh
# サムライドライブのセット 11 本(計算の回)を声から作って点検し、本編をつなぐ。projects/naze で sh episodes/samurai/build_all.sh
set -u
export PYTHONIOENCODING=utf-8
for e in ch1 ch2 ch3 ch4 ch5 ch6 s1 s2 s3 s4 s5; do
  log="out/_samurai_build_$e.log"
  python -m naze all "episodes/samurai/$e" > "$log" 2>&1 && python -m naze qc "episodes/samurai/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/samurai --skip-build > out/_samurai_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
python episodes/samurai/fix_peak.py >> out/_samurai_build_long.log 2>&1
echo "ピーク抑え 終了 $? $(date +%H:%M)"
