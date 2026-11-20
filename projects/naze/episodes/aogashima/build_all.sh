#!/bin/sh
# 青ヶ島の回の 10 本を 1 本ずつ書き出して点検し、最後に本編をつなぐ。projects/naze で sh episodes/aogashima/build_all.sh [回 …]
# 声は先に `naze voice` で作ってある前提。メモリが少ないので並べずに 1 本ずつ。
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
for e in ${*:-ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5}; do
  log="out/_aoga_build_$e.log"
  python -m naze compose "episodes/aogashima/$e" > "$log" 2>&1 && python -m naze qc "episodes/aogashima/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
