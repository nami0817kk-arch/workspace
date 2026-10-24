# フランクフルト（ブンデスリーガ④）の取材控え（2026-10-23）

道具は requests・curl（Wikipedia action=raw）・ESPN の公開 API・クラブ公式（en.eintracht.de / klub.eintracht.de / museum.eintracht.de、requests で読めた）。ブラウザの道具・検索のAI要約は根拠にしていない。
**クラブ公式まで辿れたものを優先**し、辿れないものは英語版 Wikipedia（台本は事実の言い方で書き、「確定」の札は付けていない＝tier 背景）。

## 先に確かめたこと
- フランクフルトのクラブ紹介は、scripts/・research/covered.yaml・research/posted.json に無かった（grep で堂安・長谷部などの個別回は出るが、クラブ紹介は無し）。
- **遠藤航はフランクフルトに在籍したことが無い**（依頼文に名前があったが、シュツットガルト→リヴァプール。英語版の「Eintracht Frankfurt players」と日本人選手のカテゴリの掛け合わせにも出ない）。台本には入れていない。
- 日本人選手：英語版 Wikipedia のカテゴリ（Eintracht Frankfurt players × Japanese men's footballers）で**7人**＝高原直泰・稲本潤一・乾貴士・長谷部誠・鎌田大地・堂安律・小杉啓太。**網羅は確かめられない**ので台本は「少なくとも7人」。
  - 在籍とリーグ戦（各人の infobox）：高原 2006-2008（38試合12得点）／稲本 2007-2009（43試合0得点）／乾 2012-2015（75試合7得点）／長谷部 2014-2024（235試合2得点、全大会303試合）／鎌田 2017-2023（127試合20得点、2018-19 はシント＝トロイデンにレンタル）／堂安 2025-（36試合5得点。昨季31試合5得点、今季5試合）／小杉 2026-（6試合0得点。2025-12-18 に契約、2026-01-01 から）。

## クラブ公式まで辿れたもの
- 創立：1899-03-08（クラブ博物館の年表。前身 Frankfurter FC Victoria。Kickers 1899 とは別。1920 に TuS Eintracht Frankfurt von 1861、1927 に分離、1969 に再合流）。
- 1959：ドイツ選手権決勝で Kickers Offenbach に5-3（延長）、初のドイツ王者。1959-60 ヨーロッパ杯：準決勝 Rangers にホーム6-1、Ibrox 6-3（合計12-4）。決勝 Hampden Park で Real Madrid に3-7（Kress が先制）。決勝は準決勝の14日後（museum 1945-1963）。
- 1963 ブンデスリーガ創設時から33シーズン連続で1部（museum 1963-1981）。初年度3位。
- 1976 カップウィナーズカップ準決勝 West Ham に 2-1・1-3（museum 1963-1981）。
- 1979-80 UEFAカップ：準決勝 Bayern に 0-2・5-1（延長）、決勝 Gladbach に 2-3・1-0（81分 Schaub）、アウェーゴール差で優勝（1980-05-21。museum 1963-1981）。
- 1991-92：34節で Leverkusen に3-1、首位に。最終節に Rostock で敗れ優勝を逃す（museum 1981-1996）。**英語版**：最終節の前に Frankfurt・Stuttgart・Dortmund が勝点50で並び、Frankfurt は Rostock に1-2で3位、Stuttgart が Leverkusen に2-1で優勝（1991–92 Bundesliga）。当時は20クラブ・38試合。
- 2018 DFBポカール決勝 Bayern に3-1（Rebić 2点、Gaćinović）。2022：ヨーロッパリーグ。準々決勝 Barcelona にホーム1-1、Camp Nou 3-2（**3万人超**のファン）。決勝 Seville で Rangers に1-1（延長）、PK5-4（Hrustic・Kamada・Kostić・Borré が成功、Trapp が Ramsey のPKを止めた）。（museum 2016-2024）
- 本拠地の収容：2026-08-09 に公式が60,100人と発表（51,500→59,500→60,100）。
- 株：e.V.（会員のクラブ）が AG の株の67.89%を持つ（klub.eintracht.de、2025-07-01）。会員は2000年ごろ5,000人→15万5000人超（同記事）。
- 監督：2026-05-31 公式発表、Adi Hütter（56歳）。2026-07-01 就任、契約は2029-06-30まで。前職 Monaco（2023-24 は2位、翌年3位）。1期目 2018-07〜2021-06、ヨーロッパリーグ準決勝（2019）。Krösche（スポーツ担当）「Adi Hütter stands for brave attacking football, clarity and discipline」。

