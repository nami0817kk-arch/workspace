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

# 足音を4通り作る -> output/footstep_1.wav ... _4.wav
python -m audiogen sfx footstep --count 4

# BGM を1曲生成 -> output/bgm_battle.wav
python -m audiogen bgm --style battle --key A --bars 16 --seed 7

# 音を作らずに曲の中身だけ見る
python -m audiogen describe --style battle --structure verse_chorus

# 全プリセットを書き出し、試聴ページも作る -> output/demo/index.html
python -m audiogen demo
```

`src/` にパスを通していない場合は `PYTHONPATH=src python -m audiogen ...`、
または `pip install -e .` で `audiogen` コマンドが使えるようになる。

### 効果音 (SFX)

27種類のプリセットを用意。すべて `--pitch` で音程を、`--seed` でノイズの当たり方を変えられる。

| 分類 | プリセット |
|---|---|
| 収集・獲得 | `coin` `pickup` `powerup` `level_up` `heal` |
| 動作・攻撃 | `jump` `land` `footstep` `dash` `swing` `whoosh` `laser` `charge` |
| 衝撃・破壊 | `hit` `explosion` `shatter` `thunder` `engine` |
| UI・演出 | `blip` `select` `error` `menu_open` `menu_close` `teleport` `shield` `water_drop` `alarm` |

足音や打撃のように何度も鳴る音は、毎回同じだと耳につく。`--count` で
音程とノイズを散らした一組を作れる(1つ目は指定どおりの音のまま)。

```bash
python -m audiogen sfx laser --pitch 1.5 -o assets/se/shot.wav
python -m audiogen sfx footstep --count 6 --spread 0.15 -d assets/se
```

### BGM

コード進行・ベース・メロディ・ドラムを組み立てて、**継ぎ目なくループする**曲を作る。
末尾の残響は先頭に折り返し、EQ も一周ぶん前置きしてから通しているので、
そのまま繰り返し再生してよい。継ぎ目の段差は曲中の波形の動きより小さい。

| スタイル | 曲想 |
|---|---|
| `calm` | 穏やか・タイトル画面向け (76 BPM, メジャー) |
| `adventure` | 明るい冒険もの (132 BPM, メジャー) |
| `battle` | 戦闘 (158 BPM, ハーモニックマイナー) |
| `menu` | メニュー・ショップ (96 BPM, ペンタトニック) |
| `night` | 夜・静かな場面 (68 BPM, マイナー、深いリバーブ) |
| `chiptune` | レトロゲーム風 (144 BPM, ビットクラッシュ) |
| `tension` | 不穏・緊迫 (104 BPM, フリジアン) |
| `news_open` | 報道番組のテーマ (138 BPM, ドリアン、刻んだ金管) |
| `news_bed` | 原稿読みの下敷き (98 BPM, メロディなし) |
| `sports_anthem` | 入場・表彰のアンセム (104 BPM, 行進 + ティンパニ) |
| `sports_drive` | ハイライト・煽り (152 BPM, ミクソリディアン) |
| `terrace_chant` | 客席の合唱 (128 BPM, I-bVII-IV + 手拍子) |
| `stadium_anthem` | 入場曲 (92 BPM, 主音ペダル + 分散和音) |

メロディは1小節ぶんのモチーフを作り、小節ごとの和音に合わせて置き直しながら
`A / A / B / A'` と展開する。同じ形が返ってくるので旋律として頭に残る。
`terrace_chant` だけは作りが違い、客席が歌える条件(狭い音域・同音連打・
拍の頭・休まない)に合わせた句を、展開せずそのまま押し通す。

パートは和音・アルペジオ・ベース・メロディ・ドラムの5つ。どれを鳴らすかは
スタイルごとに決まっていて(`news_bed` はメロディなし、など)、`--without` で更に外せる。

編曲まわりは自動で次のことをする。

- **声部連結** — 和音が変わるとき、全部を基本形へ飛ばさず近い音へつなぐ
- **フィル** — 区間の最後の小節でドラムの手が変わり、次の区間へ渡る感じが出る
- **経過音** — ベースが次の和音の根音の隣へ寄ってから着地する(スタイルによる)
- **終止** — `--ending` を付けると、最後の小節が主和音とシンバルで終わる
- **リタルダンド** — `--ritardando 4` で、終わりにかけてテンポを緩める
- **転調** — `lift` / `broadcast` / `anthem` 構成では、サビで全パートが全音上がる
- **借用和音** — 進行に `bVII` のように書くと、音階の外から和音を借りる
  (`I-bVII-IV` はメジャーのまま明るく外へ広がる、中継の定番)
