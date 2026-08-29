# 音声合成（VOICEVOX）

読み上げは [VOICEVOX](https://voicevox.hiroshiba.jp/) を使う。無料・ローカル動作で、
商用利用も可能（クレジット表記が必要）。

使い方は2通りあり、`config/project.yaml` の `voicevox.backend` で選ぶ。

| backend | 何を使うか | 向いている場面 |
|---|---|---|
| `auto`（既定） | ENGINE があれば ENGINE、無ければ CORE、どちらも無ければ無音 | 基本これでよい |
| `engine` | VOICEVOX アプリ / ENGINE の HTTP API | 手元に VOICEVOX を入れている |
| `core` | VOICEVOX CORE を Python から直接呼ぶ | アプリを起動できない環境・自動化 |
| `silent` | 合成しない（無音） | 構成と尺だけ確認したい |

## A. VOICEVOX アプリを使う（backend: engine）

1. VOICEVOX 本体をインストールして起動する。起動中は `http://127.0.0.1:50021` で API が待ち受ける。
2. 確認: `curl http://127.0.0.1:50021/version`
3. そのまま `python -m src.cli build <台本>` を実行する。

Docker で ENGINE だけ動かすこともできる:

```bash
docker run --rm -p 50021:50021 voicevox/voicevox_engine:cpu-latest
```

## B. VOICEVOX CORE を組み込む（backend: core）

アプリの起動が要らないので、サーバや CI でもそのまま合成できる。

```bash
python scripts/setup_voicevox_core.py
```

スクリプトは以下を `vendor/voicevox/` に用意する（数GB、`.gitignore` 済み）。

- 公式ダウンローダ（VOICEVOX/voicevox_core のリリース）
- ONNX Runtime・Open JTalk 辞書・音声モデル(.vvm)
- Python バインディング（wheel）
- `vvm_index.json` … style_id からどの .vvm を読めばいいかの索引

音声モデルは使う `style_id` のぶんだけ遅延ロードするので、52人ぶん置いてあっても
起動が重くなることはない。

ソング用モデルも欲しい場合は `--models-pattern '*.vvm'` を付ける。

## 話者(style_id)を決める

```bash
python -m src.cli speakers
```

`四国めたん: ノーマル=2, あまあま=0, ...` のように出るので、使いたい ID を
`config/project.yaml` の `cast.<名前>.style_id` に書く。

既定の配役:

| 台本での名前 | VOICEVOX | style_id |
|---|---|---|
| 霊夢 | 四国めたん / ノーマル | 2 |
| 魔理沙 | ずんだもん / ノーマル | 3 |
| ナレーター | 青山龍星 / ノーマル | 13 |

## 声の調整

| 項目 | 意味 | 目安 |
|---|---|---|
| `speed` | 話速 | 1.0 が標準。実況テンポなら 1.05〜1.2 |
| `pitch` | 音高 | -0.15〜0.15 くらい。キャラを差別化するのに使う |
| `intonation` | 抑揚 | 1.0 が標準。上げるとテンションが上がる |

台本の行単位で `speed:` を書けば、その行だけ話速を変えられる。

## キャッシュ

合成結果は `output/<台本名>/audio/` に「バックエンド＋本文＋話者＋パラメータ」のハッシュ付きで保存される。
台本の一部だけ直した場合、変わっていない行は再合成されない。
声の設定を変えたときも自動で別ファイルになるので、消さなくてよい。

## クレジット表記

VOICEVOX 音声モデルの利用規約により、**VOICEVOX を使ったことがわかるクレジット表記が必要**。
`build` は使用した話者名を自動で拾い、`description.txt` に次の行を入れる。

```
■ クレジット
音声: VOICEVOX（四国めたん・ずんだもん）
```

そのまま概要欄に貼れば要件を満たせる。キャラごとに追加の条件がある場合は
`vendor/voicevox/**/TERMS.txt` を確認すること。

## 読み間違いへの対処

漢字の読み間違いは、台本のセリフ側をひらがなに開くのが一番早い。
画面の表示は `telop` に漢字表記を書けば漢字のまま出せる。

```markdown
霊夢: このどうがはついかそうにゅうじゅつについてかいせつするわ。
  telop: 今回は「追加挿入術」について解説します
```
