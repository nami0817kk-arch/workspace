# 材料の控え: アルテタ、アーセナルで2030年まで。プレミア最高給の中身（シリーズ「クラブの財政」、2026-10-08 公開予定、取材 10/8）

**この回の主題は「プレミアで最も高い監督の給料の中身」**：契約の基礎DATA（公式が出したのは期限だけ）→
報じられた額を円に直す（convert）→ ほかの監督と在任年数で並べる（scatter）→ 見立て（7季の順位と勝ち点の表＋勝率の式）。

前の回で言ったもの（言い直さない）:
- 10/7 公開 finance_mancity（research/raw/20261007_finance_mancity.md）: 罰の重さをめぐる声・リーグの規則（W.63／W.64／B.6）・
  前例の減点の表（ミドルスブラ／ポーツマス／エヴァートン／フォレスト／チェルシー）・キャラガーの言葉・「件数で38倍」。
  → **シティが出てくるのは「グアルディオラが昨季で退いた」「いま首位」の2点だけ**にして、判決・罰の話には触れない。
- 10/3 公開 finance_barcelona: 上限・放映権・スタジアム。ユーロの換算の言い回しは重ねない。

取り方: Python の urllib / requests で本文を取り、HTML のタグを落として読んだ。Wikipedia・Commons は公式 API（User-Agent にチャンネルのURL）。
為替は frankfurter.app（ECB の参照相場）。WebSearch は URL を探すだけで、要約は根拠にしない。**ブラウザの道具は使っていない。**

## 一次情報（突き合わせた文書）

