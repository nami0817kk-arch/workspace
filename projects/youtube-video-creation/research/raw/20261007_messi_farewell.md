# 20261007 messi_farewell 材料の控え（メッシ、アルゼンチン代表の最後の試合 対ベナン）

取材: 2026-10-07 13時ごろ（日本時間）。ブラウザは使わず requests / WebSearch / WebFetch だけ。

## 1. 試合の事実

- アルゼンチン 3-0 ベナン。2026-10-06 20:00（現地）＝日本時間 10/7 8:00、エスタディオ・モヌメンタル（ESPN の会場名は Estadio Más Monumental）。親善試合。主審はチリのベハル
- 得点（ESPN の試合データ API site.api.espn.com …/fifa.friendly/summary?event=401921408 の keyEvents）
  - 48' オタメンディ（"Assisted by Lionel Messi with a cross following a corner."）。La Nación は「後半2分（A los dos minutos）」、TyC の投稿は「47'」。**分が割れるので台本は「後半の立ち上がり」**
  - 61' ニコ・パス（"Assisted by Lionel Messi."）。パスは 59' にデ・パウルと交代で入った（ESPN・Clarín「ingresó a los 59 minutos … apenas necesitó 120 segundos」）
  - 71' メッシ PK（"converts the penalty with a left footed shot to the top right corner."）。La Nación「A los 26 minutos, Giay recibió una infracción dentro del área」→ 後半26分
- メッシの出場時間: **90分（交代なし）**。ESPN の名簿でメッシに subbedOut が無く、交代の記録（keyEvents）にもメッシの名前が無い。La Nación「El juez del partido le entregó la pelota en sus manos y pitó el final」
- メッシの数字: 1得点2アシスト（ESPN 名簿 goalAssists 2, totalGoals 1）
- 10分の拍手: La Nación「en el minuto 10, en el que se detuvo el partido para que todos lo homenajeen al capitán」。ESPN keyEvents 11' "Delay in match"
- 前半: La Nación「Fueron tres las ocasiones claras en las que pudo convertir, pero falló o el arquero rival no se lo permitió」（前半0-0）
- 観客: Infobae「colmado por unas 85.000 personas」。ESPN 記事（WebFetch の要約）も 85,000
- 試合後: 審判がボールとカードを渡した（Infobae）。ドローンショー（AFA の盾・ユニホーム・W杯・「GRACIAS LEO」、La Nación）。オタメンディも代表の最後の試合（Infobae）
- 出典
  - ESPN 試合データ https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.friendly/summary?event=401921408
  - ESPN 記事 https://www.espn.com/soccer/story/_/id/50120909/lionel-messi-last-argentina-game-vs-benin-retirement （本文は requests で取れず、WebFetch の要約のみ。発言の原文には使わない）
  - La Nación 速報 https://www.lanacion.com.ar/deportes/futbol/la-despedida-de-lionel-messi-en-vivo-vs-benin-hora-todos-los-invitados-y-el-minuto-a-minuto-del-nid06102026/
  - Infobae PK https://www.infobae.com/deportes/2026/10/07/el-gol-de-penal-de-lionel-messi-en-su-despedida-de-la-seleccion-argentina-el-especial-festejo-con-el-plantel/
  - Infobae 小話 https://www.infobae.com/deportes/2026/10/07/las-perlitas-de-la-despedida-de-lionel-messi-de-la-seleccion-el-regalo-del-arbitro-un-desmayo-en-pleno-show-y-la-sorpresa-del-final/
  - Clarín（パスの場面）https://www.clarin.com/deportes/lionel-messi-nico-paz-conexion-golazo-benin-marco-traspaso-mando-10-despedida-capitan-seleccion_0_H0jhSZUlzo.html
  - Olé（記録の一覧）https://www.ole.com.ar/messi/numeros-records-lionel-messi-seleccion-argentina-despedida_0_1avcIJq2Xo.html
  - **AFA 公式サイトの試合記録は当たっていない**（ESPN の試合データと La Nación・Infobae・Clarín・TyC で一致を確かめた）

## 2. ニコ・パスとのつながり

- パスの代表デビューは 2024-10-15、モヌメンタルのボリビア戦（6-0、W杯予選）。途中出場で**メッシにアシスト**（英語版 Wikipedia「Nico Paz」"made his senior debut … recording an assist for Lionel Messi"。メッシの得点一覧でも同じ日・会場 Estadio Monumental）
- 今回は逆に、メッシの代表最後のアシストがパスへ。Clarín「Paz fue de manera exclusiva a buscar a Messi, señalándolo a la distancia para fundirse en un abrazo y agradecerle el pase」
- パスはこの代表ウィークで3点目（ボリビア・ブルキナファソ・ベナン。Clarín）

