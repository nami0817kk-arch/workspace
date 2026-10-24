"""絵コンテ「3 対 1」のページ(HTML)。out/storyboard3/panels.json とコマの画像から out/storyboard3/index.html を書く。
見た目は勝ち抜き戦の絵コンテ(storyboard_page.py)と同じ。画像は sb3/ 以下の相対パス(公開時に files で渡す)。

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


def main():
    panels = json.loads((OUT / "panels.json").read_text(encoding="utf-8"))
    cards = "".join(sp.card(p["img"], i + 1, p) for i, p in enumerate(panels))
    body = []
    body.append('<header><h1>3 対 1 絵コンテ<br>倒した 3 人が、まとめて仕返しに来る</h1>'
                '<p class="lead">動画にする前に、流れをコマで見て合わせるためのページです。勝ち抜き戦で倒した青(蹴り使い)・紫(巨漢)・赤(喧嘩屋)が、夕暮れの境内で緑を囲みます。'
                '姿勢は手で組んだスケッチです。いまの動作部品は 1 対 1 しか組めないので、合意できたら 3 人を相手にできる形を作ってから動画にします。</p></header>')
    body.append('<section><h2>流れ(約 15 秒の戦い)</h2><div class="tablewrap"><table><thead><tr><th>時刻</th><th>見せ場</th><th>ねらい</th></tr></thead><tbody>'
                '<tr><td class="num">0〜2 秒</td><td>囲まれる → 左右から同時に飛びかかる → 跳んでかわして同士討ち</td><td>3 対 1 の不利と、それを逆手に取る笑いの一拍</td></tr>'
                '<tr><td class="num">3〜6 秒</td><td>前後を同時にさばく → 巨漢に効かない → 一撃で吹き飛ぶ → 衝撃波が赤を巻き込む</td><td>巨漢の強さでいったんピンチ。敵どうしもぶつかる</td></tr>'
                '<tr><td class="num">7〜10 秒</td><td>青とバク転の打ち合い → 青を巨漢へ飛ばす → 背後の赤に後ろ蹴り</td><td>1 人ずつ崩していく。前後左右に向きが入れ替わる</td></tr>'
                '<tr><td class="num">10.5 秒</td><td>3 人が並んで構え直す(0.6 秒の静止)</td><td>嵐の前の間。ここだけ全員が止まる</td></tr>'
                '<tr><td class="num">11〜15 秒</td><td>竜巻の跳び回し蹴りで 2 人 → 巨漢に空中コンボ → 決めの止め絵</td><td>大技 2 つで一気に決着</td></tr>'
                '</tbody></table></div></section>')
    body.append(f'<section><h2>コマ割り</h2><div class="board">{cards}</div></section>')
    body.append('<section><h2>エフェクト</h2><p class="lead">勝ち抜き戦で決めた付け方のまま使います。当たりは黄色い火花、受けは青い輪、速い振りに軌跡、走り出し・着地・叩きつけに土煙、吹き飛びに流線、決めの一撃だけ閃光 1 コマ。擬音の文字・白黒反転・放射線は付けません。</p></section>')
    body.append('<section><h2>新しく作るもの</h2><ul class="vocab">'
                '<li><b>3 人を相手にする組み立て</b>緑が左右に向きを変えて戦う(いまは 1 対 1 で向きが固定)。敵どうしがぶつかる「同士討ち」も当たりとして扱う。</li>'
                '<li><b>後ろ蹴り</b>前を向いたまま、背後の相手へ足を突き出す。</li>'
                '<li><b>竜巻の跳び回し蹴り</b>跳んで体ごと回り、2 人まとめて当てる。</li>'
                '<li><b>前後を同時にさばく</b>前へ蹴りながら、後ろの拳を腕で受ける。</li>'
                '</ul><p class="note">バク転・衝撃波・空中コンボ・吹き飛びは、勝ち抜き戦で作ったものを使います。</p></section>')
    body.append('<section><h2>決めたいこと</h2><ol class="q">'
                '<li><b>この流れでよいか。</b><span class="rec"><em>おすすめ: このまま。</em> 同士討ちを 2 回入れて、3 対 1 ならではの笑いを作っています。多すぎると感じたら、衝撃波の巻き込み(7)を外します。</span></li>'
                '<li><b>長さは約 20 秒(戦い 15 秒 + 歩き入り)の 1 本でよいか。</b><span class="rec"><em>おすすめ: 約 20 秒。</em> ショート(縦)にもそのまま出せる長さ。横は勝ち抜き戦の続編として、本編にも上げます。</span></li>'
                '</ol></section>')
    body.append('<section><h2>このあとの流れ</h2><p class="note">合意できたら、(1) 3 人を相手にできる組み立てと、後ろ蹴り・竜巻蹴り・前後さばきを作る、(2) 振り付けを組んで点検に通す、(3) 横と縦を書き出して見せる、(4) 投稿、の順で進めます。'
                'コマを直したい所は、番号で教えてください(例: 「7 を外して」「12 をもっと派手に」)。</p></section>')
    page = sp.HEAD.replace("<title>勝ち抜き戦 絵コンテ</title>", "<title>3対1 絵コンテ</title>") + "<main>" + "".join(body) + "</main>"
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(OUT / "index.html", len(page) // 1024, "KB")


if __name__ == "__main__":
    main()
