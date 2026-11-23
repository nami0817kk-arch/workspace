# バスケGM：球団を勝たせろ — ストア掲載文(2026-11-23 書き直し)

公開名義は「つるはし社」。本名・nami・0817 は入れない(`docs/public-identity.md`)。
**まだ提出していない。** 文面はユーザーが見てから App Store Connect に入れる。

## 注意(先に読む)

- **App Store Connect は一部の記号を「無効な文字」として弾く**(護送ボートの提出で確認済み)。★ ■ … ―― • — を使わない。
  見出しは【】、箇条書きは「・」にする。markdown の `*` を貼らない。
- **リーグ名・チーム名・選手名は架空。** NBA に寄せているのは都市・地区・色・試合の仕組みまで。
  NBA・実在のチームの愛称・選手の名前を、掲載文・画像・キーワードに入れない(商標、審査 5.2)。「NBA」もキーワードに入れない。
- 「Basketball GM」は既存のゲームの名前なので使わない。英語の名前は「Basuke GM」(2026-11-23 ユーザー決定。公開ページも同じ)。
- 野球育成・サカマネ(同じ名義)と名前・説明・画像の作りが似ないようにする(審査 4.3)。「育成」「選手物語」「一代記」「クラブ経営」は使わない。
- 画面は日本語のみ(英語対応はまだ)。
- 課金は「広告を消す」(370円・買い切り)だけ(2026-11-23 ユーザー決定)。

## 名前・サブタイトル・キーワード

| 項目 | 日本語 |
|---|---|
| 名前(30字まで) | バスケGM：球団を勝たせろ(13字) |
| サブタイトル(30字まで) | トレードとドラフトで、優勝チームを作れ(19字) |
| キーワード(100バイトまで) | バスケットボール,ゼネラルマネージャー,シミュレーション,プレーオフ(96バイト) |

- ホーム画面の表示名は「バスケGM」(`ios/Runner/Info.plist`)。
- 名前とサブタイトルの語(バスケ・GM・トレード・ドラフト・優勝)は検索に効くので、キーワードには重ねない。日本語は1字3バイト。

## カテゴリ・年齢

ゲーム ＞ スポーツ(主)、ゲーム ＞ シミュレーション(副)。年齢区分は 4+(暴力・賭け事・成人向けの表現なし。広告は全年齢向けに限る設定)。

## プロモーションテキスト(170字まで・審査なしで差し替えられる)

あなたは球団のGM。試合は選手にまかせて、勝てるチームを作るのが仕事。相手の考えを読んだトレード、指名するまで本当の力が分からないドラフト、年俸の上限とのにらみ合い。オーナーの信頼を失えば解任。何回優勝できるか。

## 説明文

あなたは、バスケットボールの球団のGM(ゼネラルマネージャー)。
試合は選手とコーチにまかせる。あなたの仕事は、選手を集めて、勝てるチームを作ること。

【東西30チームのリーグ】
東西の地区に分かれた30チームで、レギュラーシーズンは82試合。地区の上位はプレーオフへ、その下はプレーインで残りの枠を争う。どの回戦も4勝で勝ち抜け、ファイナルを制すれば優勝。シーズンの途中にはカップ戦とオールスターもある。

【トレードは、相手の考えを読む】
優勝を狙うチームは今すぐ勝てる選手を、立て直し中のチームは若手とドラフトの指名権を欲しがる。相手のGMの性格と欲しい型を見て、何を出して何を受け取るかを組み立てる。申し込む前に「相手に聞く」で反応が見える。相手から申し込みが届くこともある。

【ドラフトは、指名するまで分からない】
候補の力は幅でしか見えない。スカウトを送り、ワークアウトに呼ぶと幅が狭まる。プレーオフに出なかったチームは、くじで上位の指名を引ける。

【年俸の上限と、オフの駆け引き】
年俸の合計には上限があり、ぜいたく税の線を超えるとオーナーが渋い顔をする。契約が切れる主力を残すか、放すか。自由契約の大物には、他のチームと競って申し込む。

【オーナーと記者と、選手の気持ち】
シーズンの初めにオーナーと目標を話し合う。記者の質問や選手との約束は、守れば言葉に重みが出て、破れば信頼を失う。信頼がなくなれば解任。出番が減った選手の気持ちにも気を配る。

