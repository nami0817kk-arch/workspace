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

### ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/business-model.md](docs/business-model.md) | 収益モデル、価格設計、立ち上げ手順、KPI、法務上の注意 |
| [docs/architecture.md](docs/architecture.md) | パイプライン設計、冪等性、拡張ポイント |
| [docs/runbook.md](docs/runbook.md) | セットアップ、日次運用、障害対応、コスト管理 |

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
| `src/moneyloop/` | パイプライン実装 |
| `config/` | 設定ファイル（ニッチ・情報源・プラン） |
| `docs/` | 収益モデル・設計・運用手順 |
| `tests/` | テストコード |
