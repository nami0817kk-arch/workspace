# 材料の控え: ポルトガル 2-1 ノルウェー（2026-10-04、UEFAネーションズリーグ A4 第4節、ポルト）

シリーズ「数字で見る注目試合」（research/20260920_match_5868072.yaml と同じ名前）。key: match_portugal_norway。
取り方: python requests（UEFA の試合API・順位API、FotMob の matchDetails、各紙の本文の段落）。WebSearch・ブラウザは使っていない。
数えた時点: 2026-10-05 6時ごろ（日本時間。試合終了の約30分後）。FPF 公式の試合記事はまだ出ていなかった（news/58131 まで。58132 以降は無いページ）。
雛形は `python tools/match_numbers.py --date 2026-10-05 --match 5181867` で作り、research/20261005_match_5181867.yaml を key に合わせて改名した。
雛形の板は assets/stats/match_20261004_5181867.png（道具が書いたもの）。

## 1. スコア・得点者・時間（UEFA 公式まで辿った → 確定）

UEFA の試合API（uefa.com の試合ページの元データ）: https://match.uefa.com/v5/matches?fromDate=2026-10-04&toDate=2026-10-04&limit=100&offset=0&order=ASC
- 試合 id 2047924（試合ページ https://www.uefa.com/uefanationsleague/match/2047924--portugal-vs-norway/ 。requests ではタイムアウトで本文を開けず、API で確かめた）
- competition 2014 UEFA Nations League、seasonYear 2027、League A Group A4、Matchday 4、status FINISHED
- kickOff 2026-10-04T18:45:00Z（utcOffset +1 → 現地19:45、日本時間10/5 3:45）、Estádio do Dragão
- score total home 2 - away 1
- scorers: FIRST_HALF 36:06 Kristoffer Ajer（Norway）／FIRST_HALF 38:43 João Cancelo（Portugal）／SECOND_HALF 79:17 Gonçalo Ramos（Portugal）
- redCards: SECOND_HALF 86:22 Francisco Conceição（Portugal）
- matchAttendance 48832、主審 Maurizio Mariani（ITA）
- UEFA の先発（lineups API https://match.uefa.com/v5/matches/2047924/lineups ）: ポルトガル Diogo Costa、Rúben Dias、Palhinha、Bruno Fernandes、Gonçalo Ramos、João Félix、Renato Veiga、Francisco Conceição、Nuno Mendes、João Cancelo、Vitinha（23）／ノルウェー Selvik、Ajer、Østigård、Møller Wolfe、Berg、Aursnes、Berge、Haaland、Ødegaard、Nusa、Schjelderup
- UEFA のチーム数字（https://matchstats.uefa.com/v1/team-statistics/2047924 ）: 支配率 58/42、シュート 19/8、枠内 7/3、パス成功 444/271（89%/80%）、走行距離 105.3/108.5km。**FotMob と少しずれる（シュート 20/9 など）。表は先週のオスロ戦と同じ物差しで比べるため FotMob にそろえた**

順位（UEFA standings API https://standings.uefa.com/v1/standings?groupIds=2014194 ）
| 順位 | チーム | 試合 | 勝 | 分 | 敗 | 得 | 失 | 勝点 |
|---|---|---|---|---|---|---|---|---|
| 1 | ポルトガル | 4 | 4 | 0 | 0 | 9 | 4 | 12 |
| 2 | デンマーク | 4 | 2 | 0 | 2 | 7 | 7 | 6 |
| 3 | ウェールズ | 4 | 1 | 0 | 3 | 2 | 5 | 3 |
| 4 | ノルウェー | 4 | 1 | 0 | 3 | 6 | 8 | 3 |
- グループの上位2つが準々決勝（UEFA の group データ teamsQualifiedNumber 2）

## 2. 試合の流れ（報道）

- O Jogo（2026-10-04 21:43 リスボン）https://www.ojogo.pt/internacional/artigo/portugal-vence-a-noruega-e-ja-tem-bilhete-para-os-quartos-da-liga-das-nacoes/18133597
  > "a formação norueguesa adiantou-se no marcador com um golo de Kristoffer Ajer, aos 36 minutos, mas a equipas das quinas deu a volta ao resultado, com golos de João Cancelo, aos 38, e Gonçalo Ramos, aos 79, acabando o jogo reduzida a 10 elementos por expulsão de Francisco Conceição, aos 86, que viu dois cartões amarelos seguidos."
  > "Com o quarto triunfo no mesmo número de jogos sob o comando do selecionador Jorge Jesus, Portugal segue na liderança do grupo, com 12 pontos, e já garantiu uma das duas vagas que dão acesso aos quartos de final"
  > "A formação lusa vai ainda defrontar a Dinamarca, em Braga, no dia 14 de novembro, e fecha a fase de grupos com a visita ao País de Gales, no dia 17 do mesmo mês"
