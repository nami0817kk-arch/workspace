# vini_red｜ヴィニシウス、ゴール取り消しの直後に一発退場 の材料

調査日: 2026-10-11。使ったのは **WebFetch / WebSearch と python の requests だけ**（ブラウザの道具は不使用）。
本編1本＋ショート1本。数字はすべて「どこの記録か」を付けた。裏が取れなかったものは「8. 取れなかったもの」に書いた。

---

## 0. この回の核（題に答えること）

**「髪を引っ張った」という行為が、なぜクラシコまで届くのか。**

答えは**主審の報告書（acta）の1行**にある。
報告書は退場の理由を「**相手の髪を引っ張った。ボールはインプレーで、二人のあいだでボールが争われていない状態で**」と書いた。
スペインの懲罰規程（第121条）は、**「ボールを争う可能性がなかった状況での退場は2試合」**と定めている。
レアル・マドリードがクラシコまでに戦うリーグ戦は**セビージャ戦の1つだけ**なので、
2試合なら**セビージャ戦とクラシコの両方**に届く。

---

## 1. 試合そのもの（ESPN の試合データ feed = 一次に近い記録）

`site.api.espn.com/apis/site/v2/sports/soccer/esp.1/summary?event=401882848`

| 項目 | 内容 |
|---|---|
| 試合 | **レアル・マドリード 1対0 ビジャレアル**（ラ・リーガ 第8節、J8） |
| 日時 | 2026年10月10日（土）、キックオフ 2026-10-10T19:00Z |
| 会場 | **サンティアゴ・ベルナベウ** |
| 主審 | **イシドロ・ディアス・デ・メラ・エスクデロス**（Isidro Díaz de Mera Escuderos） |

### 時系列（ESPN の commentary をそのまま）

| 分 | 出来事 |
|---|---|
| 19' | ジュード・ベリンガムに警告 |
| 45' | マドリード交代。ククレジャ ← カレーラス（負傷） |
| **52'** | **マドリード交代。ヴィニシウス・ジュニオール ← トレント・アレクサンダー＝アーノルド**（0対0） |
| **56'** | **ビジャレアル交代。ネイサン・サリバ ← サンティ・コメサーニャ**（＝サリバも途中出場） |
| 60' | ヴィニシウスのシュートをグラシがセーブ |
| **62'** | **ゴール！ マドリード 1対0。ヤン・ディオマンデ（アシスト：バルベルデ）。VARの確認を経て認められた** |
| 63' | VAR判定: ゴール（ディオマンデ） |
| **70'** | **ヴィニシウスのファウル**（サリバがFKを得る） |
| **71'** | **VARによりゴール取り消し。ヴィニシウスが決めたがVARの確認で無効に** |
| 72' | VAR判定: ノーゴール |
| **72'** | **ヴィニシウスに一発退場（violent conduct / 暴力的行為）** |
| 77' | マドリード交代。カマビンガ ← アルダ・ギュレル |
| 86' | マドリード交代。ダンフリース ← ディオマンデ |

- **分の食い違い（控え）**：ESPN の feed は退場を **72分**、主審の報告書（acta）は **73分**、
  AS は「すべては **70分** に起きた」（＝髪を引っ張った場面）、RFEF が公開したVAR音声のツイートは **71'**。
  **台本では、主審の報告書の「73分」を使う**（公式の文書だから）。髪を引っ張った場面は70分、
  ゴールは71分、判定は72〜73分、という並びで矛盾しない。
- **ディオマンデの得点は62分**（ESPN feed）。marca の記事本文は「63分」と書いている。
  **台本では分を言わない**（どちらの数字も置かない）。
- **ディオマンデはこの試合がマドリード移籍後初ゴール**（ガーディアン/AFP、worldsoccertalk）。
  ガーディアン「Madrid's record signing」。

### 試合の流れ（ガーディアン＝AFP の試合記事、原文から）

