# 材料の控え: ブルーノ・フェルナンデスが語ったロナウド（2026-10-04 取材）

題材: 10/3 のノルウェー戦前日会見で、デンマーク戦で主将を務めたブルーノ・フェルナンデスが、合宿を離れたロナウドを「代表の、サッカーの、国のいちばんの象徴」と語った。
前に出した回: 10/2「ロナウドの代表離脱」（scripts/20261002_ronaldo_walkout.md）、10/3「ロナウド不在のポルトガル」（scripts/20261003_portugal_without.md）。
離脱の経緯・空港の騒ぎ・フォロワー・得点者の分散・懲戒規定・146得点は繰り返さない。レオンの「7番」の言葉（10/3 で使用）とヴィティーニャの「距離を置こうとした」（10/2 で使用）も使わない。
試合（10/4 19:45 ポルト）の結果は書かない（試合の前に出す回）。

取り方: python requests（本文の段落）。WebSearch は URL を探すためだけ（検索の要約は根拠にしていない）。WebFetch は ESPN と Record の確認に1回ずつ。ブラウザの道具は使っていない。
時刻はポルトガル時間（UTC+1）。記事の published_time は記事のとおり。

## 1. ブルーノの会見（10/3、エスタディオ・ド・ドラゴン、ノルウェー戦の前日会見。ジェズス監督のあと）

### 連盟（FPF）公式 news/58103「Bruno e o efeito Jesus: «Estamos a jogar bem e a equipa está a ganhar»」（写真 Diogo Pinto / FPF）
https://www.fpf.pt/pt/News/Todas-as-not%C3%ADcias/Not%C3%ADcia/news/58103
> «Em relação ao Cris, tive uma conversa com ele, falei com ele também, e aquilo que lhe disse é o que repito aqui: o mais importante é que, independentemente daquilo que aconteça, o Cris nunca deixará de ser o maior símbolo da nossa Seleção, o maior símbolo do nosso futebol e, de certeza, o maior símbolo do nosso país»
- 同記事の地の文: 「O capitão defendeu que os assuntos internos devem ser resolvidos «de porta fechada» e salientou que «a Seleção é uma só e continuará sempre a ser uma só»」
- 同記事: 「Eu já conheço o mister, já trabalhei com o mister. Foi o mister que me trouxe aos grandes palcos em Portugal. Sei da exigência ... sei das duras que é preciso levar de vez em quando, algumas delas com razão, outras menos.」（使わない。題に答えない）
- 同記事: 「Os artistas têm que ter sempre alguma na manga. Por isso, amanhã cá estaremos para tentar dar ao povo português mais uma alegria.」（使わない）

### Record（10/3 17:41）質疑の文字起こし
https://www.record.pt/futebol/selecoes/detalhe/bruno-fernandes-tive-uma-conversa-com-o-cristiano-e-o-maior-simbolo-de-portugal
> "...Para finalizar o assunto, não tenho a necessidade de falar com os meus colegas. Todos sabemos como gerir. Temos uma situação que em nada tem a ver com os jogadores. O nosso papel é dar resultados. Eu tive uma conversa com o Cris. O que lhe disse, repito aqui... aconteça o que acontecer, o Cris nunca deixará de ser o maior símbolo da nossa seleção, do nosso futebol, o maior símbolo do nosso país por tudo o que fez. Tem um lugar reservado, não só nos melhores de sempre, mas no coração de todos os portugueses. O mais importante é deixar de dividirmos as águas. A Seleção é uma só e continuará a ser uma só. Independentemente dos ruídos, todas as casas têm que resolver os assuntos de porta fechada. O mais importante é que tudo acabe bem. Nós estamos fora do assunto. Passámos muito tempo a jogar cartas. Estamos fora da polémica. O que eu peço é que o país não se divida, não faça escolhas. Que respeite todos os lados. O Cris é e será sempre o maior ícone do nosso futebol e futebol mundial e merece o respeito de todos os portugueses."
- メディアの注目について聞かれて: "É um processo natural. Estamos habituados a isso. Joguei com o Cris no clube, a maior parte de nós joga há muito com o Cris na Seleção. Sabemos da atenção mediática que isso traz e não é algo que nos retire o foco. Sabemos que estamos a fazer as coisas bem como equipa, o Cris incluído, porque faz parte da equipa. Fez parte do primeiro jogo. ..."
- A Bola（10/3 16:33 UTC）の同じ会見の書き起こし: 「Passámos muito tempo na sala dos jogadores a jogar cartas, estamos por fora desta polémica」（「選手の部屋で」は A Bola の版にある）
  https://www.abola.pt/noticias/bruno-fernandes-revela-conversa-com-ronaldo-nao-existem-divisoes-na-selecao-2026100316312794764
  > «Tem um lugar reservado não só nos melhores de todos os tempos, mas também no coração de todos os portugueses ...»
