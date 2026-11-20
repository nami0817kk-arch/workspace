#!/bin/sh
# 宇宙エレベーターのセット 11 本(計算の回)を点検まで作り、本編をつなぐ。projects/naze で sh episodes/elevator/build_all.sh
# 声は先に `naze voice` で作ってある前提(無ければ all)。二重に起動しない。
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
for e in ch1 ch2 ch3 ch4 ch5 ch6 s1 s2 s3 s4 s5; do
  log="out/_elevator_build_$e.log"
  if [ -f "out/elevator_$e/timeline.json" ]; then step=compose; else step=all; fi
  python -m naze $step "episodes/elevator/$e" > "$log" 2>&1 && python -m naze qc "episodes/elevator/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/elevator --skip-build > out/_elevator_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
python episodes/elevator/fix_peak.py >> out/_elevator_build_long.log 2>&1
echo "ピーク抑え 終了 $? $(date +%H:%M)"
