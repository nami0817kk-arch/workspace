# PJT007 - YouTube動画作成

台本(Markdown)を書くだけで、**ゆっくり実況風の動画・音声・BGM・字幕・サムネイル・概要欄**を
まとめて書き出すパイプライン。テロップの出現アニメ、シーン転換、喋りに合わせたBGMの自動ダッキング、
YouTube基準(-14 LUFS)の音圧調整まで入っている。
画面は「立ち絵あり（口パク付き）」と「立ち絵なしのニュース風」を切り替えられる。読み上げは [VOICEVOX](https://voicevox.hiroshiba.jp/)（無料・ローカル）。
VOICEVOX アプリ経由でも、CORE を組み込んでアプリ無しでも合成できる。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux は source .venv/bin/activate
pip install -r requirements.txt
python -m src.cli init-assets    # 仮の背景・立ち絵を生成
```

ffmpeg は `imageio-ffmpeg` に同梱されるので別途インストール不要。

音声合成は次のどちらかを用意する（詳細は [docs/voicevox.md](docs/voicevox.md)）。

- **VOICEVOX アプリを起動しておく** … 何も設定せずそのまま動く
- **CORE を組み込む** … `python scripts/setup_voicevox_core.py`（数GB）。アプリの起動が不要になる

どちらも無い場合は無音で書き出し、構成と尺だけ確認できる。

## 毎日の運用（朝・昼・夜の3本）

```bash
python -m src.cli plan --routine all                     # 今日の3枠ぶんの取材リスト
python -m src.cli plan --routine morning --write         # 枠ごとに取材メモの雛形
python -m src.cli draft research/YYYYMMDD_morning.yaml   # 検証して台本に
python -m src.cli new                          # テンプレートから直接書く場合
python -m src.cli check scripts/YYYYMMDD.md    # 書式と想定尺の確認
python -m src.cli build scripts/YYYYMMDD.md    # 動画一式を書き出す
```

「いつ・どこから・何を取るか」は `config/sources.yaml` に定義してある。
仕組みの説明は [docs/research.md](docs/research.md)、
公開前の確認まで含めた手順は [docs/weekly.md](docs/weekly.md)。

## 使い方

```bash
# 1. 台本の書式と想定尺を確認（VOICEVOX 不要）
python -m src.cli check scripts/sample.md

# 2. 使える話者(style_id)を確認
python -m src.cli speakers

# 3. ビルド（音声・口パク・テロップ・字幕・サムネまで一括）
python -m src.cli build scripts/sample.md

# 音声なしで構成だけ見たいとき
python -m src.cli build scripts/sample.md --no-tts
```

出力は `output/<台本名>/` に `video.mp4` / `subtitles.srt` / `thumbnail.png` /
`description.txt` / `script.json` が揃う。

## 台本の書き方

```markdown
---
title: 【ゆっくり解説】タイトル
tags: [ゆっくり解説, VOICEVOX]
---

## オープニング
霊夢: ゆっくり霊夢よ。今日は〇〇の話をするわ。
  telop: 今日のテーマは〇〇
魔理沙: ゆっくり魔理沙だぜ。
  emotion: smile
```

`## 見出し` がそのまま YouTube のチャプターになる。
指定できる属性は `telop` / `emotion` / `image` / `pause` / `speed` / `no_telop`。
詳細は [docs/pipeline.md](docs/pipeline.md)。

## 構成

| パス | 用途 |
|---|---|
| `src/cli.py` | コマンドラインの入口 |
| `src/script_model.py` | 台本 Markdown のパース |
| `src/tts.py` | VOICEVOX で行ごとに音声合成（ENGINE / CORE、キャッシュ付き） |
| `src/render.py` | フレーム描画・口パク・演出・動画合成 |
| `src/backgrounds.py` | サッカー背景（スタジアム/ピッチ/戦術ボード）の生成 |
| `src/cards.py` | 引用・移籍・箇条書きカードの描画 |
| `src/inserts.py` | タイトルカードのぶんの時間を映像と音声に差し込む |
| `src/plan.py` | 取材計画を読み、その日の検索リストに展開する |
| `src/research.py` | 取材メモの確度を検証し、台本に変換する |
| `src/audio.py` | BGM/効果音のミックス、ダッキング、音圧調整 |
| `src/audio_gen.py` | 仮のBGM・効果音の生成 |
| `src/subtitles.py` | 字幕 SRT・チャプター・概要欄 |
| `src/thumbnail.py` | サムネイル生成 |
| `src/upload.py` | YouTube Data API での投稿 |
| `config/project.yaml` | 画面サイズ・話者(style_id)・声・BGM・演出の設定 |
| `config/sources.yaml` | 取材計画（いつ・どこから・何を取るか） |
| `research/` | 取材メモ |
| `scripts/` | 台本と `setup_voicevox_core.py` |
| `scripts/templates/` | 台本のテンプレート |
| `docs/` | [取材の仕組み](docs/research.md) / [毎週の作り方](docs/weekly.md) / [パイプライン仕様](docs/pipeline.md) / [VOICEVOX設定](docs/voicevox.md) / [背景](docs/backgrounds.md) / [カードと画像](docs/cards.md) / [情報源](docs/news-sources.md) |

## テスト

```bash
python -m pytest tests -q
```

## ライセンスまわりの注意

- VOICEVOX の利用にはクレジット表記が必要。`description.txt` に自動で入るので、そのまま概要欄に貼ればよい。
- 立ち絵・背景に配布素材を使う場合は、二次配布可否とクレジット表記を確認すること。
- `init-assets` が作るのは自前の仮素材なので、そのまま使っても権利上の問題はない。
