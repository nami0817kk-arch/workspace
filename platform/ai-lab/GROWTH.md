# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-09-01
- 平均成熟度: **86** `▁▄▁█`
- これまでに解決: **90** 件
- 未対応: **38** 件（ほかに判断待ち 1 件）

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `workspace/projects/ai-side-business` | Python | 100 | ±0 | 2 |
| `workspace/projects/ir-analysis` | Python | 100 | ±0 | 1 |
| `workspace/projects/kabu-agari-ranking` | Python | 100 | ±0 | 2 |
| `workspace/projects/price-tracker` | Python | 100 | ±0 | 2 |
| `workspace/projects/quality-gainer-tracker` | Python | 100 | ±0 | 3 |
| `workspace/projects/stock-investment` | Python | 100 | ±0 | 3 |
| `workspace/projects/tool-factory` | Python | 100 | ±0 | 3 |
| `workspace/projects/youtube-video-creation` | Python | 100 | ±0 | 5 |
| `workspace/projects/soccer-manager` | Flutter | 95 | ±0 | 2 |
| `workspace/libs/kabutan` | Python | 95 | ±0 | 2 |
| `workspace/projects/gemini-api` | Python | 93 | ±0 | 4 |
| `workspace` | monorepo | 57 | ±0 | 5 |
| `workspace/projects/ai-blog` | Python | 45 | ±0 | 4 |
| `workspace/projects/cohabitation-budget` | 雛形のみ | 15 | ±0 | 1 |

## 次にやること

1. **[高] README が無い** — `workspace`
   - README.md に「目的」「動かし方」「構成」の3節を書く。長さは要らない。
2. **[高] 自動テストが1本もない** — `workspace/projects/ai-blog`
   - まず一番壊れて困る関数1つに対してテストを1本書く。網羅は狙わない。`tests/test_<対象>.py` を作り、正常系1件・異常系1件から始める。 参考: workspace/projects/soccer-manager が既に同じことをやっているので、そこから写すのが早い。
3. **[中] ワークフローに実行時間の上限が無い** — `workspace`
   - 各 job に `timeout-minutes:` を入れる（テストなら10分、取得や公開を伴うものでも30分あれば足りる）。
4. **[中] 1つの関数が長くなりすぎている** — `workspace`
   - 関数の中で「まとまった仕事」をしている塊を、名前を付けて切り出す。切り出した先はテストしやすくなるので、そこから1本書ける。
5. **[中] ワークフローに実行時間の上限が無い** — `workspace/libs/kabutan`
   - 各 job に `timeout-minutes:` を入れる（テストなら10分、取得や公開を伴うものでも30分あれば足りる）。

詳細と依頼文は `docs/growth/2026-09-01.md` を見る。

## あなたの判断が要るもの

- `workspace/projects/cohabitation-budget` **雛形だけ作られて中身が無い**

## 直近で解決したもの

- `youtube-video-creation` CLAUDE.md で AI に前提を渡す（サッカークラブ経営シミュレーション（Flutter） で既に実践中）
- `claude-code-dev` 公開リポジトリにライセンスが無い
- `quality-gainer-tracker` 自動テストが1本もない
- `soccer-manager` ワークフローに実行時間の上限が無い
- `claude-code-dev/projects/PJT002-ai-blog` 雛形だけ作られて中身が無い
- `quality-gainer-tracker` CLAUDE.md で AI に前提を渡す（サッカークラブ経営シミュレーション（Flutter） で既に実践中）
- `quality-gainer-tracker` .env.example で必要な設定を明示する（ai-lab / 成長ループ本体 で既に実践中）
- `quality-gainer-tracker` 依存バージョンが固定されていない
- `cohabitation-budget` README が無い
- `tool-factory` ドキュメント内のリンク先が存在しない

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth snooze <fingerprint> -n 理由  # 今はやらない（理由つきで残す）
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
