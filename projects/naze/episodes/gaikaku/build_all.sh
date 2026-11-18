#!/bin/bash
# 首都圏外郭放水路の回を全部書き出す(ショート 5 本 → 本編 5 章 → つなぐ → 点検)。途中でも、できたものは飛ばして続きから。
cd "$(dirname "$0")/../.."
export PYTHONIOENCODING=utf-8
for n in s1 s2 s3 s4 s5; do
  echo "## compose $n"; python -X utf8 -m naze compose episodes/gaikaku/$n 2>&1 | tail -3
  echo "## qc $n"; python -X utf8 -m naze qc episodes/gaikaku/$n 2>&1 | tail -12
done
for n in ch1 ch2 ch3 ch4 ch5; do
  echo "## compose $n"; python -X utf8 -m naze compose episodes/gaikaku/$n 2>&1 | tail -3
done
echo "## long"; python -X utf8 -m naze long episodes/gaikaku 2>&1 | tail -5
echo "## qc long"; python -X utf8 -m naze qc episodes/gaikaku 2>&1 | tail -15
echo "## DONE"
