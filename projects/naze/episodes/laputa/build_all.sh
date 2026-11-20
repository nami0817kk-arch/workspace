#!/bin/sh
# ラピュタを風船で浮かせるセット 16 本(計算の回)を点検まで作り、本編をつなぐ。projects/naze で sh episodes/laputa/build_all.sh [回 …]
# 声は先に `naze voice` で作ってある前提(無ければ all)。二重に起動しない。
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
eps="${*:-ch1 ch2 ch3 ch4 ch5 ch6 ch7 ch8 ch9 ch10 ch11 s1 s2 s3 s4 s5}"
for e in $eps; do
  log="out/_laputa_build_$e.log"
  if [ -f "out/laputa_$e/timeline.json" ]; then step=compose; else step=all; fi
  python -m naze $step "episodes/laputa/$e" > "$log" 2>&1 && python -m naze qc "episodes/laputa/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
