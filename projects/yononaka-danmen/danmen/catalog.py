# -*- coding: utf-8 -*-
"""どの図・どの画面を使うかの索引。

図と画面が 58 種になり、**どれをいつ使うか分からなくなった**（2026-10-08）。
名前（charts2 / charts4 …）からは中身が分からないので、
**「何を見せたいか」から引けるようにする**。

    python scripts/which.py 内訳        # 内訳を見せる図を探す
    python scripts/which.py             # 全部を用途ごとに並べる

同じことができる図が複数あるときは、**先に書いてあるものを使う**。
あとのものは、前のが合わないときの控え。
"""
from __future__ import annotations

# (呼び出し方, 何を見せる図か, いつ使うか)
Item = tuple[str, str, str]

CATALOG: dict[str, list[Item]] = {
    "内訳・割合": [
        ("charts5.receipt", "レシート風の明細。金額を1行ずつ", "店頭価格175円の中身を分ける"),
        ("charts4.donut", "ドーナツ。真ん中に数字を置ける", "割合を見せ、中央に合計を置く"),
        ("figures.stack", "積み上げの帯", "割合を長さで見せる"),
        ("figures.pie", "円グラフ", "donut が合わないとき"),
        ("charts2.waterfall", "増減の積み重ね", "何が上げ、何が下げたか"),
    ],
    "比べる（2つ）": [
        ("news4.versus", "左右の全画面比べ", "日本と1国を強く対比する"),
        ("charts6.icon_compare", "大きなアイコン2つ", "板のなかで仕組みを比べる"),
        ("news3.before", "写真の左右比べ", "前と後を写真で"),
        ("figures.convert", "言い換え", "1リットル → 1年ぶん に直す"),
    ],
    "比べる（3つ以上）": [
        ("news.ranking", "横棒。注目の1本だけ色が付く", "各国・各項目を並べる"),
        ("charts5.verdict", "◎○△×の比較表", "案を複数の物差しで比べる"),
        ("charts5.numberline", "数直線", "世界のなかでどのあたりか"),
        ("figures.table", "値を並べる表", "数字をそのまま比べる"),
        ("figures.compare", "横棒", "ranking が合わないとき"),
    ],
    "ひとつの数字を強く": [
        ("news.big_number", "数字ひとつ。ニュース調", "節の山場で数字を出す"),
        ("fullscreen.number", "画面いっぱいの数字", "いちばん強く出したいとき"),
        ("talk.reaction", "聞き手が驚く＋大きな数字", "1本に2回まで"),
        ("figures.hero", "板のなかで大きく", "板の流れを崩したくないとき"),
    ],
    "時間": [
        ("figures.timeline", "年表。**過去**の出来事を並べる", "いつ決まったかを見せる"),
        ("charts4.schedule", "**これから**の予定", "この先どうなるか"),
        ("charts2.line", "折れ線", "推移を見せる"),
        ("news.change", "前と後ろ、増減を▲▼で", "いくら変わったか"),
    ],
    "流れ・関係": [
        ("charts6.icon_flow", "アイコンを矢印でつなぐ", "お金が誰から誰へ動くか"),
        ("charts3.relation", "相関図", "登場人物の関係を見せる"),
        ("figures.flow", "箱を矢印でつなぐ", "アイコンが要らないとき"),
    ],
    "並べる・まとめる": [
        ("charts6.icon_list", "アイコン付きの箇条書き", "見立ての節で理由を並べる"),
        ("news3.points", "きょうのポイント3つ（全画面）", "締めで使う"),
        ("news.board", "一覧の板", "項目と値を並べる"),
        ("figures.bars", "番号つきの箇条書き", "板のなかで並べる"),
        ("charts6.icon_stats", "アイコン＋数字を横に並べる", "節の頭でこの回の数字を出す"),
        ("charts3.stats", "数字を3つ並べる", "1日／1年／生涯のように尺度を変えて"),
    ],
    "判定・条件": [
        ("charts5.flowchart", "分岐の図", "「あなたは当てはまるか」を辿らせる"),
        ("charts4.checklist", "○×で条件を並べる", "なぜそうならないかの整理"),
        ("charts5.matrix", "4象限", "2つの軸で位置づける"),
        ("charts3.calc", "計算の式", "どう出した数字かを隠さない"),
        ("charts3.gauge", "半円のメーター", "割合をひとつ"),
        ("charts4.thermometer", "横のゲージ", "目標までどれだけ来たか"),
    ],
    "地図": [
        ("figures.world", "世界地図", "国ごとに塗る"),
        ("charts2.japan", "日本地図", "都道府県ごとに塗る"),
    ],
    "人の数": [
        ("charts2.people", "人の絵で「10人のうち4人」", "割合を人数で実感させる"),
    ],
    "出典・引用": [
        ("screens.quote", "原文の引用（全画面）", "条文や報告書の一節"),
        ("news3.statement", "公式の発言", "誰が・いつ・どこで言ったか"),
        ("charts4.newspaper", "新聞記事風", "どう報じられたか"),
        ("news3.glossary", "ことばの意味（全画面）", "難しい言葉が出たら止めて説明"),
        ("figures.photo", "写真＋説明", "現場を見せる"),
    ],
    "節の区切り": [
        ("screens.chapter", "節の中扉", "何節目で何を見るか"),
        ("news4.recap", "ここまでのおさらい", "節の切れ目で置いていかない"),
        ("talk.talk", "2人が左右に立って1往復", "問いを立てる・つなぐ"),
        ("news3.qa", "問いと答えの札", "誤解を潰す節で"),
    ],
    "ニュースの作法": [
        ("news2.breaking", "速報の帯", "報じられたことを出す"),
        ("news2.lshape", "L字（右と下に枠）", "映像を見せながら情報を出す"),
        ("news4.live", "中継風", "現地の写真に場所と日を添える"),
        ("news2.split", "分割画面（左に実写・右に数字）", "写真と数字を同時に"),
        ("studio.flip", "スタジオ解説のフリップ", "日テレ式の札を並べる"),
        ("news4.poll", "世論調査の結果", "調査の素性を必ず添える"),
        ("news2.voices", "街の声", "属性つき。顔は出さない"),
        ("fullscreen.ranking", "画面いっぱいの横棒", "板を使わず強く出す"),
        ("fullscreen.change", "画面いっぱいの増減", "板を使わず強く出す"),
    ],
    "冒頭と締め": [
        ("screens.title", "冒頭。問いを画面いっぱいに", "1本の始まり"),
        ("screens.agenda", "きょう見る断面の目次", "冒頭。あと何があるか見せる"),
        ("screens.outro", "締め。次回の問い", "1本の終わり"),
        ("screens.thumbnail", "サムネイル", "投稿のときに使う"),
    ],
}

# 仕上げに掛けるもの（図ではない）
FINISH = [
    ("texture.finish(im, 'panel')", "紙の目・わずかな暖色", "板に載せる図に"),
    ("texture.finish(im, 'screen')", "粒子・四隅の落ち・暖色", "全画面に"),
    ("annotate.apply(im, marks)", "手で書き込んだ強調9種", "質感のあと、1画面に2つまで"),
    ("sequence.grow(fn, fig)", "項目が1つずつ増える列", "語りに合わせて出す"),
    ("sequence.reveal(im, marks)", "書き込みが1つずつ増える列", "同上"),
]


def find(word: str) -> list[tuple[str, Item]]:
    """その言葉に当たる図を探す。用途・名前・説明のどれかに含まれれば拾う。"""
    out = []
    for use, items in CATALOG.items():
        for it in items:
            if word in use or word in it[0] or word in it[1] or word in it[2]:
                out.append((use, it))
    return out
