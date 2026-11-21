"""ペンギンの回のセット 5 本の題名と概要欄(out/penguin/desc_*.txt と titles.json)。python episodes/penguin/make_desc.py [本編の動画ID]
数字と出典は lines.py の冒頭の「出どころ」。映像・写真の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "penguin"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "ペンギンは寒さに強いのではなかった。4か月氷に立っても足が凍らない理由",
          "s1": "ペンギンの足は、氷の上に4か月立っても凍らない #shorts",
          "s2": "ペンギンの背中は、南極の空気より5℃も冷たかった #shorts",
          "s3": "吹雪の南極、ペンギンの群れの中は37.5℃だった #shorts",
          "s4": "赤道の真下のペンギンは、寒さではなく暑さと戦う #shorts"}
LEAD = {"long": "南極の冬、コウテイペンギンのオスは足の上に卵を乗せ、約115日食べずに氷の上に立ち続けます。足はなぜ凍らないのか。体の温度を測った記録と、熱で写すカメラの研究から、足・羽・群れの3つのしくみを確かめました。",
        "s1": "足の温度は Goldsmith & Sladen(1961)J Physiol 157:251。行きと戻りの血管で熱を体に戻すしくみは McCafferty ほか(2013)Biology Letters の考察から。",
        "s2": "McCafferty ほか(2013)Biology Letters「Emperor penguin body surfaces cool below air temperature」。2008年6月、オス40羽を熱で写すカメラで撮影。",
        "s3": "群れの中の気温は Gilbert ほか(2006)、群れの波は Zitterbart ほか(2011)PLoS ONE、群れなしでは約60日しかもたないのは Ancel ほか。",
        "s4": "赤道より北にもいるのはガラパゴスペンギンだけ。暑いときの行動(口を開けて息をする・翼を広げる・足に日陰を作る)は観察の記録から。"}
SOURCES = """▼断り書き
※血管の図は、行きと戻りの血の流れを分かりやすくした模式図です。
※「使う力が約4分の1少ない」は、大きな群れと小さな群れ(10羽)の体重の減り方の比べ(約26%)を言い換えたものです。

▼出典
・表面の温度: McCafferty et al. 2013, Biology Letters 9:20121192
・足の温度: Goldsmith & Sladen 1961, Journal of Physiology 157:251
・翼の付け根の動脈: Thomas & Fordyce 2012
・羽の数: Williams, Hagelin & Kooyman 2015, Proceedings of the Royal Society B 282:20152033
・群れの中の気温: Gilbert et al. 2006
・群れの波: Zitterbart et al. 2011, PLoS ONE
・群れで節約できる力: Ancel et al. 1997, Nature 385:304
・絶食と体重: Groscolas 1986, Journal of Comparative Physiology B
・冬の気温と風・寒さの境目: Le Maho et al. 1976
・アフリカペンギンの暮らす温度: Welman et al. 2024, Bird Conservation International
・地図: NASA Blue Marble(GIBS)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#ペンギン #生き物 #南極 #動物 #なぜ #解説"""

src = json.loads((HERE / "assets" / "sources.json").read_text(encoding="utf-8"))
text = (HERE / "lines.py").read_text(encoding="utf-8")
used = {u + (".jpg" if u.startswith("p") else ".mp4") for u in re.findall(r'(?:V|PH)\("(\w+)"', text)}
by = sorted({s["by"] for k, s in src.items() if k in used and not s.get("ai")})
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
