---
name: rekishi-daily
description: 歴史の地層（YouTube）の1日分（本編2本＋ショート10本）を、題材決め・担当（Agent）の並べ方・サムネ確認・予約・記録のコミットまで回す段取り。2026-10-31〜11-01 に 11/3〜11/5 分を回して決まった型と、踏んだ穴（サムネの型の取り違え・権限の判定で止まる upload・本編の計算違い・CI の読み替え衝突・ディスク）をまとめたもの。「次の日の分」「11/6 分」「1日分作って」「本編2本とショート」「予約まで進めて」「次！」と言われたときに使う。個々の作り方（調べ・画面・読み）は rekishi-research・rekishi-story-screen・voice-reading-check・rekishi-video。
---

# 歴史の地層：1日分の回し方

作業場所：worktree `C:\Users\なみ\dev\wt-chiso-1014\projects\rekishi-chiso`。CLI は
`PYTHONPATH=. PYTHONIOENCODING=utf-8 PYTHONUTF8=1 python -m chiso.cli …`。

## 0. 1日分の中身（既定）

| 枠 | 中身 |
|---|---|
| 12:00 本編 | if 型（「もしも〜」）。分岐点を並べる型 |
| 19:00 本編 | 通常の物語型。人物だけにせず事件・出来事・制度も（10-30 指示） |
| ショート10本 | **前日の本編2本**から5本ずつ。A 本編：9:00・11:00・13:30・16:30・18:30／B 本編：9:30・12:30・15:30・17:30・19:30（20時まで、10時・14時半は空ける） |

- 確認が要るのは**本編のサムネだけ**（10-28「サムネ以外は確認せずに進めて」）。台本・動画は見せない。自分の点検は省かない
- 題材の案は先に出して、ユーザーの「ok」を取ってから始める。ユーザーが題材を出したら（例：三種の神器）その枠に入れる

## 1. 始める前

1. ブランチ：squash マージ済みのブランチは使い回さない。`git fetch` → `git checkout -B claude/chiso-MMDD origin/master`（worktree で。未コミットの他担当のファイルはそのまま残る）
2. 題材：`posted.json` と `scripts/` を grep して既出でないか確かめる
3. 空き容量：`df -h /c`。`chiso.cli clean` は中間ファイルだけ。足りなければ 7. の片付け

## 2. 担当（Agent）の並べ方

4人を同時に（`run_in_background: true`）：本編×2、ショート×2（前日の本編から）。
各担当への依頼に必ず書くこと：