- ムバッペは代表（フランス）での膝の不調から回復し先発。前半に左ポストを直撃（カレーラスのおとし）。
- ベルナベウでムバッペに**口笛（ブーイング）が一部から**飛んだ。一方で拍手もあった。
- ヴィニシウスはブラジル代表のオーストラリア・インド遠征から戻り、**不調を理由にベンチスタート**。
- 退場後、マドリードは**10人で残り時間を守り切って 1対0**。

---

## 2. 主審の報告書（acta）— marca が中身を詳報。**一次文書の引用**

出典: https://www.marca.com/futbol/real-madrid/2026/10/11/acta-diaz-mera-detalla-expulsion-vinicius-actitud-agresiva-protestas-voz-grito.html
（requests で本文まで読めた。**WebFetch は弾かれなかったが、requests のほうが全文が取れた**）

### 退場の理由（原文）

> 「**por tirar del pelo a un adversario, con el balón en juego, sin estar el balón en disputa entre ellos**」
> （訳：相手の髪を引っ張ったため。ボールはインプレーで、二人のあいだでボールが争われていない状態で）

- 報告書は退場を **73分** と記している。

### 「その他の事象」の欄（原文）

> 「**En el minuto 73 de partido, estando el juego detenido, el jugador del club local número 7
> D. Vinicius José De Oliveira Do Nascimento, después de haber sido expulsado y encontrándose aún
> en el terreno de juego, siguió protestando mi decisión, a voz en grito, dirigiéndose a la zona
> donde me encontraba con actitud agresiva**」
> （訳：試合の73分、プレーが止まっている状態で、ホームクラブの背番号7の選手
> ヴィニシウス・ジョゼ・デ・オリヴェイラ・ド・ナシメントは、退場を命じられたあともピッチ上にとどまり、
> 私の判定に対し**大声で**抗議を続け、私がいた場所へ向かって**攻撃的な態度で**近づいてきた）

- 続けて、選手は「**tuvo que ser sujetado por compañeros de su equipo**」（**チームメイトに取り押さえられなければならなかった**）と書いた。
- ただし主審は「**no pudo apreciar ninguna expresión concreta**」（**具体的な言葉は聞き取れなかった**）とも記した。
  → **何を言ったかは報告書に無い。**ここを推測で埋めない。
- **背番号7であることが報告書に書かれている**ので、写真の人物特定（赤い7番）の裏づけにもなる。

### 同じ夜のほかの処分（報告書より）

- **モウリーニョ監督に警告**、**デレガードのチェンドに警告**。
- **ゴールキーパーコーチのヌーノ・サントスを退場**。
- ビジャレアル側は**デレガードのシスコ・ナダルを退場**。

---

## 3. VARの音声（RFEFが公開）

出典: https://www.marca.com/futbol/primera-division/2026/10/11/audio-var-condena-vinicius-clasico-conducta-violenta-video.html

- **RFEF（スペインサッカー連盟）がVARの音声を公開した。**
- VARの**ムニス・ルイス**が主審ディアス・デ・メラに、
  「**una potencial conducta violenta**」（**暴力的行為の可能性**）を見に行くよう伝えている。
- AS もVAR音声について「**conducta violenta**」の語が使われたと書いている。
- RFEF の投稿（AS の記事内に埋め込み）: 「AUDIO REVISIÓN VAR／Jornada 8｜Primera División／@realmadrid 🆚 @VillarrealCF｜**71'**」

---

## 4. 規程（AS が条文を引用。**ここが「2試合」の根拠**）

出典: https://as.com/futbol/primera/peligra-el-clasico-para-vinicius-f202610-n/

- 当てはまるのは **第121条**。**1試合から2試合**の出場停止を定める。
- 条文の原文:
  > 「**En aquellos casos en que la expulsión se deba a situaciones en que el futbolista no hubiera
  > tenido posibilidad de disputar el balón, la suspensión será de dos partidos**」
  > （訳：退場が、選手に**ボールを争う可能性がなかった**状況によるものである場合、出場停止は**2試合**とする）