- O Jogo（10/3 19:30、Filipe Rodrigues Ferreira）にも同じ会見の書き起こし https://www.ojogo.pt/internacional/artigo/bruno-fernandes-espera-que-cristiano-ronaldo-nao-tome-decisoes-a-quente/18133307
- TSF（10/3 17:50、Rui Oliveira Costa）https://www.tsf.pt/desporto/artigo/bruno-fernandes-revela-conversa-com-ronaldo-o-mais-importante-e-que-nunca-deixara-de-ser-o-maior-simbolo-da-selecao/18133258
- ESPN（10/3 15:15 ET、PA）"Cristiano Ronaldo is eternally Portugal's 'greatest symbol' - Bruno Fernandes" https://www.espn.com/soccer/story/_/id/50092158/cristiano-ronaldo-eternally-portugal-greatest-symbol-bruno-fernandes
  - 英訳: "I had a conversation with Cris. What I told him is that the most important thing, regardless of what happens, is that he will never cease to be the greatest symbol of our national team and country" ／ "He has a reserved place not only among the best of all time, but also in the hearts of the Portuguese people"（訳はポルトガル語の原文から作った）

訳（台本）:
- クリスとは、話をした。／伝えたことを、ここでもう一度言う。／何が起きても、クリスは代表のいちばんの象徴であり続ける。／この国のサッカーの、そしてきっと、この国のいちばんの象徴だ。
- 彼の居場所は、史上最高の選手たちの中だけじゃない。／ポルトガルのすべての人の、心の中にある。
- 選手の部屋で、ずっとトランプをしていた。／僕たちは、この騒ぎの外にいる。
- クリスも含めて、チームとしてうまくやれている。／クリスもチームの一員だ。今回の最初の試合にも出ていた。（台本の形。「最初の試合」＝9/24 のウェールズ戦。ロナウドが先発した）

## 2. ブルーノのテレビのインタビュー（10/3、会見のあと、ドラゴンでの練習の前。RTP 3）

### O Jogo（10/3 19:30）
https://www.ojogo.pt/internacional/artigo/bruno-fernandes-espera-que-cristiano-ronaldo-nao-tome-decisoes-a-quente/18133307
> "Eu falei com o Cristiano Ronaldo por respeito, por saber o que significa para nós portugueses, e porque a minha esperança é que ele não tome decisões a quente e queira abandonar seleção de vez, porque se o quiser fazer, tem de ser num dia de festa e não de uma maneira assim como foi. Assim o merece, é o maior ícone do nosso futebol e do país, alguém que levou o nome do país a um lugar e a um patamar onde nunca tinha estado, com todo o respeito por Eusébio e Luís Figo"
> "Se um dia tiver de acontecer que Cristiano Ronaldo deixe a Seleção, tem de ser num dia de festa e não num dia em que o país fique dividido. A Seleção tem de ser um lugar para todos e de todos e onde não existam esse tipo de divisões"

### Record（10/3、André Gonçalves）同じインタビュー（RTP 3）。台本の quotes_from はこれ
https://www.record.pt/futebol/selecoes/detalhe/bruno-fernandes-a-minha-esperanca-e-que-ronaldo-nao-tome-decisoes-a-quente-e-queira-abandonar-selecao-de-vez
> "Eu falei com o Cris por respeito, ... tem de ser num dia de festa e não de uma maneira assim como foi. ... com todo o respeito por Eusébio e Luís Figo. ..."

### TSF（10/3 19:02、Rui Oliveira Costa）同じインタビューの別の書き起こし
https://www.tsf.pt/desporto/artigo/se-acontecer-tem-de-ser-num-dia-de-festa-bruno-fernandes-espera-que-ronaldo-nao-queira-abandonar-selecao-de-vez/18133299
> "Eu falei com o Cris por uma questão de respeito, por saber o que ele significa para nós portugueses e para o povo português e porque a minha esperança é que ele não tome decisões a quente e queira abandonar a seleção de vez. Eu acho que se ele o quiser fazer, tem de o fazer num dia de festa e não uma maneira assim como foi"
- TSF は「a conversa com Ronaldo aconteceu já depois do incidente na Dinamarca」（会話はデンマークでの一件のあと）と書く

