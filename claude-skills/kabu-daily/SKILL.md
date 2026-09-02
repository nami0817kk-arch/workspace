---
name: kabu-daily
description: 日本株の日次ルーチン。quality-gainer-tracker で値上がり質ランキングを記録・追跡価格を更新し、2週間パフォーマンスと A/B/C 手法の買い候補を出したうえで、kabu-agari-ranking の公開サイトが当日分に更新されているかまで確認する。「株の日次」「今日の値上がり」「買い候補を出して」「ランキング更新された?」「トラッカー回して」のときに使う。
---

# 日本株 日次ルーチン

`projects/quality-gainer-tracker`（記録・分析）と `projects/kabu-agari-ranking`（公開サイト）を
まとめて見て、**今日見るべき銘柄と、収益サイトが壊れていないか**を報告する。

## 前提

モノレポ `C:\Users\なみ\dev\workspace` の中で作業する。読むだけなら直接見てよい。
**変更を伴うなら必ず worktree を切る**（メインツリーでの checkout は禁止・規約1）。

```bash
git -C C:/Users/なみ/dev/workspace worktree add C:/Users/なみ/dev/wt-<topic> -b claude/<topic> origin/master
```

疑問が出たら、ユーザーに聞く前に `docs/session-faq.md` → `docs/coordinator.txt` の
調整役セッションへ SendMessage（規約5）。

| 対象 | パス | Python |
|---|---|---|
| quality-gainer-tracker | `workspace/projects/quality-gainer-tracker` | システムの `python`（venv 無し） |
| kabu-agari-ranking | `workspace/projects/kabu-agari-ranking` | `.venv\Scripts\python.exe` |

データは quality-gainer-tracker の SQLite に貯まる。**これが資産**なので、取得に失敗した日も
後から `backfill` で埋める。土日祝は `rank` が空を返すが異常ではない。

## 手順

### 1〜3. 記録・更新・分析

```bash
cd "C:/Users/なみ/dev/workspace/projects/quality-gainer-tracker" && python main.py rank --top 20
cd "C:/Users/なみ/dev/workspace/projects/quality-gainer-tracker" && python main.py update
cd "C:/Users/なみ/dev/workspace/projects/quality-gainer-tracker" && python main.py report
cd "C:/Users/なみ/dev/workspace/projects/quality-gainer-tracker" && python main.py detect
```

- `rank` は平日 15:30 JST（大引け）以降でないと当日値が確定しない。それ以前なら
  「ザラ場中の暫定値」と明示する。0件なら休場日か kabutan の構造変更を疑う。
- `update` は **`rank` の直後に必ず回す**。飛ばすと `report` の集計が古いままになる。
- `report` = 記録済み銘柄の2週間パフォーマンス。**手法の答え合わせ**。
- `detect` = A/B/C 手法の候補。絞るなら `--rsi 20`。

### 4. 公開サイトの確認

**取得は CI ではなく、このPCのタスクスケジューラが行う。**
kabutan が GitHub Actions の IP を 405 でブロックするため、CI から取得する形には戻さない。

| 役割 | 実体 |
|---|---|
| 取得 | タスクスケジューラ **`kabu-daily-fetch`**（平日16:10、`projects/kabu-agari-ranking/run-daily.ps1`）→ `data/` を push |
| ビルド・公開 | Actions `kabu-daily.yml` が data/ の push で発火 → Cloudflare Pages `kabu-agari-ranking` |
| 監視 | 同ワークフローが平日17:00 JST に実行。**最新データが4日超古いと失敗し Issue が立つ** |

確認はこの順で速い。

```bash
# 手元のデータが今日（直近営業日）まで来ているか
cd "C:/Users/なみ/dev/workspace" && ls -t projects/kabu-agari-ranking/data/*.json | head -3

# 取得タスクが動いているか
powershell -Command "Get-ScheduledTaskInfo -TaskName kabu-daily-fetch | Format-List LastRunTime,LastTaskResult,NextRunTime"

# ビルド・公開側
cd "C:/Users/なみ/dev/workspace" && gh run list --workflow kabu-daily.yml --limit 5
```

公開サイト https://kabu-agari-ranking.pages.dev/ は WebFetch で取得し、
**200 が返ることではなく、出ている日付が直近営業日か**を見る。

> Cloudflare の Secrets は登録済みで、デプロイまで通る（2026-09-02 解消。
> kabu-agari-ranking / seisan-kanri-tools / soccer-manager の3サイトとも公開中）。
> デプロイ段が failure になったら、今は本物の異常として報告する。

## 報告の書き方

1. **今日の記録** — 何件記録したか。休場・失敗ならその旨。
2. **答え合わせ** — `report` が前回からどう動いたか。手法が効いているか。
3. **候補** — `detect` の銘柄。**必ず「これは投資助言ではない」と添える**。
   買い/売りの判断は書かず、検出条件に当たった事実だけを書く。

データ取得が止まっていた場合は、1〜3 より先にそれを書く。収益に直結するため。

## やらないこと

- `query` は SELECT のデバッグ専用。DB を書き換える SQL は流さない。
- 「上がりそう」「買い時」といった予測の断定はしない。
- `output/` を commit しない（CI が再生成する）。`data/` は資産なので commit する。
- 他セッションの `claude/*` ブランチには触らない。
