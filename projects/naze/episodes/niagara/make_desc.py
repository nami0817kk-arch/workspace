"""ナイアガラのセット 6 本の題名と概要欄(out/niagara/desc_*.txt と titles.json)。python episodes/niagara/make_desc.py [本編の動画ID]
題名は scripts.md(2版)の案から。数字は sim/calc.txt、測った値の出どころは research.md。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "niagara"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "ナイアガラの滝は毎年うしろへ下がる。エリー湖へ届いても、湖の水は抜けない",
    "s1": "ナイアガラの滝は、1万2千年前は11km下流にあった #shorts",
    "s2": "ナイアガラの滝の力は288万kW。発電所3基ぶんで崖を叩く #shorts",
    "s3": "夜のナイアガラの滝は、水が半分。後退は6分の1に #shorts",
    "s4": "滝がエリー湖に届いても、湖は抜けない。決めているのは出口の岩 #shorts",
    "s5": "ナイアガラの滝がエリー湖に届くのは、16万年後 #shorts",
}
LEAD = {
    "long": "ナイアガラの滝は、崖を削りながら上流のエリー湖へ下がり続けています。では、滝が湖に届いたら、湖の水は流れ出してしまうのか。落ちる水の力・川が岩を削る速さ・湖の出口から出ていく水の流れを、物理の式で計算して確かめました。答えは、一気には抜けない。湖の高さを決めているのは、滝ではなく出口の岩だからです。",
    "s1": "峡谷 約11kmを約1万2,500年で削ったので、ならすと1年に約88cm。いまの滝から上流のエリー湖までは、川に沿って35km(OpenStreetMap の川の線で自分で測った値)。",
    "s2": "人が水を抜く前の流れ 1秒5,760トンが、51m落ちると、力は 水の重さ×重力×高さ で 288万kW(自分で計算)。1842〜1906年、大きな滝は1年に1.28mずつ下がりました。",
    "s3": "1950年のナイアガラ条約で、観光の季節の昼は1秒2,832トン以上、夜と冬は1,416トン以上を滝に流すと決めました。縁1mあたりに当たる水は昔の6分の1になり、後退の速さを同じ比で計算すると1年に約22cmです。",
    "s4": "湖の出口(幅 約600m)をせきと見て、せきの式で計算すると、1秒5,760トンを流すとき湖の水面は出口の岩より約3.2m上。出口の岩が一気に10m削れても、湖が5m下がるには約52日かかります(湖の面積 2万5,700km²)。",
    "s5": "滝から湖まで川に沿って35km。いまの後退(計算で1年約22cm)で割ると約16万年、人が水を抜かなかったら約5万年。",
}
SOURCES = """▼断り書き
※後退の速さは「縁1mあたりに当たる水の量に比べる」という川の浸食の式で、1842〜1906年の値(1年1.28m・自然の流れの9割・縁420m)を物差しにして自分で計算しました。実際に測った今の後退は1年10cmほどで、資料によって幅があります。
※湖の高さは、出口を広いせきと見たせきの式 Q＝b√g(2/3h)^1.5 で計算しました。出口の幅 約600m は標高データの水面から測った値です。「出口の岩が一気に10m削れたら」は、仕組みを見るための思考の実験です。
※川の長さ・滝から湖までの距離は OpenStreetMap の川の線を自分で測った値です(川の長さ 58.5km。公表値は 56km)。
※滝の断面・湖の出口・川の縦断面の図は、形を簡単にして、高さを強調して描いたものです。場面の絵はイメージです。

▼出典
・Hayakawa & Matsukura (2009) "Factors influencing the recession rate of Niagara Falls since the 19th century", Geomorphology(縁の長さ・流量・後退の速さ)
・Calkin & Wilkinson (1982) NYSGA 案内書 "Glacial and engineering geology aspects of the Niagara Falls and Gorge"(落差・1842〜1906年の後退)
・IJC「Niagara Falls is moving」、国際ナイアガラ管理委員会 FAQ・第139回半期報告(1950年の条約・取水量)
・1950年ナイアガラ条約 本文
・USACE バッファロー地区(1969年のアメリカ滝の水止め)
・Niagara Parks 学習の手引き 2022-23
・NOAA GLERL 五大湖の表(エリー湖の面積・体積・深さ・湖面の標高)
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、国境 Natural Earth、川の線 © OpenStreetMap contributors"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#ナイアガラの滝 #エリー湖 #五大湖 #地理 #なぜ #解説"""

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
