"""ロケットのセット 6 本の題名と概要欄(out/rocket/desc_*.txt と titles.json)。python episodes/rocket/make_desc.py [本編の動画ID]"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "rocket"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "ロケットは段を捨てないと実用的に宇宙へ届かない。約9.4km/sの壁を計算で確かめる",
    "s1": "ロケットに要る速さは約9.4km/s。新幹線の約106倍 #shorts",
    "s2": "ロケットを1段で作ると燃料96%。機体が5%では荷物ゼロでも届かない #shorts",
    "s3": "アトラスは空だと自重でつぶれる。そこまで軽くしても秒速9.0km止まり #shorts",
    "s4": "ロケットは燃料を足しても速くならない。倍率は21.5倍止まり #shorts",
    "s5": "ロケットは段を捨てて荷物が乗る。2段で約1.8%、4段でも約2.6% #shorts",
}
LEAD = {
    "long": "ロケットは、燃料を使い切った部分(段)を捨てながら宇宙へ向かいます。では、段を捨てずに1つの機体で行けないのか。宇宙に出るために要る速さ(約9.4km/s)を見積もり、ツィオルコフスキーの式で、1つの機体で打つ・限界まで軽くする・燃料を増やす・水素に替える・段を捨てる、の5つの実験を、荷物が全体の何%乗るかで確かめました。最後はファルコン9で答え合わせをします。",
    "s1": "ロケットが宇宙へ出るのに要る速さは、見積もりで約秒速9.4km。軌道の速さ7.8kmに、昇る間に失う約1.5〜2km/sを足した値です。資料には9.3〜10km/sの幅があり、私のざっくり計算は8.9km/sほどでした。",
    "s2": "ファルコン9を1つの機体で打つと、約9.4km/sに要る倍率は約24倍。離陸の重さ1トンのうち燃料が約960kg、残りは約40kg。ファルコン9の1段目の空の機体は約51kgで、荷物がゼロでも届きません。",
    "s3": "アトラスは1958年に衛星を軌道へ乗せたアメリカのロケット。薄いステンレスの風船のようなタンクで、離陸の重さ116トンに対して空の機体は5.4トン(約4.65%)。ここまで軽くしても、荷物ゼロの理想で秒速約9.0kmでした。",
    "s4": "燃料を増やすと、タンクも重くなります。倍率の上限は、100を空の機体の割合で割った数。アトラスなら約21.5倍で、欲しい約24倍には届きません。",
    "s5": "段に分けると、速さが分けられ、倍率は掛け算なので一気に楽になります。各段の空の機体を8%と置くと、荷物は2段で約1.8%、3段で約2.4%、4段で約2.6%。ファルコン9の2段で約9.25km/sの簡易計算です。",
}
SOURCES = """▼出典・計算
・ツィオルコフスキーの式：NASA Glenn「Ideal Rocket Equation」。発表年は1903年（Wikipedia「Tsiolkovsky rocket equation」）
・軌道の速さ・自転で得をする速さ・計算の結果：地球の重力定数（IERS/CODATA）と恒星日から自分で計算
・地表から低軌道までに必要な速さ「9.3〜10km/s」：Wikipedia「Delta-v budget」（出典の補強が求められている記述）。動画ではこの幅の中の見積もりとして「約9.4km/s」を使っています。NASA・ESAの一次資料は確認できていません（二次資料のみ）
・ファルコン9の質量と比推力：Wikipedia「Falcon 9 Full Thrust」（SpaceXの公開資料などを引用）。SpaceXは空の機体の質量を公式に出していないため、公表値からの計算です
・H3の質量と比推力：Wikipedia「H3 (rocket)」、LE-9の比推力はJAXA資料（https://www.jaxa.jp/press/2016/06/files/20160614_h3_01_j.pdf）。空の機体は全備質量と推進薬の引き算で、公表値からの計算です
・アトラスの質量・風船タンク・ブースターの切り離し：Wikipedia「SM-65 Atlas」（M. D. Black『The Evolution of Rocket Technology』を引用）。アトラスの比推力300秒は仮置きの値です
・DC-X・DC-XA（最高2.5km・3.14km、1996年の転倒はDC-XA）：Wikipedia「McDonnell Douglas DC-X」（NASAの飛行試験の記録を引用）
・X-33：Wikipedia「Lockheed Martin X-33」。1段式の試み：Wikipedia「Single-stage-to-orbit」（ESAの監査を引用）
・スカイロンの現状（Reaction Engines が2024年10月31日に英国で経営破綻、計画は中止）：The Register 2024-11-01 https://www.theregister.com/2024/11/01/reaction_engines_administration/ ほか報道のみ。会社の公式発表の原文は未確認です
・各段の倍率・荷物の割合・燃料を増やした場合の速さは、上の数字からPythonで自分で計算
・作品・実機の写真は使っていません。図は自分で描いた簡略図です"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#ロケット #ファルコン9 #ツィオルコフスキー #宇宙 #物理 #なぜ #解説"""

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", FOOT]
    (OUT / f"desc_{k}.txt").write_text("\n".join(body) + "\n", encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok")
