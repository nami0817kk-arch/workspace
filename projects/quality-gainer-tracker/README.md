# quality-gainer-tracker — 値上がり銘柄の質の追跡

日本株の値上がりランキングから「質の高い値上がり」（出来高を伴い、過熱しすぎていない上昇）を
スクリーニングして Access DB に記録し、その後14営業日の追跡価格でパフォーマンスを検証する。
検証済みの A / B / C 手法で買い候補も検出する。

## 使い方

```bash
pip install -r requirements.txt pytest

pytest                        # テスト（ネットワーク・DB不要）
python main.py rank           # 当日の値上がり質ランキングを表示・DB保存
python main.py update         # 過去レコードの d01〜d14 追跡価格を更新
python main.py report         # 2週間パフォーマンス集計
python main.py backfill       # 過去 n 営業日分をランキング再構築して補填
python main.py detect         # A/B/C 手法の買い候補を検出
python main.py query "SQL"    # DB に任意の SQL（デバッグ用）
```

日付指定なしの `rank` は kabutan（当日リアルタイム）、日付指定ありは kabudragon（過去日）から取る。

## 構成

```
quality-gainer-tracker/
├── main.py                       CLI エントリポイント
├── src/
│   ├── data/                     価格・ランキングの取得（yfinance / kabutan）
│   ├── analysis/
│   │   ├── indicators.py         SMA / MACD / RSI / BB / Stoch / OBV
│   │   ├── screener.py           値上がり質スクリーニング
│   │   ├── pattern_detector.py   A/B/C 手法の検出
│   │   └── backfill.py           過去営業日ぶんのランキング再構築
│   └── db/manager.py             Access DB（.accdb）への記録・更新・集計
├── tests/                        ネットワークに出ないテスト
└── data/
    ├── watchlist.csv             監視銘柄（ticker / name / market / cap_type）
    └── db/                       Access DB 本体（gitignore 済み）
```

## 実行環境の前提

- **記録・追跡は Windows 専用**。DB が Microsoft Access（ODBC + ACE OLEDB）のため、
  `pyodbc` / `pywin32` と Access Database Engine が要る。
- 分析ロジック（indicators / pattern_detector）自体は OS を問わず、CI では
  その部分だけをテストしている。

## 関連プロジェクト

- `kabu-agari-ranking` — 同じランキング取得ロジックの公開サイト版
- `ir-analysis` — 開示情報の分析。銘柄判断の材料をこちらで補う