- Maisfutebol クロニカ https://maisfutebol.iol.pt/liga-das-nacoes/portugal/portugal-noruega-2-1-cronica
  > "Quatro jogos, quatro vitórias na Liga das Nações. Apuramento garantido para os quartos de final."
  > "em resposta pronta à vantagem da Noruega (e a primeira desvantagem com Jesus), dada por Kristoffer Ajer, dois minutos antes" → ジェズス体制で初めてリードを許した
  > "aos 79 minutos, foi aquele passe delicioso de Vitinha, para João Félix servir a vitória dada por Gonçalo Ramos: terceiro jogo seguido a marcar e a decidir de novo ante os vikings." → ラモスは3試合連続、ノルウェー戦で2度目の決勝点
  > "já sem Haaland em campo (muito aplaudido)"
  > "Somou a 10.ª vitória seguida neste palco"（ドラゴンで10連勝。台本では使わない）
- Record（10/4 21:39）https://www.record.pt/internacional/competicoes-de-selecoes/liga-das-nacoes/detalhe/passe-incrivel-de-vitinha-assistencia-de-joao-felix-e-finalizacao-de-ramos-o-golo-da-reviravolta-contra-a-noruega
  > "Vitinha rasgou a defesa nórdica, João Félix deu de primeira para Gonçalo Ramos e o ponta-de-lança encostou para colocar a Seleção Nacional na frente."
- Bola na Rede（SAPO 掲載 10/4 21:43）https://sapo.pt/artigo/portugal-vence-noruega-e-garante-passagem-direta-a-final-four-da-liga-das-nacoes-6ac2bac8251665e3d603d2e2
  > "Na sequência de um livre batido por Martin Odegaard, aos 36′, a seleção norueguesa adiantou-se no marcador, com Kristoffer Ajer a bater Diogo Costa."
  - 見出しの「final four」は O Jogo・Maisfutebol・RTP・Record・UEFA（上位2つが準々決勝）と食い違う → 使わない。台本は「準々決勝」
- Record（10/4 21:54）https://www.record.pt/internacional/competicoes-de-selecoes/liga-das-nacoes/detalhe/portugal-apurado-para-os-quartos-de-final-da-liga-das-nacoes-o-que-falta-para-conseguir-o-1-lugar
  > "Portugal é a primeira seleção apurada para os quartos de final da Liga das Nações."
  > "Portugal tem contas simples para fazer: basta fazer 1 ponto nos dois jogos que restam."
- RTP https://www.rtp.pt/noticias/selecao-nacional/portugal-esta-nos-quartos-da-liga-das-nacoes_d1769580 「ficou automaticamente apurado para os quartos」
- NRK（10/4 22:54 CEST）https://www.nrk.no/sport/nasjonsligaen_-norge-mener-portugal-mal-burde-blitt-annullert-etter-disse-bildene-1.18045000
  - カンセロの同点弾の前のスローインはヌーノ・メンデス（"Nuno Mendes, som tok innkastet før scoringen"）。ノルウェーのベンチは投げ方に抗議（台本では使わない）
  - コンセイソンは "fikk to gule på rappen for klaging og gestikulering mot dommer"
- NRK 採点（10/4 22:43）https://www.nrk.no/sport/bors_-slik-spilte-norge-mot-portugal-1.18044817
  > "Erling Braut Haaland – 4: Starter sin fjerde kamp på elleve dager, og det synes. Ser sliten og tung ut. ... Signaliserer selv bytte halvveis i andre omgang."
  - → 台本は「11日で4試合目の先発」「後半の途中、自分から交代の合図」「67分に退く」まで。けがかどうかは書かない（FotMob の交代理由は injury だが、報道で確かめられない）

## 3. ロナウドの扱い（1〜2行まで）

