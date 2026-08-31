# PJT008 - AIラボ

AI活用のアイデア検証・試作を行うラボプロジェクト。
検証したものはそのままこのリポジトリに残していくので、複数のツールが同居している。

## 収録しているもの

| ツール | 何をするか |
|---|---|
| [`moneyloop`](#moneyloop--ai自動リサーチによる有料ニュースレター収益化パイプライン) | 公開情報を集めて有料ニュースレターを出し、原価と粗利を自動計算する |
| [`adsite`](#adsite--広告収益型の実用ツールサイト) | 実用ツールを置いた静的サイトを生成し、広告収益を同じ台帳に取り込む |
| [`growth`](#growth--成長ループ) | 全プロジェクトを定期点検し、次にやることを提示する |

## セットアップ

```bash
python -m venv .venv
. .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
```

実行時の依存は最小限に抑えてある。`anthropic` は実際にClaudeを呼ぶときだけ必要。

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

## テスト

```bash
pytest                      # 全部
pytest tests/growth         # ツール単位で回す
```

テストはツールごとに `tests/<ツール名>/` に分けてある。
`conftest.py` の自動適用フィクスチャが他のツールのテストに漏れないようにするため。

## 構成

| パス | 用途 |
|---|---|
| `src/moneyloop/` | 有料ニュースレターのパイプライン実装 |
| `src/adsite/` | 広告収益型ツールサイトのジェネレータ |
| `src/growth/` | 成長ループ（観測・診断・横展開・台帳） |
| `site/` | adsite のコンテンツとアセット |
| `config/` | 設定ファイル（ニッチ・情報源・プラン・サイト設定） |
| `growth/` | 成長ループの対象登録（`projects.toml`）と台帳（`ledger.json`） |
| `docs/` | 収益モデル・設計・運用手順・成長ループの設計 |
| `tests/` | テストコード（ツール別のサブディレクトリ） |
| `GROWTH.md` | 成長ループの現状ダッシュボード（自動生成） |

### ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/business-model.md](docs/business-model.md) | 収益モデル、価格設計、立ち上げ手順、KPI、法務上の注意 |
| [docs/architecture.md](docs/architecture.md) | パイプライン設計、冪等性、拡張ポイント |
| [docs/runbook.md](docs/runbook.md) | セットアップ、日次運用、障害対応、コスト管理 |
| [docs/ad-monetization.md](docs/ad-monetization.md) | 広告収益の規模感、動画/アプリとの比較、AdSense審査対策、KPI |
| [docs/growth-system.md](docs/growth-system.md) | 成長ループの設計の考え方 |
