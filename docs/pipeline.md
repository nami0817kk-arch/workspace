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

## 画面のレイアウト

`config/project.yaml` の `video.show_characters` で2種類を切り替える。

| | `true`（立ち絵あり） | `false`（ニュース風） |
|---|---|---|
| 立ち絵 | 左右に表示。口パク・表情・跳ねる演出つき | 出さない |
| 文字 | 下部のテロップ枠に話者名つきで表示 | 大きな見出しを下寄せで表示 |
| 見出しの出し方 | 行ごとに毎回出す | `telop` を書いた行でだけ差し替え、以降の行はそのまま残す |
| アクセント色 | 話者の色 | 確度バッジの色（無ければ `video.accent`） |

ニュース風では**生のセリフが画面に出ない**。見出しにしたい内容だけ `telop` に書く。
相づちや繋ぎのセリフには `telop` を書かなければ、直前の見出しが残ったままになる。
見出しを消したいときは `no_telop: true`。

```markdown
霊夢: アトレティコはバルセロナとは交渉しないと明言しているわ。
  telop: アトレティコはバルサとの交渉を拒否   ← ここで見出しが変わる
  source: 報道
魔理沙: 交渉すらしないのか。                  ← 見出しはそのまま残る
```

立ち絵を出さない場合、口パクも表情も絵に影響しないのでフレーム数が減り、書き出しも速くなる。

## 演出（画面の動き）

`config/project.yaml` の `motion` で制御する。`enabled: false` にすると静止画の切り替えだけになり、
書き出しは速くなる。

| 項目 | 内容 |
|---|---|
| `telop_in` | テロップがせり上がりながらフェードインする秒数 |
| `speaker_pop` | 話し始めに、喋る側の立ち絵がひょいと跳ねる秒数 |
| `scene_fade` | シーン転換にかける秒数 |
| `scene_transition` | `dip`（一度黒に落とす）/ `crossfade`（前後を直接混ぜる） |
| `fps` | アニメーション部分の描画レート |

**演出に使う時間は、そのセリフの発話時間の内側から取る**ので、映像と音声の尺はずれない。
発話が極端に短い行では、演出のほうが自動的に縮む。

`crossfade` は前後の画面を直接混ぜるため、転換中にテロップが一瞬二重に見える。
既定を `dip` にしているのはそのため。

## BGM・効果音

`config/project.yaml` の `audio` で制御する。音源は `assets/audio/` に置く
（`init-assets` が仮のBGMと効果音を合成して置く）。

| 項目 | 内容 |
|---|---|
| `bgm` | BGMのパス。空文字ならBGMなし |
| `bgm_gain` | BGMの音量(dB)。既定 -22 |
| `bgm_fade` | 開始/終了のフェード秒 |
| `duck` | 喋っている間だけBGMを自動で下げる（サイドチェイン） |
| `se_gain` | 効果音の音量(dB) |
| `scene_se` | シーン頭で鳴らす効果音 |
| `loudness_target` | 仕上がりの音圧(LUFS)。既定 -14 は YouTube の基準。0 で無効 |

BGMは指定した長さになるまで自動でループする。台本の frontmatter に `bgm:` を書けば
その動画だけ差し替えられる。効果音は行の `se:` で鳴らす。

```markdown
魔理沙: というわけだぜ。
  se: assets/audio/se_pon.wav
```

音圧は `loudnorm` で -14 LUFS / トゥルーピーク -1.5dBFS に揃える。
ナレーションが完全な無音のとき（`--no-tts` かつ BGM なし）は正規化を飛ばす。

## 描画のしかた

セリフ1行につき「口を閉じた絵」「口を開けた絵」の2枚を描き、ffmpeg の concat demuxer で
`MOUTH_INTERVAL`（既定 0.14 秒）ごとに交互に並べて口パクにしている。
演出が入る一瞬だけフレームを細かく作り、動きが止まっている間は同じ絵を使い回す。
フレームは内容ハッシュでキャッシュするので、長い動画でも PNG が無駄に増えない。

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

## ニュース系動画をつくるとき

frontmatter に `sources:` を書くと、概要欄に「■ 出典」として URL が並ぶ。

```markdown
---
title: 【サッカーニュース】...
sources:
  - https://example.com/article1
  - https://example.com/article2
---
```

事実の扱いで気をつけること:

- **クラブや当事者が発表した「確定」と、メディアが伝えている「報道段階」を必ず分ける。**
  台本では `telop` に `【確定】` / `【報道段階】` を入れて画面でも区別できるようにする。
- 数字（移籍金・順位・記録）は伝聞のまま「〜と報じられている」で止める。断定しない。
- 複数の媒体が同じことを書いているかを確認してから台本に入れる。
  1媒体だけの情報は、そう明示するか、落とす。
- 公開前に必ず出典を読み直す。時間が経つと状況が変わる（移籍は特に）。

### 情報の確度バッジ

行に `source:` を書くと、話者名の右に確度バッジが出て、字幕にも `[確定]` などが付く。

| 指定 | 表示 | 色 | 使いどころ |
|---|---|---|---|
| `確定` / `official` | 確定 | 緑 | クラブ・当事者・公式アカウントが発表した |
| `報道` / `report` | 報道 | 橙 | 報道機関が報じた（複数社で一致していることが望ましい） |
| `未確認` / `噂` / `rumor` | 未確認 | 灰 | SNS・単一ソース・噂の段階 |

```markdown
霊夢: ○○選手が△△へ完全移籍したわ。
  telop: ○○ □□ → △△
  source: 確定
```

SNS（X など）を情報源に含める場合、バッジなしで流すと視聴者が確定情報と区別できない。
最低でも「確定」と「未確認」は必ず打ち分けること。
