# price-tracker — 楽天 値下がりウォッチ

楽天市場の価格を毎日記録し、履歴から値下がり・最安値圏を機械的に判定して公開する。
収益は楽天アフィリエイト。**価値は文章ではなく価格履歴の蓄積**（後から買えない資産）。

## 前提

- Python 3.12、**標準ライブラリのみ**。依存を足すときは `requirements.txt` に `==` で固定し、理由を書く。
- **実行時に生成AIを使わない**（費用と品質の両方の理由。README 参照）。
- 判定はすべて `src/analyze.py` の四則演算。根拠を後から説明できる形を保つ。
- `data/` は成果物ではなく資産。履歴なのでリポジトリに commit する。`dist/` は毎回作り直す生成物。

## よく使うコマンド

```bash
pytest                # テスト（ネットワーク不要）
python explore.py     # 対象ジャンルをデータで決めるための調査
python fetch.py       # 価格を取得して data/ に記録（要 RAKUTEN_APP_ID）
python build.py       # data/ から静的サイトを生成（通信しない）
```

## まだ決まっていないこと（着手前に決める）

- `config.json` の `genres` が空。**対象ジャンルを決めるまで日次取得は走れない**。
  勘で選ばず `explore.py` の調査結果で決める。
- 公開先。`config.json` の `base_url` が切り出し前の claude-code-dev のパスを指したまま。
- 日次実行のワークフローが未作成。作るときは kabu-agari-ranking の
  kabu-daily.yml を参考に、失敗時に Issue を立てるステップを必ず入れる。

## 手を入れるときに気をつけること

- `src/rakuten.py` は 1秒1回のレート制限を守っている。緩めない。
- `src/store.py` は同日に二度動かしても壊れない設計。この性質をテストで守っている。
- 秘密情報は `.env`（gitignore 済み）か GitHub Secrets へ。キー名は `.env.example` にある。
