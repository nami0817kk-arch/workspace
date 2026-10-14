# ブラジル代表の紹介（代表チームの紹介。2026-10-06 取材）

11/14(土) MIZUHO BLUE CHALLENGE THE KALLANG FOOTBALL SERIES SINGAPORE（シンガポールナショナルスタジアム）で日本と対戦する相手。
道具は requests・WebFetch・WebSearch だけ（ブラウザの道具は使っていない）。検索のAI要約は根拠にしていない（数字は FIFA・JFA・FotMob の記録と記事本文で当てた）。
CBF の公式サイト（cbf.com.br）は証明書の都合で requests でも WebFetch でも読めなかった（"unable to verify the first certificate"）。CBF の発表は英語版Wikipedia が引く CBF の記事名と、報道で代えた。

重ねない相手:
- 9/10 の「ブラジル」の回（scripts/20260910_brazil.md：W杯から17人入れ替え・チアゴ・シウヴァの反対・アンチェロッティの「34歳や35歳の選手には長期的な未来がない」）→ 17人・世代交代の言い方・チアゴ・シウヴァは使わない
- 10/6 の森保監督の回（scripts/20261006_coach_moriyasu.md：2025年10月に14試合目で初勝利・W杯32強で1-2）→ 対戦の節は言い方を変えた
- 10/6 の FIFAランキングの回（明日に回した）→ ランキングは基礎DATAの1行（7月20日発表の5位）だけ。ライブの6位・11月の増える点は言わない

## 1. 大会と日程（JFA）
https://www.jfa.jp/samuraiblue/20261117/about.html
- 「2026年11月14日(土) SAMURAI BLUE vs ブラジル代表」「会場 シンガポールナショナルスタジアム（シンガポール）」
- 「※各試合90分で終了し、延長戦、PK戦は行わない。後半終了時点でスコアが同点の場合、試合結果は引き分けとなる。」

## 2. FIFAランキング・日本との対戦成績（JFA 参加国の対戦チーム情報）
https://www.jfa.jp/samuraiblue/20261117/team_info.html
- 「◇FIFAランキング（2026年7月20日更新）：5位」「◇過去の日本代表との対戦成績：1勝12敗2分（9得点39失点）」（シンガポールの欄が「21勝2分3敗」で日本側から見た書き方なので、ブラジルの欄も日本側から見て1勝2分12敗）
- 日本は17位（同じ7月20日の回。research/raw/20261006_fifa_ranking.md の 0. と 3.）

## 3. 日本とブラジルの対戦（JFA）
- 初対戦 1989年7月23日 リオデジャネイロ 国際親善試合 ブラジル 1-0 日本（ビスマルク 74分）http://samuraiblue.jp/timeline/19890723/
- 2025年10月14日 東京スタジアム キリンチャレンジカップ2025 日本 3-2 ブラジル。JFA 見出し「SAMURAI BLUE、後半の3得点でブラジル代表に逆転、14戦目で歴史的な初勝利」https://www.jfa.jp/samuraiblue/20251014/
  - FotMob 4947213: ブラジル 26分 パウロ・エンリケ、32分 マルティネッリ／日本 52分 南野、62分 中村敬斗、71分 上田 → 0-2 から3点
- 2026年6月30日 FIFAワールドカップ2026 ●1-2 ブラジル ヒューストン(アメリカ)／ヒューストンスタジアム（JFA 2026年の日程と結果 https://www.jfa.jp/samuraiblue/schedule_result/2026.html ）

## 4. W杯2026（FIFA 公式の試合データ）
カレンダー https://api.fifa.com/api/v3/calendar/matches?idSeason=285023&idCompetition=17&count=200&language=en
| UTC | 日本時間 | 段階 | 試合 | 会場 |
|---|---|---|---|---|
| 6/13 22:00 | 6/14 | 1次 | ブラジル 1-1 モロッコ | ニューヨーク/ニュージャージー |
| 6/20 00:30 | 6/20 | 1次 | ブラジル 3-0 ハイチ | フィラデルフィア |
| 6/24 22:00 | 6/25 | 1次 | スコットランド 0-3 ブラジル | マイアミ |
| 6/29 17:00 | 6/30 | 32強 | ブラジル 2-1 日本 | ヒューストン |
| 7/5 20:00 | 7/6 | 16強 | ブラジル 1-2 ノルウェー | ニューヨーク/ニュージャージー |
| 7/19 19:00 | 7/20 | 決勝 | スペイン 1-0 アルゼンチン（延長。FotMob 4653858 "AET"） | ニューヨーク/ニュージャージー |

