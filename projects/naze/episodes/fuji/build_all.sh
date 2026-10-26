#!/bin/sh
# 富士山のセット 10 本を書き出して点検し、本編をつなぐ。projects/naze で sh episodes/fuji/build_all.sh
# 地形は Blender で描くので 1 本ずつ(並べると取り合って遅くなる)。本編の章を先に、ショートを後に。途中で止まっても再開できる
set -u
export PYTHONIOENCODING=utf-8
for e in ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5; do
  log="out/_fuji_build_$e.log"
  python -m naze prep "episodes/fuji/$e" > "$log" 2>&1 \
    && python -m naze render "episodes/fuji/$e" >> "$log" 2>&1 \
    && python -m naze compose "episodes/fuji/$e" >> "$log" 2>&1 \
    && python -m naze qc "episodes/fuji/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/fuji --skip-build > out/_fuji_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
