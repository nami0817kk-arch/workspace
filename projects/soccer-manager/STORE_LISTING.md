# ストア掲載情報 (App Store / Google Play)

ストア審査・掲載に必要な情報をまとめたドラフト。実際の申請時にストアの文字数制限・
ガイドラインに合わせて調整すること。

## 基本情報

| 項目 | 内容 |
|---|---|
| アプリ名（正式） | サッカー経営マネージャー クラブ育成シミュレーション |
| App Store のアプリID | 6809834913（アプリ内の「このアプリを評価する」がこのIDでページを開く） |
| アプリ名（短縮・ホーム画面表示） | サカマネ |
| カテゴリ | ゲーム > スポーツ / シミュレーション |
| 対象年齢 | 全年齢（暴力表現・実写、ギャンブル要素なし。クラブ経営の「融資」「スポンサー契約」はすべて架空のゲーム内通貨） |
| 価格モデル | 無料（任意視聴のリワード広告で営業ブースト + シーズンの切り替わりの全画面広告 + 買い切りのサポーター課金）。資金の購入は 1.2.0 で画面から外した |
| 対応言語 | 日本語・英語（アプリ内で切り替え可。既定は端末の設定に従う） |
| プライバシーポリシー | https://soccer-manager.pages.dev/legal/privacy.html |
| 利用規約 | https://soccer-manager.pages.dev/legal/terms.html |
| サポート窓口 | https://soccer-manager.pages.dev/legal/support.html |

### アプリ名を長くしてある理由

公開3日の実測で**露出148回・ページ閲覧39回・初回DL8**だった。ページを見た人の
11%が入れており（App Store の平均は3〜5%程度）、**見せ方ではなく「そもそも
見られていない」のが問題**と分かった。名前は検索に最も重く効く欄で、30字まで
使えるのに11字しか使っていなかった。

同じ分野の上位（カルチョビットA）も
`カルチョビットＡ(アー) サッカークラブ育成シミュレーション` という作りで、
ブランド名の後ろにカテゴリ語を足している。

**端末のホーム画面に出る名前は `サカマネ` のまま**（`CFBundleDisplayName`）。
長くなるのはストアの掲載名だけ。

## 短い説明文（Google Play「簡単な説明」80字以内 目安）

> 3部の弱小クラブを買い取った。試合は監督に任せ、金・人・方針を決めて1部の頂点へ。

## 長い説明文（ストア掲載用）

> **読まれるのは冒頭3行だけ。** その先は「もっと見る」を押さないと出ない。
> ここに「本格サッカークラブ経営シミュレーション」とだけ書いていた頃は、
> ジャンル名を名乗っているだけで、入れる理由になっていなかった。
> **1行目に状況、2行目に何を決めるのか、3行目にどこまで行けるのか**を置く。
> 説明文は検索順位には効かない（効くのはキーワード欄）ので、ここは
> まるごと「入れてもらうための文」に使ってよい。

```
3部リーグの弱小クラブを買い取った。
試合は監督に任せ、あなたは金・人・方針を決める。
サポーターと株主、2つの期待を保ちながら1部の頂点へ。

【監督を選ぶ】
監督の候補は、考え方と好みの布陣を見て雇う。先発・戦い方・キャプテン・
セットプレーの担当は毎節、監督が決める。腕のいい監督ほど、相手に合わせて
戦い方を変える。契約が切れれば、次の監督を探す。

【2つの期待を保つ】
サポーターの期待は毎月の結果とオーナーの手で、株主の期待は収支で動く。
年に3回起きる事件の判断は、どちらを取ってももう一方が傷つく。
サポーターの期待が尽きて最後通告から戻せないか、資金が尽きればクラブを
手放すことになる。それでも実績を残したまま、別のクラブ（別の国も選べる）を
買い直して続けられる。

【予算を配る】
年の予算を補強・育成・施設・営業・配当の5つに配る。補強はすぐ、営業は1年、
育成は2〜3年、施設は3〜5年かけて効く。スタジアムや練習場を建て、
スポンサー契約を結び、銀行から借りる。コーチやスカウトは、能力と得意分野を
見て一人ずつ雇う。

【オーナー室から手を打つ】
試合日のイベント、広報、地域活動、提携クラブ。何かを得れば何かを払う。
どの手をいつ打つかで、2つの期待とお金が動く。

【選手を動かす】
挙がってきた補強の候補を買うか見送るか。他のクラブから届いた売却の
オファーを受けるか断るか。主力と契約を延ばすときは、約束する出場機会と
年俸を条件の画面で話し合う。

【アカデミーを持つ】
自前のアカデミーには年間リーグがあり、有望株は毎週の試合で実戦を積む。
ただし19歳を過ぎた有望株は出場機会を求め、放っておけば他クラブに
引き抜かれる。いつプロ契約を結んで一軍へ上げるか、その判断がクラブの
背骨をつくる。

【シーズンを戦い抜く】
リーグはイングランド・スペイン・ドイツ・イタリア・フランスの5か国から選べる。
昇降格のある3部制のリーグ戦、国内カップ、大陸カップ、スーパーカップ。
得点王・年間MVP・ベストイレブンなどの個人タイトルや、殿堂入りする
レジェンド選手たちがあなたの物語を彩る。

画面は横向きです。上の帯に日付・資金・2つの期待、左にメニューを常に出し、
ボタン1つで次に予定がある日まで進みます。

進行状況は端末内に保存されます。オンラインのアカウント登録は不要です。

営業を強化できる動画広告は「見たい人だけ」が対象で、自分から選んだときだけ
再生されます。1日3回まで、見ると次の1節だけ収入が増えます。
一度も見なくてもゲームは最後まで遊べます。
全画面広告はシーズンの切り替わりで1回だけ表示され、試合中やメニュー操作には
割り込みません。バナー広告はありません。
課金はサポーター（買い切り）の1つだけです。購入すると、広告を見ずに同じ営業の
強化ができ、1日の回数が3回から5回に増え、全画面広告も表示されなくなります。
月額ではありません。資金を買う商品はありません。サポーターは、選手の成長や
試合の勝率を変えるものではありません。
```