- 日本戦 https://api.fifa.com/api/v3/live/football/17/285023/289287/400021516 : 日本 29' 佐野海舟／ブラジル 56' カゼミーロ、90'+5' ガブリエル・マルティネッリ。主将 マルキーニョス（4）。監督 Carlo Ancelotti。入場 68,777
  - FotMob 4653711: 保持 69-31、シュート 19-5、枠内 7-2、xG 2.07-0.33。56分のアシストはガブリエウ（マガリャンイス）、90+5分はブルーノ・ギマランイス
- ノルウェー戦 https://api.fifa.com/api/v3/live/football/17/285023/289288/400021532 : ハーランド 79'・90'、ネイマール 90'+10'。主将 マルキーニョス
- モロッコ戦 400021456: サイバリ 21'、ヴィニシウス 32'。主将 マルキーニョス
- グループの得点（FotMob 4667764・4667767・4667768）: ハイチ戦 クーニャ 23'・36'、ヴィニシウス 45+3'／スコットランド戦 ヴィニシウス 7'・45+3'、クーニャ 60' → ヴィニシウスは1次の3試合で4点。C組1位（英語版Wikipedia Carlo Ancelotti「advancing to the round of 32 as the top team in their group」）
- 「the first time Brazil had failed to reach the quarter-finals since 1990」（英語版Wikipedia Carlo Ancelotti、ESPN「Haaland, Norway condemn Brazil to earliest World Cup exit since 1990」2026-07-05 を引く）

## 5. 監督（アンチェロッティ）
- 英語版Wikipedia Carlo Ancelotti（raw）: 「On 12 May 2025, the Brazilian Football Confederation appointed Ancelotti as the new manager」（CBF「Carlo Ancelotti é o novo técnico da Seleção Brasileira」を引く）「In 2025, he was appointed as coach of a national team for the first time」「On 14 May 2026, Ancelotti renewed his contract … through to the 2030 FIFA World Cup」（BBC）
- FotMob チーム 8256 の名簿: coach Carlo Ancelotti（1959-06-10、67歳）
- W杯の日本戦のあと（サッカーダイジェストWeb 2026-06-30 https://www.soccerdigestweb.com/news/detail/id=193448 ）原文:
  「前半は日本が上手く守備を固めて、スペースを見つけるのに苦労しました。後半はクロスをより多く入れ、ペナルティエリアへの入り込みを増やすことで解決策を見出しました。これは成長だと思います。…」
  「前半のプランは中盤で優位性を作り、ライン間でボールを動かし、FWへパスを通すことでしたが、機能しませんでした。日本がピッチ内で非常に固く守っていたためです。ハーフタイムにシステムを変更し、よりクロスを増やして中に入り込む形に切り替えました」
  （写真のクレジット: 金子拓弥（サッカーダイジェスト写真部／JMPA代表撮影）。写真は使っていない）
- インド戦のあと（スポーツ報知 2026-10-04 Yahoo!ニュース https://news.yahoo.co.jp/articles/947e271a4f22ed1b8c3f268fd0c817a99a6e843c ）原文:
  「序盤はややリズムに乗れなかったが、次第に集中力を高めてプレーしてくれた」、「数人の若手が良いプレーをしたのが収穫」

## 6. 基礎DATA
- W杯優勝 5回（1958・1962・1970・1994・2002）準優勝2回（FotMob チーム 8256 の history trophyList「World Cup won 5」）。最多
- 主将 マルキーニョス（W杯の5試合で腕章。FIFA の試合データの Captain）。代表112試合7得点（FotMob 267365）。PSG
  - この秋の3試合は腕章が入れ替わった（9/29 はハフィーニャ→後半ブルーノ・ギマランイス、10/3 はマルキーニョス。報道）→ 台本は W杯の主将としてマルキーニョスだけ言う
- 監督 アンチェロッティ（2025年5月から）

