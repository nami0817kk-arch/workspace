# 材料の控え: ロナウド、ポルトガル代表の合宿を離脱（2026-10-02 取材、公開 10/2）

題材（ユーザーが○）: 41歳のクリスティアーノ・ロナウドが、ネーションズリーグのデンマーク戦の前日（9/30）にコペンハーゲンの代表合宿を離れた。
センシティブな題材なので、言い切るのは本人・連盟・監督の言葉で確かめた範囲だけ。処分・引退・不仲の中身は報道として扱う。

取り方: curl＋python requests（本文の段落と JSON-LD を抜いた）、X の投稿は api.fxtwitter.com で本文と時刻を取得、英語版Wikipedia は API の wikitext、
WebFetch は ESPN（requests が 202 で本文を返さない）だけ。WebSearch は URL を探すだけ（検索の要約は根拠にしていない）。ブラウザの道具は使っていない。
時刻は UTC。リスボンは UTC+1、コペンハーゲンは UTC+2、日本は UTC+9。

## 精査

台本（scripts/20261002_ronaldo_walkout.md）の読み上げ1文ごとの根拠。番号は台本の上から。原文はポルトガル語・英語のまま。

| # | 台本の文 | 根拠（URL） | 原文 |
|---|---|---|---|
| 1 | （題）ロナウド、ポルトガル代表の合宿を去る。「時が来たら真実を話す」。 | 本人の投稿 https://x.com/Cristiano/status/2105373136581546480 | "tomei a decisão de deixar o estágio da Seleção Nacional" / "A seu tempo, direi a verdade a todos os Portugueses" |
| 2 | （ショートだけ）次の試合も先発しないと監督が会見で話した直後、ポルトガル代表のキャプテンが動きました。 | Renascença 9/30 https://rr.pt/bola-branca/noticia/clube-portugal/2026/09/30/nao-ha-caso-nenhum-jesus-afasta-ideia-de-problema-com-ronaldo-e-aponta-goncalo-ramos-ao-onze/487393/ ／ Maisfutebol 9/30 https://maisfutebol.iol.pt/portugal/cristiano-ronaldo/cristiano-ronaldo-tomei-a-decisao-de-deixar-o-estagio-da-selecao-nacional ／ 主将は Sky https://www.skysports.com/football/news/13593759/cristiano-ronaldo-portugal-captain-leaves-squad-amid-reported-rift-with-head-coach-jorge-jesus | 監督 "Se tudo acontecer normalmente, é o Gonçalo Ramos que vai jogar"（Renascença）。Maisfutebol "Pouco depois, porém, Ronaldo não apareceu no relvado do Parken. O capitão deixou mesmo o estádio numa carrinha da FPF"。Sky "Portugal captain" |
| 3 | 9月30日、41歳のクリスティアーノ・ロナウドが、コペンハーゲンでの代表合宿を出ました。 | 連盟の声明（A Bola が全文を引用）https://www.abola.pt/noticias/fpf-reage-a-saida-de-ronaldo-do-estagio-da-selecao-2026093019171882159 ／ 生年月日 1985-02-05（英語版Wikipedia）https://en.wikipedia.org/wiki/Cristiano_Ronaldo | "A Federação Portuguesa de Futebol informa que o internacional português Cristiano Ronaldo deixou o estágio da Seleção Nacional, que decorre em Copenhaga." |
| 4 | 本人がインスタグラムに出した言葉です。 | Maisfutebol（同上）。A Bola は Instagram の投稿を埋め込み | "escreveu o jogador no Instagram"。同じ文面を X にも投稿（2026-09-30 19:04 UTC） |
| 5〜10 | （ロナウド）代表監督の会見のあと、連盟の会長と話をして、／代表の合宿を離れることに決めた。／時が来たら、ずっと身を捧げてきた代表を去った理由について、／すべてのポルトガルの人に真実を話す。／今は、ポルトガルと、仲間たち全員の幸運を祈るときだ。／一人の例外もなく | 本人の X https://x.com/Cristiano/status/2105373136581546480 （Instagram の文面は Maisfutebol・A Bola の引用と一字一句同じ） | 下の「本人の投稿」に全文 |
| 11 | 連盟は同じ夜、残る24人で準備を続けると発表しました。 | 連盟の声明（A Bola 9/30 19:17 UTC） | "A preparação dos encontros frente à Dinamarca e à Noruega … prosseguirá nos termos previstos, com os restantes 24 jogadores convocados." |
| 12 | さかのぼると、9月27日のノルウェー戦。 | ESPN 試合記録 https://www.espn.com/soccer/report/_/gameId/401861073 | Norway 1-2 Portugal, September 27, 2026, Oslo |
| 13 | ロナウドは後半にアップを続けましたが、最後まで出番がありませんでした。 | ESPN（同上）／Renascença 9/30（同上）／CNN Portugal の書き起こし https://cnnportugal.iol.pt/jorge-jesus/cristiano-ronaldo/nao-ha-caso-nenhum-ninguem-se-recusa-a-treinar-aqui-e-que-eu-fiz-mal-ou-se-precisar-dele-entra-jesus-responde-a-polemica-com-ronaldo-em-20-frases/20260930/6abd494bd34e9a786e75a5a8 | ESPN "with Ronaldo remaining on the bench for the full 90 minutes in Oslo"。Renascença "ter colocado Ronaldo a aquecer logo no início da segunda parte"。監督 "quando anda ali a aquecer 20 minutos, 30 minutos, e depois não entra" |
| 14 | 2日後の練習も、仲間とは別でした。 | Maisfutebol 9/30（同上） | "Na terça-feira, o avançado esteve no relvado em Malmö, conversou com Jorge Jesus, mas não participou no treino com os restantes companheiros. A FPF explicou que Ronaldo fez trabalho específico no hotel" |
| 15 | 30日の会見で、ジェズス監督はこう話しています。 | Renascença・CNN Portugal（同上）。会見は 9/30 午後、デンマーク戦の前日会見 | Renascença 15:50 UTC 掲載 |
| 16〜17 | （監督）私と彼のあいだに何か問題があるように見えているが、／問題なんて何も無い | CNN Portugal の書き起こし（同上） | "Isto parece que há aqui um caso entre mim e ele, quando não há caso nenhum, pá."（Renascença の書き方 "Parece que há um caso entre mim e ele, mas não há caso nenhum."） |
| 18 | 監督は前もって、ノルウェー戦とデンマーク戦には出さないと、本人に伝えていたと言います。 | CNN Portugal（同上） | "E disse ao Cris que o jogo na Noruega e o jogo na Dinamarca ele não iria jogar." |
| 19〜21 | そのうえで、アップのさせ方については誤りを認めました。／（監督）そこは私の誤りだ。アップに行かせるのは、／15分か20分、遅くするべきだった | CNN Portugal（同上）／Renascença（同上） | "Aqui é que eu fiz mal. Eu devia tê-lo mandado aquecer 15 ou 20 minutos mais tarde"（CNN Portugal）。Renascença "Jesus assume um erro, que foi ter colocado Ronaldo a aquecer logo no início da segunda parte: «Isso é que eu fiz mal, deveria ter sido mais tarde.»" |
| 22〜23 | そして、こうも言いました。／（監督）クラブでは会長が決める。チームでは私が決める | CNN Portugal（同上）／Renascença（同上） | "No clube manda o presidente; na equipa mando eu." |
| 24 | 会見で監督は、デンマーク戦の先発はゴンサロ・ラモスだとも話しました。 | Renascença（同上）／A Bola https://www.abola.pt/noticias/ronaldo-confirma-decidi-deixar-o-estagio-da-selecao-nacional-2026093018390304719 | "Se tudo acontecer normalmente, é o Gonçalo Ramos que vai jogar"。A Bola "Jorge Jesus também afirmou que Gonçalo Ramos seria titular contra a Dinamarca, à frente de Ronaldo." |
| 25 | そのあと、ロナウドは練習場に姿を見せないまま、チームを後にしました。 | Maisfutebol（同上） | "Pouco depois, porém, Ronaldo não apareceu no relvado do Parken. O capitão deixou mesmo o estádio numa carrinha da FPF … enquanto os restantes jogadores iniciavam a sessão." |
| 26 | 翌10月1日、ロナウドのいないポルトガルは、デンマークに4対2で勝ちました。 | ESPN 試合記録 https://www.espn.com/soccer/report/_/gameId/401861096 | Denmark 2-4 Portugal, October 1, 2026, Copenhagen |
| 27 | 2度追いつかれ、3度目のリードを奪ったのは67分。ヴィティーニャの頭でした。 | ESPN（同上）／O Jogo https://www.ojogo.pt/internacional/artigo/dinamarca-portugal-vitinha-marca-o-seu-primeiro-golo-de-cabeca-ora-veja/18132671 | 得点: Cancelo 13'・Damsgaard 23'・Ramos 25'・Højlund 53'・Vitinha 67'（assist Bruno Fernandes）・Félix 87'。O Jogo "Aos 67', Vitinha estreou-se a marcar pela Seleção Nacional … naquele que é o seu primeiro golo de cabeça na carreira" |
| 28 | これが代表での初ゴール。試合のあと、ここ数日について、こう話しました。 | Record（Sport TV の取材）https://www.record.pt/internacional/competicoes-de-selecoes/liga-das-nacoes/detalhe/vitinha-feliz-com-por-se-estredo-a-marcar-na-selecao-foi-um-jogo-muito-capaz-da-nossa-equipa ／O Jogo（同上） | 本人 "Foram duas estreias, o primeio golo de cabeça na carreira e o primeiro na Seleção." Record は質問の塊を "Questionado sobre o que se passou nos últimos dias" でまとめている（下の注） |
| 29〜30 | （ヴィティーニャ）ええ、僕たちは距離を置こうとした。／試合に集中して、それができた | Record（同上） | "Sim, nós tentamos manter-nos à margem. Focamo-nos no jogo e conseguimos." |
| 31 | ロナウドの処分はどうなるのか。ポルトガルの報道は、連盟の懲戒規定を引いています。 | Maisfutebol 9/30 https://maisfutebol.iol.pt/portugal/cristiano-ronaldo/ronaldo-arrisca-suspensao-ate-seis-meses-por-abandonar-estagio-da-selecao ／ SELFIE（iol）10/1 https://selfie.iol.pt/famosos/cristiano-ronaldo/cristiano-ronaldo-saiba-qual-e-a-pena-prevista-para-o-abandono-da-selecao-nacional/20261001/6abe24cb0cf23b0ed4fda2e4 ／ Daily Mail 10/1 https://www.dailymail.com/sport/football/article-16176633/ | 下の「処分」に条文の引用 |
| 32 | 正当な理由なく代表の活動を離れた選手は、1か月から6か月の出場停止。 | 同上（3社とも同じ文言） | "O jogador que, regularmente convocado, abandone ou não compareça injustificadamente a treino, jogo ou atividade das seleções nacionais … é sancionado com suspensão de um a seis meses" |
| 33 | ただ、今回に当てはまるかは決まっていません。連盟が出したのは、合宿を離れたことを伝える声明だけです。 | 連盟の声明（A Bola 9/30）。10/2 朝（日本時間）までに当たった記事（Renascença 10/1「FPF não revela motivo para abandono de Ronaldo」の見出し、RTP の速報ページ、A Bola・Maisfutebol の 10/1 夜の記事）に、処分や懲戒の手続きを始めたという発表は無い | 声明は処分に触れていない。**10/2 以降に発表が出ていないかは、公開前にもう一度見る** |
| 34 | 監督は、次のノルウェー戦が終わってから話すとしていて、会長もその試合のあとに話すと報じられています。 | A Bola 10/1 https://www.abola.pt/noticias/jorge-jesus-as-coisas-que-aconteceram-nao-separaram-o-grupo-nem-vao-separar-2026100121164886745 ／ Maisfutebol 10/1 https://maisfutebol.iol.pt/liga-das-nacoes/portugal/jorge-jesus-tenho-um-grupo-que-vai-de-mao-dada-comigo ／ Renascença 10/1 https://rr.pt/bola-branca/noticia/clube-portugal/2026/10/01/pedro-proenca-devera-falar-sobre-caso-ronaldo-depois-do-jogo-com-a-noruega/487543/ | 監督 "Depois do jogo do Dragão, vamos ver o que acontece."（A Bola、Sport TV）／"Depois do Dragão, vamos ver..."（Maisfutebol、RTP のフラッシュ）。Renascença "Pedro Proença … deverá explicar a polémica com Cristiano Ronaldo no fim do jogo frente à Noruega, no domingo, segundo apurou a Renascença." |
| 35 | ロナウドの代表の記録は、234試合で146得点。146は男子の最多です。 | Sky 9/30（同上）／Maisfutebol 9/30（同上）／英語版Wikipedia ／ ESPN 9/30 https://www.espn.com/soccer/story/_/id/50069045/cristiano-ronaldo-portugal-coach-leave-camp-jorge-jesus-bench-denmark | Sky "Ronaldo has scored 146 times in 234 appearances for Portugal"。Maisfutebol "internacionalizações (234) e golos (146)"。ESPN "all-time leading scorer in men's international soccer with 146 goals"。Wikipedia "most men's international goals (146)" |
| 36 | 今年の夏のワールドカップも5試合で3点。ポルトガルはベスト16で敗れました。 | 英語版Wikipedia Cristiano Ronaldo（代表の年別の表の注）・2026 FIFA World Cup Group K（試合票）https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_Group_K ／ Sky https://www.skysports.com/football/news/13560182/world-cup-2026-portugal-0-1-spain-mikel-merino-sends-spain-to-quarter-finals-as-cristiano-ronaldo-fails-to-deliver | Wikipedia "Five appearances and three goals in the 2026 FIFA World Cup"。ウズベキスタン戦 5-0 で2得点、ラウンド32 クロアチア戦 2-1 で PK 1得点、ベスト16 スペイン戦 0-1（Sky の見出し "Portugal 0-1 Spain"）。Group K の試合票で、グループの3試合すべてに先発 |
| 37 | ジェズス監督になってからの3試合で、ピッチに立ったのはウェールズ戦の67分だけ。点は取っていません。 | ESPN 試合記録 https://www.espn.com/soccer/report/_/gameId/401861044 ／ Sky 9/30 | ESPN: Portugal 1-0 Wales（9/24、Lisbon）、得点は Félix 22'、Ronaldo は先発して 67分に交代、59分のゴールはオフサイドで取り消し。Sky "being taken off in the 67th minute" |
| 38 | ポルトガルは3連勝で、取った7点のうち6点は、ロナウドがピッチにいない2試合でした。 | ESPN の3試合の記録（上の3本） | 1-0（ロナウド出場中の得点 1）＋ 2-1 ＋ 4-2 ＝ 7得点。ロナウドがピッチにいない2試合で 2＋4＝6。グループ A4 は3戦全勝・勝ち点9で首位（ESPN の順位表） |
| 39 | 報道では、今回の代表活動の4試合のうち、最初と最後に出す計画でした。 | Renascença 9/30（同上）／A Bola 9/30（同上） | Renascença "O treinador confirma que combinou com Cristiano Ronaldo antes do arranque da prova que seria titular e utilizado apenas no primeiro e último dos quatro jogos da Liga das Nações." A Bola "Ronaldo, à partida, não jogaria nos dois jogos fora, na Noruega e na Dinamarca." ※記者の言い換えなので「報道では」と言う |
| 40 | 最後の1試合は、次の10月4日のノルウェー戦です。 | 連盟の声明（Noruega は Estádio do Dragão）／A Bola 9/30 "no estádio do Dragão, contra a Noruega, no próximo domingo" | 10/4 は日曜 |
| 41 | 離れた理由を、本人はまだ話していません。 | 本人の X（"A seu tempo"）。10/2 朝（日本時間）までに当たった記事に、本人が理由を話したという報道は無い（本人のタイムラインそのものはブラウザを使わない決まりなので見ていない。**公開前にもう一度見る**） | ― |
| 42 | 146点の続きがあるかは、本人の言う真実と、ノルウェー戦のあとに出てくる言葉にかかっています。 | 見立て（上の 34・35・41 から） | 引退や代表に戻らないことは言っていない |
| 43〜50 | （ネット民）ポルトガルではあちこちでロナウドの話題。…こんな形で残念過ぎる。 | X @mimi_mylisbon https://x.com/mimi_mylisbon/status/2105649577088987141 | 下の「ネットの反応」に原文 |

