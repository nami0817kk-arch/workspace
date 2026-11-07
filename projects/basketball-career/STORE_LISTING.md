# バスケ編成室 / Hoops Front Office — ストア掲載文の下書き(iOS のみ・日本だけ)

2026-11-06 に2度作り変えた(育成 → カードで戦う → GM)。今は、GM としてトレード・ドラフト・契約でチームを作るゲーム。
公開名義は「つるはし社」。本名・nami・0817 は入れない(`docs/public-identity.md`)。
**まだ提出していない。** 文面はユーザーが見て直してから App Store Connect に入れる。

## 注意(先に読む)

- **App Store Connect は一部の記号を「無効な文字」として弾く**(護送ボートの提出で確認済み)。★ ■ … ―― • — を使わない。
  見出しは【】、箇条書きは「・」にする。markdown の `*` を貼らない。
- **リーグ名・チーム名・選手名は架空。** NBA に寄せているのは都市・地区・色・試合の仕組みまで。
  NBA・実在のチームの愛称・選手の名前を、掲載文・画像・キーワードに入れない(商標、審査 5.2)。「NBA」もキーワードに入れない。
- 名前の候補は iTunes Search API で調べた(2026-11-06)。「バスケ編成室」は見当たらなかった。「バスケGM」は同じ名前のアプリが複数あり、「Basketball GM」は既存のゲームなので避けた。
- 野球育成・サカマネ(同じ名義)と名前・説明・画像の作りが似ないようにする(審査 4.3)。「育成」「選手物語」「一代記」「クラブ経営」は使わない。
- 画面は日本語のみ。**配信は日本だけ**(2026-11-06 ユーザー決定)。英語の掲載情報は付けない。

## 名前・サブタイトル・キーワード

| 項目 | 日本語 | English (US) |
|---|---|---|
| 名前(30字まで) | バスケ編成室：GMになってトレードとドラフト(21字) | Hoops Front Office（18字） |
| サブタイトル(30字まで) | 30チームのリーグで、優勝チームを作れ(18字) | Build a champion as the GM（26字） |
| キーワード(100字まで) | バスケットボール,ゼネラルマネージャー,マネジメント,シミュレーション,年俸,サラリーキャップ,プレーオフ,スポーツ,オフライン,一人用 | basketball,general manager,simulation,draft,trade,offline |

- ホーム画面の表示名は「バスケ編成室」(`ios/Runner/ja.lproj/InfoPlist.strings`)。
- 英語の列は表の形を保つためだけに置いている(英語の掲載情報は出さない)。

## カテゴリ・年齢

ゲーム ＞ スポーツ(主)、ゲーム ＞ シミュレーション(副)。年齢区分は 4+(暴力・賭け事・成人向けの表現なし。広告は全年齢向けに限る設定)。

## プロモーションテキスト(170字まで・審査なしで差し替えられる)

あなたはGM。試合は選手にまかせて、勝てるチームを作るのが仕事。相手の考えを読んだトレード、指名するまで本当の力が分からないドラフト、年俸の上限とのにらみ合い。10年の任期で、何回優勝できるか。

## 説明文(日本語)

あなたは、バスケットボールのチームのGM(ゼネラルマネージャー)。
試合に口は出せない。できるのは、選手を集めて、勝てるチームを作ることだけ。

【東西30チーム・82試合】
東西の地区に分かれた30チームのリーグで、レギュラーシーズンは82試合。地区の上位6チームはプレーオフへ、7位から10位はプレーインで残りの2枠を争う。どの回戦も4勝で勝ち抜け、ファイナルを制すれば優勝。

【トレードは、相手の考えを読む】
優勝を狙うチームは今すぐ勝てる選手を、立て直し中のチームは若手とドラフトの指名権を欲しがる。何を出して何を受け取るか、相手の反応は申し込む前に見える。シーズン中のトレードは41試合目まで。相手から申し込みが届くこともある。

【ドラフトは、指名するまで分からない】
候補の力は幅でしか見えない。スカウトを送ると幅が狭まる。プレーオフに出なかったチームは、くじで上位の指名を引ける。

