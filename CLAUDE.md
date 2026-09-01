# workspace — 全PJTを1つの枠組みで動かす開発モノレポ

12 に分かれていたリポジトリを 2026-09-01 に統合した。分かれていた頃の実害
（並行セッションの競合・push されない作業の死蔵・リポジトリ間依存の可視性問題・
CI と Dependabot の増殖）を、この1本で構造的に解消する。

## レイアウト

| 場所 | 中身 |
|---|---|
| `projects/<name>/` | 各PJT。**1PJT = 1ディレクトリで自己完結**（CLAUDE.md・テスト・データ込み） |
| `libs/` | 複数PJTが使う共有コード（例: `libs/kabutan`）。参照は `pip install -e libs/<name>` |
| `platform/ai-lab/` | 基盤（growth 点検ループ / browser / imagegen / adsite / audiogen） |
| `templates/` `scripts/` | PJT雛形・横断スクリプト（wip-sweeper など） |
| `.github/workflows/` | 全ワークフロー。**必ず `paths:` で対象PJTに絞る**（絞らないと全PJTのCIが回る） |

## セッション運用ルール（最重要）

複数の Claude セッションが同時にこのリポジトリで作業する前提のルール:

1. **セッション開始時に、git worktree で自分専用の作業ディレクトリを切る。**
   ```
   git -C C:/Users/なみ/dev/workspace worktree add C:/Users/なみ/dev/wt-<topic> -b claude/<topic> origin/master
   ```
   メインの作業ツリー（dev/workspace 直下）で checkout やブランチ切替を**してはならない**。
   共有ツリーの奪い合いは、他セッションの未コミット作業を別ブランチに乗せる事故になる
   （2026-09-01 に実際に発生した）。worktree なら構造的に起きない。
   master に取り込んだら `git worktree remove` で片付ける。
   master へ直接 push してよいのは「単一の projects/ ディレクトリ内で完結する小さな変更」のみで、
   その場合も worktree 上で行う。
2. **作業の区切りごとに push する。WIP で構わない。**
   ローカルにしか無い作業は、他セッションから見えず事故のもと。
   毎晩22時の wip-sweeper が未pushを `wip/` ブランチへ自動退避するが、それは保険であって代替ではない。
3. **1ブランチで触るのは原則1つの projects/ ディレクトリ。**
   libs/ や platform/ を跨ぐ変更は必ずブランチで行い、コミットメッセージに影響範囲を書く。
4. **他セッションのブランチには触らない。** master への取り込みは fetch → 検証 → merge。
   作業前に必ず `git fetch` して最新の master から始める。

## 収益・運用に関わる注意

- `projects/kabu-agari-ranking/` の取得は**このPCのタスクスケジューラ「kabu-daily-fetch」**
  （平日16:10、run-daily.ps1）が行う。kabutan は GitHub Actions の IP を 405 で
  ブロックするため、CI から取得する形に戻さない。CI は data/ push でビルド・公開、
  17:00 JST に鮮度監視（4日超停止で Issue）。
- 公開サイトは全て **Cloudflare Pages** 配信（kabu-agari-ranking / seisan-kanri-tools）。
  このリポジトリは private のままでよい。Secrets は `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`。
- 共通テストCIは `.github/workflows/python-tests.yml`（workflow_call、同一リポ参照）。
  actions のバージョン更新はこの1ファイルで済む。

## 点検

`platform/ai-lab` の growth ループが projects/* と libs/* を横断点検する（週次）。
手元で回すときは pjt-health スキル参照。

## 環境

- OS: Windows 11 / Shell: PowerShell と Git Bash
- Python は PJT ごとに `.venv`（gitignore 済み）。venv がない PJT はシステム Python。