- AS の見立て:「ボールを争っている最中だったなら1試合で済む可能性もあったが、**そうでないので2試合を指す**」。
  さらに抗議の「**attitud agresiva（攻撃的な態度）**」と「**チームメイトに取り押さえられた**」の記述で
  **もっと増えうる**。
- **CTA（審判技術委員会）の分類**（marca）：髪を引っ張る行為は **CV.1＝暴力的行為（conducta violenta）** に入る。
  条文の原文:
  > 「jugador propina un codazo, cabezazo, puñetazo, bofetón, agarra del cuello, empujón, patada,
  > coz, mordisco, **tirón de pelo**… a un contrario o cualquier otra persona sin estar disputando
  > el balón, empleando fuerza excesiva o brutalidad」
- AS の審判解説者 **イトゥラルデ・ゴンサレス**（AS と Cadena SER）：
  「**レアル・マドリードのどんな不服申し立ても見通しは厳しい**。髪を引っ張った行為がボールのないところで起きている以上」。
- **処分はまだ出ていない**（10/11 時点）。ESPN は「**今週中**にスペインサッカー連盟の規律委員会が確定させる」。
  検索でも 10/11 の決定の報道は見つからなかった。**「2試合に決まった」と書かない。**

---

## 5. 反応（4つ）

### 5-1. 本人（Instagram）— **確認できた**

- 原文（スペイン語で marca が引用）: 「**La alegría sigue… Perdón a mi equipo y la afición**」
- ESPN の英語: 「**The joy remains. Sorry to my team and the fans**」
- **台本では ESPN の形に合わせた訳**を使う：「**喜びは残る。チームとファンにごめんなさい。**」
  → 2つの媒体の文言を混ぜない。marca（スペイン語）と ESPN（英語）は同じ文の訳で、内容は一致している。
- 投稿の時刻: 試合終了後。
- **もう1つの投稿（ストーリー）は使わない。** marca によると、ヴィニシウスは約20分後に
  **ファンのアカウントが作った画像（自分へのファウルを並べた合成）を自分のストーリーに貼り直し**ていて、
  その画像に「Y el que recibe amarilla y roja siempre es Vinicius, qué vergüenza」と書かれていた。
  **これは本人が書いた言葉ではない（他人の投稿の貼り付け）**ので、本人の発言として引かない。
  （OneFootball／L'Équipe も「ファンのアカウントの合成を共有した」と書いている）

### 5-2. チュアメニ — **確認できた。ただし2つの形がある**

| 媒体 | 文言 | 誰に話したか |
|---|---|---|
| **ESPN** | 「I don't understand what's happening with the referees, with the red card. I don't understand it」 | **レアル・マドリードTV** |
| ガーディアン（AFP） | 「I don't know what's going on with the referees, with this red card, I don't understand. But the most important thing is the victory」 | （明記なし） |

- **ESPN の形を採る**（話した相手が明記されているほう）。**2つを混ぜない。**
- 訳：「**審判と、あのレッドカードに何が起きているのか分からない。分からないよ。**」
- ガーディアンにしかない「でもいちばん大事なのは勝利だ」は**使わない**（混ぜないため）。

### 5-3. モウリーニョ — **会見を欠席した**

- ESPN:「Coach José Mourinho later skipped his scheduled post-match news conference」
- marca（https://www.marca.com/futbol/real-madrid/2026/10/10/mourinho-habla-partido.html）:
  - **ラ・リーガがベルナベウで「会見しない」と伝えた**のは、試合終了から**40分後**に監督が会見室に現れなかったあと。
  - **選手も誰も話さなかった**（marca「今季よく見られる形」）。
  - marca が独自に把握したところでは、**審判についての発言が処分につながることを恐れて話さないことを選んだ**。
    marca が載せている言葉:
    > 「**No voy a hablar porque quiero sentarme en el banquillo ante el Sevilla y el Barcelona**」
    > （訳：**話すつもりはない。セビージャ戦とバルセロナ戦でベンチに座っていたいから。**）
    - **扱い注意**：これは会見での発言ではなく、**marca が「把握した」として載せている言葉**。
      確度は **報道**。台本でも「報道」の札を付け、**会見で言った形にしない**。
  - 会見は**火曜（10/13）のチャンピオンズリーグ・ローマ戦の前日会見に先送り**された。
