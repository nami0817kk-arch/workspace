"""タコの回のセット 6 本の題名と概要欄(out/tako/desc_*.txt と titles.json)。python episodes/tako/make_desc.py [本編の動画ID]
数字と出典は 台本.md の「出どころ」。映像・写真の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "tako"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "タコは本当に、宇宙から来たのか",
          "s1": "タコは宇宙から来た、と論文に書いた33人の科学者 #shorts",
          "s2": "色が見えないのに、タコはなぜ岩に化けられる？ #shorts",
          "s3": "タコの心臓は3つ。泳ぐと1つが止まる #shorts",
          "s4": "切れたタコの腕が、どうしてもつかまないもの #shorts",
          "s5": "ココナッツの殻を抱えて歩くタコ #shorts"}
LEAD = {"long": "2018年、33人の科学者が「タコは宇宙から来たのかもしれない」と論文に書きました。色が見えないのに化ける体、3つの心臓と青い血、考える腕、道具を使う行動、そして遺伝子と化石。5つの証拠を、論文に当たって1つずつ確かめました。",
        "s1": "Steele ほか(2018)Progress in Biophysics and Molecular Biology 136:3–23 と、タコのゲノムを読んだ Albertin ほか(2015)Nature、3億2,800万年前の化石 Whalen & Landman(2022)Nature Communications。",
        "s2": "頭足類の多くは目の色素が1種類(Marshall & Messenger 1996, Nature)。切り取ったタコの皮膚が光に反応した実験は Ramirez & Oakley(2015)Journal of Experimental Biology。",
        "s3": "酸素を運ぶ量は Oellermann ほか(2015)Frontiers in Zoology の表(マダコ 0.61mmol/L)。人の値はヘモグロビン150g/Lから自分で計算。83%・2.5倍は Houlihan ほか(1986)。泳ぐと拍動が途切れるのは Wells & Smith(1987)。",
        "s4": "Nesher ほか(2014)Current Biology「Self-recognition mechanism between skin and suckers prevents octopus arms from interfering with each other」。",
        "s5": "Finn, Tregenza & Norman(2009)Current Biology「Defensive tool use in a coconut-carrying octopus」。インドネシアで500時間潜って観察。"}
SOURCES = """▼断り書き
※人の血が運ぶ酸素の量(約9.3ミリモル/リットル)は、ヘモグロビン150g/Lから自分で計算した値です。
※タコの心臓の図は、位置と流れを分かりやすくした模式図です。
※AI で作った絵は、画面の右上に「イメージ」と出しています(宇宙の天体・大昔の祖先・ココナッツを抱えるタコ)。

▼出典
・宇宙説: Steele et al. 2018, Progress in Biophysics and Molecular Biology 136:3–23
・タコのゲノム: Albertin et al. 2015, Nature 524:220–224
・色が見えない: Marshall & Messenger 1996, Nature 382:408
・皮膚が光を感じる: Ramirez & Oakley 2015, Journal of Experimental Biology 218:1513
・心臓: Wells 1980, J Exp Biol 85:111 / Wells & Smith 1987, J Exp Biol
・酸素を運ぶ量: Oellermann et al. 2015, Frontiers in Zoology 12:6 / Houlihan et al. 1986, J Comp Physiol B 156:683
・神経の数: Zullo & Hochner 2011, Communicative & Integrative Biology 4:26
・腕の動き: Sumbre et al. 2001, Science 293:1845 / Nesher et al. 2014, Current Biology
・吸盤の味: van Giesen et al. 2020, Cell
・ココナッツ: Finn, Tregenza & Norman 2009, Current Biology 19:R1069
・化石: Whalen & Landman 2022, Nature Communications / Landing et al. 2023, Communications Biology
・目: Ogura et al. 2004, Genome Research 14:1555
・地図: NASA Blue Marble(GIBS)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#タコ #生き物 #海の生き物 #進化 #宇宙 #なぜ #解説"""

src = json.loads((HERE / "assets" / "sources.json").read_text(encoding="utf-8"))
used = set(re.findall(r'(?:V|PH)\("([\w.]+)"', (HERE / "lines.py").read_text(encoding="utf-8")))
used |= set(re.findall(r'S\("([\w.]+)"\)', (HERE / "lines.py").read_text(encoding="utf-8")))
used = {u if "." in u else u + ".mp4" for u in used}
by = sorted({f"{s['by']}" for k, s in src.items() if k in used and not s.get("ai")})
MEDIA = "▼映像・写真(Pexels)\n" + "、".join(by)

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", MEDIA, "", FOOT]
    text = "\n".join(body) + "\n"
    assert "nami" not in text.lower() and "0817" not in text
    (OUT / f"desc_{k}.txt").write_text(text, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(by), "人:", "、".join(by))