## 英語版 Wikipedia ほか
- 愛称：Die Adler（鷲）／SGE／Launische Diva（気まぐれな歌姫）／Schlappekicker。「気まぐれな歌姫」の由来はクラブ博物館（1945-1963）も「大きな相手に勝った後に、格下に負けることが多かった」と書く。
- 人口：763,380（2019、英語版 Frankfurt）。ドイツで5番目。
- 最多出場：Körbel＝リーグ戦602（ブンデスリーガ最多）、全大会720（1972-1991）、リーグ戦45得点、ドイツカップ4回（1973-74・1974-75・1980-81・1987-88）とUEFAカップ1回。
- Hölzenbein：1967-1981、リーグ戦420試合160得点（クラブ記録）、1974 W杯優勝（西ドイツ）。
- Meier：2004-2018、リーグ戦336試合119得点、2014-15 は26試合19得点で得点王（ロッベン・レヴァンドフスキより2点多い）。
- 1960 ヨーロッパ杯決勝：観客127,621、7-3、決勝の合計10得点は今も最多（英語版）。
- 昨季（ESPN standings season=2025）：8位、勝点44（11勝11分12敗、61得点65失点）。優勝バイエルン勝点89。2024-25：3位（勝点60、68得点46失点）。
- 2021-22：ヨーロッパリーグ 7勝6分0敗（21得点13失点、13試合）。同じ年のブンデスリーガ 11位（10勝12分12敗、45得点49失点、34試合）。（英語版 2021–22 Eintracht Frankfurt season）
- 今季（ESPN standings 2026-10-23 取得）：6節まで2勝2分2敗、10得点16失点、勝点8、11位。第1節 Union 3-3（敵地）／第2節 Augsburg に1-4／第3節 Mainz に3-1（敵地）／第4節 Freiburg 2-2／第5節 Leipzig に0-6（敵地）／第6節 Köln に1-0。ポカール1回戦 St. Tönis に11-0。次は ドイツ時間10/24 18:30 敵地 Dortmund（日本時間10/25 1:30）、10/27 ポカール2回戦 Hamburg 敵地。
- 1試合あたり：今季 10÷6＝1.7得点・16÷6＝2.7失点。2021-22 EL 21÷13＝1.6得点・13÷13＝1.0失点。同年リーグ 45÷34＝1.3得点・49÷34＝1.4失点（自分で割った）。

## 確かめられなかったこと
- 堂安・小杉の今季の出場数（ESPN の試合ごとの出場記録は取得がタイムアウトした。Wikipedia の選手記事 2026-10-16 更新の値＝堂安5・小杉6）。台本は堂安は昨季の31試合5得点と通算36試合5得点（板）、小杉は「今年1月に来た20歳」にとどめた。
- 日本人7人が全員かどうか（カテゴリの掛け合わせでの数）。

## 材料の補修（research/bd_data）
- standings.json はフランクフルトの行だけ第6節に更新。results.json にフランクフルトの第5・6節を追記。
- kana_frankfurt.json に26人の読み。faces_frankfurt.json（clubfaces.py）に名選手3人・監督・日本人4人。写真は assets/photos/bd/frankfurt/、場面写真は assets/images/bd_frankfurt_*（出典は各 credits.json、Commons CC BY / BY-SA / CC0）。
- stadium_フランクフルト(_in).png は Commons（外観 CC BY-SA 4.0 Patrik Meyer／内観 CC0 Davicilio20）。bd_frankfurt_map.png は plmap.draw で1クラブだけ描いた。
