# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-09-01
- 平均成熟度: **92** `▁▄▁█`
- これまでに解決: **104** 件
- 未対応: **18** 件

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `workspace` | monorepo | 100 | ±0 | 2 |
| `workspace/projects/ai-side-business` | Python | 100 | ±0 | 1 |
| `workspace/projects/ir-analysis` | Python | 100 | ±0 | 0 |
| `workspace/projects/kabu-agari-ranking` | Python | 100 | ±0 | 1 |
| `workspace/projects/price-tracker` | Python | 100 | ±0 | 0 |
| `workspace/projects/quality-gainer-tracker` | Python | 100 | ±0 | 2 |
| `workspace/projects/stock-investment` | Python | 100 | ±0 | 3 |
| `workspace/projects/tool-factory` | Python | 100 | ±0 | 2 |
| `workspace/projects/youtube-video-creation` | Python | 100 | ±0 | 3 |
| `workspace/projects/soccer-manager` | Flutter | 95 | ±0 | 2 |
| `workspace/libs/kabutan` | Python | 95 | ±0 | 1 |
| `workspace/projects/gemini-api` | Python | 93 | ±0 | 1 |
| `workspace/projects/cohabitation-budget` | 雛形のみ | 15 | ±0 | 0 |

## 次にやること

1. **[中] 1つの関数が長くなりすぎている** — `workspace`
   - 関数の中で「まとまった仕事」をしている塊を、名前を付けて切り出す。切り出した先はテストしやすくなるので、そこから1本書ける。
2. **[中] 1つの関数が長くなりすぎている** — `workspace/projects/ai-side-business`
   - 関数の中で「まとまった仕事」をしている塊を、名前を付けて切り出す。切り出した先はテストしやすくなるので、そこから1本書ける。
3. **[中] CLAUDE.md で AI に前提を渡す（soccer-manager で既に実践中）** — `workspace/projects/gemini-api`
   - お手本の CLAUDE.md を写し、このプロジェクト固有の「目的 / 構成 / 動かし方 / 気をつけること」に書き換える。
4. **[中] 1つの関数が長くなりすぎている** — `workspace/projects/quality-gainer-tracker`
   - 関数の中で「まとまった仕事」をしている塊を、名前を付けて切り出す。切り出した先はテストしやすくなるので、そこから1本書ける。
5. **[中] 例外を握りつぶしている箇所がある** — `workspace/projects/quality-gainer-tracker`
   - 最低でも失敗内容を print / logging で残す。「失敗しても続行してよい」場所なら、なぜよいのかをコメントに書く。

詳細と依頼文は `docs/growth/2026-09-01.md` を見る。

## 保留中（理由あり）

- `workspace/projects/cohabitation-budget` 雛形だけ作られて中身が無い — index.html 1枚で完結させることが価値の完成品。README に「完成・運用中／構成を分割しない」と明記済み

## 直近で解決したもの

- `workspace/projects/youtube-video-creation` ワークフローに実行時間の上限が無い
- `workspace/projects/quality-gainer-tracker` ワークフローに実行時間の上限が無い
- `workspace` README が無い
- `workspace/projects/price-tracker` ワークフローに実行時間の上限が無い
- `workspace/projects/ai-blog` README に「動かし方」のコマンドが書かれていない
- `workspace/projects/ai-blog` 自動テストが1本もない
- `workspace/projects/ir-analysis` ワークフローに実行時間の上限が無い
- `workspace/projects/gemini-api` 依存バージョンが固定されていない
- `workspace/projects/ai-side-business` ワークフローに実行時間の上限が無い
- `workspace/projects/gemini-api` 例外を握りつぶしている箇所がある

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth snooze <fingerprint> -n 理由  # 今はやらない（理由つきで残す）
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