- **スタンドの合唱（「連盟に汚職」「テバスは出ていけ」「ネグレイラはまだ…」）は使わない**（組織・政治の話で、題に答えない）。

### 5-4. ベリンガム — **確認できなかった（この回では使わない）**

- 題材の一覧には「ベリンガム『いつでも君のそばにいる』」とあったが、
  **ESPN・ガーディアン・marca・AS・worldsoccertalk・OneFootball のどこにも、
  ベリンガムのその発言（Instagram のコメントを含む）は見つからなかった。**
  WebSearch も3通りの言い方（英語・スペイン語）で引いたが出てこない。
- 出てきたのは **sportbible の「ファンはベリンガムが『the game's gone』と言ったと確信している」**という
  **読唇術の記事**だけ。これは**未確認**で、タブロイド系。**本人の発言として使えない。**
- **確認できたベリンガムの事実**（これは使う）:
  - **取り消されたゴールは、ベリンガムが左から持ち込んでマイナスに折り返したパスから生まれた**
    （ガーディアン、Radio MARCA「tras la asistencia de Bellingham」）。
  - ベリンガムは**19分に警告**を受けている（ESPN の feed）。
- **→ 反応は「本人の謝罪」「チュアメニ」「モウリーニョの欠席」の3つで組む。**

### 5-5. ビジャレアル側（フォイス）— 確認できた（台本では使わない）

- ESPN:「I don't think he meant to hurt anyone but it is a red card」（フアン・フォイス）
- **フォイスは56分に交代で退いている**（ESPN feed：カルロス・ロメロ ← フォイス）ので、
  退場の場面はピッチの外から見ている。**台本には入れない**（題に答えない・相手側の評価）。

### 5-6. 審判解説（台本では使わない）

- Radio MARCA のゴンサレス・フエルテス:「Bien expulsado porque es un agarrón de pelo muy ostensible a Saliba.
  Es una conducta violenta por parte del delantero del Real Madrid. Y, lógicamente, el gol está bien anulado」
- 題は「なぜクラシコまで届くのか」なので、**規程の条文（4.）のほうが直接答える。**

---

## 6. 退場のあと、ピッチで起きたこと（marca。報告書の「取り押さえられた」の裏づけ）

出典: https://www.marca.com/futbol/real-madrid/2026/10/10/reaccion-vinicius-roja-llevan-tres-pantalla-ruediger-arbitro-gesto-endrick.html

- **バルベルデ、アルダ（ギュレル）、チュアメニの3人**が、主審から引き離すためにヴィニシウスを抱えた。
- **リュディガー**が、選手と主審のあいだに入って**壁（pantalla）**を作った。
- **エンドリック**がベンチから出てきて、戻らないように階段まで付き添った。
- → **主審の報告書の「チームメイトに取り押さえられた」と、映像で見えたことが一致する。**

---

## 7. 日付と順位（ESPN の日程・順位の feed）

### 次の試合

| 日 | 大会 | カード |
|---|---|---|
| 10月14日（水） | チャンピオンズリーグ | **ローマ 対 レアル・マドリード**（アウェイ） |
| **10月18日（日）** | **ラ・リーガ** | **レアル・マドリード 対 セビージャ**（ベルナベウ。AS によると 21:00 CEST） |
| **10月25日（日）** | **ラ・リーガ** | **バルセロナ 対 レアル・マドリード**（＝クラシコ。アウェイ＝カンプ・ノウ） |

