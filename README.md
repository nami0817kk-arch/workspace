# PJT008 - AIラボ

[![tests](https://github.com/nami0817kk-arch/ai-lab/actions/workflows/tests.yml/badge.svg)](https://github.com/nami0817kk-arch/ai-lab/actions/workflows/tests.yml)

AI活用のアイデア検証・試作を行うラボプロジェクト。

## できること

| コマンド | 内容 |
|---|---|
| `ailab gen "プロンプト"` | 画像を生成する（**APIキー無しでも Pollinations で本物のAI画像**。OpenAI / Gemini / Replicate / Hugging Face / Stability にも対応） |
| `ailab search "キーワード"` | フリー素材を横断検索する（Iconify / Openverse / Wikimedia / Pixabay / Unsplash / Pexels） |
| `ailab fetch "キーワード"` | フリーイラストを検索してダウンロードし、クレジットも書き出す |
| `ailab feed "対象" --source rss\|github\|qiita` | 記事・リリース情報を取得する |
| `ailab publish FILE --repo owner/name` | 生成物を GitHub へコミットする（既定はドライラン） |
| `ailab usage` | 画像生成の利用量と概算コストを見る |
| `ailab run レシピ` | 「集める→作る→送る」をYAML1本で実行する |
| `ailab mcp` | MCPサーバとして起動し、Claude から直接使えるようにする |
| `ailab connectors` / `ailab doctor` | 連携先の設定状況を見る / 実際に接続して確認する |

詳しい使い方は [docs/image-tools.md](docs/image-tools.md)。
レシピの書き方は [docs/recipes.md](docs/recipes.md)、
Claude から直接使う方法は [docs/mcp.md](docs/mcp.md)、
連携の仕組みと増やし方は [docs/connectors.md](docs/connectors.md)、
今後の計画は [docs/integrations-plan.md](docs/integrations-plan.md)。

## まず試す（APIキーなしで動きます）

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
pip install -e .
```

```bash
ailab connectors                                     # 何が使える状態か
ailab gen "青空の下でノートPCを使う猫" --style flat   # 本物のAI画像（Pollinations）
ailab fetch "cat illustration" -l 3                  # フリー素材＋クレジット
```

キーが1つも無くても、`pollinations`（生成）と `iconify` / `openverse` /
`wikimedia`（素材）が動きます。生成物は `output/`（Git管理外）へ。

## APIキーを足す

```bash
copy .env.example .env   # 使うものだけ記入
ailab doctor             # 実際に接続して確認（-- は未設定、NG は失敗）
```

有料APIを使い始めたら `ailab usage` で使用量と概算コストを確認できます。

## 構成

| フォルダ | 用途 |
|---|---|
| `src/` | 実装コード（`core/` … 連携基盤、`connectors/` … 連携先を1ファイル1つ） |
| `docs/` | 調査メモ・検証記録 |
| `recipes/` | レシピ（`ailab run` で実行するYAML） |
| `tests/` | テストコード（`python -m pytest`。外部通信はモック） |

開発時の決めごとは [CLAUDE.md](CLAUDE.md)。

## ライセンスの注意

`ailab fetch` は取得先の `CREDITS.md` / `credits.json` に出典とライセンスを残す。
CC BY 系はクレジット表示が必須なので、成果物に使うときは必ず確認すること。
