# workspace

個人開発の全プロジェクトを1本にまとめた開発モノレポ。2026-09-01 に、それまで
12 に分かれていたリポジトリを履歴ごと統合した。

このファイルは**入口の地図**。規約と手順の本体は別ファイルにある。

| 読むもの | 中身 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | セッション運用ルール（**作業前に必読**）・収益/運用上の注意 |
| [docs/session-faq.md](docs/session-faq.md) | 「これはなぜこうなっている?」の答え。疑問はまずここ |
| [docs/sessions.md](docs/sessions.md) | セッション台帳。誰がどのPJTを持っているか・PCが落ちると何が止まるか |
| [platform/ai-lab/GROWTH.md](platform/ai-lab/GROWTH.md) | 全PJTの成熟度と「次にやること」（自動生成） |

## レイアウト

| 場所 | 中身 |
|---|---|
| `projects/<name>/` | 各プロジェクト。**1つのディレクトリで自己完結**（CLAUDE.md・テスト・データ込み） |
| `libs/<name>/` | 複数プロジェクトが使う共有コード。参照は `pip install -e libs/<name>` |
| `platform/ai-lab/` | 基盤。点検ループ（growth）・ブラウザ操作・画像/音声生成など |
| `templates/` `scripts/` | プロジェクト雛形と横断スクリプト（夜間の wip-sweeper など） |
| `.github/workflows/` | 全ワークフロー。**必ず `paths:` で対象を絞る**（絞らないと全PJTで走る） |
| `docs/` | 横断ドキュメント |

## プロジェクト

### 収益を目的にしているもの

| プロジェクト | 何をするもの | 状態 |
|---|---|---|
| [kabu-agari-ranking](projects/kabu-agari-ranking/) | 日本株の値上がり/値下がり/活況ランキングを毎日自動取得して公開する静的サイト。広告収益 | 運用中・公開 |
| [price-tracker](projects/price-tracker/) | 楽天市場の価格を毎日記録し、値下がりと最安値圏を判定して公開。楽天アフィリエイト | 運用中・公開 |
| [tool-factory](projects/tool-factory/) | 計算ツールのサイトを量産する仕組み。現在 10 ツール | 運用中・公開 |
| [soccer-manager](projects/soccer-manager/) | サッカークラブ経営・育成シミュレーションのスマホアプリ（Flutter + Flame） | 開発中・ストア準備 |
| [youtube-video-creation](projects/youtube-video-creation/) | 台本(Markdown)から、ゆっくり実況風の動画・音声・BGM・字幕・サムネイルを書き出すパイプライン | 開発中 |
| [ai-side-business](projects/ai-side-business/) | AI で成果物を自動生成して納品する副業のための実行エンジン + 経営管理ツール | 開発中 |

### 投資・分析のためのもの

| プロジェクト | 何をするもの | 状態 |
|---|---|---|
| [stock-investment](projects/stock-investment/) | 日本株・米国株の投資支援システム | 運用中 |
| [ir-analysis](projects/ir-analysis/) | 適時開示(IR)の PDF を取得し、Claude API で要約・関連度判定して Excel 出力 | 運用中 |
| [quality-gainer-tracker](projects/quality-gainer-tracker/) | 「質の高い値上がり」をスクリーニングして記録し、14営業日の追跡でパフォーマンス検証 | 運用中 |

### 道具

| プロジェクト | 何をするもの | 状態 |
|---|---|---|
| [gemini-api](projects/gemini-api/) | Gemini API を叩いて JSON で返す自分用の FastAPI ゲートウェイ。APIキーを1か所に閉じ込める | 運用中 |
| [cohabitation-budget](projects/cohabitation-budget/) | 同棲の初期費用・生活費から分担額を出す1ページのツール | **完成**（`index.html` 1枚。分割しない） |
| [libs/kabutan](libs/kabutan/) | kabutan.jp のランキング取得・解析クライアント。kabu-agari-ranking と quality-gainer-tracker が共用 | 運用中 |
| [platform/ai-lab](platform/ai-lab/) | 各PJTで使う機能・仕組みの開発場所。growth 点検ループの本体 | 運用中 |

## 動かし方

Python は**プロジェクトごとに `.venv`**（`.gitignore` 済み）。無いものはシステム Python を使う。

```bash
cd projects/<name>
py -m venv .venv && .venv/Scripts/activate
pip install -r requirements.txt
pytest
```

共有コードを使うプロジェクトは、あわせて `pip install -e libs/kabutan` を入れる。

## CI と公開

- テストの実体は [`.github/workflows/python-tests.yml`](.github/workflows/python-tests.yml)（`workflow_call`）。
  各PJTの `<name>-tests.yml` はこれを呼ぶだけなので、**actions のバージョン更新はこの1ファイルで済む**。
  実行時間の上限もここで一括して掛かっている。
- 公開サイトは全て **Cloudflare Pages** 配信。このリポジトリは private のままでよい。
- **kabu-agari-ranking の株価取得だけは CI ではなくこのPCのタスクスケジューラ**が行う
  （平日 16:10、`projects/kabu-agari-ranking/run-daily.ps1`）。kabutan が GitHub Actions の
  IP を 405 で弾くため。**CI から取得する形に戻さないこと。** 経緯は
  [docs/session-faq.md](docs/session-faq.md)。

## 点検

`platform/ai-lab` の growth ループが `projects/*` と `libs/*` を横断で点検し、
成熟度と「次にやること」を [GROWTH.md](platform/ai-lab/GROWTH.md) に自動生成する。
手元で回すときは `pjt-health` スキルを使う。
