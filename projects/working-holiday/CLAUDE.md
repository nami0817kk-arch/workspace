# working-holiday — ワーホリ条件くらべ（wh.dailyquarry.com）

ワーキング・ホリデーに行く人向けに、日本と制度がある32か国・地域の条件を1つの表で比べる静的サイト。
2026-10-05 にユーザーの指示で着手（「ワーホリについてまとめたサイト。行く人向け」）。
収益は Amazon アソシエイト（持ち物ページ）と、のちに AdSense。

## 作り

- `data/mofa.json` … 外務省「ワーキング・ホリデー制度」の一覧（国・開始年・年間発給枠）。**土台はここだけ**
- `data/countries/<id>.json` … 各国の公式ページで確かめた条件。形は既存のファイルを見る
- `src/render.py` … 2つを重ねて `output/` に HTML を作る。`python src/render.py`
- `src/site_config.py` … ドメイン・名義・**AMAZON_TAG**（空のあいだは Amazon のリンクも表記も出ない）

- `data/arrival/<id>.json` … 現地に着いてからの手続き・日本語が通じる医療機関・最低賃金・仕事探しの窓口（32か国）
- `data/links.json` … 外務省「世界の医療事情」・現地の日本大使館・緊急の番号
- `data/basics.json` … 首都・通貨・時間帯（時差はビルドの年の1月と7月で計算）
- `data/geo/` … 地図の元データ（world-atlas、Natural Earth 由来）。`src/geo.py` が Equal Earth 図法で SVG にする
- `static/flags/` … 国旗（flag-icons、MIT）。`static/og.png` は `tools/make_og.py` で作る（Windows のフォントを使うので手元で）
- `templates/site.css` … 全ページ共通の見た目。`static/site.css?v=<ハッシュ>` として出る

ページ: トップ（地図・発給枠のグラフ・10年ごとの柱・比較表）、国（32）、地域（5）、2か国比較（36）、
準備、現地に着いたら、手続き早見表、よくある質問、持ち物、運営まわり。

点検: `python tools/check_links.py`（外部リンク。政府サイトは機械からの読み取りを断ることがあるので CI では回さない）

## データの決まり（テストで止める）

- **推測で埋めない。** 公式ページで確かめられない項目は `""` にして `unverified` に入れる。ページには「公式サイトで確認」と出る
- 出典は各国の政府・移民局・駐日大使館の公式ページだけ。業者・まとめ・ブログは根拠にしない
- 金額は原文の通貨のまま。円に換算しない（為替で変わる）
- 値や要点に「確認できず」「推定」などの調査メモを書かない（tests の MEMO で止まる）
- 「日本語が通じる医療機関」には、出典に日本語での対応が書いてあるものだけを載せる
- 法定の最低賃金が無い国は `jobs.no_statutory: true` にして、説明は `jobs.rules` に書く
- 外務省の一覧が変わったら（国の追加・枠の変更）`mofa.json` を直す。as_of も直す

## 公開

`master` に入ると `.github/workflows/working-holiday-deploy.yml` が Cloudflare Pages（プロジェクト名 working-holiday）へ出す。
`wh.dailyquarry.com` は Pages の Custom domains に足す（docs/public-identity.md）。
アクセス解析は入れない（他サイトと同じ方針）。
