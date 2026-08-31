# PJT008 - AIラボ

[![tests](https://github.com/nami0817kk-arch/ai-lab/actions/workflows/tests.yml/badge.svg)](https://github.com/nami0817kk-arch/ai-lab/actions/workflows/tests.yml)

AI活用のアイデア検証・試作を行うラボプロジェクト。
検証したものはそのままこのリポジトリに残していくので、複数のツールが同居している。

## 収録しているもの

| ツール | 何をするか |
|---|---|
| [`ailab`](#ailab--画像生成とフリー素材の取得) | 画像を生成し、フリー素材を横断検索して出典つきで取り込む |
| [`moneyloop`](#moneyloop--ai自動リサーチによる有料ニュースレター収益化パイプライン) | 公開情報を集めて有料ニュースレターを出し、原価と粗利を自動計算する |
| [`adsite`](#adsite--広告収益型の実用ツールサイト) | 実用ツールを置いた静的サイトを生成し、広告収益を同じ台帳に取り込む |
| [`growth`](#growth--成長ループ) | 全プロジェクトを定期点検し、次にやることを提示する |
| [`audiogen`](#audiogen--bgm--効果音ジェネレータ) | BGM と効果音を手続き的に合成して WAV に書き出す |

## セットアップ

```bash
python -m venv .venv
. .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
```

実行時の依存は既定でゼロ。必要なものだけ extras で足す。

| extras | 何に要るか |
|---|---|
| `[image]` | ailab の実行（`requests` / `Pillow` / `PyYAML`） |
| `[llm]` | moneyloop から実際に Claude を呼ぶとき（`anthropic`） |
| `[dev]` | テストと lint（`[image]` を含む） |

## ailab — 画像生成とフリー素材の取得

| コマンド | 内容 |
|---|---|
| `ailab gen "プロンプト"` | 画像を生成する（**APIキー無しでも Pollinations で本物のAI画像**。OpenAI / Gemini / Replicate / Hugging Face / Stability にも対応） |
| `ailab search "キーワード"` | フリー素材を横断検索する（Iconify / Openverse / Wikimedia / Pixabay / Unsplash / Pexels） |
| `ailab fetch "キーワード"` | フリーイラストを検索してダウンロードし、クレジットも書き出す |
| `ailab grab URL` | 自分で見つけた画像をURL指定で取り込む（出典つき） |
| `ailab feed "対象" --source ...` | 記事・リリース情報を取得する（RSS / GitHub / Qiita / Wikipedia） |
| `ailab publish FILE --repo owner/name` | 生成物を GitHub へコミットする（既定はドライラン） |
| `ailab usage` | 画像生成の利用量と概算コストを見る |
| `ailab run レシピ` | 「集める→作る→送る」をYAML1本で実行する |
| `ailab mcp` | MCPサーバとして起動し、Claude から直接使えるようにする |
| `ailab connectors` / `ailab doctor` | 連携先の設定状況を見る / 実際に接続して確認する |

このリポジトリで唯一、実行時に外部ライブラリが要る（`requests` / `Pillow` / `PyYAML`）。
`pip install -e ".[image]"` で入る（`[dev]` にも含まれる）。

### まず試す（APIキーなしで動きます）

```bash
ailab connectors                                     # 何が使える状態か
ailab gen "青空の下でノートPCを使う猫" --style flat   # 本物のAI画像（Pollinations）
ailab fetch "cat illustration" -l 3                  # フリー素材＋クレジット
```

キーが1つも無くても、`pollinations`（生成）と `iconify` / `openverse` /
`wikimedia`（素材）が動きます。生成物は `output/`（Git管理外）へ。

### APIキーを足す

```bash
cp .env.example .env     # Windows: copy .env.example .env
ailab doctor             # 実際に接続して確認（-- は未設定、NG は失敗）
```

有料APIを使い始めたら `ailab usage` で使用量と概算コストを確認できます。

### ライセンスの注意

`ailab fetch` は取得先の `CREDITS.md` / `credits.json` に出典とライセンスを残す。
CC BY 系はクレジット表示が必須なので、成果物に使うときは必ず確認すること。

詳しい使い方は [docs/image-tools.md](docs/image-tools.md)。
レシピの書き方は [docs/recipes.md](docs/recipes.md)、
Claude から直接使う方法は [docs/mcp.md](docs/mcp.md)、
連携の仕組みと増やし方は [docs/connectors.md](docs/connectors.md)、
今後の計画は [docs/integrations-plan.md](docs/integrations-plan.md)。

## moneyloop — AI自動リサーチによる有料ニュースレター収益化パイプライン

公開情報を毎日集め、Claudeが読者価値で選別し、有料/無料に出し分けて配信し、
**原価と粗利と損益分岐購読者数を自動で計算する**仕組みです。

制作原価は1号あたり約$0.18。有料購読者が2〜3人いれば全コストを回収できます。
つまりこの仕組みの価値は「記事が自動で出ること」ではなく、
**収益構造が常に数字で見えていること** にあります。

```
収集(RSS) → 選別(採点・しきい値) → 生成(号) → 分割(無料/有料) → 配信 → 計上(PL)
```

### まず動かす（APIキー不要・課金なし）

```bash
cp config/moneyloop.example.json config/moneyloop.json
python -m moneyloop.cli run --dry-run
```

Claude APIを呼ばずに全工程を通し、`output/issues/<niche>/` に
無料版と有料版のMarkdownを書き出します。

### 本番実行

```bash
export ANTHROPIC_API_KEY=sk-ant-...

python -m moneyloop.cli sub add reader@example.com --niche ai-ops --plan pro
python -m moneyloop.cli run
python -m moneyloop.cli report
```

`report` の出力例:

```
売上            : $30.00
API原価         : $0.1150
粗利            : $29.89  (約 4,483 円)
粗利率          : 99.6%
発行号数        : 1  / 1号あたり原価 $0.1150
購読者          : 有料 1 / 無料 1  (転換率 50.0%)
損益分岐購読者数: 1人
```

### 目標から逆算する

```bash
python -m moneyloop.cli plan --target-profit 3000 --conversion 5
# → 必要な有料購読者 101人 / 必要な無料読者規模 2,020人
```

### 主なコマンド

| コマンド | 用途 |
|---|---|
| `run [--dry-run] [--date] [--niche] [--no-send]` | パイプライン実行 |
| `sub add/cancel/list` | 購読者管理 |
| `revenue accrue` | 当月の購読収益を計上（冪等） |
| `report [--month] [--json]` | PLとユニットエコノミクス |
| `plan --target-profit N` | 目標利益に必要な購読者数を逆算 |

### 設計上の要点

- **冪等**: 同日に何度実行しても、号は1つ・配信は1回・計上は1回。cronの二重起動でも課金が増えません。
- **2段構え**: 安い採点でふるいにかけ、高い本文生成は上位数件だけ。原価が記事数に比例しません。
- **品質ゲート**: スコアがしきい値に届かない日は号を出しません。薄い号は解約の最大要因です。
- **依存ゼロで動く**: 本体は標準ライブラリのみ。`anthropic` は実際にClaudeを呼ぶときだけ必要です。

## adsite — 広告収益型の実用ツールサイト

無料の実務計算ツールを置いた静的サイトを生成し、AdSense枠を安全な位置に挿入して、
**広告収益の実測をmoneyloopと同じ台帳に取り込む**仕組みです。

AIで記事を量産して広告を貼る手法は、Googleの「スケールされたコンテンツの不正使用」
ポリシーに該当して成立しません。そのため**用の足りるツール**を売り物にしています。

### すぐ試せます

```bash
cp config/site.example.json config/site.json
python -m adsite.cli serve      # http://127.0.0.1:8000
```

同梱のツール（すべてブラウザ内で完結、入力値は送信しません）:

| ツール | 用途 |
|---|---|
| LLM API料金 計算 | リクエスト数と入出力トークンから月額を主要モデル横断で比較 |
| トークン数 見積もり | テキストを貼り付けて概算トークン数と1回あたりの費用を確認 |
| 業務自動化 ROI計算 | 削減時間と開発費から投資回収月数と年間効果額を試算 |

料金表は `moneyloop.pricing` を単一の情報源としてビルド時に生成されるため、
価格改定はコード側の1箇所を直すだけでサイトにも反映されます。

### 収益の取り込み

```bash
python -m adsite.cli ingest adsense-report.csv
python -m moneyloop.cli report        # 広告 + 購読を合算したPL
```

```
売上            : $40.35     ← 購読 $30.00 + 広告 $10.35
粗利率          : 99.7%
```

### 主なコマンド

| コマンド | 用途 |
|---|---|
| `build` / `serve` | 静的サイトの生成とローカル確認 |
| `check` | 公開前チェック（説明文の欠落、広告非掲載ページの検出） |
| `ingest <csv>` | AdSenseのCSVを台帳に取り込む（日次で冪等） |
| `forecast --target N --rpm R` | 目標収益に必要な月間PVを逆算 |

### 広告まわりで機械的に守っていること

- **1ページ3枠まで** — 増やすとCore Web Vitalsが落ち、検索順位経由でPVが減る
- **枠の高さを事前確保** — 広告読み込みで本文が飛ぶ(CLS)のを防ぐ
- **ツールUIの隣に置かない** — 誤クリック誘発はアカウント停止の理由になる
- **見出しと本文を分断しない** — 広告は各節の最初の段落の後に入る
- **本文量が足りないページには出さない** — AdSenseの掲載ポリシー対策

### 規模感（購読モデルとの違い）

月10万円を出すのに必要な数字です。

| モデル | 必要な数 |
|---|---|
| 購読 (Pro $30/月) | 有料34人 |
| 広告 (RPM $4) | 月間17万PV |

広告は**規模の商売**、購読は**単価の商売**です。詳細と、動画・アプリを選んだ場合の
比較は [docs/ad-monetization.md](docs/ad-monetization.md) を参照してください。

### この仕組みが解決しないこと

読者獲得は自動化されません。制作原価がほぼゼロになる結果、
ボトルネックは最初から最後まで配布です。詳細は
[docs/business-model.md](docs/business-model.md) を参照してください。

## growth — 成長ループ

各プロジェクトを定期的に点検し、**次にやることを向こうから提示してくる**仕組み。

やりたかったのは「毎回こちらから依頼を出す」のをやめること。
週に1回、全プロジェクトの状態を見て、伸びしろを見つけ、
どこかのPJTで既にうまくいっている習慣を、まだやっていないPJTへ持っていく。
提案には Claude にそのまま貼れる依頼文が付いてくるので、
やると決めたらコピペするだけで着手できる。

```
週1回（GitHub Actions）
  ↓
① 観測   全リポジトリを浅くクローンし、README/テスト/CI/依存/秘密情報などを調べる
  ↓
② 診断   「どのPJTでも満たしていたい水準」との差分を出す
  ↓
③ 横展開 あるPJTで既に実践している習慣を、まだのPJTへ伝える（お手本つき）
  ↓
④ 絞込   1PJTあたり最大3件・全体で最大12件まで。並べすぎると結局やらないので
  ↓
⑤ 出力   GROWTH.md（ダッシュボード）/ docs/growth/日付.md（詳細）/ 任意でIssue起票
  ↓
⑥ 記憶   台帳に記録。次回は「消えた指摘＝解決」として成果に数え、
         却下されたものは二度と出さない
```

⑥があるので、走らせるたびに賢くなる。同じことを毎週言ってくることはない。

### 使い方

```bash
# 対象リポジトリを作業ディレクトリへ取得する
python -m growth fetch --workspace ../growth-workspace

# 点検して提案を出す（--dry-run なら何も書き込まず標準出力に出すだけ）
python -m growth run --workspace ../growth-workspace

# 今の未対応一覧
python -m growth status

# 「今はやらない」と伝える（理由つきで残り、作業リストの枠は使わない）
python -m growth snooze <fingerprint> -n "上流の方針が決まってから"

# 「これはやらない」と伝える（以後この提案は出てこなくなる）
python -m growth dismiss <fingerprint> -n "この PJT では方針が違うため"

# 自分で対応済みにする
python -m growth done <fingerprint>
```

非公開リポジトリを読むには `GROWTH_TOKEN`（contents:read / issues:write を持つ
Fine-grained PAT）を環境変数か GitHub Secrets に設定する。

### 対象プロジェクトを増やす

`growth/projects.toml` に4行足すだけ。モノレポは `subprojects` にグロブを書けば、
配下の各PJTを自動的に個別の対象として扱う。

```toml
[[project]]
key = "new-project"
repo = "owner/new-project"
title = "説明"
weight = 1.0        # 壊れたときの痛みが大きいものは 1.0 より大きく
```

設計の背景と、なぜこの形にしたかは [docs/growth-system.md](docs/growth-system.md) に書いてある。

## audiogen — BGM / 効果音ジェネレータ

`src/audiogen/` は、BGM と効果音を手続き的に合成して WAV に書き出すツールキット。
**外部ライブラリなし**(標準ライブラリのみ)で動くので、
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

冒頭のセットアップを済ませてあれば `audiogen ...` でも同じことができる。

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

## テスト

```bash
pytest                      # 全部
pytest tests/ailab          # ツール単位で回す
```

テストはツールごとに `tests/<ツール名>/` に分けてある。
`conftest.py` の自動適用フィクスチャが他のツールのテストに漏れないようにするため。

## 構成

| パス | 用途 |
|---|---|
| `src/ailab/` | 画像生成・素材取得・連携（`core/` 連携基盤、`connectors/` 連携先） |
| `src/moneyloop/` | 有料ニュースレターのパイプライン実装 |
| `src/adsite/` | 広告収益型ツールサイトのジェネレータ |
| `src/growth/` | 成長ループ（観測・診断・横展開・台帳） |
| `src/audiogen/` | BGM / 効果音の合成ツールキット（標準ライブラリのみ） |
| `src/browser/` | Chrome の自動操作（ヘッドレス Chromium / ローカル Chrome を CDP 経由で） |
| `site/` | adsite のコンテンツとアセット |
| `config/` | 設定ファイル（ニッチ・情報源・プラン・サイト設定） |
| `growth/` | 成長ループの対象登録（`projects.toml`）と台帳（`ledger.json`） |
| `recipes/` | ailab のレシピ（`ailab run` で実行するYAML） |
| `scripts/` | 補助スクリプト（Chrome のデバッグ起動など） |
| `docs/` | 収益モデル・設計・運用手順・成長ループの設計 |
| `tests/` | テストコード（ツール別のサブディレクトリ） |
| `CLAUDE.md` | 開発時の決めごと（パッケージごとの前提） |
| `GROWTH.md` | 成長ループの現状ダッシュボード（自動生成） |

### ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/image-tools.md](docs/image-tools.md) | ailab の使い方 |
| [docs/connectors.md](docs/connectors.md) | 連携の仕組みとコネクタの増やし方 |
| [docs/recipes.md](docs/recipes.md) | レシピの書き方 |
| [docs/mcp.md](docs/mcp.md) | Claude から直接使う方法 |
| [docs/integrations-plan.md](docs/integrations-plan.md) | 連携まわりの今後の計画 |
| [docs/business-model.md](docs/business-model.md) | 収益モデル、価格設計、立ち上げ手順、KPI、法務上の注意 |
| [docs/architecture.md](docs/architecture.md) | パイプライン設計、冪等性、拡張ポイント |
| [docs/runbook.md](docs/runbook.md) | セットアップ、日次運用、障害対応、コスト管理 |
| [docs/ad-monetization.md](docs/ad-monetization.md) | 広告収益の規模感、動画/アプリとの比較、AdSense審査対策、KPI |
| [docs/growth-system.md](docs/growth-system.md) | 成長ループの設計の考え方 |
| [docs/audiogen.md](docs/audiogen.md) | audiogen の設計の詳細と検証結果 |
| [docs/chrome-automation.md](docs/chrome-automation.md) | Chrome 自動操作の使い方と検証記録 |

開発時の決めごとは [CLAUDE.md](CLAUDE.md)。