## 3. 試合後のメッシのスピーチ（TyC Sports の全文起こし。Infobae・La Nación・Clarín と突き合わせ）

https://www.tycsports.com/seleccion-argentina/seleccion-argentina-lionel-messi-discurso-despedida-amistoso-benin-id764663.html
- "Es difícil decir algo hoy, hay muchas emociones, se me cruzan muchas cosas. En lo primero que pienso es en mi viejo."
- "No venir más va a ser un dolor muy grande. Les juro que me gustaría venir toda la vida, porque jugar en la Selección Argentina es lo más lindo que te puede pasar."
- "Si bien quiero estar toda la vida acá, siento que es el momento."
- "Hoy, nuevamente acá, seguramente me toca vivir el día más triste de mi carrera, porque es donde le digo adiós a la Selección y a todos ustedes. Voy a extrañar defender los colores de la Selección, pero ahora voy a estar de ese lado, con todos ustedes, bancando a todos estos chicos y lo que venga."
- "Van a venir momentos duros, seguro, porque no es normal lo que se hizo en todo este tiempo. Y en esos momentos duros tenemos que estar nosotros acompañando más que nunca. … para conseguir objetivos grandes hay que hacer grupos fuertes, unidos, porque hay gente que quiere ver mal a la Selección. No hay que darles el gusto."
- "La verdad que estoy hablando más que nunca, no me quiero ir, no quiero dejar la cancha."
- 「mi viejo」= 父ジョルジェ。Infobae「recordando a su padre fallecido el pasado 8 de agosto」。8/8 の訃報（La Nación・Infobae）で 68歳。英語版 Wikipedia「His father Jorge … died at the age of 68」。代表引退の発表は 8/31（Infobae・Wikipedia）→ 23日後
- 前日の「きっと恋しくなる特別な瞬間」（サッカーキング・ゲキサカ 10/6）は**入れない**（題の出来事より前の発言は置かない決まり）

## 4. スカローニ監督（試合後の会見。Infobae）

https://www.infobae.com/deportes/2026/10/07/esa-aura-no-se-la-vi-a-nadie-en-mi-vida-scaloni-se-rindio-a-los-pies-de-messi-y-explico-como-intentara-reemplazarlo-en-la-seleccion/
- "El primer tiempo los compañeros mismos estaban nerviosos, no sabían qué jugada elegir, porque fue una noche muy especial"
- "No fue fácil porque querían que le fuera bien, todos querían que él hiciera lo mejor"
- "Podemos hacer un gran equipo con los nuevos chicos que van saliendo, pero esa aura no se la vi a nadie en mi vida."
- "Es irrepetible, no creo que me vaya a equivocar, no habrá nada igual"
- "Sobre la renovación, no hay novedades"（使わない）

## 5. 代表の通算（数え直し）

- 208試合126得点（ベナン戦を含む）。英語版 Wikipedia「List of international goals scored by Lionel Messi」（rev 1378963164）の年別表を自分で足して 208/126。RSSSF（2026-01-21 更新、196試合115得点まで）の1試合ずつの表から年ごとに数え直し、2005〜2025 が Wikipedia と全部一致。2026 は 208−196=12試合、126−115=11得点（W杯8試合8得点＋親善4試合3得点）
- 前の得点（125点目）は 2026-07-07 W杯エジプト戦。そのあと W杯3試合は無得点 → ベナン戦で3か月ぶり
- 時期ごとに数えた（自分で足した）

  | 時期 | 試合 | 得点 | 1試合あたり |
  |---|---|---|---|
  | 2005〜2010 | 54 | 15 | 0.28 |
  | 2011〜2014 | 43 | 30 | 0.70 |
  | 2015〜2018 | 31 | 20 | 0.65 |
  | 2019〜2022 | 44 | 33 | 0.75 |
  | 2023〜2026 | 36 | 28 | 0.78 |

  （合計 208・126）
