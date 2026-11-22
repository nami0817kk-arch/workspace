"""猫の回のセット 5 本の題名と概要欄(out/ichinen/desc_*.txt と titles.json)。python episodes/ichinen/make_desc.py [本編の動画ID]
数字と出典は lines.py の冒頭の「出どころ」。映像・写真の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "neko"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "猫は高い所から落ちても平気、ではなかった。32階から落ちた猫と、逆の結果が出た2つの動物病院の記録",
          "s1": "背中から落とした猫は、何もない空中でどうやって回るのか #shorts",
          "s2": "32階から落ちた猫は、なぜ肺と歯のけがだけで助かったのか #shorts",
          "s3": "ネズミは900mの穴に落ちても歩いて去る。小さいほど助かる理由 #shorts",
          "s4": "高い所から落ちた猫ほどけがが軽い、は記録の穴だったかもしれない #shorts"}
LEAD = {"long": "猫は高い所から落ちても平気、は本当か。32階から落ちて助かった猫の記録、ニューヨークとザグレブの動物病院の記録、落ちる速さの上限から確かめました。",
        "s1": "落ちる猫の連続写真は Marey(1894)。体を前と後ろに分けてひねり、何もない空中で向きを変えます。",
        "s2": "32階の猫と132匹の記録は Whitney & Mehlhaff(1987)JAVMA 191:1399 と、それを紹介した Vnuk ほか(2004)。猫は5階ほどで時速約100kmに達します。",
        "s3": "Haldane(1926)「On Being the Right Size」の一節から。小さく軽いほど、落ちる速さの上限は低くなります。",
        "s4": "ニューヨーク(Whitney & Mehlhaff 1987)とザグレブ(Vnuk ほか 2004、119匹)の記録を比べました。"}
SOURCES = """▼断り書き
※ニューヨークの記録の線の図は、形だけを示した模式図です。体をひねる図も模式図です。
※「32階から10匹落ちて1匹だけ病院に来たら」は、記録の穴を説明するためのたとえです。
※32階は約100m、7階は約20mとして換算しています。

▼出典
・ニューヨークの動物病院の記録(132匹): Whitney & Mehlhaff 1987, JAVMA 191:1399
・32階の猫・平均5.5階: Vnuk ほか 2004 の考察が Whitney & Mehlhaff 1987 を紹介
・ネイチャーでの紹介: Diamond 1988, Nature 332:586
・ザグレブの動物病院の記録(119匹・けがの点数・時速約100km): Vnuk ほか 2004, J Feline Med Surg 6:305
・落ちる猫の連続写真: Marey 1894, Comptes rendus 119:714(写真は Wikimedia Commons、パブリックドメイン)
・深い穴とネズミ: Haldane 1926, On Being the Right Size"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#猫 #ねこ #動物 #なぜ #解説"""

src = json.loads((HERE / "assets" / "sources.json").read_text(encoding="utf-8"))
text = (HERE / "lines.py").read_text(encoding="utf-8")
used = {u + (".mp4" if u.startswith("c") else ".jpg") for u in re.findall(r'(?:V|PH)\("(\w+)"', text)}
by = sorted({s["by"].strip() for k, s in src.items() if k in used and not s.get("ai") and s.get("site") == "Pexels"})
MEDIA = "▼映像・写真(Pexels)\n" + "、".join(by)

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", MEDIA, "", FOOT]
    out = "\n".join(body) + "\n"
    assert "nami" not in out.lower() and "0817" not in out
    (OUT / f"desc_{k}.txt").write_text(out, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(by), "人:", "、".join(by))