> **Android(Google Play)には出さない**(2026-09-26 決定)。以下に Play 向けの
> 記述が残っているのは、出すことになったときのため。当面は iOS だけを見る。

## このバージョンの新機能（1.2.0）

**App Store で公開中なのは 1.1.3（2026-10-01 公開。2026-11-23 に lookup で確認）。**
1.1.4〜1.1.8 は文面を用意しただけで、公開されていない。そのため 1.2.0 の欄は
**1.1.3 との差**で書く（1.1.4〜1.1.8 の見た目の作り直しもここに含める）。

欄の決まり: App Store の欄にそのまま貼る。`★ ■ … ― • —` と markdown の `*` は
使わない。見出しは日本語が【】、英語が [ ]。

提出のときに一緒に入れるもの:
- **掲載画像を全部差し替える**（横画面になった。iPhone 2622x1206 と iPad 2752x2064、
  日英それぞれ8枚。下の「スクリーンショット」の節）
- 説明文・プロモーション用テキスト・キーワードを日英とも差し替える
- **プレビュー動画は入れない**（`marketing/preview/` の動画は縦画面の試合・ハーフタイムを
  映していて、どちらも 1.2.0 には無い画面。App Store Connect に載っていたら削除する）

### 日本語

```
【クラブのオーナーになりました】
1.2.0 は、ゲームの中身を大きく作り替えた版です。あなたは監督ではなく、3部の弱小クラブを買い取ったオーナーです。試合は監督に任せ、お金・人・方針を決めます。

・年の予算を、補強・育成・施設・営業・配当の5つに配ります。効き始めるまでの時間がそれぞれ違います
・サポーターの期待と株主の期待、2つを保ちながら上をめざします
・先発・戦い方・キャプテン・セットプレーの担当は監督が決めます。監督は考え方と好みの布陣を見て雇います
・補強は、挙がってきた候補を買うか見送るかで決めます。売却のオファーには監督の見立てが付きます
・契約の更新と移籍は、条件を出し合う画面で話し合います
・スタジアムや練習場などの施設を建て、コーチやスカウトを一人ずつ雇います
・オーナー室から、試合日のイベント・広報・地域活動・提携クラブなどの手を打てます
・年に3回、どちらかの期待を傷つける事件の判断を迫られます
・サポーターの期待が尽きて最後通告から戻せないと、クラブを手放すことになります。実績はそのままに、別のクラブ（別の国も選べます）を買い直して続けられます

【横画面になりました】
・画面を横向きにし、上の帯に日付・資金・2つの期待、左に常設のメニューを置きました
・ボタン1つで、次に予定がある日まで進みます

【見た目】
・選手の似顔絵、ピッチ、クラブのエンブレム、実績の記章を描き直しました
・タイトル画面と、優勝・昇格を決めたときに絵が出るようになりました

【そのほか】
・設定から、このアプリを評価できるようになりました。お問い合わせの窓口も置きました
・資金を買う商品はなくなりました。課金は、広告を見ずに済むサポーター（買い切り）の1つだけです
```

### 英語

```
[You own the club now]
1.2.0 rebuilds the game. You are no longer the manager: you have bought a struggling third-tier club. The manager runs the matches; you decide the money, the people and the direction.

- Split each year's budget five ways: signings, youth, facilities, marketing and dividends. Each takes a different time to pay off.
- Keep two groups on side, the fans and the shareholders.
- The manager picks the side, the approach, the captain and the set-piece takers. You hire him for his outlook and favourite formation.
- Approve or pass on the signing candidates put to you. Offers for your players come with the manager's view.
- Renewals and transfers are negotiated on a terms screen.
- Build the stadium, the training ground and more, and hire coaches and scouts one by one.
- From the owner's office: matchday events, PR, community work, a partner club and more.
- Three times a season an incident needs your call, and every answer costs you with one side.
- If the fans lose all faith and you cannot win them back after the final warning, you have to sell. You keep your record and can buy another club, even in another country.

[Landscape]
- The game now runs in landscape, with the date, funds and both expectations along the top and a menu down the side.
- One button moves you on to the next day with something on.

[New look]
- Player portraits, the pitch, club crests and achievement badges have been redrawn.
- The title screen, and winning the league or going up, now have artwork.

[Other]
- You can rate the app and contact support from Settings.
- Funds can no longer be bought. The only purchase is Supporter, a one-off that lets you skip the ads.
```

## このバージョンの新機能（1.1.8）

**提出するのはこの版（ビルド13）。** 1.1.4〜1.1.7 はビルドだけ作って提出して
いない。中身はすべてこの版に入っている。掲載画像も作り直してある。

