# PJT008 - AIラボ

AI活用のアイデア検証・試作を行うラボプロジェクト。

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
python -m venv .venv && . .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp config/moneyloop.example.json config/moneyloop.json
PYTHONPATH=src python -m moneyloop.cli run --dry-run
```

Claude APIを呼ばずに全工程を通し、`output/issues/<niche>/` に
無料版と有料版のMarkdownを書き出します。

### 本番実行

```bash
export ANTHROPIC_API_KEY=sk-ant-...

PYTHONPATH=src python -m moneyloop.cli sub add reader@example.com --niche ai-ops --plan pro
PYTHONPATH=src python -m moneyloop.cli run
PYTHONPATH=src python -m moneyloop.cli report
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
PYTHONPATH=src python -m moneyloop.cli plan --target-profit 3000 --conversion 5
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
PYTHONPATH=src python -m adsite.cli serve      # http://127.0.0.1:8000
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
PYTHONPATH=src python -m adsite.cli ingest adsense-report.csv
PYTHONPATH=src python -m moneyloop.cli report        # 広告 + 購読を合算したPL
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

### ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/business-model.md](docs/business-model.md) | 収益モデル、価格設計、立ち上げ手順、KPI、法務上の注意 |
| [docs/architecture.md](docs/architecture.md) | パイプライン設計、冪等性、拡張ポイント |
| [docs/runbook.md](docs/runbook.md) | セットアップ、日次運用、障害対応、コスト管理 |
| [docs/ad-monetization.md](docs/ad-monetization.md) | 広告収益の規模感、動画/アプリとの比較、AdSense審査対策、KPI |

### この仕組みが解決しないこと

読者獲得は自動化されません。制作原価がほぼゼロになる結果、
ボトルネックは最初から最後まで配布です。詳細は
[docs/business-model.md](docs/business-model.md) を参照してください。

### テスト

```bash
pip install pytest && python -m pytest -q
```

## 構成

| フォルダ | 用途 |
|---|---|
| `src/moneyloop/` | 有料ニュースレターのパイプライン実装 |
| `src/adsite/` | 広告収益型ツールサイトのジェネレータ |
| `site/` | サイトのコンテンツとアセット |
| `config/` | 設定ファイル（ニッチ・情報源・プラン・サイト設定） |
| `docs/` | 収益モデル・設計・運用手順 |
| `tests/` | テストコード |
