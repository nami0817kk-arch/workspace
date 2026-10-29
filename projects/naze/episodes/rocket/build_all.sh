#!/bin/sh
# ロケットのセット 10 本(計算の回)を声から作って点検し、本編をつなぐ。projects/naze で sh episodes/rocket/build_all.sh
set -u
export PYTHONIOENCODING=utf-8 PYTHONUTF8=1
for e in ch1 ch2 ch3 ch4 ch5 s1 s2 s3 s4 s5; do
  log="out/_rocket_build_$e.log"
  # 声がまだ無ければ all(声から)、手で声を作ってあれば compose だけ
  if [ -f "out/rocket_$e/timeline.json" ]; then step=compose; else step=all; fi
  python -m naze $step "episodes/rocket/$e" > "$log" 2>&1 && python -m naze qc "episodes/rocket/$e" >> "$log" 2>&1
  echo "$e 終了 $? $(date +%H:%M)"
done
python -m naze long episodes/rocket --skip-build > out/_rocket_build_long.log 2>&1
echo "本編 終了 $? $(date +%H:%M)"
python episodes/rocket/fix_peak.py >> out/_rocket_build_long.log 2>&1
echo "ピーク抑え 終了 $? $(date +%H:%M)"
