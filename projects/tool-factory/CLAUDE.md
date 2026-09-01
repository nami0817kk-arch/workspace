# tool-factory — 計算ツール量産サイト

生産管理・品質・原価の計算ツールサイトを量産する仕組み。現在10ツール。
収益はアフィリエイトと広告（AdSense 審査待ち）。
**ツールを1本足すのに必要なのは `tools/` に定義ファイルを1つ置くことだけ**、という性質を守る。

## 前提

- Python 3.12、**標準ライブラリのみ**。依存を足すときは `requirements.txt` に `==` で固定し、理由を書く。
- テストは `unittest`（pytest ではない）。`python -m unittest discover -s tests`
- 公開は Cloudflare Pages（`.github/workflows/pages.yml`、リポジトリは private のまま）。**テストが通らないと公開されない**。
  収益導線の無いツールはテストが弾く。この関門を外さない。
- 設定は環境変数ではなく `site.json`（サイト名・base_url・広告ID・計測ID）。

## よく使うコマンド

```bash
python new_tool.py <slug> "<名前>" --category <分類>   # ひな型を作る
python -m unittest discover -s tests                  # テスト
python build.py            # dist/ に出力
python build.py --serve    # ローカル確認
```

## まだ決まっていないこと（着手前に決める）

- `site.json` の `owner` / `contact_email` が空。ASP・AdSense の審査で見られるため、
  公開前に埋める必要がある。**これは個人情報なので勝手に埋めない**。
- Cloudflare の Secrets（CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID）が登録されているか。kabu-agari-ranking と同じ値でよい。

## 手を入れるときに気をつけること

- `tools/_spec.py` の Tool / Field / Output / Faq / Affiliate が全ツールの契約。
  ここを変えると10ツール全部に波及する。テストを先に直す。
- `theme/` は全ページ共有。1ツールの都合で触らない。
- `dist/` は毎回作り直す生成物（gitignore 済み）。