| 何 | URL | 使ったところ |
|---|---|---|
| The Guardian 10/7 12:13 BST（Ed Aarons） | https://www.theguardian.com/football/2026/oct/07/mikel-arteta-signs-new-arsenal-deal-only-the-beginning | 見出し「£80m-plus」、"a four-year deal worth more than £20m a season, making him the best-paid Premier League manager"、"The new deal, to June 2030"、前契約 "worth about £10m a season plus a £5m bonus for reaching the Champions League"、"ended their 22-year wait"、"three successive runners-up finishes"、"took over from Unai Emery in December 2019"、"the Premier League's longest-serving manager after the departure of Pep Guardiola"、"the 44-year-old"、本人・クローンキー親子の言葉、"His coaching staff have also signed extended deals"、"face Leeds on Saturday"、"a surprise 3-0 defeat at Brighton ... ended the champions' 100% start" |
| BBC Sport 10/7 12:00 BST（Alastair Telfer / Sami Mokbel） | https://www.bbc.co.uk/sport/football/articles/crz65j5p8l57o | 見出し「signs new contract until 2030」、"Atletico Madrid boss Diego Simeone is reportedly paid over £20m per year, as was former Manchester City manager Pep Guardiola - both of whom Arteta benchmarked his worth against"、"an increase from his current salary of £10m per year plus an additional £5m in bonuses"、ガーリック（CEO）の言葉、"Guardiola's departure from City at the end of last term made Arteta the longest-serving manager in the English top flight"、"The 44-year-old has won a Premier League and FA Cup in charge of Arsenal, losing the Champions League final against Paris St-Germain in May" |
| Sky Sports 10/7 12:46 UK | https://www.skysports.com/football/news/11661/13590915/mikel-arteta-contract-arsenal-boss-signs-new-deal-to-extend-stay-at-premier-league-champions | "existing contract ..., signed in September 2024, was due to expire next summer"、"committed his future to the club until June 2030"、"their first Premier League title in 22 years last season following three straight second-place finishes"、"only their second Champions League final, which they lost on penalties to Paris Saint-Germain"、"He has also won an FA Cup and three Community Shields"、"the longest-serving manager in England's top-four leagues"、本人とガーリックの声明全文、"Only four managers - Sir Alex Ferguson, Pep Guardiola, Jose Mourinho and Arsene Wenger - have won the Premier League title more than once" |
| Sky Sports 10/7 12:20 UK（「step five」の回） | https://www.skysports.com/football/news/11661/13595720/mikel-artetas-new-contract-the-challenges-facing-arsenal-boss-as-he-enters-step-five-of-his-project | "he's on his fourth contract and he's 44 years old"、"If he's still in charge of Arsenal in 2029, he will have overtaken Jurgen Klopp's spell at Liverpool. If he's in there in 2030, he will have overtaken Pep's time at Manchester City"、5段階の計画（文化→選手→挑戦→勝つ→王朝） |
| Premier League 公式 10/7 | https://www.premierleague.com/en/news/4729976/arteta-signs-new-arsenal-contract-all-you-need-to-know | 「2030年6月まで」。額には触れていない |
| ESPN 10/7 | https://www.espn.com/soccer/story/_/id/50004993/mikel-arteta-signs-new-arsenal-contract | 「4年契約、2030年まで」。額には触れていない |
| アーセナル公式（X、10/7 20:20 JST） | https://x.com/Arsenal/status/2107793135464231393 | "Mikel Arteta has signed a new contract at The Arsenal"（クラブ自身の発表。**額は出していない**） |
| BBC Sport 10/7 19:30 BST（ライスの記事） | https://www.bbc.co.uk/sport/football/articles/c9gkvx74je7do | "the club's best earner Bukayo Saka, who is believed to be paid about £350,000 a week"、ライスは "reported £240,000-per-week"、"Arteta's new four-year deal ... was announced on Wednesday"、"host Leeds in the English top flight on Saturday (12:30 BST)" |
| フットボールチャンネル 10/8（The Guardian・The Times を引用元として名乗る） | https://www.footballchannel.jp/2026/10/08/post1029420/ | 「2030年6月まで」「総額8000万ポンド（約168億円）を超え」「年俸は最大2500万ポンド（約52億5000万円）」「前契約は約1200万ポンド（約25億2000万円）に、最大300万ポンド（約6億3000万円）のボーナス」 |
| football365 10/7 12:30（報じられた年俸の一覧） | https://www.football365.com/news/who-are-best-paid-premier-league-managers-de-zerbi | 「These are all based on reports」。アルテタ £20m（＝£10m＋CLの£5m の現行）／アロンソ（チェルシー）£13m／グラスナー（フォレスト）£13m／デ・ゼルビ（トッテナム）£12m／マレスカ（シティ）£12m／イラオラ（リヴァプール）£10m／エメリ（ヴィラ）£9.5m／カリック（ユナイテッド）£6.5m／ヤイスレ（ニューカッスル）£6m／モイーズ（エヴァートン）£5m／ランパード（コヴェントリー）£5m。グアルディオラは退任前 £20m |
| Wikipedia 英語版 Mikel Arteta（出典は Soccerbase、9月19日時点） | https://en.wikipedia.org/wiki/Mikel_Arteta | 就任 2019年12月22日（発表は12月20日、12月21日のエヴァートン戦はリュングベリが指揮）。通算 361試合 220勝 67分 74敗。タイトル：プレミア 2025-26／FAカップ 2019-20／コミュニティシールド 2020・2023・2026。準優勝：CL 2025-26（PSGにPK戦）・EFLカップ 2025-26 |
| Wikipedia 英語版 List of Arsenal F.C. seasons | https://en.wikipedia.org/wiki/List_of_Arsenal_F.C._seasons | リーグ順位と勝ち点：2019-20 8位56／2020-21 8位61／2021-22 5位69／2022-23 2位84／2023-24 2位89／2024-25 2位74／**2025-26 1位85**（26勝7分5敗、71得点27失点） |
| Wikipedia 英語版（監督の就任日） | Unai Emery / Enzo Maresca / Andoni Iraola / Xabi Alonso / Roberto De Zerbi | エメリ＝アストン・ヴィラ 2022年11月1日（発表は10月24日）／マレスカ＝シティ 2026年6月29日／イラオラ＝リヴァプール 2026年6月4日／アロンソ＝チェルシー 2026年7月1日／デ・ゼルビ＝トッテナム 2026年3月31日 |
| frankfurter.app（ECB 参照相場、2026-10-07） | https://api.frankfurter.app/latest?from=GBP&to=JPY | **1ポンド＝208.93円**。台本では「1ポンド＝209円」で計算する |
| 順位の控え（自分で取ったもの、9月28日・第5節終了時） | research/standings/2026-09-28.json | シティ 5勝0分0敗 勝ち点15 で1位、アーセナル 4勝0分1敗 勝ち点12 で2位 |

## 一次情報の原文（引くところ）

- アルテタ（アーセナル公式の声明。Sky・Guardian が同じ文を載せている）
  - "It's a privilege to commit my future to the club and to continue to work with exceptional people who want the best for Arsenal."
  - "This club is unique, its character and the way it makes you feel, and I have a great sense of privilege that our journey together will continue."
  - "We have already built a special bond and created memories that will last a lifetime, and what is so exciting is that this is only the beginning of what we can achieve together."
  - "I'm extremely grateful to Stan and Josh for their trust and support, and feel honoured to be leading this club through such a special period in its 140-year history."
  - "This is such a proud moment for me and my family. I feel the love and respect from our fantastic supporters, and they have mine - and ours - in return."
- リチャード・ガーリック（アーセナルのチーフエグゼクティブ）
  - "This is an important time in Arsenal Football Club's history. We want to create a winning era together with Mikel."
  - "Mikel is the only manager that's won the Premier League that's currently managing [in it]."（BBC）
  - "You look at all the other teams in the sort of traditional top six, and they've all gone through managerial changes."（BBC）
  - "We can't stand still. We can't sit there, pat ourselves on the back, and say job done."（BBC）
- スタン＆ジョシュ・クローンキー（共同会長）
  - "It has been an incredible journey so far and we are excited for what lies ahead in this special relationship."
  - "We share a special bond with Mikel. We are so proud of everything we have achieved since he returned to the club in 2019."

