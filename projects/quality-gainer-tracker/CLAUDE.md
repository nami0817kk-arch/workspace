# quality-gainer-tracker

値上がりランキングから「質の高い上昇」を選んで Access DB に記録し、
14営業日の追跡で手法（A/B/C）の成績を検証する。**記録の連続性が価値**なので、
DB スキーマと記録済みデータを壊さないことを最優先にする。

## 前提

- Python 3.12。依存は `requirements.txt` に `==` で固定。`>=` に緩めない。
- **DB は Microsoft Access（.accdb）で Windows 専用**（pyodbc + ACE OLEDB + pywin32）。
  CI（ubuntu）では DB・ネットワークに触れない分析ロジックだけをテストする。
- 取得元は kabutan（当日）/ kabudragon（過去日）/ yfinance（追跡価格）。
  **kabutan の HTML 取得・解析は 共有パッケージ [kabutan-client](https://github.com/nami0817kk-arch/kabutan-client)**（kabu-agari-ranking と共通）。
  解析の修正は kabutan-client 側で行い、requirements.txt のコミット固定を進めて取り込む。

## よく使うコマンド

```bash
pytest                  # テスト（ネットワーク・DB不要）
python main.py rank     # 当日ランキング記録
python main.py update   # 追跡価格の更新
python main.py detect   # A/B/C 買い候補の検出
```

## 手を入れるときに気をつけること

- **記録日は実行日ではなく、ページ上の終値日**（`extract_asof_date`）を使う。
  記録日は d01〜d14 の起点なので、1日ずれると追跡の検証が丸ごと狂う。
  休場日や大引け前に回すと実行日と終値日は普通にずれる。
  同じ取り違えで kabu-agari-ranking は1営業日ぶんのデータを上書きした（2026-09-07）。
- **基準日が決められないときは書き込まない。** d01 は「記録日の翌営業日」。
  取得できた価格が記録日より後からしか無いとき、いちばん古い行を d01 にすると
  14営業日ぶん丸ごと別の期間の値が入る。**数字は埋まるので後から気づけない**。
  そのため取得は「その銘柄の最古の記録日から」に変えてあり、それでも決められない
  ときは [WARN] を出して飛ばす。
- **追跡期間に株式分割が入ると成績がずれる。** 記録時終値は kabutan の生値
  （分割前）だが、d01〜d14 は調整済みの終値。検出したら [WARN] を出す
  （自動では直さない。どちらに寄せるかは手法の定義に関わるため）。
- `src/db/manager.py` の d01〜d14 列は「記録日から n 営業日後の終値」。
  列を増減すると過去レコードと整合しなくなる。スキーマ変更は移行手順とセットで。
- バッチ系（backfill / detect）は1銘柄の失敗で全体を止めず、`[WARN]` を出して続行する。
  この WARN を握りつぶしに戻さない（原因が追えなくなる）。
- `_nearest_round` の節目リストと 5% 許容は手法の定義そのもの。パラメータを
  変えると過去の検証結果と比較できなくなる。
- `data/watchlist.csv` は監視対象の定義。列は ticker / name / market / cap_type。