表（画面）も同じ根拠: 「合宿を離れるまで」は 12〜25、「デンマーク 2-4 ポルトガル」は 26〜27（ESPN の得点の分）、「連盟の懲戒規定」は 31〜33、「代表のロナウド」は 35〜37、「ジェズス監督のポルトガル」は 37〜38。
サムネ「抜けた翌日、代表は●得点」＝4（26）。題の引用は本人の投稿の訳（7〜8 を縮めたもの）。

### 依頼文と違っていたところ（台本は原文に合わせた）

- 「監督は扱いの誤りを認めた」→ **認めたのは「アップに行かせる時間」だけ**（"Aqui é que eu fiz mal. Eu devia tê-lo mandado aquecer 15 ou 20 minutos mais tarde"）。起用そのもの（ベンチに置いたこと）は「Isto foi uma opção de treinador. Tinha um plano.」で誤りとしていない
- 「デンマーク戦も先発しないと監督が会見で話した」→ 合っている。ただし監督は「ノルウェー戦とデンマーク戦には出さないと前もって本人に伝えていた」とも話している（計画どおりだったという言い分）
- 「ヴィティーニャ『その話からは離れている』（ロマーノの投稿）」→ ロマーノの該当投稿は見つけられなかった（fxtwitter で読めたロマーノの 10/1 の投稿は「マドリードに戻った」の1本だけ）。**Record の Sport TV の取材の原文**を使った。「Sim, nós tentamos manter-nos à margem.」＝「ええ、僕たちは距離を置こうとした」。Record は質問の文を載せていないので、何について聞かれたかは「ここ数日」まで（その前の段落が "Questionado sobre o que se passou nos últimos dias"）
- 「処分は1〜6か月の可能性」→ 条文の文言はポルトガル紙3社（Maisfutebol・SELFIE・Daily Mail の英訳）で一致。**FPF の規定の原本は開けなかった**（fpf.pt は 403、AF Porto に置かれた写しの PDF はタイムアウト）。条番号は Maisfutebol が「第160条2項」を挙げる（暫定の出場停止の項）。本体の条番号は記事に無い。→ 確度は「報道」、表の題は「ポルトガルの報道が引いた、連盟の懲戒規定」