訳は台本側に置いた（意味を変えずに短く割る）。

## 自分で計算したもの（台本の数字）

- **為替**：1ポンド＝209円（2026年10月7日の ECB 参照相場 208.93 を丸めた）
  - 2500万ポンド × 209 = **52億2500万円 → 約52億円**
  - 1500万ポンド × 209 = 31億3500万円 → 約31億円
  - 8000万ポンド × 209 = 167億2000万円 → 約167億円
  - 35万ポンド（サカの週給、報道）× 52週 = **1820万ポンド**／× 209 = 38億380万円 → 約38億円
- **前の契約の上限**：Guardian・BBC は「1000万＋ボーナス500万」、The Times（フットボールチャンネル経由）は「1200万＋最大300万」。
  **合計の上限はどちらも1500万ポンドで一致する**ので、台本では「前の契約は、ボーナスを入れて最大1500万ポンド」とだけ言う。
  内訳が割れていることは画面にも読み上げにも出さない（媒体の食い違いの話はしない決まり）。
- **倍率**：2500万 ÷ 1500万 = 1.667 → **約1.7倍**／勝ち点 85 ÷ 61 = 1.393 → **約1.4倍**
- **勝率**：220勝 ÷ 361試合 = 0.6094 → **61%**（9月19日時点）
- **在任の長さ**（2026年10月8日時点、年に直して小数1桁）
  | 監督 | 就任 | 在任 | 報じられた年俸（百万ポンド） |
  |---|---|---|---|
  | アルテタ（アーセナル） | 2019-12-22 | 6.8年 | 25（新契約の上限） |
  | エメリ（アストン・ヴィラ） | 2022-11-01 | 3.9年 | 9.5 |
  | デ・ゼルビ（トッテナム） | 2026-03-31 | 0.5年 | 12 |
  | マレスカ（マンチェスター・シティ） | 2026-06-29 | 0.3年 | 12 |
  | イラオラ（リヴァプール） | 2026-06-04 | 0.3年 | 10 |
  | アロンソ（チェルシー） | 2026-07-01 | 0.3年 | 13 |
  - 年俸はどれもクラブが発表していない（報道）。アルテタだけ新契約の上限、ほかは今季の数字。
    台本では「報じられている年俸」と断り、**どの媒体かは言わない**
- **リーグ順位の伸び**：2020-21 は勝ち点61で8位、2025-26 は85で1位 → **勝ち点＋24、順位は7つ上**
- 2019-20 は8位・勝ち点56。ただし12月22日の就任で、季の途中からなので表には入れず語りで1行だけ触れる

## 確かめられなかったこと

- **額はクラブが発表していない。**アーセナル公式・プレミアリーグ公式・ESPN は期限（2030年6月）しか出していない。
  8000万ポンド超・最大2500万ポンドはどちらも報道。確度は「報道」で通す
- The Times の原文は購読が要るので読めていない（額はフットボールチャンネルが引用元として名乗っている形と、Guardian の「£20m超/年・総額£80m超」で突き合わせた）
- ほかの監督の年俸は、一覧を出している側も「報じられた額」と断っている。クラブの公表は無い
- **ネットの反応は置いていない。**Bluesky の公開APIが 403 で読めず、海外のファンの投稿を取れなかった。
  日本語の投稿（Yahoo!リアルタイム検索）だけで組むと「海外の反応を必ず混ぜる」（2026-09-17）に反するので、反応の節ごと置かない
  （シリーズの回は反応が無くてもよい。10/3 のバルセロナの回と同じ扱い）
- 361試合・220勝は Soccerbase の集計（Wikipedia 経由）で、クラブの公表ではない。9月19日までの数字

## 写真

| ファイル | 出どころ | ライセンス | 中身 |
|---|---|---|---|
| 01.jpg（01_w / 01_v） | Commons `File:Mikel Arteta 2021.png` | CC BY 3.0 / Prime Video AU & NZ | アーセナルの監督としてのアルテタ（上半身・正面）。facecrop で 16:9 と 9:16 を切った |
| 02.jpg | Commons `File:1 arsenal crystal palace epl champions 2026.jpg` | CC BY-SA 4.0 / Chensiyuan | 2026年5月24日、セルハースト・パークでプレミアのトロフィーを掲げるアーセナル。背景の幕に「CHAMPIONS 2025/26」 |
| 03.jpg | Commons `File:1 josh stan kroenke 2026.jpg` | CC BY-SA 4.0 / Chensiyuan | 同じ日、トロフィーを運ぶスタンとジョシュのクローンキー親子 |

代理店（Getty・AFLO・AFP・ロイター・IMAGO・AP・PA・Lusa・EPA）の写真は使っていない。記事の写真はどれも代理店だったので当たっていない。

## サムネ

構図は `number`（年俸の数字を主役に、●で伏せる）。写真は 01_w.jpg（アルテタの顔、横長）。
直前2本（10/7 マンC・10/7 FIFAランキング）の構図と見比べて選んだ理由は報告に書く。
