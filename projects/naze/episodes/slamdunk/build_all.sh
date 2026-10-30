#!/bin/sh
# スラムダンクのセット 11 本(計算の回)を、声ができた状態から書き出して点検し、本編をつなぐ。projects/naze で sh episodes/slamdunk/build_all.sh
# 声は先に `python -m naze voice` で作ってある前提(compose は voice をやり直さない)。VOICEVOX は voice のときだけ要る。
set -u
export PYTHONIOENCODING=utf-8
for e in ch1 ch2 ch3 ch4 ch5 ch6 s1 s2 s3 s4 s5; do
  log="out/_slamdunk_build_$e.log"
  python -m naze compose "episodes/slamdunk/$e" > "$log" 2>&1 && python -m naze qc "episodes/slamdunk/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/slamdunk --skip-build > out/_slamdunk_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
python episodes/slamdunk/fix_peak.py >> out/_slamdunk_build_long.log 2>&1
echo "ピーク抑え 終了 $? $(date +%H:%M)"
