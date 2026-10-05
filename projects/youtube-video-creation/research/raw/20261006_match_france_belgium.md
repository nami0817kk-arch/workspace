# 材料の控え: フランス 4-1 ベルギー（2026-10-05、UEFAネーションズリーグ A1 第4節、サン＝ドニのスタッド・ドゥ・フランス）

シリーズ「数字で見る注目試合」（research/20261005_match_portugal_norway.yaml と同じ名前）。key: match_france_belgium。
取り方: python requests（UEFA の試合API・順位API・先発API・チーム数字API、FotMob の matchDetails、各紙の本文の段落、レキップの RSS）・WebSearch。ブラウザは使っていない。
数えた時点: 2026-10-06 朝（日本時間）。
雛形は `python tools/match_numbers.py --date 2026-10-06 --match 5181794` で作り、research/20261006_match_5181794.yaml を key に合わせて改名した。板は assets/stats/match_20261005_5181794.png（道具が書いたもの）。

## 1. スコア・得点者・時間（UEFA 公式まで辿った → 確定）

UEFA の試合API: https://match.uefa.com/v5/matches?fromDate=2026-10-05&toDate=2026-10-05&limit=100&offset=0&order=ASC
- 試合 id 2047937（https://www.uefa.com/uefanationsleague/match/2047937--france-vs-belgium/ ）
- League A Group A1、MD4、FINISHED。kickOff 2026-10-05T18:45:00Z（現地20:45、日本時間10/6 3:45）、Stade de France、観客 75,389
- score total home 4 - away 1
- scorers: FIRST_HALF 35:12 Dodi Lukébakio（Belgium）／SECOND_HALF 77:51 Désiré Doué／81:13 Rayan Cherki／88:48 Michael Olise／90+1（90:07）Michael Olise
- 先発（lineups API https://match.uefa.com/v5/matches/2047937/lineups ）: フランス Restes、Koundé、Camavinga、Dembélé、Koné、Barcola、Diouf、Yoro、Lacroix、Akliouche、Lepaul（監督 Zinédine Zidane）。控えに Cherki・Olise・Doué・Da Cunha・Rabiot など／ベルギー Vandevoordt、Mechele、Lavia、Lukaku、Lukébakio、Ngoy、Seys、Moreira、Vanaken、Castagne、Raskin（監督 Mark van Bommel）
- UEFA のチーム数字（https://matchstats.uefa.com/v1/team-statistics/2047937 ）: 支配率 61/39、シュート 24/5、枠内 9/2、パス成功 622/299（90%/81%）、CK 9/2、走行距離 111.6/114.7km。**FotMob と少しずれる（支配率 66/34、シュート 23/5）。交代の前後を分けるのに FotMob のシュート一覧を使うので、表は FotMob にそろえた**

順位（UEFA standings API https://standings.uefa.com/v1/standings?groupIds=2014191 ）

| 順位 | チーム | 試合 | 勝 | 分 | 敗 | 得 | 失 | 勝点 |
|---|---|---|---|---|---|---|---|---|
| 1 | フランス | 4 | 3 | 1 | 0 | 7 | 2 | 10 |
| 2 | イタリア | 4 | 2 | 1 | 1 | 8 | 5 | 7 |
| 3 | ベルギー | 4 | 2 | 0 | 2 | 6 | 5 | 6 |
| 4 | トルコ | 4 | 0 | 0 | 4 | 2 | 11 | 0 |

グループの日程（UEFA matches API competitionId=2014 groupId=2014191）
- 9/25 トルコ 0-1 フランス（コジャエリ）／イタリア 0-2 ベルギー
- 9/28 ベルギー 0-1 フランス（ブリュッセル）
- 10/2 フランス 1-1 イタリア（サン＝ドニ）
- 10/5 フランス 4-1 ベルギー（サン＝ドニ）／イタリア 3-1 トルコ
- 次: **11/12 イタリア対フランス（ミラノ、19:45Z＝現地20:45）**、**11/15 フランス対トルコ（ボルドー、19:45Z）**。ベルギーは 11/12 トルコ戦（イズミル）、11/15 イタリア戦（ブリュッセル）
- 上位2つが準々決勝（10/5 の回と同じ仕組み）。**準々決勝はまだ決まっていない**（イタリアがトルコに勝ったため。titrespresse に載った見出し「pourrait être entérinée en Italie lors de la prochaine journée」）
- **自分で数えた**: ミラノで引き分け以上なら2位以内が決まる。フランス11点のとき、イタリアは最大11（ベルギーに勝つ→ベルギーは最大9）、ベルギーが最大12のときイタリアは8。どちらの組み合わせでも2チームがフランスを上回れない

