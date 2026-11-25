# もじつみ / Moji Stack — ストア掲載文の下書き（iOS・iPhone のみ）

2026-10-05 作成。名前は 2026-10-04 にユーザーが決めた（CLAUDE.md「名前」）。公開名義は「つるはし社」。個人名は入れない。
競合の強さ（iTunes Search API で上位10の評価数を見る、護送ボートの STORE_LISTING.md の方法）は、作った環境から API に届かず**まだ測っていない**。
公開前に手元で測って、キーワード欄を入れ替える。

## 名前・サブタイトル・キーワード

| 項目 | 日本語 | English (US) |
|---|---|---|
| 名前（30字まで） | もじつみ：ひらがな積み上げ ことばパズル（20字） | Moji Stack: Hiragana Tower（26字） |
| サブタイトル（30字まで） | くっつけて言葉を作る脳トレ バランスゲーム（21字） | Learn Japanese by stacking（26字） |
| キーワード（100字まで） | 積み木,タワー,物理,文字,単語,言葉遊び,しりとり,脳トレ,暇つぶし,てんびん,バランス,知育,語彙,日本語,オフライン | japanese,kana,romaji,vocabulary,word,puzzle,game,study,language,learning,physics,balance,offline（96字） |
| ホーム画面の名前 | もじつみ | Moji Stack |

- 英語の名前は、2026-10-04 に決めた「Moji Stack: Hiragana Word Tower」が31字で30字を超えるため、「Word」を外した（「Word」はサブタイトルとキーワードで拾う）
- **2026-11-25 英語の欄を「日本語を学ぶ人向け」に書き直した**（ゲームに英語・ローマ字・ことばの英語の意味を入れたため）。
  英語のサブタイトルとキーワードは、ひらがなを読めない人が探す語（learn japanese・romaji・vocabulary・study）に寄せた。
  名前の Hiragana は「ひらがなを学びたい人」の検索語でもあるので残す
- 名前とサブタイトルに入れた語は、キーワード欄に重ねない（Apple は名前・サブタイトル・キーワードを組み合わせて検索に当てる）
- 「しりとり」は遊びが違うので、入れるかどうかは測ってから決める（似た遊びを探す人には当たるが、期待と違うと評価が下がる）

## 説明文（日本語）

ひらがなを1字ずつ積んで、くっついた字で「ことば」を作るパズルです。

■ 遊び方
・指でなぞって字を動かし、はなすと落ちます。「まわす」で回してから落とせます
・字は五十音に、が・ぱ などの濁点・半濁点と、小さい っ・ゃ・ゅ・ょ を合わせた74字。がっこう・きょう も作れます
・字と字が触れ合っていれば、たて・よこ・右から左・下から上、どの向きでも読めたら ことば になります
・2字で100点、3字で400点、4字で900点。長いことばほど大きく、1字で同時にいくつもできると倍に
・持っている字とことばになる字は光り、落とす先でできそうなことばも「ねこ ？」と教えてくれます
・台から字が落ちたら おしまい。高く、たくさん積んで、さいこう記録を目指しましょう

■ 6つの台と景色
ふつうの台（庭）・てんびん（神社）・さか（茶畑）・ふたつ（川）・ゆらゆら（海）・せまい（雪山）。
台ごとに景色が変わり、積むほど空が夕焼けから夜へ移っていきます。

■ ことば帳
作ったことばは「ことば帳」に集まります（約4,000語）。集めた数で、新しい台と字の色がひらきます。

■ アイテム（あり／なしを選べます）
のり（くっつく）・いた（平らな板）・とりけし（最後の字をどける）・こおり（いまの字を固める）。

■ そのほか
・通信なしで遊べます
・崩れたあと、動画を見て1回だけ「つづける」ことができます
・「広告を消す」（買い切り）で、全画面広告が出なくなり、つづける・アイテムも動画なしで使えます

## Description (English)

Learn hiragana and Japanese words by stacking them.

Hiragana letters drop one at a time. Stack them on the stage, and when touching letters spell a Japanese word, you score — and see its reading and meaning.

- Every letter shows its romaji, so you can play before you can read kana.
- Make a word and it pops up with romaji and English: ねこ — neko — cat.
- Touching letters count in any direction: top to bottom, left to right, even backwards.
- Nearly 4,000 everyday words — animals, food, nature, verbs and adjectives — with kanji and English meanings, from the JMdict dictionary.
- All 74 hiragana you need: the basic kana plus が, ぱ and small っ ゃ ゅ ょ — so you can build がっこう (gakkou, school) and きょう (kyou, today).
- Your word book keeps every word you find, with kanji and meaning. Collect more to unlock new stages and letter colors.
- Review mode quizzes you on the words you collected: see the English meaning, pick the right hiragana.
- Every letter and word can be read aloud in a Japanese voice, so you learn the sounds as you play.
- Six stages with Japanese scenery: a garden, a shrine with a seesaw, a tea field, a river, the sea and a snowy mountain.
- Turn romaji off when you can read the letters yourself.
- Optional items: glue, board, undo and freeze.
- Works offline. English and Japanese.
- "Remove Ads" (one-time purchase) removes full-screen ads and unlocks the rewarded features without videos.

## 掲載画像（`marketing/screenshots/`、`node tool/screenshots.js`）

| 順 | 見出し | 中身 |
|---|---|---|
| 1 | 字を くっつけて ことばに しよう | ことばができた瞬間（ねこ・あたらしいことば！） |
| 2 | たて・よこ・逆さでも 読めたら ことば | 落とす前の「ねこ ？」の案内 |
| 3 | 台は6種類 | てんびん（じんじゃ） |
| 4 | 高く積むほど 空が 夕焼けから夜へ | 高く積んだ塔 |
| 5 | 集めたことばで 台と字の色が ひらく | ことば帳 |

検索結果に出るのは先頭3枚なので、はじめの画面・起動画面は撮らない（docs/app-pitfalls.md 4番）。
英語版の掲載画像は、**英語の画面（ローマ字と意味つき）で撮り直す**（2026-11-25 にゲームを英語に対応させた。まだ撮っていない）。

## 課金アイテム

| 製品ID | 種類 | 表示名 | 説明 | 価格 |
|---|---|---|---|---|
| mojitsumi_remove_ads | 非消耗型 | 広告を消す / Remove Ads | 全画面広告が出なくなり、つづける・アイテムも動画なしで使えます / No full-screen ads; continue and items without videos | **ユーザーが決める**（仮に370円） |

## App Store Connect のそのほかの欄（2026-10-17）

| 欄 | 入れるもの |
|---|---|
| カテゴリ | 主: ゲーム、副: パズル。ゲームのサブカテゴリは「ワード」と「パズル」 |
| 著作権 | 2026 つるはし社 |
| サポート URL | https://mojitsumi.pages.dev/support.html |
| マーケティング URL | https://mojitsumi.pages.dev/ （app-ads.txt をここのドメインで読ませる） |
| プライバシーポリシー URL | https://mojitsumi.pages.dev/privacy.html |
| 年齢区分 | ユーザーが答える（広告「あり」。ほかは無し。4+ の見込み） |
| 価格 | 無料（課金アイテムの値段はユーザーが決める） |
| 配信地域 | すべて（日本語と英語。英語は日本語を学ぶ人向け） |
| バージョン | 1.0（ビルドは app/pubspec.yaml の 1.0.0+1） |
| 審査メモ | docs/RELEASE.md の「審査に出すときに書くこと」をそのまま |
