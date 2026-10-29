#!/bin/sh
# ノックアップストリームのセット 10 本(計算の回)を動画にして点検し、本編をつなぐ。projects/naze で sh episodes/knockup/build_all.sh
set -u
export PYTHONIOENCODING=utf-8
for e in ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5; do
  log="out/_knockup_build_$e.log"
  python -m naze compose "episodes/knockup/$e" > "$log" 2>&1 && python -m naze qc "episodes/knockup/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/knockup --skip-build > out/_knockup_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
python episodes/knockup/fix_peak.py >> out/_knockup_build_long.log 2>&1
echo "ピーク抑え 終了 $? $(date +%H:%M)"
