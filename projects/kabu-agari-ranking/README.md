# kabu-agari-ranking

日本株（東証プライム/スタンダード/グロース）の値上がり率・値下がり率・活況銘柄ランキングを
東証の営業日ごとに取得し、静的サイトとして公開する。広告（Google AdSense 想定）による収益化が目的。

公開URL: https://kabu-agari-ranking.pages.dev/

## 動かし方（誰が何をやるか）

**取得は手元PCのタスクスケジューラ「kabu-daily-fetch」**（平日16:10、`run-daily.ps1`）が行う。
kabutan は GitHub Actions の IP を 405 でブロックするため、**CI から取得する形に戻さないこと**。

```
手元PC 16:10  run-daily.ps1
   ├ git pull（失敗時は最大3回まで引き直す。ネット断が多いため）
   ├ build_site.py  取得 → 検査 → data/YYYY-MM-DD.json 保存 → output/ 生成
   ├ git commit & push（data/ のみ）
   ├ post_to_x.py   X へ投稿（キーが無ければ何もしない）
   └ check_freshness.py --after-fetch  当日分が無ければデスクトップ通知
        ↓ push
GitHub Actions（kabu-daily.yml）
   ├ pytest
   ├ build_site.py --no-fetch（data/ からビルドのみ）
   ├ Cloudflare Pages へデプロイ
   └ check_freshness.py（平日17:00 の定期実行でも回る。遅れていたら Issue）
```

失敗はデスクトップ通知で知らせる（ネット断のときは GitHub もメールも届かないため）。
**kabutan へのリトライは入れない。**

## ページ

| URL | 中身 |
|---|---|
| `/` `/losers` `/active` | 本日の値上がり・値下がり・活況（約定回数）ランキング |
| `/archive/{gainers,losers,active}/` | 営業日ごとのアーカイブと、その一覧 |
| `/weekly/` | 週ごとのまとめ（日をまたいだ最大上昇・複数回ランクイン） |
| `/frequent` | 何度もランクインした銘柄 |
| `/search` | 銘柄名・コードから過去の登場日を引く（索引は `search-index.json`） |
| `/guide` `/glossary` | ランキングの読み方・用語解説 |
| `/about` `/privacy` | 概要・プライバシーポリシー |
| `/feed.xml` `/sitemap.xml` `/robots.txt` `/404.html` | 配信まわり |

## 構成

```
src/
  build_site.py      取得 → 検査 → data/ 保存 → サイト生成のエントリポイント
  fetcher.py         ランキングの組み立て（取得・解析は libs/kabutan）
  validate.py        保存してよいデータかの検査（日付・件数・騰落率）
  render.py          Jinja2 テンプレートから output/ を生成
  aggregate.py       常連銘柄・週まとめ・検索索引の集計
  charts.py          SVG のグラフ（外部ライブラリを使わない）
  price_limit.py     制限値幅からストップ高・ストップ安を判定
  market_calendar.py 東証の休場日（内閣府の祝日表＋年末年始）
  check_freshness.py データが止まっていないかの監視
  feed.py            RSS 2.0
  post_to_x.py       X への投稿
templates/           ページテンプレート（Jinja2）
static/              og-image.png など、そのまま output/ へ写すもの
data/                日別ランキング（YYYY-MM-DD.json）。**取り直しがきかない資産**
output/              ビルド成果物（gitignore 済み。毎回作り直す）
```

## ローカル

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -e ../../libs/kabutan -r requirements.txt pytest