【年俸の上限とのやりくり】
年俸の合計には上限がある。自分の選手との再契約は上限を超えてもできるが、ぜいたく税の線を超えるとオーナーの信頼が下がる。主力の契約が切れる年に、残すか、放すか。

【チームの中も、経営も】
先発と控えの順を決め、出番が減った選手の気持ちにも気を配る。入場料を決めて収支を合わせ、スタッフ(コーチ・トレーナー・スカウト)を雇う。けがで主力が抜けることもある。

【10年の任期】
任せてもらうチームは30チームから選べる。優勝候補を引き継ぐか、どん底から立て直すか。シーズンの初めにオーナーが勝ち数の目標を決め、届かない年が続けば解任。

・東西30チーム、82試合、プレーインとプレーオフ
・トレード(相手に聞く・3年先までの指名権・保護付きの指名権)、ドラフト(2巡・くじ)、契約の交渉と延長、自由契約、ぜいたく税
・OVR と POT、細かい能力24項目、身長・体重・ウイングスパン
・受信箱(オーナー・選手・代理人から)、MVP争い、オールスター、選手の型と特性のバッジ、ボックススコア
・個人成績、MVP・新人王・最優秀守備選手、けが、スタッフ、入場料と収支
・リーグ、チーム、選手の名前はすべて架空です
・オフラインで遊べます(広告と購入の確認には通信が必要)
・広告つき。「広告を消す」(買い切り)で、全画面広告が出なくなり、スカウトの追加とオーナーの説得も動画なしで使えます

## スクリーンショット(iPhone 1206x2622・iPad 13インチ 2064x2752 の2組、各8枚。最初の3枚が検索結果に出る)

`tool/screenshots/capture_test.dart` が作る(iPhone は `flutter test tool/screenshots/capture_test.dart`、iPad は `DEVICE=ipad` を付ける)。出力は `marketing/screenshots/iphone/` と `ipad/`。

1. 「相手の考えを読んで、トレードを組む」 … トレードの画面(若手と指名権で主力を取りに行く・「受けてくれそう」)
2. 「指名するまで、本当の力は分からない」 … ドラフト(全体1位の番・調査済みの候補)
3. 「伸びる若手と、年俸のやりくり」 … チームの画面(年俸の帯・伸びしろ)
4. 「82試合を進めて、プレーオフへ」 … シーズン中(41試合を終えて・試合の結果)
5. 「相手から届く、トレードの申し込み」 … 届いた申し込み
6. 「契約の切れた主力を、残すか放すか」 … オフの契約
7. 「めざせ、ファイナル制覇」 … 優勝の画面
8. 「東西30チームのリーグで、GMになる」 … 地区の順位

**撮るときの決まり**(`docs/app-pitfalls.md` #4・Apple 2.3.2・2.3.7):
- 読み込み中の画面を撮らない(生成器が検査する)。タイトル画面は撮らない。値段(¥370)を写さない。実在の名称を入れない。

## 審査メモ(App Review Information、英文で入れる)

```
This is a single-player basketball general manager simulation. No account, login or server. Progress is saved only on the device.
Games are simulated automatically; the player manages the roster through trades, the draft, re-signing and free agents under a salary cap.
All leagues, teams and players are fictional. Real city names are used only as locations; no real team names, logos or players are used.
Ads are served by Google AdMob (limited to content suitable for all ages, no tracking permission requested).
The only in-app purchase is "Remove Ads" (non-consumable, basketball_career_remove_ads), found in Settings (gear on the home screen) with "Restore Purchases". An offer sheet may also appear after some full-screen ads.
Rewarded videos are optional: two extra scouting reports during each draft, and convincing the owner once per career after being fired.
No gambling, cash prizes or random paid items.
Before release, production ads may not be delivered yet; if a video shows "not ready", the app is working as designed. The purchase can be tested in the Sandbox.
```

## アプリのプライバシー

Google の公式の開示に合わせた6項目で答える(2026-11-06 ユーザー決定): おおよその位置情報・デバイスID・広告データ・その他の使用状況データ・クラッシュデータ・パフォーマンスデータ。
目的はサードパーティ広告とアナリティクス(クラッシュはアナリティクスだけ)、ユーザーに関連付けない、トラッキングに使わない。

## 配信する国

日本だけ(アプリと課金アイテムの両方)。
