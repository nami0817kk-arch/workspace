# kabu-agari-ranking

日本株の値上がり/値下がり/活況ランキングを平日毎日取得し、静的サイトとして公開する。
広告による収益化が目的なので、**サイトが止まること・中身が空になることが一番の損失**。

公開URL: https://kabu-agari-ranking.pages.dev/

## 前提

- Python 3.12。依存は `requirements.txt` に `==` で固定してある。
  上流の新版で毎朝のジョブが勝手に壊れるのを防ぐため、**`>=` に緩めない**。
  更新は Dependabot の PR で受け取り、CI が通るのを見てから上げる。
- 取得先は kabutan.jp のHTML。先方の都合で構造が変わりうる。

## よく使うコマンド

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt pytest

pytest                      # テスト
python src/build_site.py    # 取得 → data/ 保存 → output/ 生成
```

## 手を入れるときに気をつけること

- kabutan の HTML 取得・解析は **共有パッケージ [kabutan-client](https://github.com/nami0817kk-arch/kabutan-client)** にある
  （quality-gainer-tracker と共通）。列位置の依存・解析の修正は kabutan-client 側で行い、
  こちらは requirements.txt のコミット固定を進めて取り込む。
  `src/fetcher.py` に残っているのはランキングの組み立て（絞り込み・順位付け）だけ。
- `_extract_asof_date` は休場日対策。取得日ではなくページ上の終値日付を使う。
  ここを `date.today()` に戻すと、休日実行で日付がずれる。
- `render._normalize_day` は旧形式（`rows`/`gain_pct`/`volume`）の変換。
  消すと過去のアーカイブが読めなくなる。
- `data/*.json` は CI が自動コミットしている実データ。手で消さない。
- `output/` は毎回作り直すビルド成果物（gitignore 済み）。
- 秘密情報は `.env`（gitignore 済み）か GitHub Secrets へ。
  必要なキーは `.env.example` にある。
- **取得は手元PCのタスクスケジューラ**（run-daily.ps1、毎平日16:10）が行い、data/ を push する。
  kabutan は GitHub Actions の IP を 405 でブロックするため、CI から取得する形に戻さない。
  CI は push された data/ からのビルド・X投稿・公開と、17:00 JST の鮮度監視を担当する。
- 定期実行のワークフローには失敗時に Issue を立てるステップがある。
  ジョブを触るときはこれを消さない。**黙って止まるのが最悪の壊れ方**。
