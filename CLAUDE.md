# quality-gainer-tracker

値上がりランキングから「質の高い上昇」を選んで Access DB に記録し、
14営業日の追跡で手法（A/B/C）の成績を検証する。**記録の連続性が価値**なので、
DB スキーマと記録済みデータを壊さないことを最優先にする。

## 前提

- Python 3.12。依存は `requirements.txt` に `==` で固定。`>=` に緩めない。
- **DB は Microsoft Access（.accdb）で Windows 専用**（pyodbc + ACE OLEDB + pywin32）。
  CI（ubuntu）では DB・ネットワークに触れない分析ロジックだけをテストする。
- 取得元は kabutan（当日）/ kabudragon（過去日）/ yfinance（追跡価格）。

## よく使うコマンド

```bash
pytest                  # テスト（ネットワーク・DB不要）
python main.py rank     # 当日ランキング記録
python main.py update   # 追跡価格の更新
python main.py detect   # A/B/C 買い候補の検出
```

## 手を入れるときに気をつけること

- `src/db/manager.py` の d01〜d14 列は「記録日から n 営業日後の終値」。
  列を増減すると過去レコードと整合しなくなる。スキーマ変更は移行手順とセットで。
- バッチ系（backfill / detect）は1銘柄の失敗で全体を止めず、`[WARN]` を出して続行する。
  この WARN を握りつぶしに戻さない（原因が追えなくなる）。
- `_nearest_round` の節目リストと 5% 許容は手法の定義そのもの。パラメータを
  変えると過去の検証結果と比較できなくなる。
- `data/watchlist.csv` は監視対象の定義。列は ticker / name / market / cap_type。
