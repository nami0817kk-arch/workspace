# PJT008 - AIラボ

AI活用のアイデア検証・試作を行うラボプロジェクト。

## できること

| コマンド | 内容 |
|---|---|
| `ailab gen "プロンプト"` | 画像を生成する（**APIキー無しでも Pollinations で本物のAI画像**。OpenAI / Gemini / Replicate / Hugging Face / Stability にも対応） |
| `ailab search "キーワード"` | フリー素材を横断検索する（Iconify / Openverse / Wikimedia / Pixabay / Unsplash / Pexels） |
| `ailab fetch "キーワード"` | フリーイラストを検索してダウンロードし、クレジットも書き出す |
| `ailab feed "対象" --source rss\|github\|qiita` | 記事・リリース情報を取得する |
| `ailab publish FILE --repo owner/name` | 生成物を GitHub へコミットする（既定はドライラン） |
| `ailab run レシピ` | 「集める→作る→送る」をYAML1本で実行する |
| `ailab mcp` | MCPサーバとして起動し、Claude から直接使えるようにする |
| `ailab connectors` / `ailab doctor` | 連携先の設定状況を見る / 実際に接続して確認する |

詳しい使い方は [docs/image-tools.md](docs/image-tools.md)。
レシピの書き方は [docs/recipes.md](docs/recipes.md)、
Claude から直接使う方法は [docs/mcp.md](docs/mcp.md)、
連携の仕組みと増やし方は [docs/connectors.md](docs/connectors.md)、
今後の計画は [docs/integrations-plan.md](docs/integrations-plan.md)。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
pip install -e .
copy .env.example .env   # 使うAPIキーだけ入れる（無くても local 生成と Openverse 検索は動く）
```

```bash
ailab connectors                                    # 何が使える状態か
ailab gen "青空の下でノートPCを使う猫、フラットイラスト"
ailab fetch "cat illustration" -l 3
```

生成物は `output/`（Git管理外）に保存される。

## 構成

| フォルダ | 用途 |
|---|---|
| `src/` | 実装コード（`core/` … 連携基盤、`connectors/` … 連携先を1ファイル1つ） |
| `docs/` | 調査メモ・検証記録 |
| `recipes/` | レシピ（`ailab run` で実行するYAML） |
| `tests/` | テストコード（`python -m pytest`。外部通信はモック） |

## ライセンスの注意

`ailab fetch` は取得先の `CREDITS.md` / `credits.json` に出典とライセンスを残す。
CC BY 系はクレジット表示が必須なので、成果物に使うときは必ず確認すること。