提出のときに一緒に入れるもの（1.1.7 の節と同じ）:
- **プレビュー動画**（`marketing/preview/app_preview_{ja,en}.mp4`）を日本語・英語に
- **掲載画像9枚×4組を差し替え**（画面を作り直したので、ja/en とも全部）
- 日本語の説明文を差し替え

### 日本語

```
・画面を一通り作り直しました。順位・勝点・総合力といった数字を大きく
　見やすくし、どこを見ればよいかが分かる並びにしています
・ホーム画面にクラブの色の見出しを置き、順位を大きく出しました
・試合の途中経過を、左右に伸びるバーで見比べられるようにしました
・順位表で自分のクラブの行が一目で分かるようにしました
・選手一覧と移籍市場で、総合力や移籍金を札に分けて読みやすくしました
・能力レーダーの軸の文字が、環境によっては表示されないことがあったのを
　直しました
・設定から、このアプリを評価できるようになりました
・設定に、お問い合わせの窓口を置きました
・タイトル画面に絵を入れました
・リーグ優勝・昇格を決めたときに、その絵が出るようになりました
・選手の似顔絵、ピッチ、クラブのエンブレム、実績の記章を描き直しました
・シーズンの区切りで、評価のお願いを出すようにしました。理事会の目標を
　達成したときだけで、何度も出ることはありません
```

### 英語

```
- The screens have been redesigned. Key numbers (position, points, overall)
  are larger and easier to read.
- The home screen now has a club-coloured header with your position in it.
- Match stats are now a side-by-side comparison bar.
- Your club's row now stands out in the league table.
- Overall and fees are shown as chips in the squad and transfer lists.
- Fixed the attribute radar labels not showing on some platforms.
- You can now rate the app from Settings.
- Settings now has a link to contact support.
- The title screen now has artwork.
- Winning the league or going up now has artwork of its own.
- Player portraits, the pitch, club crests and achievement badges have all
  been redrawn.
- We now ask for a rating at the end of a season, and only when you have met
  the board's target. It will not keep asking.
```

## このバージョンの新機能（1.1.7）

**提出するのはこの版（ビルド12）。** 1.1.4〜1.1.6 はビルドを作っただけで
提出していない。中身はすべてこの版に入っている。

このとき一緒に入れるもの:

- **プレビュー動画**（`marketing/preview/app_preview_{ja,en}.mp4`）を日本語・
  英語それぞれにアップロードする。**いちばん大きな空き枠だった。**
- **英語の掲載画像9枚を差し替える**（クラブ名が日本語のままだった）
- 日本語の説明文を差し替える（冒頭3行を練り直した）

### 日本語

```
・設定から、このアプリを評価できるようになりました
・設定に、お問い合わせの窓口を置きました
・タイトル画面に絵を入れました
・リーグ優勝・昇格を決めたときに、その絵が出るようになりました
・選手の似顔絵を描き直しました。首から上だけの平たい絵をやめ、
　ユニフォームと陰影を入れています
・ピッチの芝とラインを描き直しました。スタメン画面にゴールエリアや
　ペナルティアークが入り、試合画面と見た目が揃いました
・クラブのエンブレムに縁取りと立体感を入れました
・実績に1件ずつの記章を付けました。これまでは33件すべて同じ絵でした
・シーズンの区切りで、評価のお願いを出すようにしました。理事会の目標を
　達成したときだけで、何度も出ることはありません
```

### 英語

```
- You can now rate the app from Settings.
- Settings now has a link to contact support.
- The title screen now has artwork.
- Winning the league or going up now has artwork of its own.
- Player portraits have been redrawn, with a shirt and proper shading
  instead of a flat floating head.
- The pitch has been redrawn. The lineup screen now has the goal areas and
  penalty arcs, and matches the look of the match screen.
- Club crests now have a border and some depth.
- Every achievement has its own badge. They all used to share one icon.
- We now ask for a rating at the end of a season, and only when you have met
  the board's target. It will not keep asking.
```

## このバージョンの新機能（1.1.6）

1.1.5 と同じ掲載画像で出せる（タイトル画面と演出は掲載画像に写らない）。
**1.1.5 をまだ提出していなければ、この版に差し替えて1回で出す。**

### 日本語

```
・タイトル画面に絵を入れました
・リーグ優勝・昇格を決めたときに、その絵が出るようになりました
・選手の似顔絵を描き直しました。首から上だけの平たい絵をやめ、
　ユニフォームと陰影を入れています
・ピッチの芝とラインを描き直しました。スタメン画面にゴールエリアや
　ペナルティアークが入り、試合画面と見た目が揃いました
・クラブのエンブレムに縁取りと立体感を入れました
・実績に1件ずつの記章を付けました。これまでは33件すべて同じ絵でした
・シーズンの区切りで、評価のお願いを出すようにしました。理事会の目標を
　達成したときだけで、何度も出ることはありません
```

### 英語

```
- The title screen now has artwork.
- Winning the league or going up now has artwork of its own.
- Player portraits have been redrawn, with a shirt and proper shading
  instead of a flat floating head.
- The pitch has been redrawn. The lineup screen now has the goal areas and
  penalty arcs, and matches the look of the match screen.
- Club crests now have a border and some depth.
- Every achievement has its own badge. They all used to share one icon.
- We now ask for a rating at the end of a season, and only when you have met
  the board's target. It will not keep asking.
```

## このバージョンの新機能（1.1.5）

