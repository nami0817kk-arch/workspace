# PJT008 - AIラボ

AI活用のアイデア検証・試作を行うラボプロジェクト。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## 構成

| フォルダ | 用途 |
|---|---|
| `src/` | 実装コード |
| `scripts/` | 補助スクリプト |
| `docs/` | 調査メモ・検証記録 |
| `tests/` | テストコード |

## 検証テーマ

### Chrome の自動操作

ヘッドレス Chromium の操作と、ローカル PC の Chrome 本体の操作(CDP 経由)。

```bash
playwright install chromium
python -m src.browser.headless_demo          # ヘッドレスのデモ
python -m src.browser.local_chrome --list    # ローカル Chrome のタブ一覧
```

詳細は [`docs/chrome-automation.md`](docs/chrome-automation.md)。
