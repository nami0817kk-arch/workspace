# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-08-31
- 平均成熟度: **54** `▁█▁`
- これまでに解決: **27** 件
- 未対応: **52** 件（ほかに判断待ち 8 件）

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `ai-lab` | Python | 100 | ±0 | 4 |
| `claude-code-dev/projects/PJT001-stock-investment` | Python | 100 | ±0 | 1 |
| `soccer-manager` | Flutter | 95 | ±0 | 3 |
| `claude-code-dev` | monorepo | 79 | ±0 | 1 |
| `ai-side-business` | Python | 68 | ±0 | 6 |
| `tool-factory` | Python | 60 | ±0 | 7 |
| `kabu-agari-ranking` | Python | 55 | -45 | 10 |
| `price-tracker` | Python | 55 | ±0 | 6 |
| `quality-gainer-tracker` | Python | 28 | ±0 | 9 |
| `ir-analysis` | Python | 28 | ±0 | 6 |
| `youtube-video-creation` | 雛形のみ | 15 | ±0 | 2 |
| `claude-code-dev/projects/PJT002-ai-blog` | 雛形のみ | 15 | ±0 | 1 |
| `cohabitation-budget` | 雛形のみ | 0 | ±0 | 4 |

## 次にやること

1. **[高] 定期実行ジョブが黙って失敗する状態になっている** — `kabu-agari-ranking`
   - ワークフロー末尾に `if: failure()` の通知ステップを足す（Issue 起票 / メール / Webhook のいずれか）。GitHub は定期ジョブ失敗を通知しない設定のこともあるので、明示的に鳴らす。
2. **[高] 環境変数を使っているのに .gitignore が .env を除外していない** — `kabu-agari-ranking`
   - `.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。
3. **[高] 自動テストが1本もない** — `kabu-agari-ranking`
   - まず一番壊れて困る関数1つに対してテストを1本書く。網羅は狙わない。`tests/test_<対象>.py` を作り、正常系1件・異常系1件から始める。 参考: soccer-manager が既に同じことをやっているので、そこから写すのが早い。
4. **[高] 依存パッケージがどこにも書かれていない** — `price-tracker`
   - `requirements.txt`（または `pyproject.toml`）を作り、import しているサードパーティを列挙する。
5. **[高] 環境変数を使っているのに .gitignore が .env を除外していない** — `price-tracker`
   - `.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。

詳細と依頼文は `docs/growth/2026-08-31.md` を見る。

## あなたの判断が要るもの

- `kabu-agari-ranking` **公開リポジトリにライセンスが無い**
- `price-tracker` **公開リポジトリにライセンスが無い**
- `tool-factory` **公開リポジトリにライセンスが無い**
- `claude-code-dev` **公開リポジトリにライセンスが無い**
- `cohabitation-budget` **公開リポジトリにライセンスが無い**
- `claude-code-dev/projects/PJT002-ai-blog` **雛形だけ作られて中身が無い**
- `youtube-video-creation` **雛形だけ作られて中身が無い**
- `cohabitation-budget` **雛形だけ作られて中身が無い**

## 保留中（理由あり）

- `claude-code-dev/projects/PJT001-stock-investment` 依存バージョンが固定されていない — pywin32 を含むため Windows 側で pip freeze を取る必要がある。検証できないまま版を固定すると、動いている環境をかえって壊す
- `claude-code-dev/projects/PJT001-stock-investment` 1つの関数が長くなりすぎている — selector.py はテストが1本も無く、ネットワークに出る処理も多い。screener.py のように挙動を固定してからでないと切り出せない
- `youtube-video-creation` tests/ が空のまま置かれている — テスト対象のコードがまだ無い。最初に作る機能が決まってから

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth snooze <fingerprint> -n 理由  # 今はやらない（理由つきで残す）
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
