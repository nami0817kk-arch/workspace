#!/bin/sh
# 海面の回の 10 本。projects/naze で sh episodes/geoid/build_all.sh [回 …]
# 1) 声と映像の事前点検を 1 本ずつ(声が無い回だけ。VOICEVOX は 1 つずつ)
# 2) 書き出し → 点検を NP 本(既定 3)ずつ並べる。compose は veryfast なので 1 本あたりのメモリは小さい
# 3) 引数なしのときは最後に本編をつなぐ(--skip-build)
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
eps="${*:-ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5}"
for e in $eps; do
  log="out/_geoid_build_$e.log"
  if [ ! -f "out/geoid_$e/timeline.json" ]; then
    { python -m naze voice "episodes/geoid/$e" && python -m naze vqc "episodes/geoid/$e"; } > "$log" 2>&1 || { echo "$e 声で失敗 $(date +%H:%M)"; continue; }
  else
    : > "$log"
  fi
  echo "$e 声 済み $(date +%H:%M)"
done
for e in $eps; do echo $e; done | xargs -P ${NP:-3} -I{} sh -c '
  log="out/_geoid_build_{}.log"
  { python -m naze compose "episodes/geoid/{}" && python -m naze qc "episodes/geoid/{}"; } >> "$log" 2>&1
  echo "{} 終了 $? $(date +%H:%M)"'
if [ $# -eq 0 ]; then python -m naze long episodes/geoid --skip-build > out/_geoid_long.log 2>&1; echo "long 終了 $? $(date +%H:%M)"; fi