1.1.4 はビルドを作っただけで提出していない。掲載画像を差し替える版だったが、
その直後にゲーム内の絵（似顔絵・ピッチ・エンブレム・実績の記章）を作り直した
ため、1.1.4 の掲載画像では中身と見た目がずれる。**1本にまとめてこの版で出す。**

### 日本語

```
・選手の似顔絵を描き直しました。首から上だけの平たい絵をやめ、
　ユニフォームと陰影を入れています
・ピッチの芝とラインを描き直しました。スタメン画面にゴールエリアや
　ペナルティアークが入り、試合画面と見た目が揃いました
・クラブのエンブレムに縁取りと立体感を入れました
・実績に1件ずつの記章を付けました。これまでは33件すべて同じ絵でした
・シーズンの区切りで、評価のお願いを出すようにしました。理事会の目標を
　達成したときだけで、何度も出ることはありません
```

### 英語

```
- Player portraits have been redrawn, with a shirt and proper shading
  instead of a flat floating head.
- The pitch has been redrawn. The lineup screen now has the goal areas and
  penalty arcs, and matches the look of the match screen.
- Club crests now have a border and some depth.
- Every achievement has its own badge. They all used to share one icon.
- We now ask for a rating at the end of a season, and only when you have met
  the board's target. It will not keep asking.
```

## このバージョンの新機能（1.1.4）

中身の変更は1件で、主目的は**掲載画像の差し替え**。掲載の更新はバージョンを
出さないと反映されないため、この版を出す。1枚目を専用の下絵の中に置き、
2枚目以降は帯の色を振って端末の枠に入れた。

### 日本語

```
・シーズンの区切りで、評価のお願いを出すようにしました。理事会の目標を
　達成したときだけで、何度も出ることはありません
・App Store の掲載画像を新しくしました
```

### 英語

```
- We now ask for a rating at the end of a season, and only when you have met
  the board's target. It will not keep asking.
- New App Store screenshots.
```

## このバージョンの新機能（1.1.3）

**ビルド8は TestFlight に上げてある**（2026-10-01）。提出はこの欄を貼って
ビルド8を選ぶだけで、タグも手動実行も要らない。

### 日本語

```
・アプリのアイコンを新しくしました
・まれに、購入したぶんが二重に反映されることがあったのを直しました
```

### 英語

```
- New app icon.
- Fixed a rare case where a purchase could be credited twice.
```

## このバージョンの新機能（1.1.2）

App Store Connect の「このバージョンの新機能」に貼る文面。**日本語と英語で別々に入れる。**

中身は不具合の修正2件。掲載の文面・画像は 1.1.1 から変えないので、
差し替えるのはこの欄とビルドだけ。

### 日本語

```
・広告を見ようとしたときに出ないことがあったのを直しました。特典を
　受け取れないまま回数だけ減ってしまう場合がありました
・ダークモードで、ユースの「育成方針」「メンター」で選んだ内容が
　読めなくなっていたのを直しました
```

### 英語

```
- Fixed ads sometimes failing to appear when you asked for one, which could
  use up one of your daily rewards without paying it out.
- In dark mode, the training focus and mentor you picked for a youth player
  were unreadable. Fixed.
```

## このバージョンの新機能（1.1.1）

App Store Connect の「このバージョンの新機能」に貼る文面。**日本語と英語で別々に入れる。**

中身の変更は1件だけで、あとはストアの掲載（名前・サブタイトル・キーワード・
掲載画像・英語ローカライズ）の更新。掲載の更新はバージョンを出さないと
反映されないため、この版を出す。

### 日本語

```
・ダービーの収入が、実際に入れた人数で決まるようになりました。満員でも
　入れる人数を超えて入場料が入っていたのを直しています
```

### 英語

```
- Derby income is now based on how many people actually got in. It used to
  count gate receipts for more than the stadium holds.
```

## このバージョンの新機能（1.1.0）

App Store Connect / Google Play Console の「このバージョンの新機能」に貼る文面。

```
ユース組織を作り直しました。

・ユースの年間リーグ（14節）。練習試合が順位表と得点王として残ります
・メンター制度。一軍のベテランを有望株に付けると、得意技を受け継ぎます
・有望株の流出。19歳を過ぎた選手は出場機会を求め、放っておくと去ります
・昇格はプロ契約に。背番号・週俸・契約金が発生し、慣れるまで時間がかかります
・生え抜きの印。育てた選手と買ってきた選手が見分けられます
・ユースコーチの見極めと指導が、別々の仕事をするようになりました
　（見極め＝良い子を集めて見立てる／指導＝アカデミーで伸ばす）

「次に何をすればいいか」が分かるようにしました。

・ホームに「次にやること」を1件だけ提案します
・試合前にスタメンの不備（出場停止・疲労・ポジション違い）を知らせます
・移籍の締切が近づくと知らせます
・実績画面の一番上に、あと少しで届くものが出ます
・まだ何も無い画面に、どうすれば埋まるかを書きました
・選手ごとに、いま手を打つべきことを出します

見て分かるようにしました。

・シーズンが終わると、その年の総括が出ます
・試合中に得点・決定機・カードの途中経過が見えます
・画面の数字から用語集を引けます
・クラブニュースを種類と本文で探せます
・移籍市場で2人を並べて比べられます
・日程画面からユースの日程と順位表を見られます
・理事会の目標まであと何点・何節かが分かります
・スタッフに得意分野（攻撃・守備・GK・フィジカル）が付きました
・ユースの新人は「見立て」で表示されます（コーチの見極めで精度が変わります）

セーブを守る仕組みを足しました。

・設定から、いつでも戻れる控えを1つ取れます
・セーブが壊れたときは、直前の控えから自動で復元します

不具合の修正:
・押して開いた画面からホームに戻れないことがあったのを直しました
・購入したのにクラブ資金や特典が反映されないことがあったのを直しました
・広告を最後まで見た後に画面を離れると、資金が入らないことがあったのを直しました
・分割払いで獲得した選手を手放すと、残金の支払いが消えていたのを直しました
・掲載画像に英語が混ざっていたのを直しました
・一覧の文字が語の途中で折り返していたのを直しました
・昇格プレーオフ決勝のホームが順位と無関係に決まっていたのを直しました
```