## 2. 交代と得点の流れ（FotMob matchDetails 5181794 の events）

- 60分 Olise ← Dembélé、Cherki ← Akliouche／61分 Da Cunha ← Koné／72分 Doué ← Barcola／88分 Rabiot ← Camavinga
- ベルギー 70分 Godts ← Lukébakio、De Ketelaere ← Lukaku／87分 3人
- 得点とアシスト: 35分 Lukébakio（Lavia）／77分 Doué（Da Cunha）／81分 Cherki（Olise）／88分 Olise（Doué）／90+1分 Olise（Doué）
- → **フランスの4点は、得点もアシストもすべて途中出場の4人**（Yahoo Sports/Bulinews「Only those four supersubs were involved with direct contributions in four goals scored since the 77th minute mark」）
- オリーセとドゥエは4点すべてに絡む（77分ドゥエの得点、81分オリーセのアシスト、88分・90+1分はドゥエ→オリーセ）

## 3. 交代の前と後（FotMob の shotmap から数えた）

| | 0〜59分 | 60分〜終了 |
|---|---|---|
| フランスのシュート | 15本 | 8本 |
| フランスの xG | 0.80 | 1.20 |
| 1本あたりの xG | 0.053（約5%） | 0.150（約15%） |
| フランスの得点 | 0 | 4 |
| ベルギーのシュート | 4本（xG 0.55、1点） | 1本（xG 0.04） |

- 60分から後のフランスの8本のうち7本が途中出場（オリーセ4・シェルキ2・ドゥエ1。残り1本は72分のバルコラ）
- 得点のシュート: ドゥエ 77分 xG 0.04（エリアの外、左足）／シェルキ 81分 0.30（エリア内）／オリーセ 88分 0.18（エリア内）／オリーセ 90+1分 0.49（エリア内）

試合全体（FotMob）: 支配率 66%/34%、xG 2.00/0.59、シュート 23/5、枠内 8/2、決定機 3/1、パス成功 625(90%)/287(79%)、デュエル勝ち 38/41

途中出場の4人（FotMob の選手の数字）

| 選手 | 出場 | 得点 | アシスト | 評点 |
|---|---|---|---|---|
| オリーセ | 60分〜（30分） | 2 | 1 | 9.15（両チーム最高） |
| ドゥエ | 72分〜（18分） | 1 | 2 | 8.77（2番目） |
| シェルキ | 60分〜（30分） | 1 | 0 | 7.95 |
| ダ・クーニャ | 61分〜（29分） | 0 | 1 | 7.61 |

- オリーセ: シュート4本（枠内3）、xG 0.76、xA 0.45、敵陣のペナルティエリア内でのタッチ 9、タッチ 42
- ドゥエ: シュート1本、パス10本すべて成功、決定機を作ったパス2（Big chances created 2）、タッチ18
- 先発でいちばん高い評点はヨロの 8.23（初めての代表戦。footeo）

## 4. ジダン体制の4試合（UEFA の日程と上の結果）

| 日付 | 相手 | 場所 | 結果 |
|---|---|---|---|
| 9/25 | トルコ | 敵地 | 1-0 |
| 9/28 | ベルギー | 敵地 | 1-0 |
| 10/2 | イタリア | ホーム | 1-1 |
| 10/5 | ベルギー | ホーム | 4-1 |
| 計 | | | 3勝1分、7得点2失点、勝ち点10 |

