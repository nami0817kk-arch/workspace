# 台本制作の仕組み（いつ・どこから・何を取るか）

取材は「毎回思い出しながらやる」と抜けが出る。手順を設定ファイルに落として、
**取材メモ → 検証 → 台本** を一本の流れにしてある。

```
config/sources.yaml   いつ・どこから・何を取るか（計画）
        │  plan
        ▼
research/YYYYMMDD.yaml   取材メモ（拾った内容をここに書く）
        │  draft  ← ここで確度の条件を機械的に確認
        ▼
scripts/YYYYMMDD.md      台本
        │  build
        ▼
output/YYYYMMDD/         動画一式
```

## 1. いつ・どこから・何を（config/sources.yaml）

**1日3本**を前提に、時間帯で役割を分けてある。同じ形の動画を3本出すと
飽きられるので、枠ごとに扱うものと尺を変える。

| 枠 | 公開 | 役割 | 尺 |
|---|---|---|---|
| `morning` | 07:00 | 夜のあいだに出た発表と試合結果。速さ優先で深掘りしない | 約1.5分 |
| `noon` | 12:00 | 日本人選手とJリーグに絞る | 約1.5分 |
| `evening` | 19:00 | 1日のまとめと深掘り。図解を入れる枠 | 約3分 |

`morning` が夜の話題なのは時差の都合。欧州の試合と発表は日本の深夜に出るので、
**朝いちばんが一番ネタが溜まっている時間帯**になる。

特別編として `deadline_day`（移籍期限の当日と翌日）も用意してある。

「どこから」は `domains` に定義してある。**ここに無いサイトは検索対象にしない。**
`blocked` は実測でアクセスできなかったサイト（BBC・Guardian・The Athletic など）で、
検索しても結果が返らない。詳細は [情報源](news-sources.md)。

「何を」は各 routine の `steps`。1ステップ＝1つの話題で、それぞれに
**既定の確度**と**検索の型**と**確認事項**が付いている。

## 2. 取材リストを出す

```bash
python -m src.cli plan --routine all          # 今日の3本ぶんまとめて
python -m src.cli plan --routine morning      # 朝の枠だけ
python -m src.cli plan --routine noon --write # 取材メモの雛形も作る
python -m src.cli plan --routine deadline_day --date 2026-09-01
```

日付は自動で埋まる。`confirmed transfers {period_en}` は
`confirmed transfers August 2026` に展開される。

追いたい選手がいるときは `config/sources.yaml` の `topics` に足す。
その選手ぶんの検索が自動で並ぶ。

```yaml
      - id: rumours
        topics: [Julian Alvarez, 佐野海舟]
```

## 3. 取材メモに書く

`research/YYYYMMDD_weekly.yaml` に、拾った内容を1件ずつ書いていく。

```yaml
date: "2026年8月29日"
title: "鈴木彩艶がアストン・ヴィラへ／移籍期限は9月2日朝"
lead: "夏の移籍市場が、まもなく閉まります。"
items:
  - id: suzuki
    tier: 確定
    headline: 鈴木彩艶がアストン・ヴィラへ    # 章タイトルになる
    telop: 鈴木彩艶 パルマ → アストン・ヴィラ  # 画面の見出し
    official: true                            # クラブの発表を確認した
    say:                                      # 読み上げ文。1行=1発話
      - 日本代表ゴールキーパー、すずきざいおん選手が…
      - この移籍にはパリ・サンジェルマンも…
    sources:
      - https://…
      - https://…
    card:                                     # 任意。docs/cards.md 参照
      type: transfer
      player: 鈴木彩艶（GK・日本代表）
      from: パルマ（イタリア）
      to: アストン・ヴィラ（イングランド）
```

読み上げ文は**人名・数字をひらがなに開く**（誤読を防ぐ）。画面には `telop` の
漢字表記が出るので、見た目は変わらない。

## 4. 同じ話題を繰り返さない

1日3本を続けると「朝に出した話を夜にもう一度出す」が必ず起きる。
台本を作るたびに `research/covered.yaml` に記録され、次に作るとき突き合わせる。

`plan` には直近で扱った話題が出る。

```
　直近で扱った話題（繰り返さない）:
　　08/29 07:12 [morning] 鈴木彩艶がアストン・ヴィラへ
　　08/29 12:05 [noon] 佐野海舟の去就
```

`draft` は重なっていると止まる。

```
重複しています:
  - suzuki: 08/29 07:12 の［morning］で扱った話題です（鈴木彩艶が…）。
    深掘りとして出すなら follow_up: true を書いてください
```

**意図的に深掘りする場合**は取材メモに `follow_up: true` を書く。
夜の枠で朝の速報をまとめ直すのは普通の運用なので、そのための逃げ道。

判定の幅は `coverage.repeat_within_hours`（既定36時間）で変えられる。

## 5. 検証してから台本にする

```bash
python -m src.cli draft research/20260829_weekly.yaml
python -m src.cli draft research/20260829_weekly.yaml --check-only   # 検証だけ
```

**確度の条件を満たしていないと台本を作らない。** 条件は `config/sources.yaml`
の `tiers` にある。

| 確度 | 条件 |
|---|---|
| `確定` | 出典1本以上 **かつ** `official: true`（クラブ・当事者の発表） |
| `報道` | 出典**2本以上**（2社で一致していること） |
| `未確認` | 出典1本以上 |

止まる例:

```
取材メモに不備があります:
  - a: 確度『報道』には出典が2本必要です（いまは1本）
  - b: 確度『確定』はクラブ・当事者の発表が条件です。
       発表を確認できないなら tier を下げてください
```

これは「急いでいるときほど確度を上げたくなる」のを機械側で止めるためのもの。
条件を緩めたいときは設定を変えることになるので、**判断が記録に残る**。

生成される台本には、章立て・確度バッジ・出典・まとめカードが入った状態になる。
あとは言い回しを整えて `build` すればよい。

## 6. 出来上がりまで

```bash
python -m src.cli check scripts/20260829.md   # 書式と想定尺
python -m src.cli build scripts/20260829.md   # 動画一式
```

公開前の確認は [毎週の作り方](weekly.md) のチェックリストを使う。

## 計画を育てる

やってみて分かったことは `config/sources.yaml` に戻す。

- 使えた検索の型 → `queries` に足す
- 引っかかった落とし穴 → `check` に書く（取材リストに毎回出る）
- 追う選手が変わった → `topics` を入れ替える

この3つを回していくと、回を重ねるほど取材が速く・正確になる。
