# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-08-29
- 平均成熟度: **72** `▁█`
- これまでに解決: **37** 件
- 未対応: **0** 件（ほかに判断待ち 4 件）

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `ai-lab` | Python | 100 | ±0 | 0 |
| `kabu-agari-ranking` | Python | 100 | +45 | 1 |
| `claude-code-dev/projects/PJT001-stock-investment` | Python | 100 | +52 | 0 |
| `claude-code-dev/projects/PJT003-soccer-manager` | Flutter | 95 | +7 | 0 |
| `claude-code-dev` | monorepo | 79 | +22 | 1 |
| `youtube-video-creation` | 雛形のみ | 15 | ±0 | 1 |
| `claude-code-dev/projects/PJT002-ai-blog` | 雛形のみ | 15 | ±0 | 1 |

## 次にやること

なし。

## あなたの判断が要るもの

- `kabu-agari-ranking` **公開リポジトリにライセンスが無い**
- `claude-code-dev` **公開リポジトリにライセンスが無い**
- `claude-code-dev/projects/PJT002-ai-blog` **雛形だけ作られて中身が無い**
- `youtube-video-creation` **雛形だけ作られて中身が無い**

## 保留中（理由あり）

- `claude-code-dev/projects/PJT001-stock-investment` 依存バージョンが固定されていない — pywin32 を含むため Windows 側で pip freeze を取る必要がある。検証できないまま版を固定すると、動いている環境をかえって壊す
- `claude-code-dev/projects/PJT001-stock-investment` 1つの関数が長くなりすぎている — selector.py はテストが1本も無く、ネットワークに出る処理も多い。screener.py のように挙動を固定してからでないと切り出せない
- `claude-code-dev/projects/PJT003-soccer-manager` 1ファイルが大きくなりすぎている — Flutter アプリで、この環境では実際に動かして確認できない。分割はゲーム挙動の確認とセットで行う必要がある
- `youtube-video-creation` tests/ が空のまま置かれている — テスト対象のコードがまだ無い。最初に作る機能が決まってから

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth snooze <fingerprint> -n 理由  # 今はやらない（理由つきで残す）
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