【チームの中も、経営も】
先発と控えの順、出場時間、チームの方針を決める。コーチを雇い、練習施設・医療・アリーナに投資する。入場料と売店で収支を合わせる。けがで主力が抜けることもある。

【任せてもらうチームを選ぶ】
30チームから選べる。優勝候補を引き継ぐか、どん底から立て直すか。難しさは3段階。

・東西30チーム、82試合、プレーインとプレーオフ、カップ戦、オールスター
・トレード(相手に聞く・指名権・保護付きの指名権)、ドラフト(くじ・スカウト・ワークアウト)、契約の延長、自由契約、ぜいたく税
・OVR と伸びしろ、細かい能力、選手の型と特性、選手ごとの顔
・受信箱(オーナー・選手・代理人・記者・スタッフから)、約束、MVP争い、各賞、リーグの歴史
・コーチ、施設、入場料と収支、GMの格と技能
・リーグ、チーム、選手の名前はすべて架空です
・オフラインで遊べます(広告と購入の確認には通信が必要)
・広告つき。「広告を消す」(買い切り)で、全画面広告が出なくなり、スカウトの追加とオーナーの説得も動画なしで使えます

## スクリーンショット(iPhone 1206x2622・iPad 13インチ 2064x2752 の2組、各8枚。最初の3枚が検索結果に出る)

`tool/screenshots/capture_test.dart` が作る(iPhone は `flutter test tool/screenshots/capture_test.dart`、iPad は `DEVICE=ipad` を付ける)。出力は `marketing/screenshots/iphone/` と `ipad/`。

**撮るときの決まり**(`docs/app-pitfalls.md` #4・Apple 2.3.2・2.3.7):
- 読み込み中の画面を撮らない(生成器が検査する)。タイトル画面は撮らない。値段(¥370)を写さない。実在の名称を入れない。

## 審査メモ(App Review Information、英文で入れる)

```
This is a single-player basketball general manager simulation. No account, login or server. Progress is saved only on the device.
Games are simulated automatically; the player manages the roster through trades, the draft, contracts and free agency under a salary cap.
All leagues, teams and players are fictional. Real city names are used only as locations; no real team names, logos or players are used.
Ads are served by Google AdMob (limited to content suitable for all ages, no tracking permission requested).
The only in-app purchase is "Remove Ads" (non-consumable, basketball_career_remove_ads). It is in Settings: on the title screen, tap "設定" (gear icon); during a game, tap "タイトル" at the bottom of the left menu first. "Restore purchases" is in the same box.
Full-screen ads appear when continuing after every 30 games (never in the first season) and when a new season starts.
Rewarded videos are optional: extra scouting during each draft, and persuading the owner once per career after being fired.
No gambling, cash prizes or random paid items.
Before release, production ads may not be delivered yet; if a video shows "not ready", the app is working as designed. The purchase can be tested in the Sandbox.
```

## アプリのプライバシー

Google の公式の開示に合わせた6項目で答える(2026-11-06 ユーザー決定): おおよその位置情報・デバイスID・広告データ・その他の使用状況データ・クラッシュデータ・パフォーマンスデータ。
目的はサードパーティ広告とアナリティクス(クラッシュはアナリティクスだけ)、ユーザーに関連付けない、トラッキングに使わない。

## 配信する国

アプリ本体(無料)と課金アイテムの両方を147か国(EU 27か国と中国本土を除く)に設定済み(2026-11-23、ユーザー「他のアプリと同じ」)。アプリと課金アイテムは同じ国にそろえる。

## App Store Connect に入れたもの(2026-11-23)

- アプリ情報: サブタイトル・カテゴリ(ゲーム＞スポーツ・シミュレーション)。
- 1.0 のページ: プロモーションテキスト・説明文・キーワード・サポート URL・マーケティング URL・著作権・審査メモ(サインイン不要)。
- まだ: コンテンツ配信権(ユーザーが答える)・審査の連絡先・掲載画像(横画面で作り直す)・ビルド。年齢区分とアプリのプライバシーはこの日は確かめていない。
