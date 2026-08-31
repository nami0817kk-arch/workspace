# 運用手順

## セットアップ

```bash
python -m venv .venv && . .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
pip install -e .        # `moneyloop` コマンドを使えるようにする

cp config/moneyloop.example.json config/moneyloop.json
cp .env.example .env        # ANTHROPIC_API_KEY を設定
```

`config/moneyloop.json` の `niches` を自分の領域に書き換えます。最低限:
`code` / `name` / `audience` / `angle` / `sources`。`audience` と `angle` が
選別と文体を決めるので、抽象的に書かないこと。

## まず課金なしで確認する

```bash
moneyloop run --dry-run
```

Claude APIを呼ばずに全工程を通します。`output/issues/<niche>/` に
`-free.md` と `-paid.md` が出れば配線は正常です（内容はスタブ）。

## 本番実行

```bash
moneyloop sub add reader@example.com --niche ai-ops --plan pro
moneyloop run
moneyloop report
```

## 日次運用

| コマンド | いつ |
|---|---|
| `run` | 毎日（GitHub Actionsで自動化済み） |
| `revenue accrue` | 月初。`run` からも自動で呼ばれるため通常は不要 |
| `report` | 月次レビュー |
| `sub list` | 購読者の状態確認 |

## 定期実行

`.github/workflows/daily-issue.yml` が平日朝に `run` を実行します。
有効化に必要なもの:

1. リポジトリの Settings → Secrets に `ANTHROPIC_API_KEY` を登録
2. 配信を行うなら `MONEYLOOP_WEBHOOK_URL` も登録
3. `config/moneyloop.json` をコミット（`.example` のままでは自分のニッチで動かない）

**注意**: ワークフローはSQLiteをキャッシュに保存します。キャッシュは消えることが
あるので、本番運用では `db_path` を永続ストレージ（マウントしたボリューム、
オブジェクトストレージへの同期など）に向けてください。DBが消えると
「既読記事の記憶」と「配信済み記録」が失われ、再配信が起きます。

## 想定される障害と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| `取得失敗` が続く | フィードのURL変更/停止、ネットワーク制限 | 設定の `sources` を更新。1本落ちても他は動く |
| `新規記事が0件` | 全記事が既読、または `lookback_hours` が短い | 情報源を追加するか lookback を延ばす |
| `スコアN以上の記事がなかった` | 情報源が読者層とずれている | `min_score` を下げるのではなく `sources` と `angle` を見直す |
| `生成に失敗` | 構造化出力のパース失敗、APIエラー | 号は保存されないので再実行で復旧する |
| `モデルがリクエストを拒否` | 安全分類による拒否 | フォールバックが有効なら自動で別モデルに回る |
| 原価が跳ねた | `items_per_issue` / `score_batch_size` が大きすぎる | `report` の cost_per_issue_usd を見て調整 |

## コスト管理

- 上限を握るのは `curation.items_per_issue`（生成量）と `score_batch_size`（採点回数）。
- `llm.effort` を `high` から `medium` に下げると本文の原価が下がる。品質との
  トレードオフなので、下げたら数号を読み比べてから固定すること。
- `scoring_model` だけを安いモデルに変える手もあるが、選別の質が号の質を決めるため
  最初は同一モデルのままで運用し、原価が問題になってから検討する。

## バックアップ

`output/moneyloop.db` が唯一の状態です。定期的にコピーしてください。
これを失うと重複配信と収支の履歴喪失が同時に起きます。
