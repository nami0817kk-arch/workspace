# ir-analysis — 適時開示(IR)の取得・分析と Excel 出力

株探の適時開示一覧から決算・業績修正・配当・自社株買い・増資の PDF を取得し、
Claude API で要約・スイング投資への関連度を判定して Excel レポートに出力する。

## 使い方

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt pytest

pytest                                    # テスト（ネットワーク不要）
python main.py run                        # 当日の全カテゴリを取得・分析
python main.py run --category kessan      # 決算のみ
python main.py run --date 2026-08-31      # 日付指定
python main.py run --max 10               # 件数を絞る
```

カテゴリ: `kessan`(決算) / `gyoseki`(業績修正) / `haitou`(配当) /
`jishakab`(自社株買い) / `zoshi`(増資) / `all`(全件)

## 構成

```
ir-analysis/
├── main.py                       エントリポイント
├── src/
│   ├── data/kabutan_disclosure.py   開示一覧の取得と PDF テキスト抽出
│   ├── analysis/ir_analyzer.py      Claude API での分析（haiku）
│   └── report/excel_exporter.py     Excel 出力
├── tests/                        ネットワークに出ないテスト
└── data/                         取得した PDF・レポート（gitignore 済み）
```

## 秘密情報

Claude API のキーは `.env`（gitignore 済み）に置く。キー名は `.env.example` を参照。

## 判定の出力

分析結果には `impact`（positive / negative / neutral）と
`swing_relevance`（high / mid / low）が付く。high はコンソールにも一覧表示される。
