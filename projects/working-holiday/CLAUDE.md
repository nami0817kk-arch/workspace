# working-holiday — ワーホリ条件くらべ（wh.dailyquarry.com）

ワーキング・ホリデーに行く人向けに、日本と制度がある32か国・地域の条件を1つの表で比べる静的サイト。
2026-10-05 にユーザーの指示で着手（「ワーホリについてまとめたサイト。行く人向け」）。
収益は Amazon アソシエイト（持ち物ページ）と、のちに AdSense。

## 作り

- `data/mofa.json` … 外務省「ワーキング・ホリデー制度」の一覧（国・開始年・年間発給枠）。**土台はここだけ**
- `data/countries/<id>.json` … 各国の公式ページで確かめた条件。形は既存のファイルを見る
- `src/render.py` … 2つを重ねて `output/` に HTML を作る。`python src/render.py`
- `src/site_config.py` … ドメイン・名義・**AMAZON_TAG**（空のあいだは Amazon のリンクも表記も出ない）

## データの決まり（テストで止める）

- **推測で埋めない。** 公式ページで確かめられない項目は `""` にして `unverified` に入れる。ページには「公式サイトで確認」と出る
- 出典は各国の政府・移民局・駐日大使館の公式ページだけ。業者・まとめ・ブログは根拠にしない
- 金額は原文の通貨のまま。円に換算しない（為替で変わる）
- 外務省の一覧が変わったら（国の追加・枠の変更）`mofa.json` を直す。as_of も直す

## 公開

`master` に入ると `.github/workflows/working-holiday-deploy.yml` が Cloudflare Pages（プロジェクト名 working-holiday）へ出す。
`wh.dailyquarry.com` は Pages の Custom domains に足す（docs/public-identity.md）。
アクセス解析は入れない（他サイトと同じ方針）。