- 読むもの：CLAUDE.md・docs/story-main.md（ショートは docs/story-shorts.md）・スキル rekishi-research・rekishi-story-screen・voice-reading-check。見本は**直前の日の同じ型**の台本と look
- 組み立ての型（下の 3.）と冒頭10秒の意外な一点
- 決まりの数字：知らない事実1分に2個以上・冒頭3分で7個以上、出どころ「誰が・いつ・何に」1分に1回、記録の食い違い1〜3回、事実カードと `# fact:`
- **年号・年数・割合は自分で計算し直す**（頼朝「800年」→700年あまり、元寇「約8割」→約72%、参勤「47泊48日」・黒船「約43%」は見逃した）
- 点検：check／fact-check、別 Agent 2〜3人の事実照合（前半・後半・流れ）、kana 全行→reading-ok→approve→build、全コマ目視、`ffmpeg -v error -i x.mp4 -f null -` が0行
- ロック：`C:\Users\なみ\AppData\Local\Temp\claude\mainbuild.lock`／`shortbuild.lock`（mkdir/rmdir、他者のは消さない・待つ）。共有ファイル（readings.yaml・tests/test_reading.py・config.yaml・chiso/*.py）は直前に読み直して追記だけ
- 本編は **upload しない**（サムネの OK 待ち）。ショートは screen→upload まで（1本ずつ `--at`。複数まとめると --every で等間隔になる）
- 他セッションのプロセスを止めない（10-31 に srv.py を名前で止めて他人のを巻き込んだ）。nami・0817・本名を公開文面に入れない。YouTube で削除しない
- サムネの決まり：記憶 `rekishi-thumbnail-style-1031.md` を読ませる（下の 4.）

## 3. 話の組み方（10-31 に出した型）

| 型 | 使う題材 |
|---|---|
| 謎解き型（謎→記録の手がかり→説をぶつける→決着／言えること・言えないこと） | 応仁の乱、三種の神器 |
| 分岐点を3つ並べる型（if） | もしも黒船・もしもフランス革命 |
| 現物から遡る型 | 遺物・橋杭・発掘から始まる回 |
| 一夜・一週間の実況型 | 日記・記録で時刻が追える事件 |
| 証言リレー型（同じ場面を3つの記録で） | 食い違いが大きい場面 |
| モノの旅型 | 神器・名刀・茶器・国書 |
| 数字を積み上げる型 | 費用・人数・距離の回（参勤交代） |

if の部分は必ず「もしも」と言ってから、事実と混ぜない。創作の筋・想像の台詞を足さない。

## 4. サムネ（ユーザー確認）

記憶 `rekishi-thumbnail-style-1031.md` が正。要点：全面1枚の迫力ある絵／左右分割は比べる題材だけ／**四角い札を並べない**／文字は白＋赤（＋金の細線）、重い明朝か Black ゴシック、行ごとに大小／if の回は「もしも〜？」を主役に特大（11-01 指摘）／人物はかっこいい AI 絵可（概要欄に「AI による想像図」の一文。台本の description_note に足すと承認が外れるので reading-ok・approve を取り直す）。

- 担当の報告を受けたら、**自分で画像を Read で見てから** SendUserFile（display: render）で出す。気になる点（文字と絵の重なり、数字の断定、時代に合わない物＝1789年の三色旗）は先に言う
- 直しは同じ担当に SendMessage で返す（文脈が残っている）。前の版は `_old`・`_split` などで控えさせる

## 5. 予約（本編）

- ユーザーの OK のあと、担当に `screen` と `upload <台本> --at "YYYY-MM-DD HH:MM"` を**別々のコマンドで**。
- **auto mode の判定が upload を「公開面を作る操作」として止めることがある**（11-01、フランス革命if）。止められた操作を親が代わりに打つのは迂回になるのでしない。ユーザーに「自分で打つ」か「許可」を聞き、ユーザーがチャットで「許可」と言ったら親が実行してよい
- 担当が「親経由の OK はユーザーの許可でない」と自分で止めた場合（判定で止められたのではない）は、ユーザーの OK を受けている親が実行してよい
- 本編の upload は1GB近いので 10 分を超える。`timeout` を長めにして、背景に回ったら完了の通知を待つ
- 確認：出力の「予約しました: URL」と再生リスト。サムネは失敗の警告が出なければ成功（予約中は画像を外から取れない）

## 6. 記録とマージ

1. `git add projects/rekishi-chiso` → コミット（末尾に Co-Authored-By）→ `git push origin HEAD:refs/heads/claude/chiso-MMDD`
2. CI（`gh run watch`）。**よく落ちるのは tests/test_reading.py**：
   - `test_misread_fixed_by_readings[...]`：台本の言い回しが変わって行が無い → MISREADS の断片を今の行に合わせるか、その1件を消す
   - `test_no_collisions_in_scripts`：読み替えが長い語の中に当たる（「3万石」⊂「13万石」、「都へ戻りました」⊂「京都へ戻りました」）→ メッセージのとおり長い語を readings.yaml に足す
   - `test_rules_on_posted_episodes`：読みが直って RULE_HITS の1行が当たらなくなった → その行を外す
3. 緑を自分で確かめてから `gh pr create` → `gh pr merge --squash`。赤いまま入れない

## 7. 片付け（ユーザーが「過去のファイル消して」）

- `chiso.cli clean` は投稿済みの frames・bg だけ（すでに空のことが多い）
- `out/` の大物は投稿済みの mp4・wav（11-01 に126個・14.8GB）。`posted.json` で publish_at が過ぎたものだけを選び、予約中・未投稿は残す
- **完全に消さずにごみ箱へ**（PowerShell `[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p,'OnlyErrorDialogs','SendToRecycleBin')`）。空き容量はごみ箱を空にするまで増えないので、空にするのはユーザーに頼む

## 8. 本編の誤りが公開前に見つかったら

- ショートの担当が本編の計算違いを拾うことが多い。報告をユーザーに出し、「差し替える／そのまま」を聞く（黒船・参勤は「そのままで良い」、頼朝は差し替え）
- 差し替えは：台本を直す→reading-ok・approve・build→ユーザーに Studio で**古い予約を外して非公開**にしてもらう（削除・非公開化を親や担当がしない。API の videos.update も判定で止まる）→ posted.json の旧エントリを控えて外す→ screen→upload
