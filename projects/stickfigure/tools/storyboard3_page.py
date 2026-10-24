"""絵コンテ「3 対 1」のページ(HTML)。out/storyboard3/panels.json とコマの画像から out/storyboard3/index.html を書く。
見た目は勝ち抜き戦の絵コンテ(storyboard_page.py)と同じ。画像は sb3/ 以下の相対パス(公開時に files で渡す)。コマは幕(act)ごとに並べる。

使い方: python tools/storyboard_3v1.py && python tools/storyboard3_page.py
"""
from __future__ import annotations

import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import storyboard_page as sp  # noqa: E402

OUT = Path("out/storyboard3")
ACTS = {
    1: ("第一幕", "降臨", "hero", "0〜12 秒", "静かな境内に 3 人が降り立つ。にらみ合いの間のあと、3 人が消えて四方から襲う。緑は一歩も動かずに全部受け流す(強さの見せ場)。"),
    2: ("第二幕", "連携", "red", "12〜32 秒", "3 人の連携技(蹴り上げ → 空中連打 → 叩き落とし)で形勢が逆転。立ち上がってもさばききれず、3 人の合体光線で吹き飛ぶ。いちばんのピンチ。"),
    3: ("第三幕", "覚醒", "hero", "32〜44 秒", "煙の中に立つ影。気のオーラが噴き上がり、もう一度の光線を片手の盾で受け止めて押し返す。"),
    4: ("第四幕", "逆転", "blue", "44〜62 秒", "瞬間移動で青、分身乱舞で赤、拳の激突から空中コンボで巨漢。1 人ずつ、技を変えて倒す。"),
    5: ("第五幕", "決着", "purple", "62〜72 秒", "起き上がった 3 人を、とどめの光線でまとめて空へ。光が消えて夕日が戻り、緑が背を向ける。"),
}


def main():
    panels = json.loads((OUT / "panels.json").read_text(encoding="utf-8"))
    body = []
    body.append('<header><h1>3 対 1 絵コンテ<br>倒した 3 人が、まとめて仕返しに来る</h1>'
                '<p class="lead">動画にする前に、流れをコマで見て合わせるためのページです。勝ち抜き戦で倒した青(蹴り使い)・紫(巨漢)・赤(喧嘩屋)が、夕暮れの境内で緑を囲みます。'
                'アニメの戦いの型(強さの見せ場 → 敵の連携でピンチ → 覚醒 → 必殺技で逆転 → 余韻)で、約 72 秒。姿勢は手で組んだスケッチです。</p></header>')
    rows = "".join(f'<tr><td>{html.escape(a[0])}「{html.escape(a[1])}」</td><td class="num">{html.escape(a[3])}</td><td>{html.escape(a[4])}</td></tr>' for a in ACTS.values())
    body.append(f'<section><h2>流れ(約 72 秒)</h2><div class="tablewrap"><table><thead><tr><th>幕</th><th>時刻</th><th>中身</th></tr></thead><tbody>{rows}</tbody></table></div>'
                '<p class="note">間(にらみ合い・溜め・余韻)を長めに取るのもアニメの型です。殴り合いの密度は勝ち抜き戦と同じ(打ち合い 1 秒に 1.5 発前後)で、間と大技でメリハリをつけます。カメラは今の真横の引きのまま。</p></section>')
    n = 0
    for k, (tag, name, color, span, lead) in ACTS.items():
        ps = [p for p in panels if p["act"] == k]
        cards = "".join(sp.card(p["img"], n + i + 1, p) for i, p in enumerate(ps))
        n += len(ps)
        body.append(f'<section><div><h2 style="color:var(--{color})"><span class="chip">{html.escape(tag)}</span>{html.escape(name)}  {html.escape(span)}</h2>'
                    f'<p class="lead">{html.escape(lead)}</p></div><div class="board">{cards}</div></section>')
    body.append('<section><h2>エフェクト</h2><p class="lead">勝ち抜き戦の付け方に、アニメの技の効果を足します。当たりは黄色い火花、受けは青い輪、速い振りに軌跡、着地と叩きつけに土煙、吹き飛びに流線、決めの一撃に閃光 1 コマ。'
                '加えて、気を溜める光の柱、覚醒のオーラ、光線、気の盾、瞬間移動の残像の列、分身。擬音の文字・白黒反転・放射線は付けません。</p></section>')
    body.append('<section><h2>作るもの</h2><ul class="vocab">'
                '<li><b>3 人を相手にする組み立て</b>緑が左右に向きを変えて戦う(いまの殴り合いの部品は 1 対 1 で向きが固定)。3 人の連携技も当たりとして並べる。</li>'
                '<li><b>手付けの戦いに必殺技の効果をつなぐ</b>光線・光の柱・気の盾・残像の列・オーラは、自動の戦い(fight)に部品があるので、手付けの戦いから呼べるようにする。オーラは新しく作る。</li>'
                '<li><b>新しい動作</b>着地(降り立つ)、四方からの連撃の受け流し、気を溜める構え、片手で光線を受け止める、拳と拳の押し合い。</li>'
                '</ul><p class="note">バク転・衝撃波・空中コンボ・吹き飛び・瞬間移動・分身乱舞は、これまでに作ったものを使います。72 秒を 5 つの幕に分けて書き出すので、直した幕だけ描き直せます。</p></section>')
    body.append('<section><h2>決めたいこと</h2><ol class="q">'
                '<li><b>この流れでよいか。</b><span class="rec"><em>おすすめ: このまま。</em> 第二幕のピンチを長め(20 秒)にして、覚醒からの逆転を気持ちよく見せる構成です。短くしたい所があれば、幕の番号かコマの番号で教えてください。</span></li>'
                '<li><b>ショート(縦)も同じ 72 秒で出すか。</b><span class="rec"><em>おすすめ: 出す。</em> ショートは 3 分まで出せる。縦は 2 人が枠に収まるかを先に数えてから書き出す。</span></li>'
                '</ol></section>')
    body.append('<section><h2>このあとの流れ</h2><p class="note">合意できたら、(1) 3 人を相手にできる組み立てと新しい動作・効果を作る、(2) 幕ごとに振り付けを組んで点検に通す、(3) 横と縦を書き出して見せる、(4) 投稿、の順で進めます。'
                'コマを直したい所は、番号で教えてください(例: 「8 をもっと派手に」「第二幕を短く」)。</p></section>')
    page = sp.HEAD.replace("<title>勝ち抜き戦 絵コンテ</title>", "<title>3対1 絵コンテ</title>") + "<main>" + "".join(body) + "</main>"
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(OUT / "index.html", len(page) // 1024, "KB", n, "コマ")


if __name__ == "__main__":
    main()
