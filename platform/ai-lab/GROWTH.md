# 成長ダッシュボード

このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。

- 最終更新: 2026-09-28
- 平均成熟度: **89** `▁▄▁▇███▇`
- これまでに解決: **120** 件
- 未対応: **28** 件

## プロジェクト別の成熟度

| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |
|---|---|---:|---:|---:|
| `workspace` | monorepo | 100 | ±0 | 1 |
| `workspace/projects/ai-side-business` | Python | 100 | ±0 | 1 |
| `workspace/projects/gemini-api` | Python | 100 | ±0 | 0 |
| `workspace/projects/kabu-agari-ranking` | Python | 100 | ±0 | 1 |
| `workspace/projects/price-tracker` | Python | 100 | ±0 | 1 |
| `workspace/projects/youtube-video-creation` | Python | 100 | ±0 | 2 |
| `workspace/projects/puzzle-book` | Python | 95 | ±0 | 3 |
| `workspace/projects/shaho-tekiyo` | Python | 95 | ±0 | 4 |
| `workspace/projects/soccer-career` | Flutter | 95 | ±0 | 2 |
| `workspace/projects/soccer-manager` | Flutter | 95 | ±0 | 1 |
| `workspace/libs/kabutan` | Python | 95 | ±0 | 0 |
| `workspace/libs/puzzle-generator` | Python | 95 | ±0 | 1 |
| `workspace/projects/kdp-novel` | Python | 87 | ±0 | 2 |
| `workspace/projects/goso-boat` | Flutter | 85 | ±0 | 3 |
| `workspace/projects/ipa-kakomon` | Python | 78 | ±0 | 3 |
| `workspace/projects/dailyquarry-home` | Python | 75 | ±0 | 3 |
| `workspace/projects/cohabitation-budget` | 雛形のみ | 15 | ±0 | 0 |

## 次にやること

1. **[高] README が無い** — `workspace/projects/dailyquarry-home`
   - README.md に「目的」「動かし方」「構成」の3節を書く。長さは要らない。 参考: workspace/projects/soccer-manager が既に同じことをやっているので、そこから写すのが早い。
2. **[高] 環境変数を使っているのに .gitignore が .env を除外していない** — `workspace/projects/dailyquarry-home`
   - `.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。
3. **[高] 依存パッケージがどこにも書かれていない** — `workspace/projects/kdp-novel`
   - `requirements.txt`（または `pyproject.toml`）を作り、import しているサードパーティを列挙する。
4. **[高] 環境変数を使っているのに .gitignore が .env を除外していない** — `workspace/projects/shaho-tekiyo`
   - `.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。
5. **[中] 必要な環境変数の一覧が無い** — `workspace/projects/dailyquarry-home`
   - `.env.example` にキー名だけ（値は空）を並べる。README からそれを参照する。 参考: workspace/projects/youtube-video-creation が既に同じことをやっているので、そこから写すのが早い。

詳細と依頼文は `docs/growth/2026-09-28.md` を見る。

## 保留中（理由あり）

- `workspace/projects/cohabitation-budget` 雛形だけ作られて中身が無い — index.html 1枚で完結させることが価値の完成品。README に「完成・運用中／構成を分割しない」と明記済み

## 直近で解決したもの

- `workspace/projects/stock-investment` 例外を握りつぶしている箇所がある
- `workspace/projects/stock-investment` 依存バージョンが固定されていない
- `workspace/projects/soccer-career` 1ファイルが大きくなりすぎている
- `workspace/projects/stock-investment` 1つの関数が長くなりすぎている
- `workspace/projects/price-tracker` 1ファイルが大きくなりすぎている

## 使い方

```bash
python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力
python -m growth status                       # 今の未対応一覧
python -m growth snooze <fingerprint> -n 理由  # 今はやらない（理由つきで残す）
python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない
python -m growth done <fingerprint>            # 対応済みにする
```
