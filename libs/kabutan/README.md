# kabutan-client

kabutan.jp のランキングページ（`/warning/`）の取得・解析クライアント。

`kabu-agari-ranking`（公開サイト）と `quality-gainer-tracker`（記録・追跡）が
同じ stock_table 解析を二重に持っていたのを、ここに一本化した。
**kabutan の HTML 構造が変わったときに直す場所はこのリポジトリだけ。**

## 使い方

```python
from kabutan import (
    MODE_GAINERS, fetch_ranking_html, parse_ranking_table, extract_asof_date,
)

html = fetch_ranking_html(MODE_GAINERS, market=1)   # プライム
df = parse_ranking_table(html)   # ticker / code / name / close / change_pct / metric_value
asof = extract_asof_date(html)   # 実際の終値基準日（休場日対策）
```

利用側は `requirements.txt` にコミット固定で書く:

```
kabutan-client @ git+https://github.com/nami0817kk-arch/kabutan-client.git@<SHA>
```

## 注意

- kabutan は **GitHub Actions のランナー IP を 405 でブロックする**（2026-08-31 実測）。
  CI から直接取得する設計にはしないこと。
- 取得失敗は `kabutan.fetch_errors` に残る。「休場日で0件」と「拒否されて0件」を
  利用側が区別するためのもの。
