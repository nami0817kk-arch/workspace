# パイプライン仕様

台本 Markdown 1本から、動画・字幕・サムネイル・概要欄をまとめて書き出す。

```
台本(.md) ──parse──> Script ──VOICEVOX──> 行ごとの wav
                        │                      │
                        │                      ├─ 尺(duration) が確定
                        ↓                      ↓
                     フレーム描画 ──concat──> video.mp4 (+ subtitles.srt / thumbnail.png / description.txt)
```

## コマンド

| コマンド | 用途 |
|---|---|
| `python -m src.cli init-assets` | 仮の背景・立ち絵を生成（初回のみ） |
| `python scripts/setup_voicevox_core.py` | VOICEVOX CORE を組み込む（アプリ不要にする） |
| `python -m src.cli speakers` | VOICEVOX の話者とスタイルIDを一覧表示 |
| `python -m src.cli check <台本>` | 書式チェックと想定尺の確認（VOICEVOX 不要） |
| `python -m src.cli build <台本>` | 動画一式を書き出す |
| `python -m src.cli build <台本> --no-tts` | 音声を作らず無音で構成だけ確認する |
| `python -m src.cli build <台本> --backend core` | 合成方式を明示する（auto / engine / core / silent） |
| `python -m src.cli thumbnail <台本>` | サムネイルだけ作り直す |
| `python -m src.cli upload output/<名前>` | YouTube に投稿する |

出力は `output/<台本名>/` に入る。

- `video.mp4` … 本体（1920x1080 / H.264 / AAC）
- `subtitles.srt` … 字幕ファイル（YouTube にそのままアップロードできる）
- `thumbnail.png` … 1280x720 のサムネイル
- `description.txt` … 1行目タイトル、以降が概要欄（チャプター・VOICEVOXクレジット入り）
- `script.json` … 各行の開始時刻・尺（編集ソフトに持っていく用）
- `audio/` … 行ごとの wav。内容が変わらなければ再合成しないキャッシュ

## 台本フォーマット

```markdown
---
title: 【ゆっくり解説】タイトル
thumbnail_title: サムネ用の短いタイトル   # \n で改行できる
thumbnail_subtitle: 帯に入れる一言
description: |
  概要欄の本文。
tags: [ゆっくり解説, VOICEVOX]
---

## シーン名                      ← YouTube のチャプターになる
@bg: assets/backgrounds/night.png  ← このシーンの背景（省略可）

霊夢: 実際に読み上げるセリフ。
  telop: 画面に出す文字（省略するとセリフがそのまま出る）
  emotion: smile                 ← normal / smile / angry / surprise
  image: assets/images/graph.png ← 画面中央に差し込む画像
  pause: 0.8                     ← この行のあとの無音（秒）
  speed: 1.2                     ← この行だけ話速を変える
  no_telop: true                 ← テロップを出さない
```

- 話者名は `config/project.yaml` の `cast` に定義した名前か、その `aliases` / `key`。
- `//` で始まる行はコメント。
- 全角コロン（`：`）でも書ける。

## 描画のしかた

セリフ1行につき「口を閉じた絵」「口を開けた絵」の2枚だけを描き、
ffmpeg の concat demuxer で `MOUTH_INTERVAL`（既定 0.14 秒）ごとに交互に並べて口パクにしている。
同じ内容のフレームは内容ハッシュで使い回すので、長い動画でも PNG は増えない。

行末の `pause` ぶんは口を閉じたまま保持し、字幕もそこで消える。

## 素材の差し替え

`init-assets` が作るのは仮素材。本番用に差し替えるときは:

- **立ち絵** … `assets/characters/<key>/<表情>_<close|open>.png`（背景透過 PNG、縦 700px 以上推奨）
  `<key>` は `config/project.yaml` の `cast.<名前>.key`。
  指定した表情のファイルが無ければ `normal_*.png` にフォールバックする。
- **背景** … `config/project.yaml` の `video.background`、またはシーンごとに `@bg:`。

配布素材を使う場合はライセンス（クレジット表記・二次配布可否）を必ず確認すること。

## VOICEVOX

`docs/voicevox.md` を参照。合成方式は `voicevox.backend` で選ぶ:

- `auto`（既定） … ENGINE(HTTP) → CORE(ローカル) → 無音 の順に試す
- `engine` … VOICEVOX アプリ / ENGINE の HTTP API
- `core` … `scripts/setup_voicevox_core.py` で入れた VOICEVOX CORE を直接呼ぶ
- `silent` … 合成しない

どれも使えないときは無音で書き出し、尺だけ確認できる状態にする（その旨をメッセージで出す）。
使用した話者名は `description.txt` のクレジット欄に自動で入る。

## YouTube への投稿

1. `pip install -r requirements-upload.txt`
2. Google Cloud で YouTube Data API v3 を有効化し、OAuth クライアント（デスクトップアプリ）を作成
3. `secrets/client_secret.json` に配置（`secrets/` は .gitignore 済み）
4. `python -m src.cli upload output/<名前>` を実行。初回はブラウザで認可する

既定の公開設定は `private`（非公開）。`--privacy unlisted|public` で変更する。