訳（台本）:
- クリスと話したのは、敬意からだ。／彼が僕たちポルトガル人にとって何なのか、知っているから。／願っているのは、彼がかっとなって、代表を完全に去ると決めないこと。／もし去るなら、それはお祝いの日でなければならない。／今回のようなやり方ではなく。
- 彼は、この国の名前を、来たことのない場所まで連れていった。／エウゼビオとルイス・フィーゴには、敬意を払ったうえでね。
- 背景: エウゼビオは1966年W杯の得点王（9点、ポルトガル3位）、フィーゴは2000年のバロンドール。
  https://en.wikipedia.org/wiki/Eus%C3%A9bio ／ https://en.wikipedia.org/wiki/Lu%C3%ADs_Figo

## 3. デンマーク戦のあとの選手たち（10/1、ミックスゾーン。O Jogo の書き起こし、Sofia Esteves Teixeira）

- レナト・ヴェイガ（10/1 23:06）https://www.ojogo.pt/internacional/artigo/renato-veiga-ronaldo-deram-me-indicacoes-para-nao-falar-do-assunto/18132700
  > O caso Ronaldo: "Sou alguém muito próximo do Ronaldo e sabe que tenho um grande carinho por ele, mas deram-me indicações para não falar sobre o assunto".
  - ESPN の英訳 "I've been given instructions and I can't talk about the matter"。Renascença 10/2 の見出し「"Deram-me indicações para não falar disso". FPF proíbe jogadores de falar sobre Ronaldo」（連盟が話すのを禁じたと報道。連盟の発表ではない）
  - 訳: ロナウドとはとても近いし、大切に思っている人だ。／でも、この話はしないように言われている。
- ラファエル・レオン（10/1 22:57）https://www.ojogo.pt/internacional/artigo/rafael-leao-herdou-o-sete-de-ronaldo-mais-importante-e-a-equipa/18132697
  > Se sente traído por Ronaldo: "Isso é um assunto que não nos diz respeito. Demonstrámos que somos um grande grupo. Ele em casa de certeza que está contente pela vitória. Como companheiro de equipa, sei como ele é. Mais importante é a equipa e agora é descansar e preparar o jogo".
  - 「7番」「子どもの頃からの憧れ」の部分は 10/3 の回で使ったので使わない。FPF 公式 news/58078 の版は「Certamente que ele, em casa, está contente pela vitória」
  - 訳: 僕たちが口を出す話じゃない。／彼は家で、きっと勝ったことを喜んでいる。／仲間だから、彼がどんな人かは分かる。
- ヌーノ・メンデス（10/1 23:11）https://www.ojogo.pt/internacional/artigo/nuno-mendes-sempre-estivemos-a-remar-para-o-mesmo-lado-jorge-jesus-tem-boas-ideias/18132702
  > Se aceita Ronaldo de volta: "É um jogador da Seleção e estamos mais focados no que temos de fazer agora e no que o treinador tem para nos apresentar. O resto não nos cabe a nós decidir, estamos aqui a receber seja quem for."
  - 訳: 彼は代表の選手だ。／決めるのは僕たちじゃない。／ここで、誰が来ても迎える。
- ゴンサロ・ラモス（10/1 22:02）https://www.ojogo.pt/internacional/artigo/goncalo-ramos-explica-golo-a-romario-e-atira-assuntos-exteriores-nao-influenciam-o-jogo/18132681
  > "Assuntos exteriores não influenciam o jogo de hoje, queremos ganhar todos os jogos..."（ロナウドの名は出していない。台本では使わない）
- トリンコン（10/1）Renascença https://rr.pt/bola-branca/noticia/clube-portugal/2026/10/01/temos-ideias-mais-claras-a-reacao-dos-jogadores-a-vitoria-na-noruega-com-tema-ronaldo-a-parte/487596/
  > "É sempre, óbvio que é difícil, mas tenho respeito por todos e não quero falar a situação."（使わない。尺）
- ヴィティーニャ: 同じ Renascença の「a equipa "tentou focar-se no jogo"」は 10/2 の回で使った。10/2〜10/4 にロナウドについての新しい発言は見つからなかった

## 4. ジェズス監督の前日会見（10/3、ブルーノの前）

