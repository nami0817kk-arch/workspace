# PJT007 - YouTube動画作成

台本(Markdown)を書くだけで、**ゆっくり実況風の動画・字幕・サムネイル・概要欄**を
まとめて書き出すパイプライン。音声は [VOICEVOX](https://voicevox.hiroshiba.jp/)（無料・ローカル）を使う。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux は source .venv/bin/activate
pip install -r requirements.txt
python -m src.cli init-assets    # 仮の背景・立ち絵を生成
```

ffmpeg は `imageio-ffmpeg` に同梱されるので別途インストール不要。

## 使い方

```bash
# 1. 台本の書式と想定尺を確認（VOICEVOX 不要）
python -m src.cli check scripts/sample.md

# 2. VOICEVOX を起動してからビルド
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
| `src/tts.py` | VOICEVOX で行ごとに音声合成（キャッシュ付き） |
| `src/render.py` | フレーム描画・口パク・動画合成 |
| `src/subtitles.py` | 字幕 SRT・チャプター・概要欄 |
| `src/thumbnail.py` | サムネイル生成 |
| `src/upload.py` | YouTube Data API での投稿 |
| `config/project.yaml` | 画面サイズ・話者(style_id)・声の設定 |
| `scripts/` | 台本 |
| `docs/` | [パイプライン仕様](docs/pipeline.md) / [VOICEVOX設定](docs/voicevox.md) |

## テスト

```bash
python -m pytest tests -q
```

## ライセンスまわりの注意

- VOICEVOX のキャラには個別の利用規約がある。概要欄にクレジットを入れること。
- 立ち絵・背景に配布素材を使う場合は、二次配布可否とクレジット表記を確認すること。
- `init-assets` が作るのは自前の仮素材なので、そのまま使っても権利上の問題はない。
