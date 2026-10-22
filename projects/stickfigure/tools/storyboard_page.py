"""絵コンテの Artifact ページ(HTML)を作る。out/storyboard/captions.json と各コマの画像から out/storyboard/index.html を書く。

使い方: python tools/storyboard_page.py   → out/storyboard/index.html(画像は sb/ 以下の相対パス。公開時に files で渡す)
"""
from __future__ import annotations

import html
import json
from pathlib import Path

OUT = Path("out/storyboard")

HEAD = """<title>勝ち抜き戦 絵コンテ</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@500&family=Zen+Kaku+Gothic+New:wght@400;500;700;900&display=swap">
<style>
/* 配置: 制作ボードの縦長 1 本。見出し・コマ割り(画像 + 時刻 + 一言)・決めたいことの順。色は人物の色(緑・青・紫・赤)だけを使う */
:root {
  --bg: #e9ecf1; --paper: #ffffff; --ink: #1d2230; --mute: #5b6478; --line: #c9cfdb;
  --hero: #4f9a2e; --blue: #2f6fd1; --purple: #8a4fc4; --red: #cf4a3f;
  --mark: #fff1b8; --font: "Zen Kaku Gothic New", "Hiragino Sans", "Yu Gothic", "Meiryo", sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg: #14171f; --paper: #1d2230; --ink: #eceef4; --mute: #9aa3b8; --line: #343b4d; --hero: #86d65a; --blue: #6ea2f2; --purple: #b58af0; --red: #f07a6e; --mark: #4a4217; color-scheme: dark; } }
:root[data-theme="dark"] { --bg: #14171f; --paper: #1d2230; --ink: #eceef4; --mute: #9aa3b8; --line: #343b4d; --hero: #86d65a; --blue: #6ea2f2; --purple: #b58af0; --red: #f07a6e; --mark: #4a4217; color-scheme: dark; }
body { background: var(--bg); color: var(--ink); font-family: var(--font); font-size: 15px; line-height: 1.75; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 28px 56px; }
main { max-width: 1080px; margin: 0 auto; display: flex; flex-direction: column; gap: 44px; }
h1 { font-size: clamp(26px, 5vw, 40px); font-weight: 900; letter-spacing: .02em; line-height: 1.25; margin: 0; text-wrap: balance; }
h2 { font-size: clamp(20px, 3.4vw, 26px); font-weight: 900; margin: 0; display: flex; gap: 12px; align-items: baseline; flex-wrap: wrap; }
h2 .chip { font-family: var(--mono); font-size: 12px; font-weight: 500; letter-spacing: .08em; padding: 2px 8px; border: 1.5px solid currentColor; border-radius: 3px; }
.lead { color: var(--mute); margin: 8px 0 0; max-width: 62ch; }
section { display: flex; flex-direction: column; gap: 16px; min-width: 0; }
.sum { display: flex; flex-wrap: wrap; gap: 6px 22px; font-size: 13.5px; color: var(--mute); }
.sum b { color: var(--ink); font-family: var(--mono); font-weight: 500; }
.board { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 300px), 1fr)); gap: 14px; }
.shot { margin: 0; background: var(--paper); border: 1px solid var(--line); display: flex; flex-direction: column; min-width: 0; }
.shot img { display: block; width: 100%; height: auto; background: #f7f4ee; border-bottom: 1px solid var(--line); }
.shot figcaption { padding: 10px 12px 14px; display: grid; grid-template-columns: auto 1fr; gap: 2px 10px; align-items: baseline; }
.shot .n { font-family: var(--mono); font-size: 12px; color: var(--mute); }
.shot h4 { margin: 0; font-size: 15px; font-weight: 700; line-height: 1.45; }
.shot p { grid-column: 1 / -1; margin: 4px 0 0; font-size: 13.5px; color: var(--mute); line-height: 1.7; }
.shot .t { font-family: var(--mono); font-size: 12px; color: var(--ink); background: var(--mark); padding: 0 5px; margin-left: 6px; }
.new { border-color: var(--red); }
.tablewrap { overflow-x: auto; border: 1px solid var(--line); background: var(--paper); }
table { border-collapse: collapse; width: 100%; min-width: 560px; font-size: 14px; }
th, td { text-align: left; padding: 9px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }
th { font-weight: 700; font-size: 12.5px; color: var(--mute); letter-spacing: .04em; }
td.num { font-family: var(--mono); font-variant-numeric: tabular-nums; }
tr:last-child td { border-bottom: 0; }
.q { counter-reset: q; display: flex; flex-direction: column; gap: 12px; padding: 0; margin: 0; list-style: none; }
.q li { counter-increment: q; background: var(--paper); border: 1px solid var(--line); padding: 12px 14px 12px 52px; position: relative; min-width: 0; }
.q li::before { content: counter(q); position: absolute; left: 14px; top: 12px; width: 26px; height: 26px; display: grid; place-items: center; font-family: var(--mono); font-size: 13px; background: var(--ink); color: var(--bg); }
.q b { font-weight: 700; }
.q .rec { display: block; margin-top: 4px; font-size: 13.5px; color: var(--mute); }
.q .rec em { font-style: normal; font-weight: 700; color: var(--hero); }
.sub { margin: 6px 0 0; font-size: 15px; font-weight: 900; letter-spacing: .04em; color: var(--ink); border-left: 5px solid var(--red); padding-left: 10px; }
.vocab { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 240px), 1fr)); gap: 10px; padding: 0; margin: 0; list-style: none; }
.vocab li { background: var(--paper); border: 1px solid var(--line); border-left: 5px solid var(--red); padding: 9px 12px; font-size: 13.5px; line-height: 1.6; min-width: 0; }
.vocab b { display: block; font-size: 15px; }
.note { font-size: 13.5px; color: var(--mute); max-width: 70ch; }
</style>"""


