# PJT008 - AIラボ

AI活用のアイデア検証・試作を行うラボプロジェクト。

## できること

| コマンド | 内容 |
|---|---|
| `ailab gen "プロンプト"` | 画像を生成する（OpenAI / Gemini / Stability、APIキー無しでも動く `local` あり） |
| `ailab search "キーワード"` | Web上のフリーイラストを横断検索する（Openverse / Wikimedia / Pixabay） |
| `ailab fetch "キーワード"` | フリーイラストを検索してダウンロードし、クレジットも書き出す |
| `ailab status` | 使えるプロバイダ・素材サイトを確認する |

詳しい使い方は [docs/image-tools.md](docs/image-tools.md)。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
pip install -e .
copy .env.example .env   # 使うAPIキーだけ入れる（無くても local 生成と Openverse 検索は動く）
```

```bash
ailab status
ailab gen "青空の下でノートPCを使う猫、フラットイラスト"
ailab fetch "cat illustration" -l 3
```

生成物は `output/`（Git管理外）に保存される。

## 構成

| フォルダ | 用途 |
|---|---|
| `src/` | 実装コード（`src/ailab/` … 画像生成 `imagegen/` とフリー素材 `illust/`） |
| `docs/` | 調査メモ・検証記録 |
| `tests/` | テストコード（`python -m pytest`。外部通信はモック） |

## ライセンスの注意

`ailab fetch` は取得先の `CREDITS.md` / `credits.json` に出典とライセンスを残す。
CC BY 系はクレジット表示が必須なので、成果物に使うときは必ず確認すること。
