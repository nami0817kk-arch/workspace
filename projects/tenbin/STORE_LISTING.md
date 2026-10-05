# もじつみ / Moji Stack — ストア掲載文の下書き（iOS・iPhone のみ）

2026-10-05 作成。名前は 2026-10-04 にユーザーが決めた（CLAUDE.md「名前」）。公開名義は「つるはし社」。個人名は入れない。
競合の強さ（iTunes Search API で上位10の評価数を見る、護送ボートの STORE_LISTING.md の方法）は、作った環境から API に届かず**まだ測っていない**。
公開前に手元で測って、キーワード欄を入れ替える。

## 名前・サブタイトル・キーワード

| 項目 | 日本語 | English (US) |
|---|---|---|
| 名前（30字まで） | もじつみ：ひらがな積み上げ ことばパズル（20字） | Moji Stack: Hiragana Tower（26字） |
| サブタイトル（30字まで） | くっつけて言葉を作る脳トレ バランスゲーム（21字） | Stack letters, make words |
| キーワード（100字まで） | 積み木,タワー,物理,文字,単語,言葉遊び,しりとり,脳トレ,暇つぶし,てんびん,バランス,知育,語彙,日本語,オフライン | japanese,hiragana,kana,word,puzzle,stack,tower,physics,balance,learn,vocabulary,offline |
| ホーム画面の名前 | もじつみ | Moji Stack |

- 英語の名前は、2026-10-04 に決めた「Moji Stack: Hiragana Word Tower」が31字で30字を超えるため、「Word」を外した（「Word」はサブタイトルとキーワードで拾う）
- 名前とサブタイトルに入れた語は、キーワード欄に重ねない（Apple は名前・サブタイトル・キーワードを組み合わせて検索に当てる）
- 「しりとり」は遊びが違うので、入れるかどうかは測ってから決める（似た遊びを探す人には当たるが、期待と違うと評価が下がる）

## 説明文（日本語）

ひらがなを1字ずつ積んで、くっついた字で「ことば」を作るパズルです。

■ 遊び方
・指でなぞって字を動かし、はなすと落ちます。「まわす」で回してから落とせます
・字と字が触れ合っていれば、たて・よこ・右から左・下から上、どの向きでも読めたら ことば になります
・2字で100点、3字で400点、4字で900点。長いことばほど大きく、1字で同時にいくつもできると倍に
・持っている字とことばになる字は光り、落とす先でできそうなことばも「ねこ ？」と教えてくれます
・台から字が落ちたら おしまい。高く、たくさん積んで、さいこう記録を目指しましょう

■ 6つの台と景色
ふつうの台（庭）・てんびん（神社）・さか（茶畑）・ふたつ（川）・ゆらゆら（海）・せまい（雪山）。
台ごとに景色が変わり、積むほど空が夕焼けから夜へ移っていきます。

■ ことば帳
作ったことばは「ことば帳」に集まります（2000語以上）。集めた数で、新しい台と字の色がひらきます。

■ アイテム（あり／なしを選べます）
のり（くっつく）・いた（平らな板）・とりけし（最後の字をどける）・こおり（いまの字を固める）。

■ そのほか
・通信なしで遊べます
・崩れたあと、動画を見て1回だけ「つづける」ことができます
・「広告を消す」（買い切り）で、全画面広告が出なくなり、つづける・アイテムも動画なしで使えます

## Description (English)

Stack hiragana letters one by one and make Japanese words with the letters that touch.

- Drag to move a letter, release to drop it. Rotate before dropping.
- Touching letters that read as a word — in any direction — score points. Longer words score more.
- Six stages with their own Japanese scenery: a garden, a shrine with a seesaw, a tea field, a river, the sea and a snowy mountain.
- Collect over 2,000 words in your word book to unlock new stages and letter colors.
- Optional items: glue, board, undo and freeze.
- Works offline. The game is in Japanese.
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
英語版の掲載画像は日本語のまま（ゲームが日本語のため）。

## 課金アイテム

| 製品ID | 種類 | 表示名 | 説明 | 価格 |
|---|---|---|---|---|
| mojitsumi_remove_ads | 非消耗型 | 広告を消す / Remove Ads | 全画面広告が出なくなり、つづける・アイテムも動画なしで使えます / No full-screen ads; continue and items without videos | **ユーザーが決める**（仮に370円） |
