"""首都圏外郭放水路の回のセット 6 本の題名と概要欄(out/gaikaku/desc_*.txt と titles.json)。python episodes/gaikaku/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。写真の出典は sim/photos.json(使った写真だけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "gaikaku"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '首都圏外郭放水路は、なぜ地下50mに造られたのか',
          's1': '地下神殿の柱が59本ある理由は、浮き上がらないための重し #shorts',
          's2': '25mプール1杯を1秒で空にするポンプ。動力は飛行機のエンジン #shorts',
          's3': '地下に落ちる水を、そのまま落とせない理由。60mで時速120km #shorts',
          's4': '春日部から東京湾まで36kmで、下がる高さは約5m #shorts',
          's5': '同じ雨で、浸水が114ヘクタールから2ヘクタールになった理由 #shorts'}
LEAD = {'long': '埼玉県春日部市のサッカー場の地下に、長さ177m・柱59本の「地下神殿」があります。首都圏外郭放水路が地下約50mに造られた理由を、国土交通省の資料と、国土地理院の標高データで自分で測った数字・自分で計算した数字で確かめました。',
        's1': '調圧水槽は長さ177m・幅78m・高さ18m、柱は59本で1本約500トン(国土交通省 江戸川河川事務所)。浮力は内側の体積から自分で計算した値です。',
        's2': '庄和排水機場のポンプは4台で毎秒200m³、揚程14m、ガスタービンは1台1万4000馬力(国土交通省 江戸川河川事務所)。水を持ち上げる力は 1000×9.8×200×14 で自分で計算しました。',
        's3': '第3立坑は最大で毎秒100m³・約60m落下、渦流式ドロップシャフト(国土交通省 江戸川河川事務所)。時速約120kmは v=√(2×9.8×60) の自分の計算(空気の抵抗なし)。',
        's4': '春日部市役所の標高約5.8m・荒川河口約1m・まっすぐ約36km は、国土地理院の標高タイル(z12)で自分で測りました。一帯の陸地の56%が標高10m以下。',
        's5': '2000年7月台風3号(雨160mm)は浸水114ヘクタール・236戸、2002年7月台風6号(雨164mm)は浸水2ヘクタール・0戸(国土交通省 江戸川河川事務所、試験通水)。'}
SOURCES = """▼断り書き
※標高・距離・陸地の割合は、国土地理院の標高タイル(z12)から自分で測った値です。立坑の位置は OpenStreetMap の点です。
※浮力・水の落ちる速さ・ポンプの力などは、公開されている数字から自分で計算した値です。
※地下の断面図・柱の図は、自分で描いた図で、深さなどを強調しています。
※写真の一部は、色を濃くし、切り抜いています。

▼出典
・国土交通省 関東地方整備局 江戸川河川事務所「首都圏外郭放水路」(施設概要・先端技術: 調圧水槽、立坑、トンネル、排水機場、試験通水の効果)
・事業費・工事期間: 国土交通省 関東地方整備局の資料、NISTEP 科学技術動向 2006年7月号
・地図: 国土地理院(標高タイル・シームレス空中写真)、NASA Blue Marble(GIBS)、標高 Terrain Tiles、OpenStreetMap contributors"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#首都圏外郭放水路 #地下神殿 #春日部 #洪水 #防災 #土木 #なぜ #解説"""

src = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))
used = set(re.findall(r'PHOTO\("(\w+)"', (HERE / "parts.py").read_text(encoding="utf-8"))) | {"tankgold"}
PHOTOS = "▼写真(Wikimedia Commons)\n" + "\n".join(f"・{s['artist']}({s['license']}) {s['page']}" for k, s in src.items() if k in used and s["artist"])

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", PHOTOS, "", FOOT]
    text = "\n".join(body) + "\n"
    assert "nami" not in text.lower() and "0817" not in text
    (OUT / f"desc_{k}.txt").write_text(text, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", sorted(used))
