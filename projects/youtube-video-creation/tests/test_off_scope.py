# -*- coding: utf-8 -*-
"""扱わないと決めた題材を、集める段で落とすか（2026-10-11）。

**印は付いていたのに、落とす所が無かった。**`collect.LEAGUE_BY_HINT` は
「Jリーグ」「J1」に `japan` を付けるが、その印を見て外す処理が無く、
10/11 は候補470件のうち**約110件**が Jリーグ・国内の育成年代・女子だった。
毎日その量を人が読み飛ばしている。

決まりは CLAUDE.md の
「**Jリーグは扱わない**」（2026-09-07 ユーザー決定）
「**女子サッカーは扱わない**」（2026-09-16 ユーザー指示。日本人が絡んでも入れない）
「**扱うのは欧州7リーグ**」（2026-09-15）。

**いちばん大事なのは、海外でプレーする日本人を落とさないこと。**
検索で来ている上位5語のうち4語が日本人名で、登録が付くのも
日本人選手本人の発言のショートなので、ここを巻き込むと本末転倒になる。
"""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.gather import off_scope  # noqa: E402


@pytest.mark.parametrize("text", [
    "【今日のJリーグ】10月11日 キックオフ時間・放送予定",
    "J1リーグ 第33節の結果",
    "ルヴァンカップ 準決勝の組み合わせ",
    "天皇杯 4回戦",
    "USWNT player ratings: Wilson's 8/10 a bright spot",
    "なでしこジャパンのDF守屋が負傷離脱",
    "WEリーグ 開幕節の結果",
    "女子W杯の抽選",
    "全国高校サッカー選手権 県大会",
    "国スポ少年男子 準々決勝",
    "関東大学リーグ 第12節",
    "高円宮杯 プレミアリーグEAST 第18節",
    "U-17日本代表のメンバー発表",
])
def test_扱わない題材は落とす(text):
    assert off_scope(text), f"落とせていません: {text}"


@pytest.mark.parametrize("text", [
    "前田大然81分、イプスウィッチが土壇場で逆転",
    "久保建英がソシエダで2ゴール",
    "上田綺世が56分から出場、リールが暫定首位",
    "田中碧にBBC採点7。アーセナル戦で先発71分",
    "旗手怜央が移籍後初ゴール、バーンリーが今季初勝利",
    "鈴木彩艶が5試合連続先発",
    "遠藤航、リヴァプールで4試合ぶりの出番",
    "Vinicius Jr sent off for hair-pulling against Villarreal",
    "Premier League: Manchester United held by Tottenham",
])
def test_海外でプレーする日本人と欧州の題材は残す(text):
    got = off_scope(text)
    assert not got, f"残すべき題材を落としています（{got} に当たった）: {text}"


def test_当たった言葉を返す():
    """なぜ落としたかを、呼ぶ側が言えるようにしておく。"""
    assert off_scope("【今日のJリーグ】") == "Jリーグ"
    assert off_scope("USWNT player ratings") == "USWNT"