def card(img: str, n: int, p: dict, new: bool = False) -> str:
    t = f'<span class="t">{p["t"]:.1f}s</span>' if "t" in p else ""
    return (f'<figure class="shot{" new" if new else ""}"><img src="{html.escape(img)}" alt="{html.escape(p["title"])}" loading="lazy">'
            f'<figcaption><span class="n">{n:02d}</span><h4>{html.escape(p["title"])}{t}</h4><p>{html.escape(p["text"])}</p></figcaption></figure>')


def section(tag: str, name: str, color: str, theme: str, lead: str, data: dict, start: int = 1, extra_sum: str = "", new: bool = False, flashy: list = ()) -> str:
    cards = "".join(card(p["img"], start + i, p, new) for i, p in enumerate(data["panels"]))
    fl = ""
    if flashy:
        fcards = "".join(card(p["img"], i + 1, p, True).replace('class="n">', 'class="n">派手 ') for i, p in enumerate(flashy))
        fl = f'<h3 class="sub">派手な動きの追加案(差し込む見せ場)</h3><div class="board">{fcards}</div><h3 class="sub">全体のコマ割り</h3>'
    return (f'<section><div><h2 style="color:var(--{color})"><span class="chip">{html.escape(tag)}</span>{html.escape(name)}</h2><p class="lead">{html.escape(lead)}</p></div>'
            f'{extra_sum}{fl}<div class="board">{cards}</div></section>')


