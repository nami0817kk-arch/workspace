# シリーズごとの情報元（2026-10-15 時点の整理）

チャンネル「海外サッカーの理由」の本編シリーズが、**いま実際にどこから数字・事実・写真を取っているか**を並べた。
シリーズの一覧の正は CLAUDE.md「10月のシリーズの並べ直し（2026-10-08…）」。この文書は読み取りだけで作った（外には出ていない）。

**書き方の約束**
- 確認済み … 道具のコード（`ファイル:行`）か、実際の取材メモ・`credits.json` で裏が取れたもの
- 記述のみ … CLAUDE.md や docstring に書いてあるが、コードや実物では確かめていないもの
- 不明 … どちらにも無い。推測では埋めない

## 0. 先に知っておくこと（全シリーズ共通）

**確度の上限は `config/sources.yaml` の `domain_tiers`**（群ごと。`src/plan.py:166` の `ceiling` が引く）。

| 群 | 上限 | 主なサイト |
|---|---|---|
| official / official_jp | 確定 | クラブ・リーグ・連盟の公式（premierleague.com, laliga.com, uefa.com, fifa.com, jfa.jp, 各クラブ） |
| english / japanese / 現地語（german, italian, french, dutch, portuguese, spanish, ukrainian）/ aggregator | 報道 | BBC, Sky, ESPN, kicker, Marca, ゲキサカ ほか |
| stats | 報道 | transfermarkt.*, fotmob.com, fbref, sofascore, whoscored |
| social / rumour | 未確認 | x.com（ロマーノだけ確定）、まとめサイト、タブロイド |

- **この表に載らないサイトは、上限が空（「網に無い」）になる。** シリーズで多用している
  **Wikipedia・SEC（sec.gov）・Deloitte・Companies House・historicalkits・web.archive.org・ECB/frankfurter は `sources.yaml` に1つも無い**（`grep` で確認）。
  取材メモの `tier:` は人が手で付けている（財政の回は確定5・報道1・背景1）
- 4段階の確度は 確定／報道／未確認／背景。「背景」は数字の根拠にしない説明用の置き場
- **FotMob の API（`www.fotmob.com/api/data`）と Transfermarkt の API（`tmapi-alpha.transfermarkt.technology`）は、どちらも公開ドキュメントの無い内部API。**
  コードに「壊れたら例外で止まる」と明記（`tools/fotmob_player.py:3`・`tools/scorers.py:3`・`tools/match_numbers.py:3`）。取れなくなる危険を常に抱える
- **日本語名の辞書が要る**：選手は `research/kana/players.json` ＋ Wikidata の日本語ラベル（`tools/player_pool.py:5`、`tools/scorers.py:86`）、
  クラブは `config/clubs.yaml`、20クラブ紹介は `research/<リーグ>_data/kana.json`（`tools/plbuild.py:197-200`）。辞書に無い名前は雛形の頭に英語のまま出る（`tools/scorers.py:13`）
- **写真の権利の3段**：①Commons の自由ライセンス（CC0/BY/BY-SA）＝`src/portrait.py`・`tools/stadiumbg.py`・`tools/plfaces.py`。
  ②報道写真・クラブ公式の写真＝`tools/pressphoto.py`・`tools/photopool.py`・`tools/articlephoto.py`。**「許諾は得ていない／出どころを明示して使用」と `credits.json` に書かれ、権利は晴れていない**（`tools/pressphoto.py:6-14`）。
  ③自作（板・図・地図の描画）。エンブレムは別枠で、`src/crest.py:3` に「権利は晴れていない」。放送映像は使わない（`tools/pressphoto.py:21`）

## 1. 定番シリーズ（毎日の8枠）

### 1-1 クラブ紹介（プレミア20・ラ・リーガ20は出済み／残りが進行中、ブンデス18は材料あり、セリエAは道具に未登録）