- **クラシコまでに挟まるリーグ戦はセビージャ戦の1つだけ。**（ESPN・marca・AS が一致）
- AS は「2試合の出場停止でも、残っているのがちょうどその2つなので、カンプ・ノウには立てない」と書いた。
- AS はさらに「もっと重ければ、エル・サルディネロ（アウェイ）も」と書いている。**台本では使わない**（まだ処分が出ていないため）。

### ラ・リーガ順位（第8節終了時点、ESPN の順位 feed）

| 順位 | クラブ | 試合 | 勝 | 分 | 敗 | 得点 | 失点 | 勝ち点 |
|---|---|---|---|---|---|---|---|---|
| 1 | **バルセロナ** | 8 | 8 | 0 | 0 | 34 | 7 | **24** |
| 2 | アトレティコ・マドリード | 8 | 6 | 1 | 1 | 18 | 8 | 19 |
| 3 | **レアル・マドリード** | 8 | 6 | 0 | 2 | 19 | 8 | **18** |
| 5 | セビージャ | 7 | 4 | 1 | 2 | 10 | 9 | 13 |

- ESPN の記事も「3位、アトレティコに1点差、首位バルセロナに6点差」と書いていて一致。
- **バルセロナは8戦8勝**。クラシコは**その無敗の相手の本拠地**で行われる。

---

## 8. 取れなかったもの・使わないもの

| 何 | なぜ |
|---|---|
| **ベリンガムの「いつでも君のそばにいる」** | **どの媒体にも見つからなかった**（5-4）。読唇術の記事しか出てこない。**使わない** |
| 出場停止の試合数の決定 | **10/11 時点で出ていない**。ESPN「今週中に確定」。「2試合になった」と書かない |
| ヴィニシウスのストーリーの文言 | **他人の投稿の貼り付け**なので本人の言葉ではない（5-1） |
| BBC | 読みに行っていない（marca・AS・ESPN・ガーディアンで足りた） |
| kicker | この題材では使っていない |
| スタンドの合唱・ネグレイラ | 題に答えない。組織の話 |
| ムバッペへの口笛 | 題に答えない（別の話） |
| ネットの反応 | **集めていない**（この日の方針。precheck の「反応が1件もありません」の × は残す） |

---

## 9. 写真（代理店のものは入れていない）

| ファイル | 中身 | 出どころ | 代理店か |
|---|---|---|---|
| `assets/images/20261011_vini_red/01.jpg` | **背番号7のヴィニシウスが叫んでいる横長**（1980x780。元の下にあった marca の絵文字の帯を切り落とした） | marca.com の記事（probable-vinicius-conozca-reglamento） | **表記なし。画像を開いて透かしが無いことを確かめた** |
| `assets/images/20261011_vini_red/02.jpg` | エンブレムに口づけするヴィニシウス（1980x1320） | marca.com（vinicius-pide-perdon-expulsion-villarreal）。**写真の表記は PABLO MORENO**（marca の撮影者） | 違う |
| `assets/images/20261011_vini_red/03.jpg` | ベルナベウのタッチラインに立つモウリーニョ（900x600 に寄せて切った） | marca.com（mourinho-habla-partido） | **表記なし。開いて確かめた** |

- **落とした写真**：marca「Vinicius abre la puerta a Diomande」の1枚は
  キャプションが「**NurPhoto via Getty Images**」だったので**取り込まなかった**。
- **AS の og:image**（ベンチのヴィニシウス、1472x828）は**撮影者の表記がどこにも無かった**ので見送った。
- **ESPN の og:image は取り込んでいない**（ESPN のサッカー写真はほぼ Getty）。
- **放送映像は使っていない**。AS の「Agarrón de Vinicius al pelo de Saliba. Movistar LaLiga」は
  放送の切り出しなので**除外**。
- 被写体の確認：`01.jpg` は**白いユニフォームの背番号7**で、主審の報告書が「背番号7 D. Vinicius」と
  書いているのと一致する。`02.jpg` と `01.jpg` は同じ顔。