def main():
    d = json.loads((OUT / "captions.json").read_text(encoding="utf-8"))
    fl = json.loads((OUT / "flashy.json").read_text(encoding="utf-8"))
    fl["giant"] = [p for p in fl["giant"] if "run" not in p["img"]]       # 腕を駆け上がる案は、絵がまだ分かりにくいので外す
    mb, mg, mr = d["blue"]["meta"], d["giant"]["meta"], d["red_first"]["meta"]
    summ = lambda m, extra="": (f'<div class="sum"><span>長さ <b>{m["seconds"]:.0f} 秒</b></span><span>当たり <b>{m["hits"]} 発</b></span>'
                                f'<span>打ち合い <b>{m["exchanges"]} 発/秒</b></span><span>動いているコマ <b>{int(m["moving"] * 100)}%</b></span>{extra}</div>')
    body = []
    body.append('<header><h1>勝ち抜き戦 絵コンテ<br>もっと激しく・もっと派手なアクション案</h1>'
                '<p class="lead">動画にする前に、1 試合ごとの流れをコマで見て合わせるためのページです。通常のコマは実際の振り付け案の姿勢から描いています。赤い線の「派手な動き」と空中コンボは、まだ動作が無いので手で組んだ姿勢のスケッチです(実際の動きは作りながら調整します)。</p></header>')
    body.append('<section><h2>派手にする動き</h2><p class="lead">拳が当たるだけの殴り合いに、体を大きく使う動きを混ぜます。どれも、いまの動作には無いものです。</p><ul class="vocab">'
                '<li><b>宙返り(バク転・前宙)</b>蹴りをバク転でかわす。前宙で相手を飛び越えて背後へ。</li>'
                '<li><b>スライディング</b>跳び蹴りの下を滑って抜け、砂ぼこりを引く。</li>'
                '<li><b>空中の蹴り連続</b>跳んだまま頭・胸・足と 3 発。</li>'
                '<li><b>衝撃波</b>巨漢が地面を叩き、割れ目と輪が走る。緑は跳んで越える。</li>'
                '<li><b>柱を砕く吹き飛び</b>一撃で飛んで柱に激突、破片が散る。</li>'
                '<li><b>空中コンボ</b>打ち上げ → 空中 2 発 → 宙返りかかと落とし → 地面が割れる。</li>'
                '</ul></section>')
    fx = json.loads((OUT / "fx.json").read_text(encoding="utf-8"))
    fxc = "".join(card(p["img"], i + 1, p, True).replace('class="n">', 'class="n">効果 ') for i, p in enumerate(fx))
    body.append('<section><h2>エフェクト(効果)</h2><p class="lead">殴り合いの手応えと速さを、絵の効果で足します。参考(Alan Becker)の見せ方は、効果を少なく・短くして動きで見せるので、「付ける所を決めて、付けすぎない」方針です。</p>'
                f'<div class="board">{fxc}</div>'
                '<div class="tablewrap"><table><thead><tr><th>効果</th><th>付ける所</th><th>強さ</th></tr></thead><tbody>'
                '<tr><td>火花(黄)</td><td>当たった全部</td><td>小技は小さく、吹き飛ばす一撃は 1.5 倍、決めは 2 倍</td></tr>'
                '<tr><td>青い火花の輪</td><td>受け止め</td><td>小さく。赤い火花と色で分ける</td></tr>'
                '<tr><td>振りの軌跡(三日月)</td><td>速い蹴り・大振り・かわされた技</td><td>約 4 コマで消える。連打では蹴りと大振りだけ(拳には付けない)</td></tr>'
                '<tr><td>土煙</td><td>走り出し・踏み込み・着地・吹き飛んで滑る・起き上がり</td><td>地面を強く蹴るときだけ。1 歩ごとには付けない</td></tr>'
                '<tr><td>流線</td><td>吹き飛び・突進</td><td>飛んでいる間だけ、後ろに数本</td></tr>'
                '<tr><td>閃光 1 コマ + 衝撃の輪</td><td>決めの一撃・巨漢の一発・空中コンボの叩きつけ</td><td>各試合 1〜2 回。そのあと約 0.1 秒の止め</td></tr>'
                '<tr><td>衝撃波・割れ目・破片</td><td>巨漢が地面を叩く・叩きつけ</td><td>大技専用</td></tr>'
                '<tr><td>手足の光の尾</td><td>空中の連打・宙返り</td><td>跳んでいる間だけ</td></tr>'
                '</tbody></table></div>'
                '<p class="note">付けないもの: 擬音の文字(バシッ!など)、白黒反転、画面全体に走る放射線。参考の見せ方に合わせて、前から外しています。</p></section>')
    body.append('<section><h2>狙い</h2><p class="lead">いまの殴り合いは 1 秒に 1.5〜1.7 発、連続技は 2〜3 発まで。これを、1 秒に 2 発前後・最長 5 連打にして、試合ごとに激しさの種類を変えます。決勝は、打ち上げて空中で追撃し、叩きつける空中コンボで締めます。</p>'
                '<div class="tablewrap"><table><thead><tr><th>試合</th><th>激しさの種類</th><th>打ち合い(発/秒)<br>今 → 案</th><th>連続技</th><th>見せ場</th></tr></thead><tbody>'
                '<tr><td>第一回戦 緑 vs 青</td><td>速さ</td><td class="num">1.48 → 1.95</td><td>蹴り 3 連・4 連打・5 連打</td><td>蹴りを受け続け、胸に 1 発もらう → 5 連打の最後で吹き飛ばす</td></tr>'
                '<tr><td>準決勝 緑 vs 巨漢</td><td>力</td><td class="num">1.64 → 1.54</td><td>2 連打・4 連打</td><td>緑が 2 度吹き飛ばされ、食らいついて崩す。数より一発の重さ</td></tr>'
                '<tr><td>決勝 緑 vs 赤</td><td>空中</td><td class="num">1.68 → 約 1.9</td><td>3 連 + 空中 3 発</td><td>拳がぶつかる → 打ち上げ → 空中 2 発 → 叩きつけ</td></tr>'
                '</tbody></table></div></section>')
    body.append(section("ROUND 1", "第一回戦 緑 vs 青(蹴り使い)  テーマは速さ", "blue", "速さ", "青が蹴りで攻め立て、緑は受け、かわし、1 発もらう。反撃は 4 連打と 5 連打。止まっている間を作らず、構えている間も弾む。", d["blue"], 1, summ(mb), flashy=fl["blue"]))
    body.append(section("ROUND 2", "準決勝 緑 vs 巨漢(紫)  テーマは力", "purple", "力", "体は 1.25 倍。巨漢の一発で緑が吹き飛ぶ(2 度)。緑の攻めは最初は効かず、足払いで崩れてから通り始める。", d["giant"], 1, summ(mg, '<span>緑が吹き飛ぶ <b>2 回</b></span>'), flashy=fl["giant"]))
    body.append(section("FINAL", "決勝 緑 vs 赤(喧嘩屋)  前半は互角の殴り合い", "red", "互角", "赤は両拳を顔の前に構える喧嘩屋。大振りをくぐり、被弾し、拳がぶつかり、腹で折れる。ここまでが約 5 秒。", d["red_first"], 1, summ(mr)))
    air = d["red_air"]
    body.append(section("FINAL 後半", "空中コンボ(新しい動作)", "red", "空中",
                        "決勝の締め。アッパーで打ち上げ、跳んで空中で 2 発、叩きつけてバウンド、決めの止め絵。約 4 秒。ここだけ、絵は手で組んだ姿勢です。実際の動きは作りながら調整します。",
                        air, 10, '<div class="sum"><span>追加する動作 <b>打ち上げ・空中の打ち・叩きつけ</b></span></div>', new=True, flashy=fl["red"]))
    body.append('<section><h2>決めたいこと</h2><ol class="q">'
                '<li><b>エフェクトは、上の表の付け方でよいか。</b><span class="rec"><em>おすすめ: この表のとおり。</em> 擬音の文字・白黒反転・放射線は付けない(参考の見せ方と合わない)。多すぎると感じたら、土煙と軌跡から減らす。</span></li>'
                '<li><b>派手にする動きを、どこまで入れるか。</b><span class="rec"><em>おすすめ: 第 1 弾は「宙返り(バク転・前宙)」「空中コンボ」「衝撃波」の 3 つ。</em> 見た目の差が大きく、ほかの試合にも使える。スライディング・空中の蹴り連続は動作が小さいので一緒に入れる。柱を砕く吹き飛びは、背景に壊れる物を足す作業があるので第 2 弾に回す。</span></li>'
                '<li><b>決勝を空中コンボで締めてよいか。</b><span class="rec"><em>おすすめ: 入れる。</em> 参考の動画でも、空中・高低差が一番派手に見える所。動作を 3 つ足すだけで、ほかの試合にも使える。</span></li>'
                '<li><b>準決勝の巨漢は、数より重さでよいか。</b><span class="rec"><em>おすすめ: このまま。</em> 全部を速くすると巨漢の重さが消える。代わりに衝撃波と、緑が 2 度吹き飛ばされる所を大きく派手にする。</span></li>'
                '<li><b>武器(剣・棒)は入れるか。</b><span class="rec"><em>おすすめ: 今回は入れない。</em> 参考の戦いは剣やつるはしを使うが、手持ちの動作と IK が増える。素手の激しさを先に固めてから。</span></li>'
                '<li><b>必殺技(気弾・光線・分身)は入れるか。</b><span class="rec"><em>おすすめ: 今回は入れない。</em> 自動で作る戦いには既にある。手で付けた殴り合いに混ぜると、見た目の種類が増えて散らかる。</span></li>'
                '<li><b>長さは 62 秒から約 70 秒に伸びてよいか。</b><span class="rec"><em>おすすめ: 伸ばす。</em> 決勝の空中コンボぶんだけ。ショートは 1 分に収めたいので、縦版は出場者紹介を短くして合わせる。</span></li>'
                '</ol></section>')
    body.append('<section><h2>このあとの流れ</h2><p class="note">合意できたら、(1) 動作を足す(宙返り・スライディング・空中の蹴り・衝撃波・空中コンボ。約 2〜3 時間)、(2) 3 試合の振り付けを作り直す、(3) 点検に通してから書き出す(約 35 分)、(4) 見せる、(5) 投稿、の順で進めます。コマを直したい所は、番号で教えてください(例: 「第一回戦の 7」)。</p></section>')
    page = HEAD + "<main>" + "".join(body) + "</main>"
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(OUT / "index.html", len(page) // 1024, "KB")


if __name__ == "__main__":
    main()