| 項目 | 内容 |
|---|---|
| ①何を作る | 基礎DATA（9行の板）→ そのクラブの話 → 名選手 → 登録選手一覧 → 今季のここまで。`tools/plbuild.py`（`CLUB_LEAGUE=` で切替） |
| ②出どころ | **英語版 Wikipedia の原文が土台**（確認済み）：登録選手と生年月日 `tools/plsquad.py:28`（`en.wikipedia.org/w/index.php?action=raw`）、代表出場 `tools/plclubcaps.py:46`、日本人の在籍歴 `tools/pljapan.py:55`、基礎DATAの板は「下請けが Wikipedia 原文から調べた」（`tools/plbuild.py:14`）。座標・地図は Wikipedia と Commons の白地図（`tools/plmap.py:33,65`）。今季の結果は ESPN（`tools/plbuild.py:761`、`tools/llresults.py:37` の `site.api.espn.com`）。ラ・リーガは材料の下請け資料に Marca・西語版 Wikipedia・クラブ公式が加わる（`research/ll_data/*_research.md` の出典集計で en.wikipedia 327・es.wikipedia 52・marca 45） |
| ③確度の上限 | Wikipedia は群に無い（上限空）。ESPN・Marca は報道。クラブ公式（valenciacf.com など）は確定だが、実際に引けたのは一部だけ（下記⑤） |
| ④写真 | 顔＝Wikipedia 記事の代表画像のうち Commons の自由ライセンスだけ（`tools/plfaces.py:11-17`）。クラブ時代の写真は名指しの Commons ファイル（`tools/clubfaces.py`）。下地＝本拠地の Commons 写真（`tools/stadiumbg.py`）またはエンブレム（`tools/crestbg.py`。権利は晴れていない）。地図は自作＋Commons 白地図 |
| ⑤弱点 | クラブ公式サイトが JavaScript 描画で取れないクラブがある（アラベス `ll_data/alaves_research.md`）。シーズン記事の無いクラブは試合結果が欠けた（ESPN で補う目的で `llresults` を作った。`tools/llresults.py` の docstring）。優勝回数は Honours 節の機械読みを**捨てた**（6クラブが0回になった。`tools/pltrophies.py` の docstring）。infobox の出場数はリーグ戦のみ（`tools/plclubcaps.py` の docstring）。**セリエAは `tools/clubleague.py` に未登録**（premier／laliga／bundesliga の3つのみ） |
| ⑥一次情報 | **届きにくい。**土台が Wikipedia（二次）。クラブ公式は読み上げの根拠として引けたクラブだけ。数字は「原文どおり」で、食い違いは両方書く運用（`alaves_research.md` 冒頭） |

### 1-2 選手紹介（8節の型。市場価値の順）

| 項目 | 内容 |
|---|---|
| ①何を作る | 基礎DATA→歩んできた道→今季の数字→プレースタイル（レーダー・シュートマップ）→見立て。`tools/player_pool.py`（人選）→`tools/player_intro.py`（雛形） |
| ②出どころ | **Transfermarkt が中心**（詳細・市場価値の推移・大会別の数字。`tools/player_intro.py:33`、API は `tools/japan_abroad.py:28`）。人選の物差しも Transfermarkt の市場価値（`tools/player_pool.py:6`）。プレースタイルは **FotMob の選手データ**（`tools/fotmob_player.py:36`）。日本語名は Wikidata（`tools/player_pool.py:40`）。エピソード・本人の言葉は取材メモで報道から（`tools/player_intro.py` の docstring「数字はすべて Transfermarkt。出典はその選手のページ1本」） |
| ③確度の上限 | stats 群＝報道。成績の節は 報道 で書くと明記（`player_intro.py` docstring） |
| ④写真 | 顔写真は人が記事か Commons から取る（`player_intro.py` docstring）。実物では **Commons（CC BY-SA）と、BBC・マンチェスター・シティ公式など報道・クラブ公式の写真が混在**（`assets/images/20261014_anderson/*/credits.json`。報道分は「許諾は得ていない」） |
| ⑤弱点 | 2つの内部API頼み。名前の表記が日本の媒体とズレる人は上書き辞書が必要（ホランド→ハーランド、`tools/player_pool.py:7`）。**Transfermarkt の更新頻度（月1など）の記述はコードにも CLAUDE.md にも見つからなかった＝不明** |
| ⑥一次情報 | 数字は Transfermarkt（二次集計）止まり。本人の発言は取材メモ側で報道に当たる。公式の一次（クラブの声明）まで辿るかは回による |