## 本人の投稿（原文と訳）

X @Cristiano 2026-09-30 19:04 UTC（リスボン 20:04、コペンハーゲン 21:04、日本 10/1 04:04）。api.fxtwitter.com で取得。写真1枚つき。
Instagram の同じ投稿は A Bola が埋め込み、Maisfutebol が「escreveu o jogador no Instagram」として同じ文面を引用。

> Após a conferência de imprensa do Selecionador Nacional, e no seguimento de uma conversa com o Presidente da Federação Portuguesa de Futebol, tomei a decisão de deixar o estágio da Seleção Nacional.
>
> A seu tempo, direi a verdade a todos os Portugueses sobre as razões que motivaram a minha saída da equipa nacional, à qual sempre me dediquei.
>
> Agora é tempo de desejar boa sorte a Portugal e a todos os meus companheiros de equipa, sem exceção.

訳（台本）: 代表監督の会見のあと、連盟の会長と話をして、代表の合宿を離れることに決めた。／時が来たら、ずっと身を捧げてきた代表を去った理由について、すべてのポルトガルの人に真実を話す。／今は、ポルトガルと、仲間たち全員の幸運を祈るときだ。一人の例外もなく

- 英紙の英訳は社ごとに少し違う（Sky "the truth about the reasons behind my departure"、Daily Mail は最後の "without exception" が抜けている）。**原文から訳した**
- 会長は Pedro Proença（ペドロ・プロエンサ、FPF 会長）。台本では名前を出さず「連盟の会長」
- 「saída da equipa nacional（代表を去る）」は合宿を離れたことか代表そのものかが文面から決まらない。台本は本人の言葉どおり「代表を去った理由」と訳し、語りでは「合宿を出ました」「合宿を離れました」までしか言わない（引退とは言わない）