- **ペダル** — 和音が動いてもベースを主音に据え置く(入場曲の助走)
- **帯域バランス** — 仕上げに低域の削り・低中域の抜き・輪郭の持ち上げをかける

放送向けの使い方の例:

```bash
# ニュースのオープニング(静かに入って本編へ)
python -m audiogen bgm --style news_open --bars 12 --structure intro --seed 3

# 原稿読みの下敷き。8小節でループする
python -m audiogen bgm --style news_bed --key D --bars 8 --seed 5

# 試合前後のアンセム(終わりでテンポを緩めて主和音で締める)
python -m audiogen bgm --style sports_anthem --bars 12 --structure full --seed 3 \
    --ending --ritardando 3

# ハイライト。後半のサビで全音上へ転調する
python -m audiogen bgm --style sports_drive --key G --bars 12 --structure lift --seed 3 --ending

# 客席の合唱。狭い音域・同音連打・展開しないチャント型の旋律
python -m audiogen bgm --style terrace_chant --bars 16 --structure anthem --seed 3 --ending

# 入場曲。主音のペダルの上で分散和音が回り、打楽器だけの切れ目を挟んで転調
python -m audiogen bgm --style stadium_anthem --bars 16 --structure anthem --seed 5 --ending
```

`--structure` で曲の起伏を付けられる。

| 構成 | 並び |
|---|---|
| `loop` | 単一区間(既定) |
| `intro` | 静かな入り(ドラムとメロディなし)→ 本編 |
| `verse_chorus` | A メロ → サビ(メロディが1オクターブ上がる) |
| `full` | イントロ → A メロ → サビ → アウトロ |
| `lift` | A メロ → サビ(全体が全音上へ転調) |
| `broadcast` | イントロ → A メロ → サビ(転調)→ 締め |

```bash
python -m audiogen bgm --style adventure \
    --key F --scale lydian --bpm 120 --bars 16 --structure full \
    --progression "I-V-vi-IV" --drums drive --swing 0.3 --stereo --seed 42
```

主なオプション:

| オプション | 説明 |
|---|---|
| `--key` / `--scale` | キーと音階(`major`, `minor`, `dorian`, `blues` ほか) |
| `--bpm` / `--bars` | テンポと小節数 |
| `--structure` | 曲構成(`loop` `intro` `verse_chorus` `full` `lift` `broadcast`) |
| `--progression` | コード進行(ローマ数字。例 `"i-VI-III-VII"`) |
| `--drums` | ドラムパターン(`none` `soft` `basic` `drive` `march` `shuffle` `news` `anthem` `sports` `stomp`) |
| `--swing` / `--humanize` | 裏拍のずらし量と、タイミング・音量のゆらぎ |
| `--chord-instrument` ほか | パートごとの音色(下記) |
| `--without` | 外すパート(`chords` `arp` `bass` `lead` `drums`) |
| `--seed` | 乱数シード。同じ値なら同じ曲になる |
| `--ending` | 最後の小節を主和音で締める(1曲として終わらせる) |
| `--midi` | 同じ譜面を MIDI でも書き出す(DAW の音源で鳴らせる) |
| `--ritardando` | 最後の何小節でテンポを緩めるか(`--final-tempo` で緩め方) |
| `--stereo` / `--no-loop` | ステレオ出力 / 末尾の残響を切らずに残す |

音色は波形を重ねてフィルタとエンベロープを通した「楽器」として定義してある。
`pad` `strings` `choir` `brass` `low_brass` `pluck` `organ` `bell` `marimba`
`chip_lead` `pulse_lead` `sub_bass` `pick_bass` と、
素の波形(`sine` `triangle` `saw` `square` `pulse25` `pulse12`)。
どれも同じ音量感になるよう補正済みなので、差し替えても全体のバランスは崩れない。

### 素材一式をまとめて作る

ゲーム1本ぶんの素材を JSON に宣言しておくと、そこから一括生成できる。

