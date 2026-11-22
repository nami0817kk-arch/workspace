"""サイゼリヤの回のセット 6 本の題名と概要欄(out/saize/desc_*.txt と titles.json)。python episodes/saize/make_desc.py [本編の動画ID]
数字と出典は lines.py の冒頭の「出どころ」。映像・写真の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "saize"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "サイゼリヤが安いのは、安い材料のせいではなかった。原価率48%、ドリア1皿の儲けは約9円",
          "s1": "320円のミラノ風ドリア、サイゼリヤに残る儲けは約9円 #shorts",
          "s2": "サイゼリヤの原価率は48%。ほかのファミレスの1.5倍なのに安い理由 #shorts",
          "s3": "サイゼリヤのドリアのソースは、オーストラリアの自社工場で作っている #shorts",
          "s4": "サイゼリヤがレタスのために、東京ドーム62個分の土地を買った理由 #shorts",
          "s5": "サイゼリヤは日本より海外のほうが儲かっている。決算で見る #shorts"}
LEAD = {"long": "サイゼリヤは、なぜあの値段で出せるのか。2026年10月の決算短信の数字を自分で割り、会社が公開している工場の説明と合わせて確かめました。",
        "s1": "2026年8月期の決算短信で、日本の会社の儲け(営業利益)は売上の約3%。その割合を320円のドリアに当てはめた、たとえの計算です。",
        "s2": "サイゼリヤ(日本の会社)とすかいらーくの決算短信から、売上に対する原価と、給料・家賃などの費用の割合を比べました。",
        "s3": "サイゼリヤの公式サイトの「ミラノ風ドリア」「自社工場の取り組み」から。",
        "s4": "サイゼリヤの公式サイトの「サラダ」「自社工場の取り組み」から。",
        "s5": "2026年8月期の決算短信の、日本の会社の数字とアジアの数字から。"}
SOURCES = """▼断り書き
※ドリア1皿の内訳(材料など約155円・給料や家賃など約156円・儲け約9円)は、会社全体の割合を320円に当てはめた、たとえの計算です。ドリアそのものの原価ではありません。
※サイゼリヤは日本の会社(個別)の数字、すかいらーくはグループ全体(連結)の数字です。

▼出典
・サイゼリヤ 2026年8月期 決算短信(2026年10月14日)
・すかいらーくホールディングス 2025年12月期 決算短信(2026年2月13日)
・サイゼリヤ 価格改定のお知らせ(2026年10月、ミラノ風ドリア 税込300円→320円)
・サイゼリヤ 公式サイト「ミラノ風ドリア」「自社工場の取り組み」「サラダ」
・店の数: 流通ニュース 2025年10月15日(2025年8月末 国内1,053店・海外629店)"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#サイゼリヤ #ミラノ風ドリア #決算 #なぜ #解説"""

src = json.loads((HERE / "assets" / "sources.json").read_text(encoding="utf-8"))
text = (HERE / "lines.py").read_text(encoding="utf-8")
used = {u + (".mp4" if u.startswith("c") else ".jpg") for u in re.findall(r'(?:V|PH)\("(\w+)"', text)}
by = sorted({s["by"].strip() for k, s in src.items() if k in used and not s.get("ai") and s.get("site") == "Pexels"})
MEDIA = "▼映像(Pexels)\n" + "、".join(by)

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