## プロモーション用テキスト（App Store、170字以内）

**審査なしでいつでも差し替えられる唯一の欄。** 説明文の上に出る。短い期間で
文言を試せる場所なので、埋めておく。

```
3部の弱小クラブを買い取ったオーナーに。試合は監督に任せ、予算を5つに配り、
施設を建て、サポーターと株主の2つの期待を保つ。1部の頂点をめざす経営シミュレーション。
一度も広告を見なくても、最後まで遊べます。
```

## サブタイトル（App Store、30字以内）

名前のすぐ下に出て、検索にも効く欄。**空欄のままだと無料の枠を1つ捨てることになる。**

**アプリ名に入れた語をここで繰り返さない。** 名前が
「サッカー経営マネージャー クラブ育成シミュレーション」になったので、
`クラブ` `育成` `シミュレーション` はここでは使わない。

試合を監督に任せるオーナーのゲームになった（1.2.0）ので、「監督の采配」は
言わない（2026-11-23 に書き直した）。

```
オーナーとして3部から1部の頂点へ
```

## 英語圏向けの掲載（App Store の英語ローカライズ）

アプリは UI だけでなく**選手名・クラブ名まで英語のプールを持っている**
（`lib/data/name_pool.dart` が `Tr.isEnglish` で切り替える）。英語版として
完成しているのに掲載が日本語だけだったため、英語圏では存在しないのと同じ
だった。日本語圏の検索は激戦（公開3日で露出148回）で、同じ商品のまま
市場をもう1つ増やせるのがこの欄。

**画像は `marketing/screenshots_en/` と `marketing/screenshots_ipad_en/`。**
日本語の画面に英語の説明文を添えると、中身が伝わらないどころか不信を招く。

### アプリ名（30字以内）

```
Underdog FC: Soccer Club Sim
```

`Soccer Manager` `Football Manager` はどちらも実在のアプリ・シリーズの名前
なので、その並びは避けている。`Underdog` で中身（弱小クラブ）を出し、
`Soccer` `Club` `Sim` で検索の手がかりを確保する。

### サブタイトル（30字以内）

```
Take a small club to the top
```

### キーワード（100字以内）

アプリ名に入れた `soccer` `club` `sim` は繰り返さない。

```
football,manager,owner,chairman,tycoon,transfer,league,promotion,stadium,budget,academy,fans
```

### プロモーション用テキスト（170字以内・審査なしで差し替え可）

```
You just bought a struggling third-tier club. The manager runs the matches; you split the budget, build the club and keep the fans and shareholders on side.
```

### 説明文

```
You just bought a struggling third-tier club.
The manager runs the matches; you decide the money, the people and the direction.
Keep two groups happy, the fans and the shareholders, and take it to the top.

[Hire a manager]
Read each candidate's outlook and favourite formation, hire one, and leave
the matches to him. He picks the side, the approach, the captain and the
set-piece takers every matchday, and the better he is, the more he adapts to
the opponent. When his contract runs out, you find the next one.

[Keep two groups happy]
Fan expectation follows each month's results and your own moves; shareholder
expectation follows the books. Three times a season an incident needs your
call, and every answer costs you with one side or the other. If the fans lose
all faith after the final warning, or the money runs out, you have to sell.
You keep your record and can buy another club, even in another country.

[Spend the budget]
Split it between signings, youth, facilities, marketing and dividends.
Signings work at once, marketing in a year, youth in two or three, facilities
in three to five. Build the stadium and the training ground, sign sponsors,
borrow from the bank, and hire coaches and scouts one by one for their
ability and specialty.

[Make your moves from the office]
Matchday events, PR, community work, a partner club. Every move gains you
something and costs you something, and when you make it matters.

[Move players]
Approve or pass on the signing candidates put to you, accept or turn down
offers for your players, and agree minutes and wages when you renew a key man.

[Run an academy]
Your academy plays its own season, so prospects get real matches. But once
they turn 19 they want first-team football, and clubs will come for the ones
you leave behind. Deciding when to hand out a professional contract is the job.

[Climb]
Pick a league in England, Spain, Germany, Italy or France. Three divisions,
promotion play-offs, domestic cups and continental cups. Top scorers, player
of the season and a team of the season along the way.

The game is played in landscape, with the date, funds and both expectations
along the top, a menu down the side, and one button to move on to the next
day with something on.

Your progress is saved on your device. No account, no sign-in.

The video ads that boost your marketing play only when you choose to watch
them. Up to 3 a day, each one raises income for the next matchday. You can
finish the game without watching a single one.
One full-screen ad appears when a season rolls over, never during a match or
while you are in the menus. There are no banners.
The only purchase is Supporter, a one-off: you get the same marketing boost
without ads, your daily limit rises from 3 to 5, and the full-screen ad between
seasons stops appearing. It is not a subscription, funds are not for sale, and
it does not change player growth or your chances in a match.
```

