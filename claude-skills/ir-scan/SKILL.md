---
name: ir-scan
description: 株探の適時開示（決算・業績修正・配当・自社株買い・増資）を ir-analysis で取得して分析し、Excel に出したうえで、重要なものは TDnet / EDINET / 会社IR の原文PDFまで当たって裏取りする。「今日のIR」「決算チェック」「開示を見て」「業績修正あった?」「自社株買いの銘柄」のときに使う。
---

# IR開示スキャン

`projects/ir-analysis` で当日の適時開示をまとめて取り込み、
**要約で止めず、効きそうな開示だけ原文まで確認する**ための手順。

## 前提

- パス: `C:\Users\なみ\dev\workspace\projects\ir-analysis`
- **必ず venv の Python を使う。** システムの `python` には `pdfplumber` が無く、
  `main.py` は import の時点で落ちる。

```bash
cd "C:/Users/なみ/dev/workspace/projects/ir-analysis" && ./.venv/Scripts/python.exe main.py run
```

venv が無い場合はここで作る（`.venv` は gitignore 済み）。

```bash
cd "C:/Users/なみ/dev/workspace/projects/ir-analysis" && python -m venv .venv \
  && ./.venv/Scripts/python.exe -m pip install -r requirements.txt
```

- 出力: `data/reports/ir_report_YYYYMMDD.xlsx`、PDF原本は `data/pdfs/`
- `.env` に APIキーが要る（`load_dotenv` 済み）。キー切れは実行時エラーで分かる。
- 依存は実測値で**バージョン固定**されている。`>=` に緩めない。更新は Dependabot の PR で受ける。

## 手順

### 1. 取り込む

```bash
# 当日・全カテゴリ・上位20件
cd "C:/Users/なみ/dev/workspace/projects/ir-analysis" && ./.venv/Scripts/python.exe main.py run

# カテゴリを絞る（kessan / gyoseki / haitou / jishakab / zoshi / all）
cd "C:/Users/なみ/dev/workspace/projects/ir-analysis" && ./.venv/Scripts/python.exe main.py run --category gyoseki --max 30

# 過去日
cd "C:/Users/なみ/dev/workspace/projects/ir-analysis" && ./.venv/Scripts/python.exe main.py run --date 2026-08-28
```

件数が多い日は `--max` を上げる前に `--category` で絞る。全件を薄く見るより、
業績修正（`gyoseki`）と自社株買い（`jishakab`）を厚く見るほうが情報量が多い。

### 2. 出力を読む

生成された Excel を読み、次の観点で並べ替えて上位だけ扱う。

- **上方/下方の修正幅**（率と絶対額の両方。小型株は率が跳ねるので絶対額も見る）
- **通期に対する進捗**（第1四半期で進捗50%超なら上振れ含み）
- **自社株買いの発行済比率と取得期間**（比率が小さく期間が長いものは効きにくい）
- **増資は原則ネガティブ**として扱い、資金使途で判断を分ける

### 3. 効きそうなものだけ原文で裏取りする

**ここを飛ばさない。** 抽出は PDF のレイアウトに依存するので取り違えが起きうる。
上位3〜5件は必ず原文に当たる。手順は `primary-source-research` スキルに従う。
複数銘柄を並列で当てるなら `ir-reader` サブエージェントを使う。

一次情報の優先順位:

1. **TDnet**（https://www.release.tdnet.info/）— 開示原本。**直近31日分しか残らない**
2. **EDINET**（https://disclosure2.edinet-fsa.go.jp/）— 有報・四半期・大量保有。期間制限なし
3. **会社の IR ページ** — 決算説明資料。数値の背景はここが一番濃い
4. 株探・日経などの記事は**手がかりであって根拠ではない**

`data/pdfs/` に原本があればそれを直接読むのが速い（Read の `pages` 指定で読める）。

### 4. 報告する

開示ごとに1行ずつ。**数値は原文表記のまま**引く（丸めない・単位を変えない）。

```
9999 会社名  上方修正  営業利益 12.0億→15.5億 (+29.2%)  通期進捗 58%
  出典: TDnet 2026-08-31 「2027年3月期第1四半期決算短信」p.1
```

裏取りできたものと、ツール出力のままのものを**必ず区別して書く**。

## やらないこと

- 銘柄の売買推奨はしない。開示の事実と数値だけを示す。
- 原文を開いていないものを「確認済み」と書かない。
- `data/pdfs/` を消さない（再取得は相手先に負荷をかける）。
