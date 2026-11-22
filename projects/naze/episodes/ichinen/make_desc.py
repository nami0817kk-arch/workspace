"""1年の回のセット 5 本の題名と概要欄(out/ichinen/desc_*.txt と titles.json)。python episodes/ichinen/make_desc.py [本編の動画ID]
数字と出典は lines.py の冒頭の「出どころ」。映像・写真の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "ichinen"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "大人の1年が速いのは、ジャネーの法則のせいではなかった。14〜94歳の499人に聞いた調査",
          "s1": "年を取ると1年が速くなる、は本当か。499人に聞いた結果 #shorts",
          "s2": "熱を出した妻に60まで数えてもらったら、1分が短くなった #shorts",
          "s3": "31メートル落ちた人は、時間がゆっくりに見えたのか #shorts",
          "s4": "楽しい旅行は短いのに、あとで思い出すと長い理由 #shorts"}
LEAD = {"long": "子どものころの夏休みは長かったのに、大人の1年はあっという間。よく言われるジャネーの法則と「体の時計」の説を、14〜94歳の499人に聞いた調査と、31mの落下実験で確かめました。",
        "s1": "ジャネーの法則は Paul Janet(1877)。調査は Wittmann & Lehnhoff(2005)Psychological Reports 97:921、内容は Wittmann & Mella(2021)の本文で確認。",
        "s2": "Hoagland(1933)Journal of General Psychology 9:267。熱が高いほど速く数えた、という記録から「体の中の時計」の考えが生まれました。",
        "s3": "Stetson, Fiesta & Eagleman(2007)PLoS ONE。落ちている間も速い数字は読めず、あとで自分の落下を他の人の落下より36%長く見積もりました。",
        "s4": "「休暇のパラドックス」は Claudia Hammond『Time Warped』(2012)の言葉。思い出の数で、過ぎた時間の長さを測っているという考えです。"}
SOURCES = """▼断り書き
※調査の結果の図・妻の「1分」の図・年齢ごとの思い出の多さの図は、形だけを示した模式図です。
※落ちている時間 約2.5秒は、31mの自由落下の計算です。

▼出典
・ジャネーの法則: Paul Janet 1877
・年齢と時間の速さの調査(14〜94歳499人): Wittmann & Lehnhoff 2005, Psychological Reports 97:921
・同じ調査の調べ直し(子どもの有無): Wittmann & Mella 2021, Timing & Time Perception 9:275
・オランダ・ニュージーランド: Friedman & Janssen 2010
・日本(868人): Janssen, Naka & Friedman 2013, Time & Society 22:274
・熱と時間の感じ方: Hoagland 1933, Journal of General Psychology 9:267
・31mの落下実験: Stetson, Fiesta & Eagleman 2007, PLoS ONE 2:e1295
・休暇のパラドックス: Claudia Hammond 2012『Time Warped』
・10〜30歳の記憶が多く残る: Rubin ほか(レミニセンス・バンプ)
・地図: NASA Blue Marble(GIBS)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#時間 #心理学 #ジャネーの法則 #なぜ #解説"""

src = json.loads((HERE / "assets" / "sources.json").read_text(encoding="utf-8"))
text = (HERE / "lines.py").read_text(encoding="utf-8")
used = {u + (".jpg" if u.startswith("p") else ".mp4") for u in re.findall(r'(?:V|PH)\("(\w+)"', text)}
by = sorted({s["by"].strip() for k, s in src.items() if k in used and not s.get("ai")})
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