## キーワード（App Store キーワードフィールド、100字以内目安）

**アプリ名・サブタイトルに入っている語をここで繰り返さない。** 検索の突き合わせは
名前・サブタイトル・キーワードをまとめて見るので、重ねたぶんは枠を削るだけになる。
以前ここに `サッカー,マネージャー,経営` と書いていたが、3つともアプリ名に
入っていた。名前を長くしたぶん `クラブ` `育成` `シミュレーション` も名前側に移り、
`オーナー` はサブタイトルに入った。ここに残すのはどちらにも無い語だけ。
（2026-11-23 にサブタイトルを書き直し、そこから外れた `監督` `移籍` `リーグ`
`成り上がり` をこちらへ移した。`采配` はもう遊ぶ人の仕事ではないので入れない。）

区切りは読点ではなくカンマで、スペースは入れない（入れると1文字ぶん損をする）。

```
監督,移籍,リーグ,戦略,選手,昇格,優勝,スタジアム,予算,株主,サカマネ
```

## スクリーンショットとフィーチャーグラフィック

**手で撮らない。生成器がある。**

```bash
flutter test tool/screenshots/capture_test.dart --update-goldens
flutter test tool/screenshots/feature_graphic_test.dart --update-goldens
```

`tool/` に置いてあるのは、これらがテストではなく生成器で、実行すると
ファイルを書き換えるため。`test/` の外なので CI では回らない。

出力は端末・言語ごとに8枚ずつ。**1.2.0 から横画面**（スマホは横向きに固定した）。

| 出力先 | 寸法 | App Store の枠 |
|---|---|---|
| `marketing/screenshots/` | 2622x1206 | iPhone・Dynamic Island 搭載の中型（6.3インチ）・日本語 |
| `marketing/screenshots_en/` | 2622x1206 | 同・英語 |
| `marketing/screenshots_ipad/` | 2752x2064 | iPad 13インチ・日本語 |
| `marketing/screenshots_ipad_en/` | 2752x2064 | iPad 13インチ・英語 |

寸法は Apple の仕様（2026-11-23 に確認）:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
iPhone で**必須なのは「Dynamic Island 搭載・中型」の枠だけ**（横は 2622x1206 か 2556x1179）。
大型（6.9インチ）は任意で、出さなければ中型から縮めて使われる。iPad はアプリが
iPad で動く設定（`TARGETED_DEVICE_FAMILY = "1,2"`）なので 13インチが必須。
どれも1〜10枚、png か jpg、透過なし。

英語ぶんは**翻訳ではなく、英語で動かしたアプリを撮ったもの**。選手名・クラブ名
まで英語のプールに切り替わる。生成器は言語を決めてからシミュレーションに入る
（ニュースや事件の文面は作られた時点の言語で確定し、後から切り替えても遡って
訳されない）。撮る前に、クラブ名・選手名・ニュースがその言語になっているかを
検査している。

iPad ぶんが要るのは、アプリが iPad でも動く設定になっているため。iPhone
だけだと「13インチのiPadディスプレイのスクリーンショットをアップロード
する必要があります」で提出できない。

撮り方: 実機と同じ包み方（`LandscapeScale`・`FmThemeScope`）の `MainShell` を端末の
寸法で組み、**左のメニューとページのタブを実際に押して**開いた画面を撮る。帯を
乗せるぶん縮めて置くが、組むのは実機の寸法（枠の幅で組ませると割付が変わり、
名前が切れる）。試合の結果は乱数なので、冬の移籍ウィンドウ（第25節の前）まで
進めて**理事会の目標より4つ以上上の順位にいる回**を撮る（下位の回だと1枚目から赤字が並ぶ。
数字は作らず、実際に進めた結果から選ぶ）。

**番号は撮る順ではなく、ストアに並べる順。** 検索結果には**先頭の数枚しか出ない**ので、
「クラブを買った経営者になる」ことが伝わる順に置いている。

| ファイル | 画面 | 帯の言葉（日 / 英） |
|---|---|---|
| `01_home.png` | 状況（監督の報告・期待・決めること） | 弱小クラブのオーナーになる / Buy a struggling club |
| `02_budget.png` | 経営 > 概要（年のお金・予算の配り方） | 予算を5つに配る / Split the budget five ways |
| `03_office.png` | オーナー室 > オーナーの仕事（試合日のイベント） | サポーターと株主、2つの期待 / Keep fans and shareholders on side |
| `04_facilities.png` | クラブ > 施設 | 施設を建てて、クラブを大きくする / Build up the club |
| `05_transfer.png` | 移籍 > SD の案（冬の窓） | 補強の候補を、買うか見送るか / Sign him, or pass |
| `06_league.png` | リーグ > 順位・日程 | 3部から、1部の頂点へ / From the third tier to the top |
| `07_staff.png` | クラブ > スタッフ（雇った状態で撮る） | コーチもスカウトも、選んで雇う / Hire coaches and scouts |
| `08_community.png` | クラブ > ファンと街 | 街とファンを味方につける / Win over the town and the fans |

手元の確認用に、端末・言語ごとのフォルダへ写したもの:
`C:\Users\<ユーザー>\Downloads\サカマネ1.2.0_掲載画像\{1_iPhone_日本語,2_iPhone_英語,3_iPad_日本語,4_iPad_英語}`