### 1-3 スタジアム紹介

| 項目 | 内容 |
|---|---|
| ①何を作る | 本拠地の歴史・収容・移転の経緯。板は `clubdata` を流用 |
| ②出どころ | 取材メモの出典集計（`research/20261009〜20261014_stadium_*.yaml`）：en.wikipedia.org が最多（45）、web.archive.org、ESPN API、BBC、プレミアリーグの公式データ（`pulselive.com`）、footballgroundguide.com、地方自治体・大学・地元団体のページ、クラブ公式（inter.it） |
| ③確度の上限 | Wikipedia・web.archive.org・footballgroundguide は群に無い。BBC・ESPN は報道。取材メモの `tier` は 報道2・背景2（ブライトン回） |
| ④写真 | Commons（CC0／BY／BY-SA）。20クラブぶんは `tools/stadiumbg.py`（「報道写真を使う必要がない」と明記 `:9`）。回ごとに `assets/images/<日付>_stadium_*/credits.json` |
| ⑤弱点 | 収容数・年は資料で食い違いやすい（取材メモで下請けが両方書く運用）。Commons に無い角度は撮れない |
| ⑥一次情報 | 自治体の計画資料・クラブ公式まで辿った回がある（ブライトン回の出典）。常にではない |

### 1-4 比べる（選手／クラブ／同じ年齢）

| 項目 | 内容 |
|---|---|
| ①何を作る | 2人（2クラブ）の基礎DATA（2列）→ 今季の数字→市場価値の歩み→見立て。`tools/player_compare.py`。**どちらが上かは言い切らない** |
| ②出どころ | 選手紹介と同じ材料（Transfermarkt の www と API、`tools/player_compare.py:78`）。取材メモ実物（`20261014_compare_*`）では Transfermarkt 38＋API 27、ESPN API 14、FotMob 6、クラブ公式（asmonaco.com など） |
| ③確度の上限 | 報道（stats 群） |
| ④写真 | 2人の顔を並べる。Commons（CC0 など。`20261014_cmp_baleba/credits.json`）を使い、2人を並べた画像は `pairphoto` で自作 |
| ⑤弱点 | 選手紹介と同じ（内部API・日本語名辞書）。順位付けは「自分で数えた数字」だけ（CLAUDE.md「シリーズに型を足す」ア） |
| ⑥一次情報 | 数字の元は Transfermarkt／ESPN。**公式の試合記録まで辿ってはいない（記述のみ：試合の分は Opta／ESPN で確かめる決まり）** |

### 1-5 クラブの財政

| 項目 | 内容 |
|---|---|
| ①何を作る | 決算を順に追う（売上→本業の利益→最終損益→借入）。再生・視聴時間が最も高い型 |
| ②出どころ | **決算書の原文**：マンチェスター・U 回は SEC 提出の 20-F（`www.sec.gov` 23件）・四半期決算 6-K・Deloitte Football Money League（`deloitte.com`）・Companies House（英国法人登記）・為替は ECB の参照相場（`api.frankfurter.app`、`data-api.ecb.europa.eu`）。バルサ・レアルはクラブ公式の決算、`assets.laliga.com`（リーグの公開資料）。1件ごとに千ポンド単位の原数値から自分で計算（`research/20261014_finance_manutd.yaml` 冒頭） |
| ③確度の上限 | sec.gov・deloitte・companies house はいずれも `sources.yaml` に無い（上限空）。実際は人が `tier: 確定` を付けている（同ファイルに確定5） |
| ④写真 | スタジアム等の Commons 写真（CC BY-SA／CC0。同ファイル78行目の記述） |
| ⑤弱点 | 決算の締め日が各社で違う。Deloitte の次の版は2027年1月で、順位は1年前の数字になる。プレミアの配分の公式表が見つからない回があった（同ファイルの「×」）。為替は日付を固定して言う |
| ⑥一次情報 | **届く。**財政は全シリーズで最も一次寄り（提出書類の原文） |

