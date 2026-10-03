# 材料の控え: ロナウドのいないポルトガル（2026-10-03 取材）

題材: 9/30 にロナウドが代表合宿を離れたあとのポルトガル。10/1 デンマーク戦 4-2 と、その翌日からの騒ぎ。
前日（10/2）に「ロナウドの代表離脱」の回（scripts/20261002_ronaldo_walkout.md）を出している。離脱の経緯・懲戒規定・234試合146得点・W杯の数字・監督の会見の発言は繰り返さない。経緯は1行だけ。

取り方: python requests（本文の段落・ページに埋め込まれた JSON）、ESPN は content.core.api.espn.com（記事本文）と site.api.espn.com（試合の summary: 得点・アシスト・シュート数・順位）、
X の投稿は Yahoo!リアルタイム検索で見つけて api.fxtwitter.com で本文と時刻を取得、Yahoo!ニュースのコメント欄はページの __PRELOADED_STATE__ から本文を取得。
WebSearch は URL を探すためだけ（検索の要約は根拠にしていない）。ブラウザの道具は使っていない。時刻は特記なければ UTC。

## 1. デンマーク戦（10/1、コペンハーゲン、パルケン）

- 連盟（FPF）公式の試合記事「Não há duas sem três: Portugal vence na Dinamarca」 https://www.fpf.pt/pt/News/Todas-as-not%C3%ADcias/Not%C3%ADcia/news/58075
  - "Portugal venceu por 4-2, no Parken, num jogo em que esteve três vezes na frente, viu o adversário responder nas duas primeiras e só conseguiu colocar um ponto final na discussão já perto dos 90 minutos. João Cancelo, Gonçalo Ramos, Vitinha e João Félix marcaram os golos"
  - "Com o terceiro triunfo consecutivo, Portugal reforçou a liderança do Grupo A4 da Liga A da UEFA Nations League e passou a somar nove pontos. A Equipa das Quinas regressa a casa já no domingo, 4 de outubro, para receber a Noruega, no Estádio do Dragão, às 19h45, em encontro da 4.ª jornada."
  - 19h45 はポルトガル時間（UTC+1）→ 日本時間 10/5（月）3:45
- ESPN 試合 summary（gameId 401861096）: 得点 Cancelo 13'（assist G. Ramos）、Damsgaard 23'、G. Ramos 25'（assist Bruno Fernandes, through ball）、Højlund 53'、Vitinha 67' header（assist Bruno Fernandes）、Félix 87'（assist Dalot）。
  シュート ポルトガル 19（枠内10）、デンマーク 12（枠内3）。選手別: G. Ramos 6本（枠内2）1得点1アシスト、Bruno 2アシスト、Leão 7番で先発（63分 Trincão と交代）、Félix 81分 IN。
  順位: ポルトガル 3勝 勝ち点9（A4 首位）、デンマーク・ノルウェー・ウェールズ 各3。
- 主将: DN（Isaura Almeida）https://www.dn.pt/desporto/uma-seleo-com-cabea-e-um-p-e-meio-na-final-four-da-liga-das-naes "Com Bruno Fernandes de regresso ao onze titular (e como capitão)" ／ "Rafael Leão, que vestiu a camisola 7 na ausência do ‘dono’, Ronaldo"
  - 同記事 "João Félix entrou fresco e no primeiro remate matou o jogo, fazendo o 4-2, aos 87 minutos, marcando pelo terceiro encontro seguido" ／ ヴィティーニャは代表46試合目で初得点
- 7番: RTP の速報 https://www.rtp.pt/noticias/desporto/jesus-sinaliza-que-havera-tempo-para-falar-de-ronaldo-o-importante-agora-e-focar-no-jogo_e1768915 "O site da UEFA apresentava, na manhã desta quinta-feira, ... que Rafael Leão passaria a ostentar a camisola número 7" ／ "a atribuição do número 7 a Rafael Leão é um procedimento normal, dentro das regras estabelecidas pela UEFA, em que o número da camisola em competição não pode ficar vaga"（台本では言わない。背番号の規則は題に答えない）

### レオンの言葉（FPF 公式 news/58078、ミックスゾーン）
https://www.fpf.pt/pt/News/Todas-as-not%C3%ADcias/Not%C3%ADcia/news/58078
> Ronaldo e a camisola 7? O Cris para mim é um ídolo de infância. O número 7 tem um significado especial para mim, porque foi a data de nascimento dos meus filhos. Simplesmente tentei honrar a camisola e desfrutar. É um assunto que não nos diz respeito. Demonstrámos mais uma vez que somos um grupo. Certamente que ele, em casa, está contente pela vitória.