## プレビュー動画（App Preview）

`marketing/preview/app_preview_ja.mp4` と `app_preview_en.mp4`（20秒・886x1920）。
**検索結果でもページでも1枠目に出て、自動再生される。** ここが空のままだと、
いちばん目立つ枠を静止画に使うことになる。

> **撮り直しが要る（2026-11-23 時点・まだ撮り直していない）。** 今の動画は
> ライブ観戦とハーフタイムの画面を映しているが、どちらも 1.2.0 で無くなった。

```bash
flutter test tool/preview/capture_frames_test.dart   # コマを書き出す
python tool/preview/encode.py                        # 動画にまとめる
```

**撮った絵をつないでいるのではなく、動いているアプリをそのまま撮っている。**
試合画面は時間で動くので、1コマ進めては書き出す、を繰り返すと実際の映像になる。
App Preview は「アプリが動いている様子」であることを求められるので、静止画の
紙芝居では出せない。試合以外の画面は自分では動かないため、ゆっくり送りながら撮る。

守っている決まり（encode.py が検査する）:

- 長さ 15〜30秒（いまは20秒）、H.264、500MB 以内（いまは約1.2MB）
- iPhone 6.5インチ以上は 886x1920（縦）
- `yuv420p`。外すと再生できない端末が出る
- **無音でも音声トラックを1本入れる。** 音声トラックが無い動画が弾かれた事例がある

踏んだ穴:
- 20秒のうち10秒がハーフタイムの静止画だった。**止まった画面を何秒も映さない。**
- 送り先に横並びの絞り込みを掴んで、一覧が横にずれた。**縦に動くものを選ぶ。**
- 送った直後の未描画の状態を撮りにいって落ちた。**送ってから1コマ進めて撮る。**
- 移籍ウィンドウを試合開始後に待とうとして固まった。**試合を始める前に開けておく。**

フィーチャーグラフィック（Google Play 必須、1024x500）は
`marketing/feature/feature_graphic.png`。背景の
`marketing/feature/stadium_bg.jpg` は生成した画像で、実在のスタジアム・
クラブ・選手は写っていない。文字はアプリ同梱のフォントで載せているので、
ストアの絵とアプリの中で書体が揃う。

> **（1.1.x までの縦画面の話。1.2.0 の横画面では下絵を使っていない。下絵が縦長で、横の枠に入らないため）**
>
> **1枚目だけは専用の下絵を敷く**（`marketing/hero/hero_bg.png`、生成AIで作った絵）。
> 下絵の中央に端末を置く場所が空けてあり、生成器がそこへ実機の画面を重ねる。
> **絵だけにはできない**——App Review 2.3.3 が「掲載画像はアプリが動いている様子を
> 見せること。タイトル絵・ログイン画面・起動画面だけのものは不可」としている。
> 端末の中は**実機の寸法で組ませてから縮める**（枠の幅で組み直させると、
> 選手名が「Ashwo…」のように切れる）。
> **iPad では使わない。** 下絵は縦長（9:16）なので、横に広い iPad ではどこで
> 切っても端末を置く空き枠がはみ出して白く残る。iPad は検索結果に出ないため、
> 帯のままにしてある。
>
> **2枚目以降には言葉の帯を乗せてある**（生成器が自動で付ける。`_captions` に文言）。
> 画面をそのまま撮っただけでは、スクロールしている人に何のゲームか伝わらない。
> 同じ分野の上位（カルチョビットA・サッカークラブ物語）は全カットに帯がある。
> 露出5,730に対してページ閲覧557（9.7%）で詰まっていたので、ここを上げにいく。
> 帯の文字には **`fontFamily` を明示する**（省くと日本語が豆腐になる。実際なった）。
> 帯は **`Material` で包む**（包まないと黄色い二重下線が引かれる。実際引かれた）。
> 帯の地の色は画像ごとに振ってある（`_shades`）。同じ緑が9枚続くと、並べたときに
> 単調になる。画面は端末の枠に入れて影を落とす（切り抜きに見えないように）。
>
> **開始画面は撮らない。** セーブ一覧の読み込みを待つ画面で、読み込み中の丸だけが
> 写った白紙になっていた。それを1枚目としてストアに出していた（2026-09-28 に
> ユーザーの指摘で判明）。例外もはみ出しも出さないので、それまでの検査を全部
> すり抜けていた。いまは撮るたびに「読み込み中の丸が無いこと」「文字が3つ以上
> あること」を見ている。
>
> 移籍市場は、移籍ウィンドウが開いている時期に撮る。閉じている時期だと
> 「クローズ中」の帯が出て「獲得する」が全部灰色になり、何もできない画面が
> ストアに載る（1.1.0 の撮り直しで気づいた）。生成器が自分で開く時期まで
> 進めるので、手で合わせる必要はない。
>
> 撮り直しが必要になるのは、画面の見た目や文言を変えたとき。
> 以前ここに置かれていた画像は、アイコンフォントを読まないまま撮ったため
> 天気アイコンが豆腐（□）で写っていた。生成器はアイコンフォントを
> 読み込み、見つからなければ失敗する。

## 審査時の留意事項

- **データ収集の申告は「収集なし」ではなくなった。** AdMob を組み込んだため、
  広告識別子(Android広告ID / IDFA)・おおよその位置(IPアドレス由来)・端末情報が
  Google に取得される。Play のデータセーフティでは「広告 ID」「デバイスまたは
  その他の ID」を*収集する*と申告し、目的は「広告またはマーケティング」を選ぶ。
  App Store の App プライバシーでは「識別子 > デバイス ID」を
  「サードパーティ広告」の目的で申告する。詳細は AdMob の公式ガイダンスに従うこと。
