---
name: rekishi-video
description: 歴史の聞き流し動画（YouTube チャンネル「歴史の地層｜日本史・世界史を聞き流し」）を、題材決め・台本・読みの点検・確認用の動画・本番・ショート・サムネイル・概要欄まで作る手順。「歴史の動画作って」「次の回」「西太后の回」「台本書いて」「確認用作って」「本番作って」「サムネ作って」と言われたときに使う。台本確認の関門（approve）を飛ばさないための手順書でもある。
---

# 歴史の地層の動画をつくる

チャンネル: [@rekishi-no-chiso](https://www.youtube.com/@rekishi-no-chiso)（運営：つるはし社）
コード: `C:/Users/なみ/dev/workspace/projects/rekishi-chiso`（**worktree を切ってから触る**）
素材（立ち絵・表情・絵画・地図）: `C:/Users/なみ/dev/output/rekishi-chiso/assets`（リポジトリに入れない）

**決まり（なぜ）は `projects/rekishi-chiso/CLAUDE.md` の「1. 決まり」。** 台本の書き方は `scripts/_template.yaml`（ひな形）と
`scripts/_showcase.yaml`（全部の道具を使った見本）。ここは**手順と関門**だけ。コマンドは `python -m chiso.cli <名前>`。

## 手順（この順に。2026-10-08 に道具を使う順へ並べ直した）

```
下調べ → 台本 → kana → check → draft → qc → 自分の確認3回 → approve → build → qc → shorts → thumb --variants
→ describe --keywords → 見せる → screen → upload
```

1. **下調べ**：題材カレンダー（CLAUDE.md）の次の人物・出来事。いちばんの見どころ（名場面・数字・謎）を1つ決める（冒頭とサムネになる）。
   `keywords "織田信長"` で検索候補によく続く語・題名3・タグ15の下書き（out/keywords_<名前>.md）。
   事実は資料で確かめて research/<題材>_facts.md に出典ごと控える。絵は Commons のパブリックドメインだけ（撮影者の CC 付きは使わない）。
   取ったら**1枚ずつ目で見る**（別人の絵が混じる）。地名は places.yaml、用語は terms.yaml に足す
2. **台本**：`scripts/_template.yaml` を写して上から埋める（texture・recap・サムネの layout・ショートの hook が正しい既定で入る）。
   題名は名前を先頭に。最後の節は「まとめ：〇〇とは何者だったのか」。図は3つ以上。同じ背景は40秒まで・20秒に1回は新しいもの。
   絵の割り当ての下書きは `assign scripts/x.yaml --assets research/x_assets.md`（out/x_assign.md。台本は書き換えない。見て採るものだけ写す）
3. **kana**：`kana scripts/x.yaml` で全行の読みを見る。読み違いは readings.yaml に足す
4. **check**：`check scripts/x.yaml`。止める（×）→ 直すと効く（!）→ 参考（・）の順に、同じ種類は1件にまとめて行の番号が並ぶ。
   × は全部直す。! の「冒頭15秒に数字がない」「ショートの1行目」「同じ背景が40秒」「剣崎70%」「道具の重なり」「サムネの文字の置き場」は直す。
   ・（文体・章の題）は読んで直すか決める。目安の数字は chiso/check.py の頭
   「話と画面：」（行で話す年・場所・出来事と、映っている絵・札・図が違う。10-08 ユーザー指摘）は0件にする。絵を替えるか detail で寄せるか、節を分ける
5. **draft**：まず `draft scripts/x.yaml --lines 40`（冒頭だけ）で見た目を見て、次に全体の `draft`。最後に「かかった時間：音声・前景・背景・重ね」が出る
6. **qc**：`qc scripts/x.yaml --video out/x_draft.mp4`。`out/x_qc.png`（20秒ごと・節ごとの段）を**画像を開いて目で見る**（重なり・はみ出し・ちらつき＝1行だけ消えてまた出る）。
   `out/x_qc.md` の「画面が大きく変わらない区間」で40秒超えがあれば、絵を足すか detail・mark・札・図で直す。音の大きさ・長い無音も見る
   **行ごとに、話していることと映っているものが合っているか**も見る（draft の最後に「話と画面」の知らせがもう一度並ぶ。知らせの無い行も目で見る）
7. **自分の確認3回**（台本のユーザー確認は不要。10-05）：事実（前半・後半を資料で）・流れとキャラ（初めて聞く人の耳で）・読み（kana）を Agent で並べて確認 →
   直す → 直した所の確認 → 最後の通し確認で「公開してよい水準」が出るまで回す。記録は dev/output/rekishi-chiso/review/<題材>/
8. **approve**：`approve scripts/x.yaml`（台本のハッシュを控える。台本を変えたら打ち直し）
9. **build**：`build scripts/x.yaml`。終わったら本番の `out/x.mp4` にも **qc** を掛けて一覧を見る
10. **shorts**：`shorts scripts/x.yaml`（`--only s1` で1本、`--draft` で確認用）。頭の約2秒に問いを特大、最後は頭と同じ画でループ。1本60秒以内
11. **thumb --variants**：構図は題材で選ぶ（face／scene／versus／number／map。3回続けない）。引きの要素（reactor・hide・contrast・flip・flash）は1つか2つ、
    **台本で答えが出ることだけ**。和服・文字・紋の入った絵は反転しない。`thumb scripts/x.yaml --variants` で3案と一覧の大きさの確認用を作り、読めるか見る
    （YouTube Studio の「テストと比較」に3枚載せる。API では載せられない）
12. **describe --keywords**：`describe scripts/x.yaml --keywords`（概要欄。章・クレジット・絵の出典・次回・「この動画で扱うこと：」）
13. **見せる**：本番の動画・サムネ3案・ショートをユーザーに見せる（「見せて」は承認ではない）
14. **screen**：ユーザーが本番を見て OK と言ったときだけ `screen scripts/x.yaml`（ショートは `screen-shorts`）
15. **upload**：`upload scripts/x.yaml --at "YYYY-MM-DD 19:00"`、ショートは翌日 `upload-shorts --start "YYYY-MM-DD 11:00"`（11〜21時、15時は空ける）。
    台本の playlists・shorts_playlists・en があれば、投稿のあとに再生リストへ入れ英語の題名を付ける（投稿済みは `playlists --sync`・`localize`）。
    許可が足りない・失効したらコマンドは止まり、**`reauth` はユーザーが打つ**

## つまずき所

- 「作り直しは後で」「待って」と言われたら、走っている処理を**すぐ止める**（TaskStop と、残った python・ffmpeg）
- 大きい動画（200MB 超）はスマホに届かない。ユーザーは**スマホ版は要らない**と言っている
- 道具の重なり：detail を書いた行で図は終わる／図の出ている行の挿絵・寄りの行の吹き出しは出ない（check が知らせる）
- 描き方・config を変えたら前景のコマは全部描き直しになる（描き方の指紋）。背景は `work/<台本>/bg` に絵ごとの1枚で控える
- 空きメモリが少ないと ffmpeg が落ちる（config の bg_workers は5。10で落ちた）。VOICEVOX は6GBを超えると音声のあとに立ち上げ直す
- Commons の API は回数制限がある。curl で間隔をあけて取る（Python の通信は証明書で落ちる）
