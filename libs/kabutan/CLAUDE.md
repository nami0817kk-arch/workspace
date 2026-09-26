# kabutan-client

kabutan.jp の取得・解析の共有ライブラリ。利用側は kabu-agari-ranking（コミット固定で参照）。
（もう1つの利用側だった quality-gainer-tracker は 2026-09-26 に廃止した。）

- **後方互換を壊さない**: 公開名（fetch_ranking_html / parse_ranking_table /
  extract_asof_date / fetch_stock_name / fetch_errors / MODE_* / MARKETS）と
  parse の出力列は kabu-agari-ranking のテストが前提にしている。変えるときはそちらも確認。
- 解析を変えたら tests/ の固定 HTML も合わせて更新する。
- 破壊的変更をしても利用側は SHA 固定なので即座には壊れないが、
  取り込み時に気づけるようこのファイルと README に書き残す。
