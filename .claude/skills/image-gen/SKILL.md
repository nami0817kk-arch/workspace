---
name: image-gen
description: このリポジトリで画像を生成する。ユーザーが「画像を作って」「イラストを生成して」「バナー/アイキャッチ/ダミー画像が欲しい」と言ったときに使う。OpenAI / Gemini / Stability のAPI、またはAPIキー不要のローカル生成を使い分ける。
---

# 画像生成

`ailab gen` コマンドを使う。実装は `src/ailab/connectors/images_*.py`。

## 手順

1. 使えるコネクタを確認する（初回のみ）。

   ```bash
   python -m ailab connectors   # PYTHONPATH=src が必要。pip install -e . 済みなら ailab connectors
   ```

2. 生成する。プロンプトは具体的に（被写体・構図・画風・色）。

   ```bash
   python -m ailab gen "青空の下でノートPCを使う猫、フラットイラスト、パステル調" --size 1024x1024
   ```

3. 保存先パス（既定 `output/images/`）をユーザーに伝え、必要なら画像を Read して内容を確認する。

4. GitHub へ置きたいと言われたら `python -m ailab publish <path> --repo owner/name --path <保存先>`。
   既定はドライランなので、内容を見せて確認を取ってから `--yes` を付ける。

## 使い分け

- `--provider auto`（既定）… APIキーがあるものを優先。
- APIキーが1つも無い場合は自動的に `local` になる。これは**生成AIではなく**、
  プロンプトから決まるグラデーション画像。プレースホルダやダミーには十分だが、
  「猫の絵」を頼まれて `local` しか無いときは、その旨を伝えて
  APIキー設定（`.env`）か `ailab fetch` でのフリー素材取得を提案する。
- 枚数は `-n`、サイズは `--size 1024x1024`、モデルは `--model`。

APIキーは `.env`（`.env.example` 参照）に置く。値を読み取ってログや応答に出さないこと。