### A Bola「«Ronaldo como símbolo», orgulho e cansaço: tudo o que disse Jorge Jesus」（10/3 16:39 UTC）
https://www.abola.pt/noticias/ronaldo-como-simbolo-orgulho-e-cansaco-tudo-o-que-disse-jorge-jesus-2026100314243370394
> — Está disponível para uma reconciliação com Ronaldo?
> — O foco tem que ser a Seleção por tudo. A Noruega, aquilo que temos que fazer bem, que o nosso povo também esteja em sintonia com a bandeira e com o objetivo. Ronaldo é um símbolo da Seleção e de Portugal. Depois do jogo há muito tempo para se falar sobre isso.
> ... O jogo amanhã é o mais importante. Um jogo que se espera bem jogado. É para aí que eu quero ir. O problema neste momento chama-se Noruega.
- FPF 公式 news/58102 の見出しも「Jorge Jesus foca na qualificação: «O problema chama-se Noruega»」（写真 Diogo Pinto / FPF）
- TSF（10/3 17:31）https://www.tsf.pt/desporto/artigo/jesus-mantem-que-ronaldo-e-um-simbolo-da-selecao-mas-foco-e-ter-carinho-da-qualificacao-ja-no-domingo/18133246 「voltou a adiar as explicações sobre o abandono」
- 訳（台本）: ロナウドは代表の、そしてポルトガルの象徴だ。／その話は、試合のあとに時間がたっぷりある。／いまの問題の名前は、ノルウェーだ。
- 監督は「um símbolo」（象徴）、ブルーノは「o maior símbolo」（いちばんの象徴）。言葉の違いは原文どおり

## 5. 連盟と2人の歩み寄りの続き

- Renascença（10/2 17:00、Eduardo Soares da Silva）https://rr.pt/bola-branca/noticia/clube-portugal/2026/10/02/pedro-proenca-quer-reunir-jesus-e-ronaldo-para-regresso-do-capitao/487731/
  「Pedro Proença ... quer reunir com Cristiano Ronaldo e Jorge Jesus para resolver as diferenças」／「Proença deverá falar publicamente sobre o caso depois do jogo contra a Noruega, no domingo à noite」
- RTP（10/2〜3 の速報）https://www.rtp.pt/noticias/desporto/selecao-portuguesa-a-norte-prepara-se-para-a-rececao-de-domingo-a-noruega_e1769193
  「quererá garantir que a história de Cristiano Ronaldo na seleção não termine com uma página negra」／「por agora não há a intenção de promover uma reunión entre CR7 e o selecionador」（**会わせる話は報道で食い違う**。台本では「会長は試合のあとに話す見込み」だけ言う。10/2・10/3 の回の言い回しと重ねない）
- A Bola（10/3 20:01 UTC）「Em dia de jogo de Portugal, Ronaldo vai regressar à Arábia Saudita」
  https://www.abola.pt/noticias/em-dia-de-jogo-de-portugal-ronaldo-vai-regressar-a-arabia-saudita-2026100319540038361
  > "o capitão vai viajar de Madrid até Riade no seu jato privado ... O voo está marcado para as 12h50 de Portugal Continental (13h50 locais) e a chegada para as 19h44 (21h44 locais), precisamente em cima do apito inicial da Seleção Nacional frente à Noruega"
  > "o Al Nassr joga na sexta-feira"
  - 着くのはポルトガル時間 19:44、キックオフ 19:45 の1分前（報道。予定）

## 6. ブルーノの代表の数字

- 代表の出場: Record（10/1、デンマーク戦の主将の記事）「O médio do Man. United é o jogador com mais internacionalizações que consta no onze inicial de Portugal (95). Bernardo Silva, que está no banco, tem 114.」→ デンマーク戦で 96試合
  https://www.record.pt/futebol/selecoes/detalhe/ruben-dias-capitao-da-selecao-apesar-de-bruno-fernandes-ter-mais-internacionalizacoes
- 英語版 Wikipedia の infobox（nationalteam-update 21:42, 1 October 2026 UTC）: Portugal 96試合29得点（数の突き合わせ用。出典は Record の95＋1と合う）
  https://en.wikipedia.org/wiki/Bruno_Fernandes
- アシスト: Bola na Rede（10/1 21:35 UTC、Diogo Lagos Reis。Playmaker のデータ）「Ao fazer duas contra a Dinamarca ... ficou agora com 27 assistências. Desta forma, Bruno Fernandes fica somente atrás de dois jogadores: Cristiano Ronaldo (35) e de Luís Figo (40).」
  https://bolanarede.pt/especial-bola-na-rede/atualidade/bruno-fernandes-no-podio-de-mais-assistencias-pela-selecao-nacional-eis-o-registo/
- 主将: デンマーク戦で主将（DN・Record。UEFA のサイトは一時ルベン・ディアスと誤表示）。ノルウェー戦（9/27）はけがでスタンド（A Bola 9/27 の先発記事「Bruno Fernandes, lesionado, também foi para a bancada」）。A Bola 10/3「a expectativa é que isso deva acontecer novamente no Dragão frente à Noruega」
  https://www.abola.pt/noticias/oficial-o-onze-de-portugal-para-enfrentar-a-noruega-2026092716060086951
