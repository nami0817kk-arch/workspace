# 画像生成 & フリーイラスト取得ツール

`src/ailab/` に入っている `ailab` コマンドの使い方メモ。

- **画像生成** (`ailab gen`): OpenAI / Gemini / Stability の画像生成APIを同じ書き方で呼ぶ。
  APIキーが1つも無くても、Pillow で作る `local` プロバイダが必ず動く。
- **フリーイラスト取得** (`ailab search` / `ailab fetch`): Openverse・Wikimedia Commons・Pixabay を
  横断検索し、ライセンス情報つきでダウンロードする。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux は source .venv/bin/activate
pip install -r requirements-dev.txt
pip install -e .                # ailab コマンドが使えるようになる
copy .env.example .env          # macOS/Linux は cp。使うキーだけ埋める
```

`pip install -e .` をしない場合は `python -m ailab ...` でも同じことができる
（その場合は `set PYTHONPATH=src` / `export PYTHONPATH=src` が必要）。

まず状態確認:

```bash
ailab connectors   # 連携先の一覧と設定状況（旧 ailab status も同じ）
ailab doctor       # 実際に接続して確認
```

APIキーが設定されている連携先に `OK` が付く。
連携の仕組みと増やし方は [connectors.md](connectors.md)。

## 画像生成

```bash
# APIキーがあるプロバイダを自動選択して生成
ailab gen "青空の下でノートPCを使う猫、フラットイラスト"

# プロバイダとサイズを指定して2枚
ailab gen "資料の表紙用の抽象背景" --provider openai --size 1536x1024 -n 2

# APIキー無しでプレースホルダ画像（プロンプト文字入り）
ailab gen "PJT008 AIラボ" --provider local --size 1200x630
```

保存先は既定で `output/images/`（`-o` で変更、`output/` は Git 管理外）。

| コネクタ | 環境変数 | 既定モデル | 備考 |
|---|---|---|---|
| `openai` | `OPENAI_API_KEY` | `gpt-image-2` | 新規アカウントに無料クレジットが付く（時期により変動） |
| `gemini` | `GEMINI_API_KEY` (or `GOOGLE_API_KEY`) | `gemini-2.5-flash-image` | 画像生成モデルに無料枠は無い。新しいIDは `ailab doctor` で確認して差し替える |
| `stability` | `STABILITY_API_KEY` | `core` | `--model ultra` / `sd3`。サイズは近いアスペクト比に丸められる |
| `replicate` | `REPLICATE_API_TOKEN` | `black-forest-labs/flux-schnell` | `--model owner/name` または `owner/name:バージョン`。完了まで自動で待つ |
| `huggingface` | `HF_TOKEN` (or `HUGGINGFACE_API_KEY`) | `black-forest-labs/FLUX.1-schnell` | 無料枠あり。エンドポイントは `HF_INFERENCE_URL` で差し替え可 |
| `local` | 不要 | `abstract-v1` | 生成AIではなくプロンプトから決まるグラデ画像。ダミー用 |

`--provider auto`（既定）は openai → gemini → replicate → huggingface → stability → local の順
（各コネクタの `priority`）に、使えるものを選ぶ。どのAPIも有料なので、試作中は `local` で十分なことも多い。

### モデルIDは変わる

各社のモデルは短い周期で入れ替わり、古いIDは提供終了する。
コードを直さなくても `.env` で追随できる。

```bash
AILAB_OPENAI_MODEL=gpt-image-2
AILAB_GEMINI_MODEL=gemini-3.1-flash-image
AILAB_REPLICATE_MODEL=black-forest-labs/flux-schnell
```

優先順位は `--model` 引数 > `AILAB_<コネクタ名>_MODEL` > コネクタの既定値。
Gemini で今使えるモデルは `ailab doctor` が件数を返すので、
`GET /v1beta/models` の結果（AI Studio の一覧）で確認する。

既知の提供終了（2026年8月時点で調べた範囲）:

- DALL·E 2 / 3 … 2026-05-12 に提供終了。`--model dall-e-3` はもう使えない
- `gpt-image-1.5` / `gpt-image-1-mini` / `chatgpt-image-latest` … 2026-12-01 に停止予定。移行先は `gpt-image-2`
- Imagen 各種 … 2026-08-17 に停止。Gemini の画像モデルへ移行する

## フリーイラストの検索・取得

```bash
# 使える素材サイトを横断検索（結果を目で確認する）
ailab search "猫 イラスト" -l 5

# JSON で欲しいとき（他のスクリプトに渡す用）
ailab search "cat illustration" --source openverse --json

# 検索してそのままダウンロード（既定は output/illust/）
ailab fetch "cat illustration" -l 3
```

| コネクタ | APIキー | 内容 / ライセンス |
|---|---|---|
| `iconify` | 不要 | SVGアイコン20万点以上。ライセンスはアイコンセットごと（MIT / Apache / CC BY など） |
| `openverse` | 不要 | CC0 / CC BY など作品ごとに異なる。既定で「商用利用可・改変可」に絞って検索する |
| `wikimedia` | 不要 | パブリックドメイン / CC BY-SA など |
| `pixabay` | `PIXABAY_API_KEY`（無料登録） | イラスト・ベクター。Pixabay Content License（商用可・クレジット不要） |
| `unsplash` | `UNSPLASH_ACCESS_KEY`（無料登録） | 写真。Unsplash License。ダウンロード時にAPIへ通知する（規約要件、自動で行う） |
| `pexels` | `PEXELS_API_KEY`（無料登録） | 写真。Pexels License（商用可・クレジット不要） |

アイコンだけ欲しいときは `--source iconify`、写真なら `--source unsplash` のように絞る。

### ライセンスの扱い

`ailab fetch` は画像と一緒に、保存先へ次の2つを書き出す。

- `credits.json` … 取得した素材のメタデータ（タイトル・作者・ライセンス・出典URL）
- `CREDITS.md` … 人が読む用のクレジット一覧表

CC BY / CC BY-SA 系は**表示（クレジット）が必須**なので、成果物に使うときは
`CREDITS.md` の内容を必ず添える。Wikimedia Commons の CC BY-SA は
二次的著作物へ同じライセンスを要求する点にも注意。

### いらすとや等について

いらすとや・ちょうどいいイラストなど日本の素材サイトは公開APIを持たず、
利用規約でまとめてのダウンロードを制限していることがある。
このツールはそれらをスクレイピングしない。必要なときはサイトの規約に従って手で保存すること。

## 生成物を GitHub へ送る

```bash
# 既定はドライラン（何を送るか表示するだけ）
ailab publish output/images/fuji.png --repo owner/name --path docs/img/fuji.png
# 実際にコミットする
ailab publish output/images/fuji.png --repo owner/name --path docs/img/fuji.png --yes
```

詳細は [connectors.md](connectors.md)。

## Python から使う

```python
from ailab import assets, imagegen

images = imagegen.generate("水彩風の富士山", provider="auto", size="1024x1024")
images[0].save("output/images/fuji.png")

found = assets.search("cat illustration", source="openverse", limit=5)
assets.download_all(found[:2], "output/illust")
```

コネクタを直接使うこともできる。

```python
from ailab.core import registry

github = registry.get("github")
print(github.publish("output/images/fuji.png", repo="owner/name", dry_run=True).describe())
```

## テスト

```bash
python -m pytest
```

テストは外部ネットワークに出ない（HTTPは全てモック）。