### 1-6 記録の解説

| 項目 | 内容 |
|---|---|
| ①何を作る | 得点・出場・連勝・最年少・移籍金などの記録の成り立ち。板は `versus` など |
| ②出どころ | 取材メモの出典集計（`20261009〜20261014_record_*`）：en.wikipedia.org が圧倒的（70）、englandfootball.com（22）、ESPN API、UEFA、プレミアリーグ、Yahoo（海外・日本）、クラブ公式 |
| ③確度の上限 | Wikipedia は群に無い。UEFA・プレミア・FA 系は確定、Yahoo は aggregator＝報道（`sources.yaml` の aggregator 注記：元がどこかを見る） |
| ④写真 | Commons（例：2004年ハイバリーの優勝セレモニー、CC BY-SA 2.5。`20261014_unbeaten/trophy/credits.json`） |
| ⑤弱点 | 記録の定義（公式戦か リーグ戦か）で数字が変わる。Wikipedia 依存が高い |
| ⑥一次情報 | リーグ・協会の公式（premierleague.com, uefa.com, englandfootball.com）まで引ける回が多い（取材メモの出典から確認） |

### 1-7 ユニフォームとエンブレムの歴史（新規）

| 項目 | 内容 |
|---|---|
| ①何を作る | キットとクラブ章の変遷を年代順に |
| ②出どころ | 取材メモの出典集計（`20261009〜20261014_kit_*`）：en.wikipedia.org（16）、クラブ公式（chelseafc.com 13 など）、**historicalkits.co.uk（11）**、web.archive.org（8）、Guardian・BBC、twtd.co.uk、紋章学協会（theheraldrysociety.com）、SEC（スポンサー契約） |
| ③確度の上限 | クラブ公式は確定、Guardian・BBC は報道、historicalkits・twtd・Wikipedia・web.archive.org は群に無い |
| ④写真 | Commons のキット着用写真（`20261014_kit_chelsea/credits.json` で CC0 など）。クラブのエンブレム画像そのものは `src/crest.py`（権利が晴れていない扱い） |
| ⑤弱点 | **古いキットの正確な年代は愛好家サイト（historicalkits）頼み**になりやすい。エンブレムは商標で、Commons に無い年代がある |
| ⑥一次情報 | クラブ公式の発表まで辿れる回がある。過去の年代は二次資料止まり |

### 1-8 移籍の深掘り（新規。1つの移籍／1クラブの移籍期間）

| 項目 | 内容 |
|---|---|
| ①何を作る | 移籍金の歴代上位、または1クラブの今夏の収支 |
| ②出どころ | 取材メモの出典集計（`20261009〜20261014_transfer_*`）：**transfermarkt.com が最多（34）**、クラブ公式（liverpoolfc.com 12 ほか）、ECB 為替、goal.com、FotMob、Sky、SI |
| ③確度の上限 | Transfermarkt＝報道（stats）。クラブ公式の発表は確定 |
| ④写真 | Commons（CC BY-SA。バルコラの2026年7月の写真、アンフィールドの空撮。`20261014_transfer_liverpool_window/credits.json`） |
| ⑤弱点 | **移籍金は Transfermarkt の推定が混じる**（クラブが公表しない額がある）。為替の換算日を固定する必要。手作業で台帳（`research/ll_data/pl_transfers_2026.txt` 等）を作る |
| ⑥一次情報 | クラブ公式の発表まで届く移籍と、届かない移籍がある（額は特に）。**「届かない額を何で言ったか」は回ごとに手で確認が必要＝一律には不明** |

