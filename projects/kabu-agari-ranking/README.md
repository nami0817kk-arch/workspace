# kabu-agari-ranking

日本株（東証プライム/スタンダード/グロース）の値上がり率・値下がり率・活況銘柄ランキングを
毎日自動取得し、静的サイトとして公開する。広告（Google AdSense想定）による収益化が目的。

公開URL: https://kabu-agari-ranking.pages.dev/

GitHub Actions が毎日平日 16:00 JST（大引け後）にランキングを取得・記録し、
Cloudflare Pages に自動デプロイする。

## ページ構成

- `/index.html` 値上がりランキング（本日）
- `/losers.html` 値下がりランキング（本日）
- `/active.html` 活況銘柄ランキング（本日、約定回数ベース）
- `/archive/{gainers,losers,active}/` 各ランキングの過去日アーカイブ
- `/about.html` `/privacy.html`

## 構成

```
src/
  fetcher.py     kabutan.jp から当日の値上がり/値下がり/活況ランキングを取得
  build_site.py  取得→data/*.json保存→サイトビルドのエントリポイント
  render.py      Jinja2テンプレートからoutput/に静的HTMLを生成
templates/       ページテンプレート（Jinja2）
static/          og-image.png など、ビルドのたびにoutput/へそのままコピーする静的アセット
data/            日別ランキング（YYYY-MM-DD.json）
output/          ビルド成果物（gitignore対象、CI実行のたびに再生成）
```

## ローカルでの動作確認

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt pytest
pytest                      # テスト（ネットワーク不要）
python src/build_site.py    # 取得 → data/ 保存 → output/ 生成
```

## テスト

`tests/` に、ネットワークに出ずに動くテストを置いている。

- `test_fetcher.py` kabutan の HTML 解析と、ランキングの絞り込み・並び替え
- `test_render.py` 過去データの読み込み（旧形式の変換を含む）とページ生成

取得先の HTML 構造が変わると、例外ではなく「空のランキング」という形で壊れる。
そこを検知するためのものなので、`src/fetcher.py` を触ったらテストも合わせて更新する。

## 秘密情報

X API と Cloudflare の認証情報は `.env`（gitignore 済み）か GitHub Secrets に置く。
必要なキー名は `.env.example` を参照。

`output/index.html` をブラウザで開いて確認する。

## 自動更新（GitHub Actions）

`.github/workflows/daily-gainers-site.yml` が平日 16:00 JST に自動実行し、
`data/*.json`（当日ランキング）をコミット、`output/` を Cloudflare Pages にデプロイする。
手動テストは GitHub の Actions タブから `workflow_dispatch` で実行できる。

市場休場日などでランキングが0件の場合は、`data/` への新規コミットをスキップする
（既存データは壊さない）。

## AdSense（要対応・TODO）

- `templates/base.html` に広告枠のプレースホルダーを設置済み（`data-ad-client="ca-pub-XXXXXXXXXXXXXXXX"`）。
  AdSenseアカウントの取得・審査申請はユーザー本人が行う必要がある。
  審査には一般的に、プライバシーポリシー・実際のコンテンツ・一定期間の運用実績が求められる。
- 審査通過後、`templates/base.html` の publisher ID・ad-slot ID を実際の値に置き換え、
  コメントアウトしている `<script>` タグを有効化する。

## 既知の制約・注意事項（v1時点）

- データ取得元（kabutan.jp）のスクレイピングは利用規約上のリスクを許容した上で採用している。
  今後規約変更や取得停止要請があった場合はデータ取得方法の見直しが必要。
- 「活況銘柄ランキング」はkabutan.jp上「本日の活況銘柄」（mode=2_9）を使用しており、
  実体は出来高（株数）ではなく約定回数によるランキングである点に注意（about.htmlに明記）。
- 掲載日付（rec_date）は取得実行日ではなく、kabutan.jpページ内の実際の終値基準日
  （`<time datetime="YYYY-MM-DD">終値</time>`）から取得している。休場日に手動実行しても
  直近営業日の日付で正しくラベル付けされる（fetcher.py の `_extract_asof_date`）。
- 掲載情報は投資助言ではない旨を `templates/about.html` に明記している。
- お問い合わせ先は未設定（保留中）。AdSense審査前に用意することを推奨。

## 由来

もとは `nami0817kk-arch/claude-code-dev` リポジトリ内の `PJT006-gainer-ranking-site` として
開発したが、公開URLをサイト内容に合ったものにするため本リポジトリに切り出した。