- **主将を務めた試合の通算数は見つからなかった**（台本では言わない）
- ロナウドが主将を外れた試合（ジェズス監督の下）: 9/27 ノルウェー 1-2 ポルトガル（ベンチ）、10/1 デンマーク 2-4 ポルトガル（不在）。10/2・10/3 の回で扱ったので台本では言わない

## 7. 試合（10/4）

- 連盟の試合記事（10/1）「receber a Noruega, no Estádio do Dragão, às 19h45」→ 日本時間 10/5（月）3:45。A Bola も「agendado para as 19.45 horas de domingo, no Estádio do Dragão」
- 主審はイタリアのマウリツィオ・マリアーニ（RTP。使わない）

## 8. ネットの反応（3件。全文）

Yahoo!ニュース「ブルーノ・フェルナンデス「C・ロナウドは最高の象徴。代表に分裂はない」（GOAL）」10/4 7:20 配信のコメント欄（__PRELOADED_STATE__ から本文を取得、10/4 朝の時点）
https://news.yahoo.co.jp/articles/afd1d586c62e0868f50723bbf037954a74b4572e/comments

1. commentId 4bb2549a-d301-4736-a31e-3efcd42b5670（取得時「56分前」）全文:
   上手い言い回しやなぁ。「象徴」でありそれは変わらないとはいってるが、直接的は発言は避け、代表自体を最大限に立てている。今までの功績は変わらないし、それだけは事実だからね。
   （「直接的は」は原文のまま）
2. commentId 67e8cb99-3687-4af0-89cc-277c2995f91e（取得時「1時間前」）全文:
   もうロナウドは要らないって声もあるけど、これまで数々の劣勢をひっくり返してきた男は絶対に必要
   ただ、スタメンは厳しいと思うからスーパーサブ的な役割を受け入れなきゃだと思う
   スタメン確約じゃないことを受け入れて、チームの雰囲気を乱さなければ、選手だって揃ってるし次のW杯だって全然狙えるレベル
   ポルトガルの象徴がベンチにいるだけでも相手からしたら嫌だし、味方からしたら心強い
3. commentId 6151c4da-793b-49ce-91ce-aaf60b6d0db4（取得時「9分前」）全文（ショートの締め）:
   ロナウドの功績を讃え、しかしあの態度でもまだチームに必要で戻ってきてほしいとまでは言わないパーフェクトな大人コメントやな

台本に載せたのは 1 と 3 の2件（流れの点検で、2 は会見の言葉そのものへの声ではなく尺も長いので外した）。
選ばなかったもの: 同じ欄の「ブルーノ「一応建前では…」」「ロナウド消えてブルーノ内心大喜びだろうな」は、本人が言っていない内心を決めつける投稿なので外した。X（Yahoo!リアルタイム検索「ブルーノ ロナウド」）は確執の噂・中傷が中心で、題の中身（会見の言葉）への声が無かった。
**海外の声は取れなかった**: Yahoo!リアルタイム検索の英語・ポルトガル語の語（"Bruno greatest symbol Ronaldo" ほか5つ）では、報道（ロマーノ）の投稿しか出なかった。Reddit は requests で 403。

## 9. 写真

- 01.jpg（冒頭・サムネ）: Commons「File:Bruno Fernandes Croatia v Portugal 2 July 2026-136.jpg」CC BY-SA 4.0 / Bryan Berlin（User:Berlination）。W杯のクロアチア戦（2026-07-02、トロント）。両腕を広げて指示を出す横長。01_w・01_v は facecrop で切った（頭と顎が入っているのを目で見た）
- 02.jpg: FPF 公式 news/58103 の写真（Diogo Pinto / FPF）。10/1 デンマーク戦、背中の「B. FERNANDES 8」と左腕の主将の腕章。顔は写っていない（facecrop は顔0件）。テレビのインタビューの節の頭に敷く
- 03.jpg: FPF 公式 news/58102 の写真（Diogo Pinto / FPF）。ジェズス監督の横顔（練習）。facecrop は顔0件（横顔）
- 当たって使えなかったもの: TSF・O Jogo の写真は Lusa、TSF の監督は EPA、ESPN は Getty、Renascença は EPA。FPF のデンマーク戦の他の写真（news/58075〜58078）にブルーノの顔は無かった。Commons の 2018年の顔写真（Alexander Veprev）は古いので外した
- ロナウドの写真は取っていない（主役はブルーノの言葉。ロナウドは語られる側）

## 10. 話者の名前（声の重なりを避けるため）
- draft が声の重なりで止めたので、話者名を「ブルーノ」「ジェズス監督」（10/2・10/3 と同じ）「メンデス」にした。config の voice_fixed には触っていない