## 2. 随時のシリーズ

| シリーズ | 道具 | 数字・事実の出どころ（確認済み） | 確度の上限 | 写真 | 既知の弱点 |
|---|---|---|---|---|---|
| 週報（欧州組の1週間） | `tools/japan_abroad.py week` | **Transfermarkt の試合記録 API**（`:28`）。名簿は `config/japan_abroad.yaml`（手で48人。`:36` の EXTRA は検索ページで確認した番号） | 報道（stats） | 人が記事／Commons から取る | 名簿は手更新。大会の対応表が足りないと数えられない（`COMPETITIONS`） |
| 順位表 | `tools/standings_week.py` | **FotMob の順位表**（`src/standings.py:24`）。台本にする段で各リーグ公式の順位表URLを `sources` に足す（`src/standings.py:195-202`＝premierleague.com, laliga.com, bundesliga.com, legaseriea.it, ligue1.com）。「先週比」は自分の控え（`research/standings/`）との差 | 取得は報道、公式URLまで足せば確定 | 自作の板（`assets/stats/`） | 先週比は前の控えが無いと「―」。ただし順位表の企画は 10/8 に「やらない」と決定済み |
| 試合の数字 | `tools/match_numbers.py` | **FotMob の試合詳細**（`:35,128`）。スコア・得点者は「台本にする段でリーグ公式まで辿る」運用（`:5-9`）。分は Opta／ESPN で確認する決まり（CLAUDE.md 1298行目付近） | 報道→公式で確定 | 記事の写真（`photopool`）または Commons | 内部API。FotMob と公式で1分ずれることがある（記述のみ） |
| 得点王レース | `tools/scorers.py` | **FotMob のリーグ統計**（`:3-9`。PK内訳・出場時間つき）。日本語名は Wikidata（`:40,86`） | 報道（stats） | 自作の棒グラフ | 内部API。辞書にない名前は英語のまま |
| 月間まとめ | `tools/monthly.py` | 手元の控え（順位・得点王）＋日本人の1か月だけ Transfermarkt（`:128,131`）。「今月の出来事」は `research/covered.yaml`（自分が扱った話題の記録） | 報道 | 回ごと | 話題の選択が自分の過去記録に依存（外部の基準は無い） |
| 監督の経歴 | 道具なし（手）。`tools/plmanagers.py` はプレミアの監督の顔写真だけ | 取材メモ実物：ESPN・maxifoot・Transfermarkt・Wikipedia（ジダン回）、**JFA（jfa.jp, jfa.or.jp）・rsssf・ゲキサカ・ja.wikipedia**（トルシエ回） | 日本代表の経歴は JFA＝確定。外国人の経歴は報道止まり | 顔＝Commons（`plmanagers.py:3-5`） | 道具が無く、回ごとに出典が違う |
| 代表紹介 | 道具なし（手。`tools/clubdata` の板を流用） | ブラジル・NZ 回：**FotMob、JFA、`api.fifa.com`、nzfootball.co.nz、kirin.co.jp**（取材メモの出典） | JFA・FIFA は確定、FotMob は報道 | Commons／記事 | FIFA の API は公開ドキュメント未確認（**不明**）。相手国側の一次は国ごとに探す |
| 仕組みの解説 | 道具なし（`python -m src.cli plan --routine explain` が計画の雛形） | 召集規定の回：**digitalhub.fifa.com（FIFA の規程原文）11件**、FotMob、Transfermarkt、AFC、プレミア、rfef.es | FIFA・AFC・リーグは確定 | 自作の図 | 規程は版が変わる。日付を必ず言う |

## 3. 情報元の抜け・偏り