訳（台本）: クリスは僕にとって、子どもの頃からの憧れなんだ。／7番には特別な意味がある。／子どもたちが生まれたのが、7日だったから。（原文は「子どもたちの生まれた日付だった」。ロマーノの英訳も "born on the 7th"）／ただ、このユニホームに恥じないように、楽しもうとした。
- RTP の見出しも「Leão sobre o número sete: "O Cris para mim é um ídolo de infância"」。ロマーノの英訳（"Cristiano is my idol since I was a child"）は使わず、原文から訳した
- 「É um assunto que não nos diz respeito」以降は尺で外した（意味は変えない）

## 2. ジェズス監督の3試合（ESPN の試合 summary）

| 日 | 試合 | ロナウド | シュート（枠内） | 得点（アシスト） |
|---|---|---|---|---|
| 9/24 | ポルトガル 1-0 ウェールズ（gameId 401861044） | 先発、67分に G. Ramos と交代。シュート7本（枠内2） | 23（5） | Félix 22'（Nuno Mendes） |
| 9/27 | ノルウェー 1-2 ポルトガル（401861073） | ベンチで出番なし | 12（4） | Félix 17'（Pedro Neto）、Haaland 51'、G. Ramos 54'（アシストなし） |
| 10/1 | デンマーク 2-4 ポルトガル（401861096） | 不在 | 19（10） | Cancelo 13'（G. Ramos）、Ramos 25'（Bruno）、Vitinha 67'（Bruno）、Félix 87'（Dalot） |

- 得点者: Félix 3（3試合連続）、G. Ramos 2、Cancelo 1、Vitinha 1 → 7点を4人
- アシスト: Nuno Mendes、Pedro Neto、G. Ramos、Bruno Fernandes 2、Dalot → 5人（6本）
- G. Ramos: ウェールズ戦は途中出場（シュート1）、ノルウェー戦・デンマーク戦は先発 → 先発した2試合で2得点1アシスト。ESPN 記事 "took Ronaldo's place for the second straight game" "assisting on João Cancelo's opener and then scoring his second goal in two games"
- 枠内シュート10本（デンマーク戦）は3試合で最多（5・4・10）
- 前回の回で言ったこと（使わない言い回し）: 「3連勝で、取った7点のうち6点は、ロナウドがピッチにいない2試合でした」。今回は「誰が取ったか」で言い直す
- ハーランドはオスロでの対戦（9/27）で 51分に1点（アシスト Patrick Berg、セットプレー）

## 3. 試合後の監督（FPF 公式 news/58077 と RTP・ESPN）

https://www.fpf.pt/pt/News/Todas-as-not%C3%ADcias/Not%C3%ADcia/news/58077
> Sobre os últimos dias e a capacidade de manter o foco: «Este jogo e, a seguir, aquele jogo do Dragão. Até aí, tenho estado focado no jogo, como vou estar focado no jogo do Dragão. Depois do jogo do Dragão, a gente vai ver. ...»

訳（台本）: この試合、そして次はドラゴンでの試合。／ドラゴンの試合が終わったら、そこで考える。
- 試合前（RTP）は "O importante agora é focar no jogo. Depois vamos para o Dragão e é focar no jogo no Dragão. Depois de certeza que haverá tempo para falar sobre isso"（TSF 10/1 18:39 リスボン https://www.tsf.pt/desporto/artigo/jesus-diz-que-o-foco-esta-nos-jogos-e-depois-de-certeza-que-havera-tempo-para-falar-sobre-ronaldo/18132591 ）
- 依頼文の「逃げずに話す」に当たる言葉は原文に無い。「話す時間は必ずある」（試合前）と「ドラゴンの試合のあとで考える」（試合後）。台本は試合後の言葉を使った
- ESPN https://www.espn.com/soccer/story/_/id/50079904/cristiano-ronaldo-portugal-coach-jorge-jesus-denmark （ESPN News Services、10/2 00:09 UTC）: "Returning to Portugal, the people will fight at the Dragao stadium." ／ Renato Veiga "I've been given instructions and I can't talk about the matter"（使わない）
- 前回の回で「監督は、次のノルウェー戦が終わってから話すとしていて」と言っている。今回は本人の言葉で1回だけ
- 前置きは「ここ数日のことを聞かれた監督は、次の試合を戦うスタジアム、ドラゴンの名を挙げました。」（FPF の記事の見出し語 "Sobre os últimos dias e a capacidade de manter o foco" に合わせた。ドラゴン＝エスタディオ・ド・ドラゴン、10/4 の会場）

## 4. 10/2 ポルトの空港（A Bola 10/2 12:36 UTC）

