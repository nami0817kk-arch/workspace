---
name: kabu-daily
description: 値上がり株ランキング（kabu-agari-ranking、kabu.dailyquarry.com）の日次確認。当日分のデータが取れて、公開サイトが直近営業日に更新されているかを確かめる。「株の日次」「ランキング更新された?」「kabu のサイト大丈夫?」のときに使う。
---

# 値上がり株ランキング 日次確認

`projects/kabu-agari-ranking`（公開サイト https://kabu.dailyquarry.com/ ）が、
**今日も止まらずに更新されているか**を確かめて報告する。

> 2026-09-26 に、値上がり銘柄を記録して手法を検証する道具（quality-gainer-tracker）を
> **廃止した**（8/28 から使われていなかった。検証の最終成績は 14日後の平均 −4.9%）。
> このスキルから記録・答え合わせ・買い候補の手順は外した。再提案しない。

## 前提

モノレポ `C:\Users\なみ\dev\workspace` の中で作業する。読むだけなら直接見てよい。
**変更を伴うなら必ず worktree を切る**（メインツリーでの checkout は禁止・規約1）。

```bash
git -C C:/Users/なみ/dev/workspace worktree add C:/Users/なみ/dev/wt-<topic> -b claude/<topic> origin/master
```

疑問が出たら、まず `docs/session-faq.md` を読む。載っていなければ自分で判断し、
判断できないものはユーザーに直接聞く（調整役は 2026-09-07 に廃止）。

## 仕組み

**取得は CI ではなく、このPCのタスクスケジューラが行う。**
kabutan が GitHub Actions の IP を 405 でブロックするため、CI から取得する形には戻さない。

| 役割 | 実体 |
|---|---|
| 取得 | タスクスケジューラ **`kabu-daily-fetch`**（平日16:10、`projects/kabu-agari-ranking/run-daily.ps1`）→ `data/` を push |
| ビルド・公開 | Actions `kabu-daily.yml` が data/ の push で発火 → Cloudflare Pages |
| 監視 | 同ワークフローが平日17:00 JST に実行。1営業日の欠測で Issue が立つ（休場日は数えない） |

## 確認の順番

```bash
# 手元のデータが今日（直近営業日）まで来ているか
cd "C:/Users/なみ/dev/workspace" && git fetch -q origin && git ls-tree --name-only origin/master projects/kabu-agari-ranking/data/ | tail -3

# 取得タスクが動いているか
powershell -Command "Get-ScheduledTaskInfo -TaskName kabu-daily-fetch | Format-List LastRunTime,LastTaskResult,NextRunTime"

# ビルド・公開側
cd "C:/Users/なみ/dev/workspace" && gh run list --workflow kabu-daily.yml --limit 5
```

公開サイト https://kabu.dailyquarry.com/ は WebFetch で取得し、
**200 が返ることではなく、出ている日付が直近営業日か**を見る。
16:10 より前に見た場合は、前営業日の分が出ていれば正常。

取り逃した営業日は二度と取れない（kabutan は当日分しか出さない）。16:10 の取得が失敗していたら、
**その日のうちに** `projects/kabu-agari-ranking` で `src/build_site.py` を手で回す（プロジェクトの CLAUDE.md 参照）。

## 報告の書き方

1. **データ** — 直近営業日の分があるか。無ければ最初にそれを書く（収益サイトなので）
2. **取得タスク** — 最後の実行時刻と結果
3. **公開** — サイトに出ている日付と、Actions の最新の結果

## やらないこと

- 「上がりそう」「買い時」といった予測や売買の判断を書かない
- `output/` を commit しない（CI が再生成する）。`data/` は資産なので commit する
- 他セッションの `claude/*` ブランチには触らない