## 監督の会見（9/30 午後、コペンハーゲン、デンマーク戦の前日会見）

出典: CNN Portugal「20 frases」（9/30 19:25 リスボン）・Renascença（9/30 15:50 UTC）。英語は Sky・ESPN。
台本で使った発言（原文 → 訳）:
- "Isto parece que há aqui um caso entre mim e ele, quando não há caso nenhum, pá." → 私と彼のあいだに何か問題があるように見えているが、問題なんて何も無い
- "Aqui é que eu fiz mal. Eu devia tê-lo mandado aquecer 15 ou 20 minutos mais tarde" → そこは私の誤りだ。アップに行かせるのは、15分か20分、遅くするべきだった
- "No clube manda o presidente; na equipa mando eu." → クラブでは会長が決める。チームでは私が決める

語りで使ったもの:
- "E disse ao Cris que o jogo na Noruega e o jogo na Dinamarca ele não iria jogar."（前もって伝えていた）
- Gonçalo Ramos の先発（Renascença・A Bola）

使わなかった発言（尺。中身は台本と矛盾しない）: "Não, não se recusou a treinar."（練習を拒んではいない）、"Posso prometer o que eu quiser. Eu sou treinador."、"Ronaldo ficou zangado"（Canal 11、Renascença 10/1）、"Porque não há um Cristiano, nem nunca vai haver nenhum jogador, que vá mudar as minhas ideias como treinador."、会長について "Mas eu já tinha, depois de jantar, eu e o Cris já tínhamos resolvido o problema."