https://www.abola.pt/noticias/selecao-chega-ao-porto-e-adeptos-discutem-por-causa-de-ronaldo-e-jesus-policia-teve-de-intervir-2026100212362216436
- "O clima de enorme sobressalto e divisão que envolve a Seleção Nacional transbordou esta sexta-feira para o Aeroporto Francisco Sá Carneiro, no Porto."
- "No momento em que a comitiva saía do terminal rumo ao autocarro, um adepto dirigiu uma chuva de ofensas verbais e duras críticas a Jorge Jesus, num momento gravado em vídeo"
- 叫びの一部: "Tens um ego do tamanho da Torre Eiffel, pá! Não vales uma unha do CR7, a unha mais pequenina do pé dele, pá!"（台本は「エゴはエッフェル塔ほど」を地の文で1回だけ）
- "Na mesma zona de desembarque, um outro adepto manifestou o seu descontentamento contra Cristiano Ronaldo, gerando uma acesa troca de argumentos e acusações cruzadas entre os populares"
- "elementos da Polícia de Segurança Pública (PSP) no local foram forçados a intervir de imediato para separar os intervenientes"
- 外したもの: 同じ日にジェズスが拍手で迎えられた場面（CNN Portugal の動画の見出し「entre aplausos e críticas」、Maisfutebol の動画の見出し）。台本では「拍手で迎えた人もいた」とは言っていない → **言わないと罵声だけが目立つ**ので、1行「拍手で迎える人もいました」を入れるか迷い、見出しだけで本文を読めていないため入れなかった
- リスボンの看板（「Lisboa acordou com cartazes de apoio a Ronaldo e ataque a Jesus」）は見出しのみ。使わない

## 5. フォロワー（A Bola 10/2 11:43 UTC）

https://www.abola.pt/noticias/selecao-perde-quase-dois-milhoes-de-seguidores-e-jorge-jesus-tambem-soma-baixas-2026100211430858247
- "No total, as plataformas da equipa das quinas já registaram a perda de quase dois milhões de seguidores desde o início do conflito. O pico ... ocorreu precisamente esta quinta-feira, dia do encontro frente aos dinamarqueses: numa questão de 24 horas, cerca de um milhão de utilizadores decidiu deixar de acompanhar os canais oficiais da Seleção"
- "Jorge Jesus ... somando uma quebra a roçar os 100 mil seguidores nas suas plataformas pessoais."
- "o capitão português apresentou um saldo substancialmente positivo no número de seguidores"
- どのSNSの合計か、もとの人数は記事に無い → 台本は「代表の公式SNSの合計」「200万人近く」「試合の日の24時間でおよそ100万人」「10万人近く」「増えた」まで

## 6. 連盟の動き（A Bola 10/2 12:10 UTC）

https://www.abola.pt/noticias/fpf-tenta-consenso-entre-jesus-e-ronaldo-para-que-a-historia-do-capitao-na-selecao-nao-acabe-assim-2026100212101701560
- 見出し「Cimeira de paz: FPF quer juntar Jesus e Ronaldo para que a história do capitão não acabe assim」
- "a Federação Portuguesa de Futebol (FPF) assume um papel ativo na crise e vai fazer tudo o que estiver ao seu alcance para promover uma plataforma de consenso entre técnico e jogador"
- "Questionada sobre eventuais reuniões de emergência entre as partes, a FPF nada confirma, mas sabe A BOLA que ... Pedro Proença e restantes elementos da direção federativa tudo farão para que a história de Cristiano Ronaldo na Seleção Nacional não termine assim"
- → 連盟は何も認めていない。台本は「報じられています」で言う。確度は報道

## 7. ネットの反応（個人の投稿だけ、3件。全文）

1. X @rikoriko_j468（コーディー、プロフィール「The Blues💙Citizens @ManCity」）2026-10-02 03:20 UTC。Yahoo!リアルタイム検索「ポルトガル ロナウドいない」で見つけ、fxtwitter で全文
   原文「ポルトガルの強さ見てるとやっぱりロナウドいない方が強いのな 個としてではなくチームとして強い」 https://x.com/rikoriko_j468/status/2105860446955970864
   → 短いので short_voice
2. X @Breezy09800（プロフィール「Football Runs the Timeline / Messi & Yamal Supremacy @Barcelona」）2026-10-02 07:06 UTC。Yahoo!リアルタイム検索「Portugal without Ronaldo」。fxtwitter で全文（画像1枚つき。文だけで通じる）
   原文 "Portugal 🇵🇹 without Ronaldo suddenly turns into the second version of Spain ,pure football, no noise. 🥶🇵🇹🇪🇸" https://x.com/Breezy09800/status/2105917360813351397
   訳「ロナウド抜きのポルトガルは、急に第2のスペインになった。純粋なサッカーで、雑音が無い。」（絵文字・国旗は外した）
