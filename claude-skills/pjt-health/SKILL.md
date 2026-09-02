---
name: pjt-health
description: ai-lab の growth ループで全プロジェクトを点検し、成熟度・未対応の提案・判断待ちの項目を出して、次にやることを1つに絞る。「全プロジェクトの状況」「次に何をやるべき」「棚卸し」「点検して」「GROWTH.md 更新」のときに使う。snooze / dismiss での提案の片付けもここ。
---

# プロジェクト点検（growth ループ）

`workspace/platform/ai-lab` の `growth` パッケージが全リポジトリを横断点検する。
**このスキルは点検を回して、出てきた提案を1つに絞る**。

## 前提

```bash
cd "C:/Users/なみ/dev/workspace" && PYTHONPATH=platform/ai-lab/src python -m growth status
```

- **システムの `python` で動く。** growth は標準ライブラリだけで書かれていて、
  `platform/ai-lab` に venv は無い。
- **`PYTHONPATH=platform/ai-lab/src` が必須**（src レイアウトのため）。
- 台帳 `platform/ai-lab/growth/ledger.json`、対象定義 `growth/projects.toml`（11リポジトリ）
- 出力 `GROWTH.md`（**自動生成。手で編集しない**）
- 週次 Actions `growth-loop` が毎週月曜 09:13 JST に実行し、master 上で自動更新する。
  手元で回すのは週の途中で状況を知りたいときか、提案を片付けるとき。

## 手順

### 1. 現状を見る（通信しない・速い）

```bash
cd "C:/Users/なみ/dev/workspace" && PYTHONPATH=platform/ai-lab/src python -m growth status
```

### 2. 点検し直す

**`fetch` と `run` は `--workspace <dir>` が必須引数。** 各リポジトリのクローンを置く場所で、
既定値は無い。scratchpad に作ればよい。

```bash
WS="C:/Users/なみ/AppData/Local/Temp/claude/growth-workspace"
cd "C:/Users/なみ/dev/workspace" && PYTHONPATH=platform/ai-lab/src python -m growth fetch --workspace "$WS"
cd "C:/Users/なみ/dev/workspace" && PYTHONPATH=platform/ai-lab/src python -m growth run   --workspace "$WS"
```

`fetch` は通信する。直近で回っているなら `run` だけでよい。

### 3. 提案を片付ける

| 状態 | やること |
|---|---|
| 対応した | **何もしない。** 次回の `run` が自動検出するので手動 `done` は不要 |
| 今はやらない | `growth snooze <ID>` — **理由が必須**。保留欄に理由ごと残る |
| もう出さない | `growth dismiss <ID>` — 恒久的に対象外にするとき |

理由なしの `dismiss` は情報が消えるので避ける。

### 提案の具体箇所が要るとき

ledger には提案の詳細（幽霊ファイルの具体パス等）が保存されない。
`platform/ai-lab/src/growth/signals.py` の `_MD_PATH_RE` / `_MD_LINK_RE` を
手元で再実行すると具体箇所を出せる。

## 報告の書き方

`GROWTH.md` をそのまま貼らない。次の3つに圧縮する。

1. **前回から動いたもの** — 成熟度が上下したものだけ。±0 は書かない。
2. **判断が要るもの** — ユーザーにしか決められない項目（方針・公開可否・ライセンス）。
3. **次の1手** — **1つだけ**選んで理由つきで薦める。
   基準は「収益に近い」>「壊れている」>「成熟度が低い」。

未対応が0件なら1行で伝えて終わる。無理に探さない。

## やらないこと

- `GROWTH.md` を手で編集しない（次回 `run` で上書きされる）。
- `ledger.json` を直接書き換えない。
- 提案を全部消化しようとしない。1回に1つで十分。