試合後（10/1、RTP のフラッシュ・Sport TV）: "As coisas que acontecem não separam o grupo, não nos separou e não nos vai separar."（尺で外した）／"Depois do Dragão, vamos ver..."（34 の語りに使った）／A Bola 10/1 17:36「Ronaldo é um assunto encerrado」の記事で "Ele é um símbolo e uma figura. Isso não está em causa."（外した）

## 連盟（FPF）の声明（9/30、A Bola 19:17 UTC が全文を引用。O Jogo・TSF も同じ）

> A Federação Portuguesa de Futebol informa que o internacional português Cristiano Ronaldo deixou o estágio da Seleção Nacional, que decorre em Copenhaga. A preparação dos encontros frente à Dinamarca e à Noruega, este último a disputar no Estádio do Dragão, prosseguirá nos termos previstos, com os restantes 24 jogadores convocados. Toda a comitiva mantém o foco absoluto nos próximos compromissos da Seleção Nacional e na concretização dos objetivos definidos.

- 理由・処分には触れていない。代わりの選手も呼んでいない（Renascença の見出し「FPF não revela motivo para abandono de Ronaldo e não convoca substituto」）
- fpf.pt そのものは 403 で開けなかった。**一次の掲載先は確かめていない**（各紙の引用で一致）

