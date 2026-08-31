# アーキテクチャ

## パイプライン

```
sources.collect  →  curate.dedupe/score/select  →  generate.generate_issue
      RSS/Atom          安い判定でふるいにかける        高い生成は少数だけ
        ↓                        ↓                          ↓
   items テーブル          スコア（非永続）             issues テーブル
                                                            ↓
                          paywall.render_*  →  deliver.deliver_issue
                          無料版/有料版に分割      ファイル / Webhook
                                                            ↓
                                              ledger  収支とユニットエコノミクス
```

`orchestrator.run_daily` がこの6段を1本につなぎます。各モジュールはDBやHTTPを
直接持たず、引数で受け取るため単体でテストできます。

## モジュールの責務

| モジュール | 責務 | 意図的にやらないこと |
|---|---|---|
| `sources` | RSS/Atomの取得とパース | 本文クロール（robots/著作権の問題を持ち込まない） |
| `curate` | 重複除去、スコアリング、選別 | 本文生成 |
| `generate` | 号の本文・ティザー・要点の生成 | 配信 |
| `paywall` | 無料版/有料版の出し分け | 課金判定（プランは設定が持つ） |
| `deliver` | 配信サービスへの受け渡し | SMTP送信そのもの |
| `ledger` | 原価と収益の計上、PL算出 | 決済（Stripe等の責務） |
| `storage` | SQLite永続化と冪等性の担保 | ビジネスロジック |
| `llm` | Claude呼び出しとトークン計上 | プロンプトの内容以外の判断 |

## 冪等性（いちばん重要な設計制約）

cronは二重起動し、ジョブはリトライされます。そのたびに課金と配信が増えると
運用が破綻するため、3箇所で重複を止めています。

| 対象 | キー | 効果 |
|---|---|---|
| 号の生成 | `issues(niche, issue_date)` | 同日再実行でAPIを呼ばない |
| 配信 | `deliveries(issue_id, subscriber_id)` | 同じ号を二度送らない |
| 収支計上 | `ledger(kind, category, ref)` | 原価・購読収益の二重計上を防ぐ |

購読収益の `ref` は `sub:{email}:{niche}:{YYYY-MM}` なので、月内に何度
`revenue accrue` を実行しても1回しか計上されません。

## 原価を抑える構造

- **2段構え**: 全記事をOpus 5の本文生成に流すと原価が線形に増えます。
  採点（`effort=low`、短い出力）でふるいにかけ、生成は上位数件だけに絞ります。
- **プロンプトキャッシュ**: 号ごとに変わらないシステムプロンプトに
  `cache_control` を付けています。キャッシュは前方一致なので、
  **可変情報を `EDITOR_SYSTEM` に混ぜるとキャッシュが無効化されます**。
- **品質ゲート**: `min_score` を割った日は号を出さず、生成コストを払いません。
  薄い号を惰性で出すことは解約の最大要因でもあります。

## LLM層の差し替え

`llm.LLMClient` はプロトコルで、実装は2つあります。

- `ClaudeClient`: Anthropic公式SDK。思考は adaptive、構造化出力（json_schema）、
  安全分類による拒否に備えたサーバサイドフォールバック付き。
- `StubClient`: スキーマからダミー値を組み立てる決定論的スタブ。
  `--dry-run` とテストで使い、課金を発生させずに配線・冪等性・収支計算を検証します。

上位のパイプラインはどちらを渡されたかを知りません。

## 拡張ポイント

| やりたいこと | 触る場所 |
|---|---|
| 情報源を増やす（API、スクレイプ） | `sources.py` に fetcher を追加 |
| 配信先を増やす（SMTP、Slack） | `deliver.Deliverer` を実装して `self_deliver` に追加 |
| Stripe Webhookで購読を同期 | `storage.upsert_subscriber` / `cancel_subscriber` を叩く受口を追加 |
| ニッチを増やす | 設定の `niches` に追記するだけ（コード変更不要） |
| 有料記事以外の収益源 | `ledger.record_revenue` に category を足す |
