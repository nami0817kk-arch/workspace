#!/bin/sh
# 海面の回の 10 本: 声 → 映像の事前点検 → 書き出し → 点検 を 1 本ずつ。最後に本編をつなぐ(--skip-build)。
# projects/naze で sh episodes/geoid/build_all.sh [回 …]。メモリが少ないので並べない。動いている naze の処理が無いことを先に確かめる。
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
for e in ${*:-ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5}; do
  log="out/_geoid_build_$e.log"
  { python -m naze voice "episodes/geoid/$e" && python -m naze vqc "episodes/geoid/$e" && python -m naze compose "episodes/geoid/$e" && python -m naze qc "episodes/geoid/$e"; } > "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
if [ $# -eq 0 ]; then python -m naze long episodes/geoid --skip-build > out/_geoid_long.log 2>&1; echo "long 終了 $? $(date +%H:%M)"; fi
