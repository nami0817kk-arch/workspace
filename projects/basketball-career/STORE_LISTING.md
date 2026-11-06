# バスケデッキ / Basketball Deck — ストア掲載文の下書き(iOS のみ・日本だけ)

2026-11-06 に作り変えた(もとは「バスケ育成：6歳から始める選手物語」。野球育成と同じ雛形に見えるので、カードで戦うゲームにした)。
公開名義は「つるはし社」。本名・nami・0817 は入れない(`docs/public-identity.md`)。
**まだ提出していない。** 文面はユーザーが見て直してから App Store Connect に入れる。

## 注意(先に読む)

- **App Store Connect は一部の記号を「無効な文字」として弾く**(護送ボートの提出で確認済み)。★ ■ … ―― • — を使わない。
  見出しは【】、箇条書きは「・」にする。markdown の `*` を貼らない。
- **リーグ名・チーム名・選手名・大会名は架空。** 実在の名称を掲載文・画像・キーワードに入れない(商標)。「バスケ」「バスケットボール」は一般名称。
- 名前の候補は iTunes Search API で調べた(2026-11-06)。「ブザービーター」は英語名の同じアプリが複数あり、同名の漫画もあるので避けた。「バスケデッキ」は見当たらなかった。
- 野球育成(同じ名義)と名前・説明・画像の作りが似ないようにする(審査 4.3)。「育成」「6歳から」「選手物語」「一代記」は使わない。
- 画面は日本語のみ。**配信は日本だけ**(2026-11-06 ユーザー決定)。英語の掲載情報は付けない。

## 名前・サブタイトル・キーワード

| 項目 | 日本語 | English (US) |
|---|---|---|
| 名前(30字まで) | バスケデッキ：カードで勝ち抜く1シーズン(19字) | Basketball Deck（15字） |
| サブタイトル(30字まで) | 予告を読んで、ラスト1本を決めろ(16字) | Read the play, hit the buzzer（29字） |
| キーワード(100字まで) | バスケットボール,デッキ構築,ローグライク,カードゲーム,部活,高校,全国大会,戦略,作戦,ダンク,3P,オフライン,一人用,スポーツ | basketball,deckbuilder,roguelike,card,strategy,offline |

- ホーム画面の表示名は「バスケデッキ」(`ios/Runner/ja.lproj/InfoPlist.strings`)。
- 英語の列は表の形を保つためだけに置いている(英語の掲載情報は出さない)。

## カテゴリ・年齢

ゲーム ＞ カード(主)、ゲーム ＞ スポーツ(副)。年齢区分は 4+(暴力・賭け事・成人向けの表現なし。広告は全年齢向けに限る設定)。

## プロモーションテキスト(170字まで・審査なしで差し替えられる)

相手の次の攻めは、予告で見えている。点を取るか、守るか。手札のカードで決める、バスケの勝ち抜きカードゲーム。地区予選から全国大会まで、デッキと仲間を強くして日本一をめざそう。

## 説明文(日本語)

相手が次に何をしてくるかは、予告で見えている。
3Pで9点を狙ってくるなら、ブロックで止めるか、それ以上に点を取り返すか。
手札のカードを切って試合を進める、バスケの勝ち抜きカードゲームです。

【1試合は4クォーター】
毎ラウンド手札を5枚引き、スタミナ3で好きなだけカードを出します。シュートで点を取り、守りで相手の点を削る。パスを出したあとのアリウープ、最後のラウンドだけ大きく決まるブザービーター、ドライブを止めるチャージング。組み合わせしだいで、点差は一気に動きます。

【勝つたびにデッキが強くなる】
試合に勝つと、3枚の候補から新しいプレーを1枚選べます。練習でカードを強くし、部室では部費でカードを買ったり、弱いカードを外したり。強いデッキは、枚数が多ければいいとは限りません。

【仲間は5人まで】
強豪校に勝つと、仲間が加わりたいと言ってきます。3Pが得意なシューター、毎ラウンド守ってくれるセンター、最初のラウンドに手札を増やす司令塔。誰を迎えるかで、戦い方が変わります。

【地区予選から全国大会へ】
大会ごとに8つの行き先を選びながら勝ち上がり、最後は決勝。普通の試合に負けると気持ちが減り、決勝に負けたらその場で敗退。全国大会で優勝すれば日本一です。

【何度でも、違うシーズン】
行き先・相手・手に入るカードは毎回変わります。実績を達成すると新しいカードと仲間が増え、日本一になると、ひとつ上の難しさに挑めます。

・カード34種、仲間13人、出来事6つ、難しさ10段階
・リーグ、チーム、選手、大会の名前はすべて架空です
・オフラインで遊べます(広告と購入の確認には通信が必要)
・広告つき。「広告を消す」(買い切り)で、全画面広告が出なくなり、カードの引き直しと決勝のやり直しも動画なしで使えます

## スクリーンショット(iPhone 1206x2622・iPad 13インチ 2064x2752 の2組、各8枚。最初の3枚が検索結果に出る)

`tool/screenshots/capture_test.dart` が作る(iPhone は `flutter test tool/screenshots/capture_test.dart`、iPad は `DEVICE=ipad` を付ける)。出力は `marketing/screenshots/iphone/` と `ipad/`。

1. 「相手の予告を読んで、カードを切る」 … 試合(予告・パスのあとのアリウープ・手札)
2. 「ラスト1本は、ブザービーター」 … 決勝の最後のラウンド(3点差・ブザービーター13点)
3. 「行き先を選んで、勝ち抜く」 … 県大会の8つの行き先
4. 「勝つたびに、デッキが強くなる」 … 勝ったあとのカード3枚
5. 「仲間を5人そろえる」 … 強豪に勝ったあと仲間を迎える
6. 「部費でプレーを買い足す」 … 部室
7. 「めざせ、全国制覇」 … 優勝の画面
8. 「34種のカードを集めよう」 … カード図鑑

**撮るときの決まり**(`docs/app-pitfalls.md` #4・Apple 2.3.2・2.3.7):
- 読み込み中の画面を撮らない(生成器が検査する)。タイトル画面は撮らない。値段(¥370)を写さない。実在の名称を入れない。

## 審査メモ(App Review Information、英文で入れる)

```
This is a single-player basketball card game. No account, login or server. Progress is saved only on the device.
Each match has 8 rounds. Each round you draw 5 cards and spend 3 stamina; the opponent's next attack is shown in advance.
Ads are served by Google AdMob (limited to content suitable for all ages, no tracking permission requested).
The only in-app purchase is "Remove Ads" (non-consumable, basketball_career_remove_ads), found in Settings (gear on the home screen) with "Restore Purchases". An offer sheet may also appear after some full-screen ads.
Rewarded videos are optional: re-roll the card choices after a win, and retry a lost final once per season.
All leagues, teams, players and tournaments are fictional. No gambling, cash prizes or random paid items.
Before release, production ads may not be delivered yet; if a video shows "not ready", the app is working as designed. The purchase can be tested in the Sandbox.
```

## アプリのプライバシー

Google の公式の開示に合わせた6項目で答える(2026-11-06 ユーザー決定): おおよその位置情報・デバイスID・広告データ・その他の使用状況データ・クラッシュデータ・パフォーマンスデータ。
目的はサードパーティ広告とアナリティクス(クラッシュはアナリティクスだけ)、ユーザーに関連付けない、トラッキングに使わない。

## 配信する国

日本だけ(アプリと課金アイテムの両方)。