- 3試合で3点 → この1試合で4点
- オリーセは4試合で4得点2アシスト（Yahoo Sports/Bulinews「Olise scored four goals and assisted twice in France's first four games under Zidane」）。7点のうち6点に絡んだ（トルコ戦はムバッペへのアシスト、10/3 の回で言った）
- ホームで初めての勝利（Al Jazeera/Reuters「Zinedine Zidane secured his first home win in charge」）
- 先発は前の試合から10人を替えた（La Provence の会見の問い「trois jours après un match, vous avez procédé à dix changements dans le onze de départ」）。ジダン「quatre équipes différentes et compétitives」

## 5. 試合後の言葉

- ジダン（会見。La Provence 2026-10-05 22:02）https://www.laprovence.com/article/sports/3897202379035114/equipe-de-france-je-suis-tres-optimiste-pour-la-suite-annonce-zinedine-zidane-apres-son-premier-rassemblement
  > "Il nous a peut-être manqué de la percussion dans nos 25-30 derniers mètres, chose qui nous a manqué de toute façon dans nos trois matches (quatre en réalité, ndlr). Et c'est vrai que quand on a égalisé, ça a été un tout autre match."
  > （オリーセは今の世界最高か）"Je n'ai rien à dire, c'est juste exceptionnel ce qu'il fait !"
  > "Ce qui n'était pas évident, c'était justement de faire quatre équipes différentes et compétitives."
  > "Sur le plan comptable, déjà sur les quatre matchs, on a dix points. C'est assez bien."
  > "Il va falloir qu'on occupe plus la surface de réparation."
- オリーセ（TF1。Maxifoot）https://www.maxifoot.fr/france/olise-apprecie-les-idees-de-zidane-foot-465149.htm
  > "Je pense que c'est un collectif aussi. Il amène des idées, on les suit. Là, on a bien fait les quatre matchs, donc on va continuer comme ça"
  （同じ言葉の見出し: レキップ https://www.lequipe.fr/Football/Actualites/Michael-olise-apres-la-victoire-de-la-france-contre-la-belgique-zidane-ramene-des-idees-on-les-suit/1723675 。requests は 403）
- ドゥエ（TF1。Foot Mercato）https://www.footmercato.net/a322584739654565112-equipe-de-france-la-reaction-ravie-de-desire-doue
  > "On avait à coeur de gagner ce dernier match. C'est une belle prestation, on a tous été concernés. C'est important de continuer comme ça. Ce n'est jamais facile de marquer surtout contre ce genre d'équipe qui défend bien. On a des joueurs de grand talent dans cette équipe, c'est magnifique"
- 使わなかったもの: footmercato の「Je ne sais même pas ce que j'ai fait」は 9/28 ブリュッセルの試合の話（10/5 ではない）。footeo の「Notre deuxième période, avec les changements, a été extraordinaire」は La Provence の書き起こしに無いので使わない。レキップ「オリーセが29試合で10得点10アシスト、コパ以来の速さ」は通算の話なので使わない（10/3 の紹介の回と重ねない）

## 6. 試合の流れ（報道）

- Goal.com（英）https://www.goal.com/en-us/lists/france-belgium-nations-league-comeback/blt0946771c48059ccd
  > "Lavia sliced open the French defense with a pinpoint pass, releasing Dodi Lukebakio one-on-one with Guillaume Restes"
  > "In a decisive triple substitution, he introduced Michael Olise, Rayan Cherki, and Lucas Da Cunha."
  > "Desire Doue ... received a pass from Da Cunha, turned brilliantly on the edge of the box, and buried a low left-footed drive into the corner."
  > "Olise drove down the right flank with purpose before cutting the ball back to Cherki at the near post. The substitute's first-time strike took a deflection off Vandevoordt's foot and arm"
  > "Doue and Olise linked up with a sequence of intricate one-touch passing in a tight space on the edge of the area"
- Al Jazeera（Reuters）https://www.aljazeera.com/sports/2026/10/5/super-subs-help-france-demolish-belgium-with-late-flurry
- Yahoo Sports（Bulinews）https://sports.yahoo.com/articles/uefa-nations-league-olise-shines-210200394.html
- footeo 採点 https://news.footeo.com/2026/10/05/france-belgique-les-notes-des-bleus-avec-olise-homme-du-match-dembele-a-la-peine-13890

