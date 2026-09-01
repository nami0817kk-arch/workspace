# 読み上げ（音声合成）

`imagegen say` は、文章を読み上げた音声ファイルを作る。画像生成と同じコネクタ基盤の上に
乗っているので、`imagegen connectors` / `doctor` / レシピ / MCP からそのまま使える。

```bash
imagegen say "今日のニュースをお伝えします。"          # 使えるものが自動で選ばれる
imagegen say --file scripts/narration.md --provider voicevox --voice 3
imagegen voices --provider voicevox                    # 使える声の一覧
```

## どれが使われるか

`--provider auto`（既定）は、**使える中で優先順位のいちばん高いもの**を選ぶ。

| 優先 | コネクタ | キー | 何が要るか |
|---:|---|---|---|
| 10 | `openai_tts` | `OPENAI_API_KEY` | 画像生成と同じキーを共用する |
| 20 | `elevenlabs` | `ELEVENLABS_API_KEY` | 声は `ELEVENLABS_VOICE_ID`（未設定ならアカウントの先頭） |
| 40 | `voicevox` | 不要 | 手元で VOICEVOX ENGINE が起動していること |
| 90 | `beep` | 不要 | 何も要らない（プレースホルダ） |

`voicevox` は ENGINE が起動していなくても「設定済み」に見える（キーが要らないため）。
起動していなければ合成時に接続エラーになるので、`imagegen doctor voicevox` で先に確かめる。
ENGINE が動いていないことは失敗ではなく「未確認（`--`）」として表示する。

## beep は読み上げではない

`beep` は声を作らない。**先頭に短いビープを置いた、文字数から決まる長さの WAV** を返す。

- TTS を1回も呼ばずに、動画の並びや字幕のタイミングを確かめられる
- 同じ文章からは必ず同じ WAV が出る（再現性）
- 無音ではなくビープにしてあるのは、プレースホルダのまま公開してしまわないため
- 速さは `IMAGEGEN_BEEP_CPS`（1秒あたりの文字数、既定 7.0）で調整する

## 長文の扱い

サービスごとに入力の上限が違う（OpenAI 4096文字など）。上限より長い文章は
**句点・感嘆符・改行の切れ目**で分割して合成し、WAV なら1本につなぎ直す。

- 分割はコネクタではなく `src/imagegen/speech.py` の仕事。コネクタは1回分の合成だけを知っていればよい
- つなげない形式（MP3 など）は分かれたまま連番で保存する
- `--no-join` を付けると WAV でも分けたまま保存する
- 課金は**つなぐ前の文字数**で決まるので、記録も分割後の実回数で残す

## クレジット表記

VOICEVOX は、生成した音声を使うときに「VOICEVOX:キャラ名」の表示が要る。
表記の文言は ENGINE の `/speakers` から引くので、話者を変えてもずれない。

- `SynthesizedSpeech.credit` に載り、保存先の `CREDITS.md` に自動で追記される
- 素材（`imagegen fetch`）と同じ扱い。**出典は必ず手元に残す**

## 利用量

```bash
imagegen usage        # 画像の枚数と音声の文字数・概算コスト
```

音声の単価は**1000文字あたり**で、画像（1枚あたり）とは単位が違う。
そのため単価表を分けてある（上書きは `output/costs.json`（任意） の `speech` キー）。

```json
{ "speech": { "elevenlabs": { "": 0.22 } } }
```

金額は概算。正確な請求額は各社のダッシュボードで確認すること。

## レシピから使う

```yaml
name: ニュース読み上げ
steps:
  - id: news
    feed: { source: rss, query: "https://example.com/feed" }
  - say:
      text: "{{ news.0.title }}"
      provider: voicevox
      out: output/speech
      filename: "{{ today }}_headline"
```

`say` の結果には `path` と `seconds`（尺）が入る。動画に並べるときはこれを使う。

## Claude から使う（MCP）

`imagegen mcp` で起動すると `synthesize_speech` と `list_voices` が生える。
保存先パスと尺、必要なクレジットを返す。

## 声を増やす（コネクタを足す）

1. `src/imagegen/connectors/speech_<名前>.py` に `Connector` 継承クラス＋`@register`
2. `category = "speech"` と `synthesize()` / `list_voices()` を実装する
3. `src/imagegen/connectors/__init__.py` に import を1行
4. テストを書く（HTTPは `FakeSession`）

`max_chars`（1回に渡せる文字数）と `default_voice` を宣言しておけば、
分割と既定値の解決は入口（`speech.py`）がやる。CLI・MCP・レシピの選択肢は
登録簿から作られるので、触る必要はない。