## 処分（報道。未確定）

- 条文の引用（Maisfutebol 9/30 21:38 UTC・SELFIE 10/1、文言は同じ）:
  > O jogador que, regularmente convocado, abandone ou não compareça injustificadamente a treino, jogo ou atividade das seleções nacionais ou relacionada com a representação desportiva da FPF ou de Portugal, é sancionado com suspensão de um a seis meses e, acessoriamente e se for jogador profissional, com multa entre 5 e 10 UC
  - 訳: 正規に招集された選手が、代表の練習・試合・活動、または FPF やポルトガルを代表する競技の活動を、正当な理由なく離れ、または欠いたときは、1か月から6か月の出場停止とし、プロ選手には付加して 5〜10 UC の罰金を科す
  - SELFIE: 1 UC＝102ユーロ → 510〜1,020ユーロ（台本では言わない）
  - 「第160条2項」（Maisfutebol）: "A ausência ou o abandono determina a suspensão preventiva automática do jogador nos termos previsto no presente regulamento"（欠席または離脱は、規定に従い選手の自動的な暫定出場停止をもたらす）。**台本では言わない**（今回が「正当な理由なく」に当たるかが決まっていない段階で、暫定の出場停止に入っているように聞こえるため）
  - Daily Mail は "reports in Portugal claim Ronaldo could be suspended … for between one and six months if he is found to have 'abandoned' the team" と書き、条文を英訳して引用