## 7. 反応（X の個人の投稿。Yahoo!リアルタイム検索「ジダン 交代」「オリーセ」→ api.fxtwitter.com で全文）

使ったもの（台本の順）
- IiIuzivert7（2026-10-05 20:33 UTC）https://x.com/IiIuzivert7/status/2107207473841238058
  > ドゥエ、シェルキ、オリーセ
  > 後半で交代切った奴らが全員決めるのヤバすぎる
  > ジダンの采配力半端ないしもうこれ勝てる国おらんレベルじゃね？今
- uribou0725（20:27 UTC。81分の逆転のころ）https://x.com/uribou0725/status/2107206028907684159
  > 交代選手で逆転された……
  > 現時点の選手層の厚さでは、ベルギーとフランスではまだ差があるな
- juuuun1228（22:01 UTC）https://x.com/juuuun1228/status/2107229823005561036（short_voice）
  > この完成度のオリーセとドゥエがまだ若手扱いなの、フランス強すぎるやろ
- 30字を超える行は、句読点か意味の切れ目で行を分けただけ（言葉は変えていない。cont: true）

候補に残したが使わなかったもの
- gunya15 https://x.com/gunya15/status/2107211051985232277 （「４ー１」の表記が読み上げで崩れるため）
- MY_Soccer_Sp https://x.com/MY_Soccer_Sp/status/2107209913588183364 （「4-1」が「よん、いち」と読まれるため）
- 外したもの: 実況アナウンサーの投稿（nishitatsuhiko）、メディアのアカウント（SoccerKingJP・DAZN_JPN・ABEMA_soccer・TakaharaKiyoshi の DAZN News 転載）、確かめられない数字を含む投稿（k11B04「210分3G2A」）

## 8. 写真（すべてレキップの写真部の撮影。RSS https://dwh.lequipe.fr/api/edito/rss?path=/Football/ の alt に表記。代理店ではない）

- 01.jpg: "Les Bleus ont changé de visage après l'heure de jeu. (F.Faugere/L'Equipe)" 記事 1723670。開いて見た: 20番ドゥエの背中、左に21番ダ・クーニャ、同点弾のあとの輪。透かし無し
- olise/01.jpg: "Entré à la 60e minute, Michael Olise a délivré une passe décisive et inscrit un doublé. (P. Lahalle/L'Équipe)" 記事 1723676。開いて見た: 11番オリーセが両手を広げて走る
- doue/01.jpg: "Désiré Doué est entré en jeu et a marqué cinq minutes plus tard. (A. Réau /L'Équipe)" 記事 1723667。開いて見た: 20番ドゥエが両手を広げる
- zidane/01.jpg: "Zinédine Zidane et Michael Olise lors de France - Belgique, lundi soir. (P. Lahalle/L'Équipe)" 記事 1723696。開いて見た: ジダンとオリーセがタッチライン脇、左に21番ダ・クーニャ（交代の前）。_v は --center 0.74 で2人を残した
- cherki/01.jpg: "Rayan Cherki a marqué le but du 2-1 pour la France. (P. Lahalle/L'Équipe)" 記事 1723669。9番シェルキ、右に15番ヨロ
- lukebakio/01.jpg: "Dodi Lukebakio a ouvert la marque après 35 minutes de jeu. (F. Faugère /L'Équipe)" 記事 1723660。白のユニホームでひざをつく
- 各フォルダの _w・_v は tools/facecrop.py、_w_v は _v の写し（10/5 の回と同じ）。01_w は `--top 0.156` で切り直した（題の帯が顔にかかったため）。zidane/01_v は `--center 0.74`
- doue/01_t.jpg: 01.jpg から顔を上に寄せて切った縦（677x762）。表の行（右に立てる）とサムネの2枚目に使う。ショート用に 01_t_v.jpg（01_v.jpg の写し）
- 表のある行は、中央に人が写る横長の写真だと表が顔を覆ったので、縦の写真（olise/01_v・cherki/01_v・zidane/01_v・doue/01_t）を右に立てた（tools/preview4.py を全行で回して確かめた）
