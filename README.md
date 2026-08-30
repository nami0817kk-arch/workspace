# PJT008 - AIラボ

AI活用のアイデア検証・試作を行うラボプロジェクト。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## 構成

| フォルダ | 用途 |
|---|---|
| `src/` | 実装コード |
| `docs/` | 調査メモ・検証記録 |
| `tests/` | テストコード |

## audiogen - BGM / 効果音ジェネレータ

`src/audiogen/` は、BGM と効果音を手続き的に合成して WAV に書き出すツールキット。
**外部ライブラリなし**(Python 3.10+ の標準ライブラリのみ)で動くので、
`pip install` もモデルのダウンロードも API キーも不要。
`seed` を固定すれば毎回まったく同じ音が出るため、素材の再現性も保てる。

### すぐ試す

```bash
# 使えるプリセットの一覧
python -m audiogen list

# 効果音を1つ生成 -> output/coin.wav
python -m audiogen sfx coin

# BGM を1曲生成 -> output/bgm_battle.wav
python -m audiogen bgm --style battle --key A --bars 16 --seed 7

# 全プリセットをまとめて書き出す -> output/demo/
python -m audiogen demo
```

`src/` にパスを通していない場合は `PYTHONPATH=src python -m audiogen ...`、
または `pip install -e .` で `audiogen` コマンドが使えるようになる。

### 効果音 (SFX)

15種類のプリセットを用意。`--pitch` で音程を、`--seed` でノイズの当たり方を変えられる。

| プリセット | 用途 |
|---|---|
| `coin` / `pickup` / `powerup` | コイン・アイテム取得、パワーアップ |
| `jump` / `laser` / `hit` / `explosion` | ジャンプ、ショット、被弾、爆発 |
| `blip` / `select` / `error` | UI のカーソル移動、決定、キャンセル |
| `heal` / `teleport` / `whoosh` | 回復、ワープ、風切り |
| `footstep` / `alarm` | 足音、警報 |

```bash
python -m audiogen sfx laser --pitch 1.5 -o assets/se/shot.wav
```

### BGM

コード進行・ベース・メロディ・ドラムを組み立てて、**継ぎ目なくループする**曲を作る。
末尾の残響は先頭に折り返しているので、そのまま繰り返し再生してよい。

| スタイル | 曲想 |
|---|---|
| `calm` | 穏やか・タイトル画面向け (76 BPM, メジャー) |
| `adventure` | 明るい冒険もの (132 BPM, メジャー) |
| `battle` | 戦闘 (158 BPM, ハーモニックマイナー) |
| `menu` | メニュー・ショップ (96 BPM, ペンタトニック) |
| `night` | 夜・静かな場面 (68 BPM, マイナー、深いリバーブ) |
| `chiptune` | レトロゲーム風 (144 BPM, ビットクラッシュ) |
| `tension` | 不穏・緊迫 (104 BPM, フリジアン) |

スタイルの既定値は個別に上書きできる。

```bash
python -m audiogen bgm --style adventure \
    --key F --scale lydian --bpm 120 --bars 16 \
    --progression "I-V-vi-IV" --drums drive --stereo --seed 42
```

主なオプション:

| オプション | 説明 |
|---|---|
| `--key` / `--scale` | キーと音階(`major`, `minor`, `dorian`, `blues` ほか) |
| `--bpm` / `--bars` | テンポと小節数 |
| `--progression` | コード進行(ローマ数字。例 `"i-VI-III-VII"`) |
| `--drums` | ドラムパターン(`none`, `soft`, `basic`, `drive`, `march`, `shuffle`) |
| `--without` | 外すパート(`chords` `bass` `lead` `drums`) |
| `--seed` | 乱数シード。同じ値なら同じ曲になる |
| `--stereo` | ステレオで書き出す |
| `--no-loop` | 末尾の残響を切らずに残す |

### Python から使う

```python
from audiogen import bgm, sfx, write_wav

write_wav("output/coin.wav", sfx.generate("coin", seed=1))

config = bgm.BGMConfig(style="night", key="D", bars=16, seed=99)
write_wav("output/night.wav", bgm.generate(config))

# パート別に取り出してミックスを自分で調整することもできる
tracks = bgm.render_tracks(config)
write_wav("output/night_bass_only.wav", tracks["bass"])
```

音を1から組み立てる場合は、低レベルのモジュールを直接使う。

```python
from audiogen import core, effects, envelope, notes, oscillators

tone = oscillators.saw(notes.note_to_freq("A3"), 1.0)
tone = envelope.apply(tone, envelope.adsr(1.0, 0.01, 0.2, 0.6, 0.3))
tone = effects.lowpass(tone, oscillators.sweep(4000, 400, 1.0))
core.write_wav("output/pluck.wav", effects.reverb(tone, wet=0.3))
```

### モジュール構成

| モジュール | 役割 |
|---|---|
| `core` | バッファ操作、ミックス、正規化、WAV 書き出し |
| `oscillators` | サイン/ノコギリ/三角/矩形/ノイズ、周波数スイープ |
| `envelope` | ADSR、打楽器向けの指数減衰 |
| `effects` | フィルタ、ディレイ、リバーブ、歪み、ビットクラッシュ |
| `notes` | 音名・音階・和音・コード進行 |
| `drums` | ドラム音源と16分グリッドのパターン |
| `sfx` | 効果音プリセット |
| `bgm` | 曲の構成と生成 |
| `cli` | コマンドラインインターフェース |

### テスト

```bash
pytest
```