3. Yahoo!ニュース（フットボールチャンネル「C・ロナウド電撃離脱で“混乱”のポルトガル代表が4発快勝…」10/2 6:00）のコメント欄 1ページ目 kinoko
   原文「まあ使う気がないなら最初から話し合いして呼ばなければ良かったね　大ベテランだしロナウドもそれ相応に扱われたいと思うのも当然だと思う　人間だからね」
   https://news.yahoo.co.jp/profile/news/comments/b97aed00-5696-4280-b8cb-eb05bca8c83b （記事 https://news.yahoo.co.jp/articles/65c32a887504a366adeab1bed6acebf83a0ecf05 ）

選び方: 「いない方が強い」側（1・2）だけにならないよう、ロナウドの側に立つ声（3）を入れた。
当たって入れなかったもの:
- Yahoo!（同じ記事・サッカーキングの2本）: 「目の上の瘤」「ガンでしかなかった」「お邪魔虫」「10人で戦ってた」など、選手をおとしめる言い方のもの。マイルドペガサス「21世紀に入ってからデンマークには勝ててなかった」（事実と違う含みがある）。vvs（AI に聞いた答えを貼ったもの＝本人の言葉ではない）。tn1「ブルーノいきなり2アシストしてて草」（短く中身は合うが、語尾の「草」を読み上げると伝わりにくい）。jwm「フェリックス絶好調だな…」（候補。3件に収めるため外した）。lqo「ポルトガルが勝ったこと自体よりロナウドがいなかったことのほうが話題になる…」（候補）
- X: runio_bear10_07「普通にロナウドいない方がポルトガル強いじゃん(今は)／ラモスが成長したなーと思いました」（1と重なる）、warunta_（移籍金の数字が裏の取れない話）、Eb2Oggrtyu（あざけり）。報道・まとめ・転載アカウント（433、GoalJP_Official、TouchlineX、UTD_Seth001、derocktoldme、MadridXtra など。作り話の引用も混じる）は入れない
- ポルトガル語の個人の投稿: Yahoo!リアルタイムで「seleção sem Ronaldo」「deixei de seguir seleção」は0件

## 写真

- 連盟（FPF）公式サイトの試合記事の写真。撮影は「Diogo Pinto / FPF」（記事の「Foto:」の欄）。連盟の撮影で、代理店（Getty・AFP・ロイター・AP・Lusa・EPA・IMAGO）ではない。透かし無し
  - 01.jpg（2197x1465）news/58075「Não há duas sem três」: 13分の先制点を祝う輪（中央カンセロ、左に9番 G. RAMOS の背中）
  - 02.jpg（5763x3842）news/58076: ヴィティーニャ（23番）が指を立てて喜ぶ
  - 03.jpg（2147x1432）news/58077: ジェズス監督がピッチ脇で指示
  - 01_w.jpg・01_v.jpg は tools/facecrop.py で切った（カンセロの顔中心。頭と顎が入っているのを目で見た）
  - FPF の画像は ImageToBytesHandler.ashx で Content-Type が付かず、articlephoto（pressphoto）が「画像ではありません」で止まった。同じ URL を requests で落とし、Pillow で開けることを確かめ、credits.json は pressphoto と同じ形で手で書いた
- 当たって使えなかったもの: A Bola のギャラリー29枚・記事の写真はすべて IMAGO／Lusa／EPA。DN は EPA（Liselotte Sabroe）、Record は AP、TSF は EPA、ESPN は Getty、O Jogo は動画の切り出し（放送映像）とみて使わない
- レオンの言葉の行は、レオン1人の写真が取れていない（FPF 58078 の写真は別の選手）。01（祝う輪）を敷いた

## 追記（台本の言い回しの裏）

- 「ワールドカップのあとに就いたジェズス監督」: ESPN 10/2 "Jesus, who took over from Roberto Martinez after Portugal's World Cup round-of-16 exit"
- 「北部の街ポルト」: 連盟の試合記事・A Bola（Aeroporto Francisco Sá Carneiro, no Porto）
- 本と本のあいだの重なり（前回 scripts/20261002_ronaldo_walkout.md）を10字で突き合わせ、読み上げで重なる行は0（反応の訳「ロナウドのいないポルトガル」を「ロナウド抜きのポルトガル」に、サムネ1行目を「ロナウド不在のポルトガル」にして外した）
- サムネは群れの回（チーム）なので、祝う輪（01）とジェズス監督（03）の2枚並べ。2行目「4発快勝の裏で●●万人が離れた」は、いちばん強い事実（代表の公式アカウントが200万人近く減）を伏せた
