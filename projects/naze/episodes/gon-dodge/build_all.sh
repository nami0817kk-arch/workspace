#!/bin/sh
# ゴンのドッジボールのセット 13 本(計算の回)を、声ができた状態から書き出して点検し、本編をつなぐ。projects/naze で sh episodes/gon-dodge/build_all.sh [章…]
# 声は先に `python -m naze voice` で作ってある前提(compose は voice をやり直さない)。
set -u
export PYTHONIOENCODING=utf-8
list=${*:-"ch1 ch2 ch3 ch4 ch5 ch6 ch7 ch8 s1 s2 s3 s4 s5"}
for e in $list; do
  log="out/_gon_build_$e.log"
  python -m naze compose "episodes/gon-dodge/$e" > "$log" 2>&1 && python -m naze qc "episodes/gon-dodge/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