- アカウント登録・ログイン機能は引き続き無い。提供者自身は何も収集していない。
- 「融資」「スポンサー契約」は実際の金銭のやり取りを伴わないゲーム内経済である旨を
  Reviewer向けメモ（App Store Connect の「レビュー用メモ」欄等）に明記すると良い。
- Web版（Cloudflare Pages、`.github/workflows/soccer-pages.yml`）は無料の試遊版として
  引き続き公開する想定。ストア版と機能差分が出た場合はこのドキュメントを更新する。

## 申請チェックリスト

ビルドと鍵の作り方は [`docs/RELEASE_GUIDE.md`](docs/RELEASE_GUIDE.md) を参照。
ここは「ストアの画面で何を埋めるか」のチェックリスト。

### 共通（提出前）

- [ ] 上記のプライバシーポリシーURL・利用規約URLをブラウザで開いて表示を確認する
      （Web版のデプロイが一度も走っていないと404になる）
- [ ] `pubspec.yaml` の `version:` を今回の提出内容に合わせて更新した
- [ ] スクリーンショットを生成した（下記の生成器を実行。横画面で8枚×4組）
- [ ] 実機で一度リリースビルドを起動し、初回起動〜ニューゲーム〜1試合消化まで通した

### Google Play

- [ ] アプリ署名（Play App Signing）を有効にした
- [ ] AAB をアップロードした（APK ではなく AAB）
- [ ] データセーフティ フォームを提出した
      **「データを収集しない」を選んではいけない。** リワード広告(AdMob)が
      広告IDなどを収集するため、下の行のとおり収集ありで申告する。
      （この記述は、広告もIAPも無かった頃の名残だった）
- [ ] コンテンツのレーティング アンケートに回答した
- [ ] ターゲット層と広告の申告で**「広告あり」**を選んだ
- [ ] データセーフティで「広告 ID」「デバイスまたはその他の ID」の収集を申告した
- [ ] アプリ内課金の商品を登録した（IDを1文字も違えないこと）。**いま画面から
      売っているのはサポーターの1件だけ**（`lib/widgets/supporter_section.dart`）
      - `soccer_manager_supporter`（**非消費型**）
      - 資金パック3件（`soccer_manager_funds_small` / `soccer_manager_funds_medium` /
        `soccer_manager_funds_large`、**消費型**）は 1.2.0 で画面から外した
        （買う画面の部品 `FundsPackCard` も 2026-11-23 に消した）。**新しく登録しない。**
        コードは、承認待ち（Ask to Buy）や落ちて届き損ねた購入がストアから
        送られてきたときに受け取るためだけに残している
- [ ] AdMob のアプリIDと広告ユニットIDを自分のものに差し替えた
      （既定は Google のテスト用ID。差し替え忘れると収益が発生しない）
- [ ] プライバシーポリシーURLを登録した（必須。未入力だと公開できない）
- [ ] クローズドテスト（テスター20人・14日間）を開始した
      ※個人開発者アカウントの新規登録では製品版公開の前提条件
- [ ] 短い説明（80字以内）・詳しい説明を上記の文面から転記した
- [ ] アプリアイコン（512×512）を用意した
      （フィーチャーグラフィック 1024×500 は
      `marketing/feature/feature_graphic.png` に生成済み）

### App Store

- [ ] App Store Connect でアプリレコードを作成した
      （バンドルID `com.namiki.soccermanager`）
- [ ] IPA をアップロードし、TestFlight にビルドが出たことを確認した
- [ ] App プライバシーで「識別子 > デバイス ID」を
      「サードパーティ広告」の目的で申告した
- [ ] アプリ内課金の商品を登録した（IDを1文字も違えないこと）。**いま画面から
      売っているのはサポーターの1件だけ**（`lib/widgets/supporter_section.dart`）
      - `soccer_manager_supporter`（**非消費型**）
      - 資金パック3件（`soccer_manager_funds_small` / `soccer_manager_funds_medium` /
        `soccer_manager_funds_large`、**消費型**）は 1.2.0 で画面から外した。
        **新しく登録しない。** App Store Connect に既にある分は、コードが
        ストアから届いた購入を受け取れるように残してある（承認待ちや、落ちて
        届き損ねたぶん）。販売を止めるかどうかはストアの画面で決める
- [ ] 「購入の復元」導線が動くことを確認した（審査要件）
      ※ 復元で戻るのは非消費型のサポーターのみ
- [ ] 年齢制限レーティングのアンケートに回答した
- [ ] サポートURL・マーケティングURLを登録した
- [ ] キーワード（100字以内）を上記から転記した
- [ ] レビュー用メモに、ゲーム内の「融資」「スポンサー契約」が実際の金銭を
      伴わない架空のゲーム内経済である旨を記載した
- [ ] 輸出コンプライアンスの申告が求められないことを確認した
      （`Info.plist` の `ITSAppUsesNonExemptEncryption=false` で自動回答される）

### 注意

- Android の applicationId と iOS のバンドルIDは、どちらも
  `com.namiki.soccermanager` で揃えてある。iOS のバンドルIDはアンダースコアを
  使えないため、それを含まない名前にした。
- このIDは**公開後は変更できない**。初回提出前に確定させること。