- W杯（大会ごと。年別表の注記と大会の記録から）: 2006 3試合1点 ベスト8 / 2010 5試合0点 ベスト8 / 2014 7試合4点 準優勝 / 2018 4試合1点 ベスト16 / 2022 7試合7点 優勝 / 2026 8試合8点 準優勝（決勝スペインに延長0-1、Wikipedia）。計34試合21点（Wikipedia の大会別表・Olé と一致）
  - 最後の2大会で 15点（21点の71%）
  - W杯34試合は歴代最多。ロナウドは27試合（Olé「por delante de Cristiano Ronaldo, que quedó con 27」）
- 決勝は9回（Infobae「nueve finales disputadas」）。2007コパ●・2014W杯●・2015コパ●・2016コパ●・2021コパ○・2022フィナリッシマ○・2022W杯○・2024コパ○・2026W杯●
- 代表の主要タイトル: W杯2022・コパ・アメリカ2021/2024・フィナリッシマ2022（ほかに2005年U-20W杯・2008年五輪）
- Olé のアシスト68・先発186 は使っていない（他で確かめていない）。Olé の「ボリビア・エクアドル・ウルグアイに11点ずつ」は Wikipedia（11・7・6）と食い違うので使わない
- 出典: https://en.wikipedia.org/wiki/List_of_international_goals_scored_by_Lionel_Messi / https://www.rsssf.org/miscellaneous/messi-intlg.html / https://en.wikipedia.org/wiki/Lionel_Messi

## 6. 反応（個人の投稿3件。Yahoo!リアルタイム検索「メッシ ラストマッチ」「メッシ 代表 最後」「メッシ ベナン」「メッシ 引退試合」→ api.fxtwitter.com で全文。海外は Mastodon のタグ #Messi の公開タイムライン）

1. @s_b796（めばる。「社会人。趣味は読書…サンフレッチェ応援」）2026-10-07 03:46 UTC https://x.com/s_b796/status/2107679037896491447
   原文「メッシの引退試合、オタ（カタール英雄）へのアシスト、ニコ（新世代）へのアシストなのは綺麗だな」
2. @ketutotappabig（如水。ゲーム垢）2026-10-07 03:49 UTC https://x.com/ketutotappabig/status/2107679663866925219（short_voice）
   原文「メッシの引退試合でパスが決める。／未来への完璧なパスじゃないか」
3. mastodon.social @free_user（プロフィールにアルゼンチンの旗。投稿121件の個人）2026-10-07 02:09 UTC https://mastodon.social/@free_user/117397191113912315
   原文（スペイン語）「gracias Leo lo que hiciste en la selección no tiene precio」＋ #argentina #messi #benin（タグは外す）
   訳「ありがとう、レオ。代表で君がしてくれたことに、値段なんてつけられない」

入れなかったもの: 報道・まとめ・転載（foot_ch、RBcleay、PIKAEMON2002、soccernews_19、kruger0811、Yakan_so_ko_nin、naigaitimes_com、sore_shirabeta ほか）。Knuckle_BMW（協会への悪口を含む）、hetakuni「撤回したら？」（題の答えから外れる）、bOabOfmQUF32872（揶揄）。
海外の個人の声: Bluesky 検索 API は 403、reddit は 403、Guardian のコメント欄は無し。Yahoo!リアルタイム検索のスペイン語はほぼ報道だけ。Infobae の「ミーム」記事の投稿（@napoliarg1 など）は投稿の本体まで辿れず使っていない

## 7. 写真（La Nación の自社カメラマンの写真。代理店ではない）

記事: La Nación 速報（上の URL）。表記は写真説明のとおり「Aníbal Greco - LA NACION」
- 01.jpg「Messi tuvo tres oportunidades, peor no logró concretar」（メッシ1人、10番のユニホーム）→ サムネ・冒頭（01_w）・ショート（01_v）
- 02.jpg「La selección Argentina despide a Lionel Messi con un partido ante Benín en el estadio Mas Monumental」（メッシと代表の仲間、看板に GRACIAS CAPITÁN）
- 03.jpg「Messi estuvo muy participativo en la primera parte」（メッシとベナンの選手）。顔が横向きで facecrop が顔を拾えず、--center 0.78 で切った
- 同じ記事の og:image（LUIS ROBAYO - AFP）と「JUAN MABROMATA - AFP」は取り込んでいない。Infobae は REUTERS、Olé は AP、ESPN・Guardian は AFP/Getty
- 10/6 以前のメッシの写真（9/30 Commons Bryan Berlin のエジプト戦、10/4 Commons 2005年バルサ、9/7 Commons 2022W杯、9/22 Commons 2018、9/26 iprofesional）とは別の写真