- **当てはまるかは誰も判断していない**: 本人は「会長と話したうえで」離れたと書いている。連盟の声明は処分に触れない。10/2 朝（日本時間）までに、懲戒の手続きを始めたという発表は見つからない
- 首相の介入（Record → Daily Mail）: 題に答えないので外した

## 試合（ESPN の試合記録）

| 日 | 試合 | ロナウド |
|---|---|---|
| 9/24（木） | ポルトガル 1-0 ウェールズ（リスボン）。Félix 22' | 先発、67分に交代。シュート7本（枠外5）。59分のゴールはオフサイドで取り消し |
| 9/27（日） | ノルウェー 1-2 ポルトガル（オスロ）。Félix 17'、Haaland 51'、G. Ramos 54' | ベンチで90分、出番なし。試合後は仲間とサポーターへのあいさつに加わらずロッカールームへ（CNN Portugal・Renascença） |
| 10/1（木） | デンマーク 2-4 ポルトガル（コペンハーゲン）。Cancelo 13'、Damsgaard 23'、G. Ramos 25'、Højlund 53'、Vitinha 67'、Félix 87' | 合宿を離れて不在 |
| 10/4（日） | ポルトガル 対 ノルウェー（ポルト、エスタディオ・ド・ドラゴン） | ― |

- グループ A4: ポルトガル 3勝 勝ち点9、デンマーク・ノルウェー・ウェールズ 各3（ESPN、10/1 試合後）
- ヴィティーニャの代表初ゴール: 本人「o primeiro na Seleção」（Record）、O Jogo「estreou-se a marcar pela Seleção Nacional」。ESPN の試合記録は「初」とは書いていない

## 代表の記録

- 234試合146得点（Sky 9/30・Maisfutebol 9/30・英語版Wikipedia の年別の表の合計）。146 は男子の最多（ESPN・Wikipedia）
  - WebFetch で読んだ ESPN の 10/1 の記事（Kirkland）の要約に「243」と出たが、他の3つが 234 なので要約の読み違いとみて使わない
- 2026年W杯: 5試合3得点（Wikipedia の注 "Five appearances and three goals in the 2026 FIFA World Cup"）。Group K の試合票でグループ3試合に先発、ウズベキスタン戦 5-0 で2得点（6分・39分）、ラウンド32 クロアチア戦 2-1 で PK、ベスト16 スペイン戦 0-1（Sky・Al Jazeera・PBS の見出し、メリーノの後半追加タイム）
  - ESPN 7/6 の「Four appearances」は記事の時点の数とみて使わない

## 外したもの（題に答えない・推測が混じる）

- 本人に近いスペインの記者 Edu Aguirre（El Chiringuito）「火曜の夜、監督はアップの件で本人に謝り、会見でも謝ると約束した。それなのに会見で…だから裏切りだ」（Daily Mail の引用）。**本人・監督・連盟のどれでもない人の話で、監督の言い分と食い違う**。台本では言わない
- O Jogo「Decisão tomada e irreversível: Cristiano Ronaldo não volta à Seleção Nacional」（見出し。本文は読めていない）、英語版Wikipedia「O Jogo confirmed his retirement from the national team」。**本人は引退と言っていない**ので台本では言わない
- 姉エルマ・アヴェイロの Instagram（Sky・Daily Mail）
- 首相モンテネグロの関与（Record → Daily Mail）
- 7番はラファエル・レオンがデンマーク戦で着けた（Sky・O Jogo）。背番号は埋め草
- ホイルンドの喜び方（Record）
- 監督の試合後の「グループは割れない」（尺）

## ネットの反応（個人の投稿だけ。1件）