- 9/30 に合宿を離れた（research/raw/20261003_portugal_without.md）。10/1 デンマーク戦、10/4 ノルウェー戦の2試合に不在 → **この試合は離れてから2試合目**（依頼文の「初めての試合」ではない）
- 主将: FotMob の先発で isCaptain は Bruno Fernandes（10/1・10/4 とも）。9/27 は Rúben Dias、9/24 は Ronaldo
- 10/2・10/3・10/4 の回で騒動を扱ったので、台本は「離れてから2試合目」「主将はブルーノ」の2行だけ

## 4. 数字（FotMob matchDetails、5181867。先週のオスロ戦は 5181864）

| | ポルトガル | ノルウェー |
|---|---|---|
| ボール支配率 | 59% | 41% |
| xG | 1.80 | 0.45 |
| シュート | 20 | 9 |
| 枠内シュート | 7 | 3 |
| 決定機 | 3 | 0 |
| パス成功 | 433 (87%) | 274 (78%) |
| デュエル勝ち | 38 | 31 |

- 得点のシュート（shotmap）: アイエル 36分 xG 0.02（セットプレー、エリア外）、カンセロ 38分 xG 0.05（スローインから、エリア外）、ラモス 79分 xG 0.82（流れの中、エリア内）
- 評点（FotMob）: ヌーノ・メンデス 8.34（90分、1アシスト、地上の競り合い 8/11）、カンセロ 8.09（63分、1点、シュート4本枠内3本、12分に警告）、ヴィティーニャ 8.03（86分、パス 65/67、敵陣の奥へのパス 18、ロングボール 4/4）、フェリックス 7.91（89分、1アシスト、ドリブル 4/5）、ウーデゴール 7.84（ノルウェー最高、1アシスト）、ラモス 7.74（90分、1点）
- ハーランド: 67分、シュート3本、xG 0.30、タッチ22回。（枠内シュートは選手の数字で0本、ショットマップでは27分の頭が「枠内・セーブ」で食い違う → 台本は枠内を言わない）

### 1週間前のオスロ（9/27 ノルウェー 1-2 ポルトガル、FotMob 5181864）との比べ
| | 9/27 オスロ | 10/4 ポルト |
|---|---|---|
| ポルトガルの支配率 | 38% | 59% |
| ノルウェーのシュート | 22 | 9 |
| ノルウェーの xG | 2.52 | 0.45 |
| ノルウェーの決定機 | 6 | 0 |
| ハーランドのシュート | 8（90分） | 3（67分） |
| ハーランドの xG | 1.50 | 0.30 |
- オスロの得点: フェリックス17分、ハーランド51分、ラモス54分（9/27 の ESPN summary と同じ。research/raw/20261003_portugal_without.md）
- 2.52 → 0.45 は5分の1を下回る（2.52 / 5 = 0.504）

## 5. 本人の言葉（1件）

ジョアン・カンセロ（試合後。Maisfutebol「João Cancelo: «Fizemos todos um grande trabalho, Ronaldo incluído»」）
https://maisfutebol.iol.pt/selecao/selecao-nacional/joao-cancelo-fizemos-todos-um-grande-trabalho-ronaldo-incluido
> «Conseguimos assimilar os conceitos do novo treinador rapidamente. Também é preciso um bocadinho de sorte. ... Hoje fomos a melhor equipa em campo mais uma vez.»
> «Estava bem posicionado. Sei que o Nuno tem um lançamento muito forte. Foi um instinto, estar lá, graças a Deus correu bem e foi um grande golo.»
訳（台本）: 新しい監督の考え方を、すぐに自分たちのものにできた。／今日もまた、ピッチでいちばんのチームは僕たちだった。
訳（台本・得点の流れの節）: ヌーノのスローインが強いのは知っていた。／あそこにいたのは本能だよ。／うまくいって、すごいゴールになった。（「Estava bem posicionado」「graças a Deus」は尺で外した。意味は変えていない）
- 「この夏からチームを率いるジェズス監督」: ESPN 10/2 "Jesus, who took over from Roberto Martinez after Portugal's World Cup round-of-16 exit"（research/raw/20261003_portugal_without.md の追記）。W杯の敗退は 7/6（FotMob の日程）
- 「このグループで一番乗り」: Record「Portugal é a primeira seleção apurada para os quartos de final」は大会全体で最初の意味。台本は「大会全体で一番乗りです」（確度は報道の記事どおり）
- 同じ記事のロナウドの話（「Ronaldo incluído」）は使わない（騒動は別の回で扱った）

## 6. 写真