**単一サイト・内部API依存**
- **FotMob の内部API**に、順位表・得点王・試合の数字・選手のプレースタイル・日本人の次の相手が乗っている（`src/standings.py:24`, `src/results.py:25`, `tools/fotmob_player.py:36`）。公式ドキュメントが無く、壊れると5つの道具が同時に止まる。公式URL（`src/standings.py:195-202`）を足すのは台本の段で、取得の代替にはなっていない
- **Transfermarkt（www と tmapi-alpha）**に、選手紹介・比べる・週報・移籍・月間まとめが乗っている（`tools/player_pool.py`, `player_intro.py`, `japan_abroad.py`, `monthly.py`）。人選の物差し（市場価値）も同じサイト。取れない日の代わりが道具の中に見当たらない（記述のみ：kabutan のような取得停止の前例が CLAUDE.md にあり、Transfermarkt は大丈夫という保証は無い）
- **英語版 Wikipedia**が、クラブ紹介（40クラブぶん）の基礎DATA・登録選手・結果の土台（`tools/plsquad.py:28` ほか）。ラ・リーガは出典集計で en.wikipedia 327件・es.wikipedia 52件。編集で変わる二次資料で、`sources.yaml` の確度の枠にも入っていない

**一次情報に当たれないところ**
- クラブ紹介の基礎DATA：クラブ公式が JavaScript 描画で取れないことがある（アラベス）。数字は Wikipedia の食い違いを両記して運用
- 選手紹介・比べる：数字は Transfermarkt 止まり（公式の試合記録の原本まで辿る手順はコードに無い）
- ユニフォーム：過去年代は愛好家サイト（historicalkits）頼み
- 移籍の額：クラブが公表しない額は Transfermarkt の推定になる

**確度の枠から外れた出どころ**
- `sources.yaml` に **Wikipedia・SEC・Deloitte・Companies House・historicalkits・web.archive.org・ECB／frankfurter・footballgroundguide** が無い。シリーズの主力出典なのに、`draft` の確度の上限チェック（`src/plan.py:166`）が効かない（空になる）。群へ足すか、「網に無い」を許す運用かは、ユーザー判断の余地（この文書では決めない）

**権利の危うい出どころ**
- **報道写真・クラブ公式写真・エンブレム**：「許諾は得ていない」と明記して使っている（`tools/pressphoto.py:6-14`、`src/crest.py:3`、`assets/images/20261014_anderson/bbc/credits.json`）。申し立てが3回でチャンネル削除のリスクを引き受ける判断（ユーザー決定。CLAUDE.md／`pressphoto.py`）。選手紹介と短い動画に出やすく、**スタジアム・ユニフォーム・財政は Commons で足りる回が多い**
- **被写体の取り違え**：`--who` は「人がそう言った」控えにすぎず、`photopool` は透かし・本人かを機械で確かめられない（`tools/photopool.py` docstring）。一覧を目で見る運用に頼る
- **Yahoo 経由の記事**は警告が出ない（`docs/series_brief.md` の「事実」節）。元記事を開く運用

**ユーザーが決めて除外しているもの（偏りではなく方針）**
- 女子サッカー、Jリーグ、日本人の次の相手・欧州カップの相手紹介（作らない）、ブラウザで JavaScript を実行して集める方法（禁止）。

## 4. 「不明」とした項目
- Transfermarkt の市場価値・詳細ページの更新頻度（月1などの記述）
- `api.fifa.com` の公開ドキュメントと利用条件（代表紹介で出典に出ているが、道具では呼んでいない）
- 移籍の深掘りで、クラブが公表しない額を何で補っているか（回ごとで一律でない）
- セリエA版のクラブ紹介の道具・出典（`tools/clubleague.py` に未登録）
- 随時シリーズ（監督の経歴・代表紹介・仕組みの解説）の「写真の出どころ」の標準（道具が無く回ごとに違う）