1. X @mimi_mylisbon（mimi@ポルトガル、たらふくごはん。プロフィール「ポルトガル在住」。2026-10-01 13:22 UTC。Yahoo!リアルタイム検索で見つけ、fxtwitter で全文を取得）
   原文「🇵🇹ではあちこちでロナウドの話題。朝のニュースではどの話題よりロナウドの話題が最初に紹介される。先日のノルウェー戦で出場なしだったのよね。何か荒波が立つだろうと思ってたけど、🇵🇹代表から自ら離脱とは。もっときれいに去れる時機はとっくに来ていたと思う。こんな形で残念過ぎる。」
   - 国旗の絵文字 🇵🇹 は2か所とも「ポルトガル」と読んだ（外すと「ではあちこちで」「代表から自ら」と文が欠けるため。ほかは一字も変えていない）
   - 読み上げでは長いので句読点の位置で行を分けた（cont: true）
   https://x.com/mimi_mylisbon/status/2105649577088987141

尺（4分36秒）のため外したもの:
- X @pqd9v（2026-10-01 14:59 UTC）「ロナウドの言い分も分かるし、離脱の仕方が強引だったのは本人にも責任あると思う。もう少し折れるところは折って話し合う余地を残してもよかったんじゃないかな／彼はクラブと同じように、コンディションを管理したかったんだろうけど／クラブでは良かったけど代表はまた違ったのかもね、、／なんだかな」 https://x.com/pqd9v/status/2105673891721203977
  （外した理由は尺。中身は両方の言い分を見ていて使える。理由の推測が混じる）

当たって入れなかったもの:
- X（Yahoo!リアルタイム）: Darekasth「ロナウドってもう代表完全に引退なんか…」（引退を前提にした問い）、xtw250「こんな終わり方はして欲しくなかったな」（終わったと決めている）、kqi7__「7番をレオンに渡すのは軽率すぎる」（背番号の話を台本に足す必要がある）、YasushiMorita15（首相の話）、ニュースの転載・まとめ（SoccerKingJP・kicker_jp・otabezinho_kfsh・aratasuzuki・NetiNeti24 など）、grok の自動返信
- ポルトガル語の個人の投稿: Bluesky の検索 API は 403／タイムアウト。Yahoo!リアルタイムで "Ronaldo seleção Jesus" "Ronaldo estágio seleção" を引いたが出たのは B24PT（媒体）だけ。O Jogo の「Redes sociais não perdoam」の埋め込み4件（GonaloSilva3・bunnyhoneey・danielcabral_7・diniscf88）は、3件が画像に頼るミーム（文字だけでは通じない）、GonaloSilva3 は「ロナウドの口利きで監督になり、ロナウドを追い出した」という筋立ての冗談で、事実でない含みがあるので入れない
- Piers Morgan の X 2件（RTP が埋め込み）: 有名人で、罵りが主

## 写真

- 記事の写真は使わない:
  - Maisfutebol: "Cristiano Ronaldo (Kristian Tuxen Ladegaard Berg/NurPhoto via Getty Images)"（代理店）
  - A Bola: "Cristiano Ronaldo - Foto: IMAGO"（代理店）
  - Sky・Renascença: articlephoto で候補が出なかった（Sky は 365dm の配信。代理店か確かめられない）
- Commons: File:Cristiano Ronaldo Croatia v Portugal 2 July 2026-087.jpg（Bryan Berlin、CC BY-SA 4.0、1920x2880）。2026年W杯ラウンド32 のクロアチア戦、ポルトガル代表のアウェーのユニフォーム（W杯2026 のワッペン）。`portrait --file` で取得、目で本人と確かめた。透かし無し
  - 冒頭とサムネは `tools/widecrop.py --top 0.08` で頭のてっぺんが入る位置で 16:9 に切った assets/images/20261002_ronaldo_w/01.jpg（1920x1080）
- 監督の行: File:2020-02-17 Encontro com Técnico do Flamengo, Jorge Jesus (cropped).jpg（Palácio do Planalto、CC BY 2.0）と上のロナウドを `tools/pairphoto.py` で並べた assets/images/20261002_pair_jesus_ronaldo/01.jpg（左ジェズス・右ロナウド。ショート用の 01_v.jpg も）
  - `portrait` が最初に返した File:Jorge Jesus SLB.jpg は 2012年・413x633 で小さいので捨てた
- サムネは1人が主役なのでロナウドだけ（draft の「群れの回」のヒントは、決まり「1人が主役の回のサムネに別の人を並べない」を優先して従わない）