```json
{
  "sample_rate": 44100,
  "output": "assets/audio",
  "sfx": [
    {"name": "coin",     "as": "se/coin", "seed": 1},
    {"name": "footstep", "as": "se/step", "count": 4, "seed": 2}
  ],
  "bgm": [
    {"as": "bgm/title",  "style": "calm",   "bars": 16, "seed": 7, "structure": "intro", "stereo": true},
    {"as": "bgm/battle", "style": "battle", "bars": 32, "seed": 3, "structure": "verse_chorus"}
  ]
}
```

```bash
python -m audiogen build assets.json          # 変更のあったものだけ作り直す
python -m audiogen build assets.json --dry-run  # 予定だけ表示
python -m audiogen build assets.json --force    # すべて作り直す
```

前回どの設定で作ったかを出力先の索引ファイルに記録しているので、2回目以降は差分だけを生成する。

### 試聴

生成した WAV を並べて聴き比べるページを作れる。波形の概形と再生ボタンが並ぶ。

```bash
python -m audiogen preview -d output/demo   # -> output/demo/index.html
```

### Python から使う

```python
from audiogen import bgm, sfx, write_wav

write_wav("output/coin.wav", sfx.generate("coin", seed=1))

config = bgm.BGMConfig(style="night", key="D", bars=16, seed=99)
write_wav("output/night.wav", bgm.generate(config))

# 音を作らずに譜面だけ組み立てる
arrangement = bgm.compose(config)
print(arrangement.notes["lead"][:4])       # Note(start=..., midi=..., length=...)
print(bgm.describe(config)["chords"][:2])  # コード進行を音名で

# パート別に取り出してミックスを自分で調整することもできる
tracks = bgm.render_tracks(config)
write_wav("output/night_bass_only.wav", tracks["bass"])

# 同じ譜面を MIDI で書き出して DAW の音源で鳴らす
from audiogen import midi
midi.write("output/night.mid", arrangement)
```

音を1から組み立てる場合は、低レベルのモジュールを直接使う。

```python
from audiogen import core, effects, instruments, notes, oscillators

tone = instruments.get("pluck").render(notes.note_to_freq("A3"), 1.0)
core.write_wav("output/pluck.wav", effects.reverb(tone, wet=0.3))

# 波形やフィルタを直接触ることもできる
sweep = oscillators.saw(oscillators.sweep(880, 110, 1.0), 1.0)
core.write_wav("output/sweep.wav", effects.lowpass(sweep, 1200))
```

### モジュール構成

| モジュール | 役割 |
|---|---|
| `core` | バッファ操作、ミックス、正規化、WAV 書き出し |
| `oscillators` | 波形生成(段差は PolyBLEP で帯域制限)、周波数スイープ |
| `envelope` | ADSR、打楽器向けの指数減衰 |
| `effects` | フィルタ、ディレイ、リバーブ、歪み、リミッター、サイドチェイン |
| `notes` | 音名・音階・和音・コード進行 |
| `instruments` | 波形を重ねた音色の定義 |
| `drums` | ドラム音源と16分グリッドのパターン |
| `sfx` | 効果音プリセットとバリエーション生成 |
| `styles` | 曲想・曲構成の定義(宣言的な設定だけ) |
| `bgm` | 作曲(`compose`)と合成(`render_tracks` / `generate`) |
| `midi` | 譜面の MIDI 書き出し |
| `manifest` | JSON からの一括生成と差分ビルド |
| `preview` | 試聴ページの生成 |
| `cli` | コマンドラインインターフェース |

### 設定の検証

`bgm.compose()` は最初に設定を検査する。範囲外の値はその場で
`ValueError` になり、どの項目にいくつを渡したかがメッセージに出る。

```python
bgm.generate(bgm.BGMConfig(bpm=0))
# ValueError: bpm must be between 20 and 400 (指定: 0)
bgm.generate(bgm.BGMConfig(key="H"))
# ValueError: invalid key: 'H' (例: C, F#, Bb, A3)
sfx.generate("coin", pitch=0)
# ValueError: pitch must be > 0 (指定: 0.0)
```

設計の詳細と検証結果は [`docs/audiogen.md`](docs/audiogen.md) を参照。

### テスト

```bash
pytest
```