pytest                                 # ネットワークに出ない
python src/build_site.py               # 取得 → 保存 → 生成
python src/build_site.py --no-fetch    # 取得せず data/ から生成するだけ
python src/build_site.py --force       # 検査を飛ばして保存（誤検知したときだけ）
```

`output/index.html` を開いて確認する。検索ページだけは `fetch` を使うので、
ファイルを直接開かず簡易サーバ越しに見る（`python -m http.server --directory output`）。

## 気をつけること

- **取り逃した営業日は二度と取れない。** kabutan は当日分しか出さない。
  取得が失敗した日は、その日のうちに `src/build_site.py` を手で回す。
- **日付を `<time>` の先頭から採ってはいけない。** ページ冒頭の指数ヘッダは
  NYダウ → 国内指数の順で、先頭は米国市場の終値日。2026-09-07 に国内ランキングが
  1営業日ずれ、金曜分を月曜のデータで上書きした。判定は `libs/kabutan` の
  `extract_asof_date` がランキング表自身の日付から行う。
- **鮮度の警報は Deploy より後に置く。** 手前に置くと、警報が出た日は公開まで
  道連れで止まる（2026-09-22 に発生）。
- 依存は `==` で固定する。更新は Dependabot の PR で受け取る。
- 秘密情報は `.env`（gitignore 済み）か GitHub Secrets へ。キー名は `.env.example`。

## テスト

`tests/` はすべてネットワーク無しで動く。

| ファイル | 見ているもの |
|---|---|
| `test_fetcher.py` | HTML 解析、ランキングの絞り込みと並び替え |
| `test_validate.py` | 保存前の検査（日付ずれ・件数不足・騰落率の異常） |
| `test_market_calendar.py` | 休場日と、鮮度判定の期待値 |
| `test_price_limit.py` | ストップ高・ストップ安の判定（実データ入り） |
| `test_render.py` `test_site_pages.py` | ページ生成、旧形式の読み込み、要約・欠測の表示 |
| `test_aggregate.py` | 常連銘柄・週まとめ・検索索引 |
| `test_charts.py` | グラフの軸・はみ出し・ラベル・色 |
| `test_feed.py` | RSS が妥当な XML か |
| `test_links.py` | 全リンクが実在するか、孤立ページが無いか |

取得先の HTML 構造が変わると、例外ではなく「空のランキング」という形で壊れる。
`src/fetcher.py` や `libs/kabutan` を触ったらテストも合わせて更新する。

## 独自ドメインへ移す

`pages.dev` は数百万サイトの共有サブドメインで、Google の評価が付きにくい
（2026-09-24 時点で、sitemap の183URLのうちインデックスは1件だけ）。
AdSense の審査要件でもあるので、独自ドメインへ移す。

手順（上から順に）:

1. **ドメインを取る。** DNS が Cloudflare にあるので、Cloudflare Registrar が
   いちばん手数が少ない（原価販売・更新も同額・DNS 設定が自動）。
2. **Cloudflare Pages にカスタムドメインを追加。**
   Pages → kabu-agari-ranking → Custom domains → Set up a custom domain。
   同じ Cloudflare アカウントのドメインなら DNS は自動で入る。
3. **`src/site_config.py` の `SITE_URL` を新ドメインに変える。** 触るのはここだけ
   （canonical・sitemap・RSS・OGP・X の投稿文が全部ここを見ている）。
4. **push してデプロイ。** 生成物の canonical と sitemap が新ドメインになる。
5. **Search Console に新しいプロパティを登録。** DNS(TXT) で確認すると
   コードを触らずに済む（meta タグでやるなら `SEARCH_CONSOLE_TOKEN` を差し替える）。
   登録したら `https://<新ドメイン>/sitemap.xml` を送信する。
6. **旧URL（pages.dev）はそのまま残る。** Pages の既定サブドメインは無効化できず、
   ホスト名単位のリダイレクトも Pages 側では書けない。canonical が新ドメインを
   指しているので重複は避けられる。気になるなら Cloudflare の Redirect Rules で
   pages.dev → 新ドメインの 301 を1本足す。
7. **AdSense はこのあと。** 独自ドメインになってから申請する。

## AdSense（残作業）

- 有効化は `render.ADSENSE_CLIENT` に pub-ID を入れる1箇所だけ。
  空のあいだは広告スクリプトも枠も描かない（審査前に空の枠を置かない）。
- **未了**: 独自ドメイン（`pages.dev` は審査に通りにくい。費用が発生するので要判断）、
  運営者情報とお問い合わせ先（`about.html`）。
- アカウント取得と審査申請は利用者本人が行う必要がある。

## 既知の制約

- kabutan のスクレイピングは規約上のリスクを許容して採用している。
  取得停止要請などがあれば取得方法の見直しが必要。
- 「活況銘柄」は出来高（株数）ではなく**約定回数**のランキング（about に明記）。
- 掲載開始直後の4日分は集計日の判定が信用できず除外していたが、2026-09-24 に
  株探の日足と突き合わせて実際の相場日を確定させ、公開に戻した
  （`tools/verify_rec_date.py` / 読み替えは `render.DATE_CORRECTIONS`）。
- 制限値幅を超える変動は「ストップ高」と言い切らない。値幅の拡大や
  株式分割・併合でも起こるため、「制限値幅超」として注記に留める。

## 由来

もとは `nami0817kk-arch/claude-code-dev` の `PJT006-gainer-ranking-site`。
公開URLをサイト内容に合わせるため切り出し、2026-09-01 に workspace モノレポへ統合した。