- 01.jpg ← Record 10/4 21:54 の記事の写真（キャプション「João Félix em ação」、クレジット「Foto: Victor Sousa」。代理店の表記なし。og 画像は帯とロゴ入りなので、帯の無い 1280x720 版 https://cdn.record.pt/images/2026-10/img_1280x720uu2026-10-04-21-48-00-2466412.jpg を取った。実寸 1080x720）。写っているのは中央のヴィティーニャ（23）、左に11番フェリックス、右に白の8番ベルゲ。試合当日の写真。articlephoto は og 画像の取得が途中で切れて止まったので、requests で落として credits.json を手で書いた
- 01_w・01_v は tools/facecrop.py（ヴィティーニャの顔中心）
- 当たって使えなかったもの: Maisfutebol（AP の Luis Vieira）、RTP（Lusa の José Coelho）、NRK（AFP/NTB・Reuters）、A Bola のギャラリー（前回の控えで IMAGO/Lusa/EPA）、O Jogo のギャラリー（写真の出どころを本文から読めず）、FPF 公式（試合記事がまだ出ていない）
- 近い時期の Commons（Bryan Berlin、CC BY-SA 4.0）:
  - cancelo/ ← File:Joao Cancelo Croatia v Portugal 2 July 2026-156.jpg（W杯 クロアチア戦）
  - ramos/ ← File:Goncalo Ramos Croatia v Portugal 2 July 2026-229.jpg
  - mendes/ ← File:Nuno Mendes Croatia v Portugal 2 July 2026-068.jpg（顔が取れず --top 0.03 --center 0.52 で切った）
  - ajer/ ← File:Kristoffer Ajer Morocco v Norway 7 June 2026-159.jpg
  - haaland/ ← File:Erling Haaland Morocco v Norway 7 June 2026-164.jpg（assets/images/20261002_cmp_haaland_wide から写した。白のユニホーム。--top 0.05 --center 0.63）

## 7. 反応（X の個人の投稿3件。Yahoo!リアルタイム検索「ポルトガル ノルウェー」「ハーランド ポルトガル」「カンセロ」→ api.fxtwitter.com で全文）
1. @Lie_yao__lu_sha（プロフィールに #NFF・@nff_landslag＝ノルウェー代表を追う人）2026-10-04 20:58 UTC https://x.com/Lie_yao__lu_sha/status/2106851497262940233
   原文「セルヴィキ含めて目立って悪いプレイヤーはいなかったけど、(強いていえばロングボールがズレがちなセルヴィキとハーランドくらい？)2試合前のホームポルトガル戦くらいの圧倒的な力を見せて欲しい…
あれ見せられたら期待しちゃうから」
   → 括弧だけ外して行に分けた（言葉は欠けていない）。「2試合前のホームポルトガル戦」＝9/27 オスロ。見立ての比べと同じ話なので先頭に置いた
2. @ntnori7 2026-10-04 20:56 UTC https://x.com/ntnori7/status/2106851020659945812
   原文「ポルトガル代表、ロナウド離脱があったけど普通に強い。サイドバックの2人は世界トップクラスだし、カンセロはバルセロナでもエグイの決めてたし好調だよなぁ。」
3. @orengetakumi 2026-10-04 20:45 UTC https://x.com/orengetakumi/status/2106848188653273528（short_voice）
   原文「ポルトガルなんだかんだでつえーな
ノルウェーがなかなか厳しい」
入れなかったもの: SUiCa41「むむむむーーー彡´◉ω◉ﾐ ノルウェーが不調なのかポルトガルが好調すぎるのか」（顔文字と「むむむむ」を読み上げると伝わりにくい）、Lie_yao__lu_sha の別の投稿（デンマークとの順位の計算の話）、H7Iqk「とうとうノルウェーにまで勝ってんのか」（先週も勝っているので事実と食い違う含み）、審判への感想（GyakusyunoReds ほか。題に答えない）。FOOTY30_JP・WFN・GOAL Japan・DAZN Japan・サッカーキング・ゲキサカ系の速報アカウントは入れない
- 声: カンセロの行の話者名は「カンセロ選手」。「ジョアン・カンセロ」「カンセロ」はどちらも style 52 で「ネット民」（voice_fixed 52）とぶつかり draft が止まるため。config の voicevox.voice_fixed に「ジョアン・カンセロ: 99」を足せば元の名前に戻せる（触ってよいファイルの外なので足していない）
