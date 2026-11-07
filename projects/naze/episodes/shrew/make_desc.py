"""小さい動物ほどたくさん食べる回のセット 6 本の題名と概要欄(out/shrew/desc_*.txt と titles.json)。python episodes/shrew/make_desc.py [本編の動画ID]
数字と出典は sim/facts.md。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "shrew"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '体重2gで、毎日体重の6倍を食べる動物。小さいほどたくさん食べる理由を、体の表面で確かめる',
    's1': '体重2gの動物は、毎日体重の6倍を食べる #shorts',
    's2': 'サイコロを切ると表面は10倍。小さい動物が冷える理由 #shorts',
    's3': '心臓が1分に1,511回打つ動物 #shorts',
    's4': '冬になると、脳を縮める動物がいる #shorts',
    's5': 'ゾウは体重の1割、トガリネズミは6倍を毎日食べる #shorts'}
LEAD = {'long': '世界で最も小さい哺乳類の1つ、コビトジャコウネズミは体重2gで、毎日体重の約6倍を食べます。小さい動物ほどたくさん食べなければならない理由を、体の表面の広さと、体を保つのに要るエネルギーで計算して確かめました。',
    's1': 'コビトジャコウネズミは1日にコオロギ8〜12匹、体重の約6倍を食べ、餌なしでは数時間しか生きられない(Geyer ほか 2022)。60kgの人に置きかえると360kg(自分で計算)。',
    's2': '1辺1cmのサイコロ(表面6平方cm)を1辺1mmに切ると1,000個で表面60平方cm。同じ形なら、体重1gあたりの表面は2gの動物が6トンの144倍(自分で計算)。',
    's3': 'コビトジャコウネズミの心拍は最高1,511回/分(恒温動物で報告された最高)、安静時は人の12倍、体重あたりの酸素消費は人の67倍(Jürgens ほか 1996)。',
    's4': 'ヨーロッパトガリネズミは冬を前に頭骨が平均15.3%縮み(Lázaro ほか 2017)、脳の重さは10〜26%減る(Lázaro ほか 2018)。春にまた大きくなる。',
    's5': 'アジアゾウは1日12〜18時間食べ、生の重さで最大で体重の10%(Schwarz ほか 2020)。体重1gあたりのエネルギーは2gの動物が6トンの約40倍(クライバーの式で自分で計算)。'}
SOURCES = """▼断り書き
※「体重の6倍」は飼育下のコビトジャコウネズミの値です。ヨーロッパトガリネズミは季節と年齢で体重の45〜77%(Wołk 1969)。
※エネルギーと表面の倍率は、クライバーの式(70×体重kg^0.75)と、同じ形として計算した自分の値です。動物の絵は AI で作ったイメージです。

▼出典
・Jürgens ほか 1996「Heart and respiratory rates and their significance for convective oxygen transport rates in the smallest mammal, the Etruscan shrew」J Exp Biol
・Geyer ほか 2022「Establishing and Maintaining an Etruscan Shrew Colony」JAALAS
・Wołk 1969「Body weight and daily food intake in captive shrews」Acta Theriologica
・Gębczyński 1971「Oxygen consumption in starving shrews」Acta Theriologica
・Keicher ほか 2017 J Exp Biol(体の脂肪の入れ替わり)
・Lázaro ほか 2017 Current Biology、Lázaro ほか 2018 Brain Struct Funct(冬に縮む頭骨と脳)
・Kleiber 1932 Hilgardia、Poczopko 1979 Acta Theriologica(クライバーの式と係数)
・Wolf ほか 2020 Biology Letters(ハチドリの体温 3.26℃)、Suarez 1992 Experientia
・San Diego Zoo Wildlife Alliance(アフリカゾウの体重)、Schwarz ほか 2020 Gajah(ゾウの食べる量)
・絵: Google Gemini と Cloudflare Workers AI(FLUX)で作ったイメージ"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#トガリネズミ #動物 #生き物 #物理 #なぜ #解説"""

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", FOOT]
    text = "\n".join(body) + "\n"
    assert "nami" not in text.lower() and "0817" not in text
    (OUT / f"desc_{k}.txt").write_text(text, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok")