## 7. この秋の3試合（FotMob の試合記録）
| UTC | 日本時間 | 試合 | ブラジルの得点 | 会場 |
|---|---|---|---|---|
| 9/25 10:00 | 9/25 19:00 | オーストラリア 1-1 ブラジル | 90+5' ハイアン（アシスト ハフィーニャ）。オーストラリア 68' イランクンダ | タウンズビル |
| 9/29 10:00 | 9/29 19:00 | オーストラリア 2-4 ブラジル | 3' ヴァンデルソン、45+1' ハフィーニャ、70' ブルーノ・ギマランイス、80' ヴィニシウス。オーストラリア 30' チルカーティ、34' メトカーフ | ブリスベン |
| 10/3 14:00 | 10/3 23:00 | インド 0-4 ブラジル | 28' エステヴァン、42' ペドロ、58'・90+5' サムエル・リノ | コルカタ |
FotMob: https://www.fotmob.com/matches/x/5924776 ・ /5924777 ・ /5985687
- ブルーノ・ギマランイスは 9/29 が代表50試合目（mixvale 2026-10-01「Capitão inédito, Bruno Guimarães chega a 50 jogos na Seleção Brasileira」、bnews「Bruno Guimarães celebra 50 jogos pela Seleção com gol e faixa de capitão」）。FotMob はインド戦のあとで 51試合4得点（850354）で合う
- 「Ancelotti usou todos os 26 convocados na janela.」（Canal GOAT 2026-10-03 https://canalgoat.com.br/noticias/selecao-brasileira/brasil-goleia-a-india-por-4-a-0-em-calcuta-com-golaco-de-estevao-pedro-de-pivo-e-dois-de-samuel-lino-e-fecha-a-data-fifa-invicto-duas-vitorias-um-empate-e-26-jogadores-usados.html ）。FotMob の3試合の先発と交代を足しても26人
- エステヴァン（チェルシー、2007-04-24生まれ19歳）、ハイアン（ボーンマス、20歳）。FotMob の名簿
- 9/10 の招集で、インドとは初めての対戦（Forbes Brasil・9/10 の回の台本「史上初めてインドと対戦」）

## 8. 見立てのために数えた（自分で。FIFA・FotMob の得点時刻から）
W杯の5試合＋この秋の3試合＝8試合。
- 得点: 1+3+3+2+1+1+4+4 = **19**（1試合 2.4）
- 90分を過ぎてから（後半の追加時間）: 日本戦 90+5、ノルウェー戦 90+10、オーストラリア1戦目 90+5、インド戦 90+5 = **4**（19点の21%、およそ5点に1点）
- 相手にリードを許した試合: モロッコ（0-1）、日本（0-1）、ノルウェー（0-1）、オーストラリア1戦目（0-1）、オーストラリア2戦目（1-2）= **5**。結果は 分・勝・負・分・勝 → 負けは **1**（ノルウェー）
- 日本との直近2試合: 2025/10/14 はブラジルが先制して日本が勝ち、2026/6/30 は日本が先制してブラジルが勝ち → どちらも**先制した側が負けた**
- 日本はW杯で 29分から56分まで、27分間リードしていた

## 9. 写真（すべて Commons、Bryan Berlin、CC BY-SA 4.0、2026-06-13 ブラジル対モロッコ）
- 01 Carlo Ancelotti Brazil V Morocco 13 June 2026-34.jpg（-47 は左端に別の人の頭と耳が写り込むので替えた）。01t は色味を少し暖かく・明るくしたサムネ用
- 02 Vinícius Júnior …-207.jpg / 03 Marquinhos …-153.jpg（腕章あり）/ 04 Bruno Guimaraes …-78.jpg / 05 Casemiro …-76.jpg / 06 Gabriel Martinelli …-144.jpg（ビブス姿）
- 07 Brahim Diaz Vinicius Junior …-128.jpg（横長の試合の写真。今は台本で使っていない）
- 08 = 06 と同じ写真（日本戦の数字を読む行用）。08_v はショート用に 05（上）と 03（下）を上下に並べた1枚（表が顔にかからない位置）
- 09 = 01 と 05 を左右に並べた1枚（山場の監督の言葉の行。語る人＝左、主役＝右）。09_v は 01_v と同じ
- 10 = 05 と 06 を左右に並べた1枚（勝ち越しの行。ゴールを決めた2人）。10_v は 06_v と同じ
- 表のある行は縦写真を右に立てる形（表が左）。表の無い行は 09・10（2枚並べ）。日本戦の1〜3行目は 09 を引き継ぐ
- エステヴァンは Commons にパルメイラス時代（2024年）しか無く、使っていない
