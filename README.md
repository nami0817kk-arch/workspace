# PJT008 AIラボ / 成長ループ

各プロジェクトを定期的に点検し、**次にやることを向こうから提示してくる**仕組み。

やりたかったのは「毎回こちらから依頼を出す」のをやめること。
週に1回、全プロジェクトの状態を見て、伸びしろを見つけ、
どこかのPJTで既にうまくいっている習慣を、まだやっていないPJTへ持っていく。
提案には Claude にそのまま貼れる依頼文が付いてくるので、
やると決めたらコピペするだけで着手できる。

## 何をしているか

```
週1回（GitHub Actions）
  ↓
① 観測   全リポジトリを浅くクローンし、README/テスト/CI/依存/秘密情報などを調べる
  ↓
② 診断   「どのPJTでも満たしていたい水準」との差分を出す
  ↓
③ 横展開 あるPJTで既に実践している習慣を、まだのPJTへ伝える（お手本つき）
  ↓
④ 絞込   1PJTあたり最大3件・全体で最大12件まで。並べすぎると結局やらないので
  ↓
⑤ 出力   GROWTH.md（ダッシュボード）/ docs/growth/日付.md（詳細）/ 任意でIssue起票
  ↓
⑥ 記憶   台帳に記録。次回は「消えた指摘＝解決」として成果に数え、
         却下されたものは二度と出さない
```

⑥があるので、走らせるたびに賢くなる。同じことを毎週言ってくることはない。

## 使い方

```bash
# 開発用の依存（pytest だけ）を入れる。実行時の依存はゼロ。
pip install -e ".[dev]"

# 対象リポジトリを作業ディレクトリへ取得する
python -m growth fetch --workspace ../growth-workspace

# 点検して提案を出す（--dry-run なら何も書き込まず標準出力に出すだけ）
python -m growth run --workspace ../growth-workspace

# 今の未対応一覧
python -m growth status

# 「これはやらない」と伝える（以後この提案は出てこなくなる）
python -m growth dismiss <fingerprint> -n "この PJT では方針が違うため"

# 自分で対応済みにする
python -m growth done <fingerprint>

# テスト
pytest
```

非公開リポジトリを読むには `GROWTH_TOKEN`（contents:read / issues:write を持つ
Fine-grained PAT）を環境変数か GitHub Secrets に設定する。

## 対象プロジェクトを増やす

`growth/projects.toml` に4行足すだけ。モノレポは `subprojects` にグロブを書けば、
配下の各PJTを自動的に個別の対象として扱う。

```toml
[[project]]
key = "new-project"
repo = "owner/new-project"
title = "説明"
weight = 1.0        # 壊れたときの痛みが大きいものは 1.0 より大きく
```

## 構成

| パス | 役割 |
|---|---|
| `src/growth/survey.py` | 観測。リポジトリを読んでシグナルにする |
| `src/growth/rules.py` | ベースライン診断のルール |
| `src/growth/practices.py` | 横展開する習慣の定義 |
| `src/growth/ledger.py` | 台帳。記憶と学習を担う |
| `src/growth/planner.py` | 論点のマージ・優先度づけ・件数の絞り込み |
| `src/growth/render.py` | ダイジェスト / ダッシュボード / Issue 本文 |
| `src/growth/github.py` | クローンと Issue 起票（標準ライブラリのみ） |
| `growth/projects.toml` | 対象プロジェクトの登録 |
| `growth/ledger.json` | 台帳の実体（自動更新） |
| `GROWTH.md` | 現状ダッシュボード（自動生成） |
| `docs/growth/` | 実行ごとのダイジェスト |
| `docs/growth-system.md` | 設計の考え方 |

設計の背景と、なぜこの形にしたかは [docs/growth-system.md](docs/growth-system.md) に書いてある。
