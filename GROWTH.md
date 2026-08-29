# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-08-29
- 平均成熟度: **72** `▁█`
- これまでに解決: **18** 件
- 未対応: **6** 件

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `ai-lab` | Python | 100 | ±0 | 0 |
| `kabu-agari-ranking` | Python | 100 | +45 | 0 |
| `claude-code-dev/projects/PJT001-stock-investment` | Python | 100 | +52 | 2 |
| `claude-code-dev/projects/PJT003-soccer-manager` | Flutter | 95 | +7 | 1 |
| `claude-code-dev` | monorepo | 79 | +22 | 0 |
| `youtube-video-creation` | 雛形のみ | 15 | ±0 | 2 |
| `claude-code-dev/projects/PJT002-ai-blog` | 雛形のみ | 15 | ±0 | 1 |

## 次にやること

1. **[中] 依存バージョンが固定されていない** — `claude-code-dev/projects/PJT001-stock-investment`
   - 動いている今の環境で `pip freeze` を取り、`requirements.txt` を `==` で固定する。更新は Dependabot に任せて、上がったときに気づけるようにする。 参考: kabu-agari-ranking が既に同じことをやっているので、そこから写すのが早い。
2. **[低] 1ファイルが大きくなりすぎている** — `claude-code-dev/projects/PJT001-stock-investment`
   - 責務ごとにモジュールを分ける。まず「他から呼ばれていない塊」を別ファイルに出すのが安全。
3. **[低] 雛形だけ作られて中身が無い** — `claude-code-dev/projects/PJT002-ai-blog`
   - 次の一手を1つだけ決めて README に書く（例:「最初に作る機能はこれ」）。当面やらないなら README にその旨を書くか、リポジトリをアーカイブする。
4. **[低] 1ファイルが大きくなりすぎている** — `claude-code-dev/projects/PJT003-soccer-manager`
   - 責務ごとにモジュールを分ける。まず「他から呼ばれていない塊」を別ファイルに出すのが安全。
5. **[低] 雛形だけ作られて中身が無い** — `youtube-video-creation`
   - 次の一手を1つだけ決めて README に書く（例:「最初に作る機能はこれ」）。当面やらないなら README にその旨を書くか、リポジトリをアーカイブする。

詳細と依頼文は `docs/growth/2026-08-29.md` を見る。

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
