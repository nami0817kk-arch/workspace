#!/bin/sh
# 海を抜く回のセット 10 本を 4 本ずつ並べて書き出し、点検まで。projects/naze で sh episodes/drain/build_all.sh [回 …]
# 声は先に `naze voice` で作ってある前提。
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
eps="${*:-ch5 ch4 ch2 ch3 ch1 s1 s2 s3 s4 s5}"
one() {
  log="out/_drain_build_$1.log"
  python -m naze compose "episodes/drain/$1" > "$log" 2>&1 && python -m naze qc "episodes/drain/$1" >> "$log" 2>&1
  echo "$1 終了 $? $(date +%H:%M)"
}
export -f one 2>/dev/null
for e in $eps; do echo $e; done | xargs -P ${NP:-3} -I{} sh -c '
  log="out/_drain_build_{}.log"
  python -m naze compose "episodes/drain/{}" > "$log" 2>&1 && python -m naze qc "episodes/drain/{}" >> "$log" 2>&1
  echo "{} 終了 $? $(date +%H:%M)"'
