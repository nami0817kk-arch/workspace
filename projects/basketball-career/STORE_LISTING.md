# バスケ育成 / Basketball Career — ストア掲載文の下書き（iOS のみ）

2026-10-19 作成。公開名義は「つるはし社」。本名・nami・0817 は入れない（`docs/public-identity.md`）。
**まだ提出していない。** 文面はユーザーが見て直してから App Store Connect に入れる。

## 注意（先に読む）

- **App Store Connect は一部の記号を「無効な文字」として弾く**（護送ボートの提出で確認済み）。★ ■ … ―― • — を使わない。
  見出しは日本語【】、英語 [ ]、箇条書きは「・」と「-」にする。
- **リーグ名・チーム名・選手名・大会名は架空。** 実在の名称（NBA・Bリーグ・ウィンターカップなど）を掲載文・画像・キーワードに入れない（商標）。
  「バスケ」「バスケットボール」は一般名称なので使ってよい。
- 競合の強さ（上位10アプリの評価数）を測っていない。護送ボートと同じ手順（iTunes Search API）で測ってから、サブタイトルとキーワードを決め直す余地がある。
  名前に「バスケ」が入るので、バスケ系の検索には当たる。大手のスポーツゲームが強いはずなので、「育成」「一代記」「シミュレーション」「ライバル」で差別化する。

## 名前・サブタイトル・キーワード

| 項目 | 日本語 | English (US) |
|---|---|---|
| 名前（30字まで） | バスケ育成：6歳から始める選手物語（17字） | Basketball Career: Rise Up（26字） |
| サブタイトル（30字まで） | 身長と才能と運で決まる一代記（14字） | Raise a player from age 6（25字） |
| キーワード（100字まで） | バスケットボール,シミュレーション,部活,ライバル,プロ,海外,ミニバス,オフライン,一人用,成長,スポーツ,放置,育てる | sports,sim,manager,coach,training,rival,pro,overseas,offline,story,hoops,player,grow,life,career |

- 名前とサブタイトルに入れた語（バスケ・育成・選手・物語・身長・才能・運・一代記／Basketball・Career・Rise・Raise・Player・age）はキーワード欄に重ねない。
- ホーム画面の表示名は「バスケ育成」（日本語）／「Basketball Career」（英語）（`ios/Runner/*.lproj/InfoPlist.strings`、登録済み）。
- 英語版を出すかはユーザーの判断。このアプリは**画面が日本語のみ**（英語の画面は未実装）。英語の掲載情報を出すなら、画面の英語化が先。
  いまは**日本語だけで出す**のが筋（配信国を日本に絞るか、英語の掲載情報は付けない）。

## カテゴリ・年齢

ゲーム ＞ スポーツ（主）、ゲーム ＞ シミュレーション（副）。年齢区分は 4+ を目指す（暴力・賭け事・成人向けの表現なし。広告は全年齢向けに限る設定）。

## プロモーションテキスト（170字まで・審査なしで差し替えられる）

6歳から選手を育て、引退までを見届ける一代記。身長と才能と運が行き先を決める。勝負どころは自分で選ぶ。ライバルとの戦い、進路、海外挑戦まで。

## 説明文（日本語）

6歳の少年（少女）がバスケットボールを始める。ミニバス、中学、高校、そして進路。
プロになるのか、大学で力をつけるのか、海を渡るのか。ひとりの選手の一生を、あなたが育てる。

【身長と才能と運が行き先を決める】
成長期に伸びる身長、持って生まれた素質、そして運。同じ練習をしても、同じ人生にはならない。
身長が高いほどゴール下で有利、低いほどドリブルとスピードで有利。ポジションは身長と得意なプレーから自動で決まる。

【季節ごとの選択】
1年は春夏秋冬の4回。練習・特訓・研究・練習試合・交流・休養から選ぶ。
伸ばす能力を決めて、疲れと気持ちと怪我に気をつけながら、チームワークとコーチとの信頼も育てよう。同じ練習ばかりだとマンネリで伸びが落ちる。

【勝負どころは自分で決める】
夏と冬の大会は勝ち抜き。点差が3点以内で終わりそうなら「勝負どころ」。ドライブ、3P、パス、ディフェンス。成功率を見て、最後のプレーを自分で選ぶ。

