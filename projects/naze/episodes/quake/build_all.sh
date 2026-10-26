#!/bin/sh
# 地震のセット 10 本を書き出して点検し、本編をつなぐ。projects/naze で sh episodes/quake/build_all.sh
# 2 本ずつ並べて回す(1 コマ約 0.3 秒。全部で 2 時間ほど)
set -u
export PYTHONIOENCODING=utf-8
run() {
  python -m naze compose "episodes/quake/$1" > "out/_build_$1.log" 2>&1 && python -m naze qc "episodes/quake/$1" >> "out/_build_$1.log" 2>&1
  echo "$1 終了 $?"
}
for pair in "ch1 s1" "ch2 s2" "ch3 s3" "ch4 s4" "ch5 s5"; do
  set -- $pair
  run $1 & run $2 & wait
done
python -m naze long episodes/quake --skip-build > out/_build_long.log 2>&1
echo "本編 終了 $?"
