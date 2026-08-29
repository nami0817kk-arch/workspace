# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-08-29
- 平均成熟度: **54** `▄`
- これまでに解決: **0** 件
- 未対応: **23** 件

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `ai-lab` | Python | 100 | ±0 | 1 |
| `claude-code-dev/projects/PJT003-soccer-manager` | Flutter | 88 | ±0 | 3 |
| `claude-code-dev` | monorepo | 57 | ±0 | 1 |
| `kabu-agari-ranking` | Python | 55 | ±0 | 7 |
| `claude-code-dev/projects/PJT001-stock-investment` | Python | 48 | ±0 | 6 |
| `youtube-video-creation` | 雛形のみ | 15 | ±0 | 3 |
| `claude-code-dev/projects/PJT002-ai-blog` | 雛形のみ | 15 | ±0 | 2 |

## 次にやること

1. **[高] 定期実行ジョブが黙って失敗する状態になっている** — `kabu-agari-ranking`
   - ワークフロー末尾に `if: failure()` の通知ステップを足す（Issue 起票 / メール / Webhook のいずれか）。GitHub は定期ジョブ失敗を通知しない設定のこともあるので、明示的に鳴らす。
2. **[高] 環境変数を使っているのに .gitignore が .env を除外していない** — `kabu-agari-ranking`
   - `.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。
3. **[高] 自動テストが1本もない** — `kabu-agari-ranking`
   - まず一番壊れて困る関数1つに対してテストを1本書く。網羅は狙わない。`tests/test_<対象>.py` を作り、正常系1件・異常系1件から始める。 参考: claude-code-dev/projects/PJT003-soccer-manager が既に同じことをやっているので、そこから写すのが早い。
4. **[高] README が無い** — `claude-code-dev`
   - README.md に「目的」「動かし方」「構成」の3節を書く。長さは要らない。
5. **[高] 自動テストが1本もない** — `claude-code-dev/projects/PJT001-stock-investment`
   - まず一番壊れて困る関数1つに対してテストを1本書く。網羅は狙わない。`tests/test_<対象>.py` を作り、正常系1件・異常系1件から始める。 参考: claude-code-dev/projects/PJT003-soccer-manager が既に同じことをやっているので、そこから写すのが早い。

詳細と依頼文は `docs/growth/2026-08-29.md` を見る。

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