【ライバル、進学、移籍、そして海外へ】
同じ時代を走るライバルが、準決勝で毎年立ちはだかる。進学先を選び、プロ契約を勝ち取り、チームを移り、世界に挑む。
外れたら大学や実業団からもう一度。どんな結末も、ひとつの物語。

【育てた選手は殿堂へ】
引退すると称号がつき、実績が解除される。実績が増えるほど、次の選手は少し強い状態で始められる。結果は短い文章にして共有もできる。

・リーグ、チーム、選手、大会の名前はすべて架空です
・オフラインで遊べます（広告と購入の確認には通信が必要）
・広告つき。「広告を消す」（買い切り）で、全画面広告が出なくなり、回復も動画なしで使えます

## English description（日本語のみで出すなら使わない）

[Raise one player from age 6 to retirement]
Mini-basketball, junior high, high school, and then the big choice: turn pro, grow at university, or cross the ocean. Your player's whole life is in your hands.

[Height, talent and luck decide the road]
Height grows in the teen years, talent is born with you, and luck does the rest. Taller players shine near the rim; shorter ones win with dribbling and speed. Your position is decided by your height and your strengths.

[Four seasons a year]
Train, push hard, study, scrimmage, hang out, or rest. Watch fatigue, morale and injuries. Build team chemistry and trust with your coach. Repeating the same drill makes you stale.

[You make the clutch call]
Tournaments are single elimination. When the game is within 3 points at the end, choose the last play yourself: drive, three, pass or defend, with the odds in front of you.

[Rivals, schools, transfers and overseas]
A rival stands in your way almost every year. Pick your school, win a pro contract, switch teams, challenge the world. If you miss, try again from university or the corporate league.

All leagues, teams, players and tournaments are fictional. Contains ads. The in-app purchase Remove Ads turns off full-screen ads and lets you recover without watching videos.

## スクリーンショット（6.9インチ縦、最初の3枚が検索結果に出る）

1. 「6歳から、ひとりの選手を育てる」 … 育成画面（コートの絵・成長のグラフ・能力）
2. 「勝負どころは、自分で選ぶ」 … 勝負どころの画面（成功率つきの4択）
3. 「ライバルとの対決」 … 向かい合う2人の絵（ライバル戦の勝負どころ）
4. 「年のはじめに目標を決める」 … 目標カードと、過ごし方の選択
5. 「称号と殿堂」 … エンディング（称号・通算・成長の軌跡）

**撮るときの決まり**（`docs/app-pitfalls.md` #4・Apple 2.3.2・2.3.7）:
- 読み込み中の画面を撮らない。撮るたびに `CircularProgressIndicator` が無いこと・文字が一定数あることを検査する。
- タイトル画面は撮らない（何ができるゲームかを伝えない）。広告を消していない状態で撮り、値段（¥370）を写さない。
- 実在の名称（リーグ・チーム・選手）を絵に入れない。

## 審査メモ（App Review Information）

- 登録・ログイン・サーバーはない。ゲームの進み具合は端末の中だけに保存される。
- 広告は Google AdMob（全年齢向けに限る設定・追跡の許可は求めない）。広告を消すのは買い切りの非消費型（商品ID `basketball_career_remove_ads`、370円）。復元の導線は設定画面にある。
- リーグ・チーム・選手・大会の名前はすべて架空。実在の団体・人物とは関係がない。
- 賭け事・現金の景品・ランダムな課金（ガチャ）はない。

## アプリのプライバシー（App Store Connect の答え。護送ボートと同じ形）

- 開発者はデータを収集しない。広告のために Google（AdMob）が端末の識別子・広告の操作などを取得する（開発者は受け取らない）。
- 追跡（ATT）は使わない。広告識別子（IDFA）は渡さない。
- 子ども向けではない。広告の内容は全年齢向けに限る。
- 正確な答えは、提出時に `ios-app-release` スキルと護送ボートの `docs` の記録を見て合わせる。

## 配信する国

日本のみから始めるのが安全（画面が日本語のみ・AdMob の同意画面 UMP が要る国を避ける）。広げるときは護送ボートの「配信する国」の決め方に合わせる。
