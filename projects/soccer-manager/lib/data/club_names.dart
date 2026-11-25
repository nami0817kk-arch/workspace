import '../l10n/tr.dart';
import '../models/league_theme.dart';

/// 国・部ごとのクラブ名(2026-11-22)。
///
/// ユースのアプリ(youth-academy の YA.PRO_CLUBS)と同じ付け方:
/// 実在の今季(2025-26)の1〜3部の顔ぶれに1クラブずつ対応させ、名前は
/// 「町 + 実在の愛称を少し変えた語」。正式名・エンブレムそのものは使わない。
/// 実在のクラブと同じ部に置く。名前は設定から書き換えられる。
///
/// 3部のうち、実在では組が分かれている国(スペイン・イタリア・フランス)は、
/// そこから部のクラブ数ぶんを選んだ。
// i18n-ignore: 日本語表示用の名前データ(英語は対になる組で持つ)。
class ClubNames {
  ClubNames._();

  /// [theme] の [tier] 部のクラブ名(表示の言語で)。部のクラブ数より
  /// 少し多いこともある(自クラブが入る分の余り)。
  static List<String> tier(LeagueTheme theme, int tier) {
    final block = _data[theme]![(tier - 1).clamp(0, 2)];
    return [
      for (final line in block.split('\n'))
        if (line.contains('|'))
          Tr.pick(line.split('|')[0].trim(), line.split('|')[1].trim()),
    ];
  }

  /// [theme] の全部の部のクラブ名(1部から順に)。
  static List<String> all(LeagueTheme theme) => [
        for (var t = 1; t <= 3; t++) ...tier(theme, t),
      ];

  /// クラブ名(日本語・英語のどちらでも)から、エンブレム画像の番号
  /// (assets/crests/NNN.webp)を引く。表に無い名前なら null。
  ///
  /// 番号は _data の並び(国 → 部 → 行)の通し番号。チームの id は
  /// 新しく始めたとき・部の入れ替えのたびに付け直され、どの名前が付くかも
  /// 自クラブの名前を避ける分だけずれるので、名前から引くのがいちばん確か。
  /// 名前は作った時の言語で保存されるため、両方の言語で引ける。
  static int? crestIndexOf(String name) => _crestIndex[name.trim()];

  /// 表にあるクラブの数(エンブレム画像の枚数)。
  static int get crestCount => _crestNames.length ~/ 2;

  /// 番号 [index] のクラブの (日本語, 英語) の名前。
  static (String, String) crestNames(int index) =>
      (_crestNames[index * 2], _crestNames[index * 2 + 1]);

  static final List<String> _crestNames = [
    for (final blocks in _data.values)
      for (final block in blocks)
        for (final line in block.split('\n'))
          if (line.contains('|')) ...[
            line.split('|')[0].trim(),
            line.split('|')[1].trim(),
          ],
  ];

  static final Map<String, int> _crestIndex = {
    for (var i = 0; i < _crestNames.length; i++) _crestNames[i]: i ~/ 2,
  };

  // 1行に「日本語|英語」。部ごとに1つの文字列で持つ(翻訳漏れの点検が
  // 長い表の途中を見落とさないよう、i18n-ignore を部ごとに付ける)。
  static const Map<LeagueTheme, List<String>> _data = {
    LeagueTheme.england: [
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
ロンドン キャノニアーズ|London Cannoneers
バーミンガム ヴィラーノ|Birmingham Villano
ボーンマス チェリーナ|Bournemouth Cherrina
ブレントフォード ビーハイヴ|Brentford Beehive
ブライトン ガルズ|Brighton Gulls
バーンリー クラレッティ|Burnley Claretti
ロンドン ブルーライオンズ|London Blue Lions
クロイドン パレシアンズ|Croydon Palacians
リヴァプール タフィーズ|Liverpool Taffies
フラム コテジアンズ|Fulham Cottagians
リーズ ピーコックス|Leeds Peacocks
リヴァプール レッドバーズ|Liverpool Redbirds
マンチェスター スカイズ|Manchester Skies
マンチェスター デヴィルズ|Manchester Devils
ニューカッスル マグパイアーズ|Newcastle Magpiers
ノッティンガム フォレスターズ|Nottingham Foresters
サンダーランド ブラックパンサーズ|Sunderland Black Panthers
ロンドン コッカレルズ|London Cockerels
ロンドン ハンマリーズ|London Hammeries
ウルヴァーハンプトン ウルフパック|Wolverhampton Wolfpack
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
バーミンガム ブルーノーザ|Birmingham Bluenosa
ブラックバーン ローザズ|Blackburn Rosas
ブリストル レッドロビン|Bristol Red Robin
ロンドン ヴァリアント|London Valiant
コヴェントリー スカイライン|Coventry Skyline
ダービー ラムホーンズ|Derby Ramhorns
ハル アンバータイガー|Hull Amber Tiger
イプスウィッチ トラクターズ|Ipswich Tractors
レスター フォクシーズ|Leicester Foxies
ミドルズブラ リヴァーサイダーズ|Middlesbrough Riversiders
ロンドン ドックライオンズ|London Dock Lions
ノリッジ カナリアンズ|Norwich Canarians
オックスフォード イエローズ|Oxford Yellows
ポーツマス ポンピアンズ|Portsmouth Pompeians
プレストン リリーズ|Preston Lilies
ロンドン フーパーズ|London Hoopers
シェフィールド ブレイダーズ|Sheffield Bladers
シェフィールド ナイトアウルズ|Sheffield Night Owls
サウサンプトン セイントリーズ|Southampton Saintlies
ストーク ポッタリーズ|Stoke Potteries
スウォンジー ホワイトスワン|Swansea White Swan
ワトフォード ホーネティアーズ|Watford Hornetiers
ウェスト・ブロムウィッチ スロッスルズ|West Bromwich Throstles
レクサム レッドワイバーン|Wrexham Red Wyvern
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
ウィンブルドン ウォンブリーズ|Wimbledon Womblies
バーンズリー タイカーズ|Barnsley Tykers
ブラックプール タンジェリーナ|Blackpool Tangerina
ボルトン トロッティーズ|Bolton Trotties
ブラッドフォード バンタミーズ|Bradford Bantamies
バートン ブルワリーズ|Burton Breweries
カーディフ ブルーウィングス|Cardiff Bluewings
ドンカスター ドニーズ|Doncaster Donnies
エクセター グレシア|Exeter Grecia
ハダースフィールド テリアンズ|Huddersfield Terrians
ロンドン オリエンタルズ|London Orientals
リンカーン インピーズ|Lincoln Impies
ルートン ハットメイカーズ|Luton Hatmakers
マンスフィールド スタッガーズ|Mansfield Staggers
ノーサンプトン シューメイカーズ|Northampton Shoemakers
ピーターバラ ポッシュメン|Peterborough Poshmen
プリマス ピルグリマーズ|Plymouth Pilgrimers
バースラム ヴェイリアンツ|Burslem Valeiants
レディング ロイヤリーズ|Reading Royalies
ロザラム ミルストーンズ|Rotherham Millstones
スティーヴニッジ ボロウズ|Stevenage Boroughs
ストックポート ハットンズ|Stockport Hattons
ウィガン ラティカーズ|Wigan Laticers
ウィコム チェアメイカーズ|Wycombe Chairmakers
''',
    ],
    LeagueTheme.spain: [
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
ビトリア ババソーレ|Vitoria Babasore
ビルバオ レオネーラ|Bilbao Leonera
マドリード コルチョーネ|Madrid Colchone
バルセロナ ブラウグラーナ|Barcelona Blaugrana
ビーゴ セレステーラ|Vigo Celestera
エルチェ フランハベルデ|Elche Franjaverde
バルセロナ ペリキータ|Barcelona Periquita
ヘタフェ アスローネ|Getafe Azulone
ジローナ ブランキベルメル|Girona Blanquivermell
バレンシア グラノータ|Valencia Granota
パルマ ベルメヨーナ|Palma Bermellona
パンプローナ ロヒージャ|Pamplona Rojilla
オビエド カルバヨーナ|Oviedo Carbayona
マドリード フランヒロハ|Madrid Franjirroja
セビリア ベルディブランカ|Sevilla Verdiblanca
マドリード メレンガーレ|Madrid Merengale
サン・セバスティアン チュリウルディン|San Sebastian Txuri-Urdin
セビリア ネルビオネーラ|Sevilla Nervionera
バレンシア ムルシエラーゴ|Valencia Murcielago
ビジャレアル スブマリーノ|Villarreal Submarino
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
アルバセテ メカニコス|Albacete Mecanicos
アルメリア インダリコ|Almeria Indalico
アンドラ トリコロール|Andorra Tricolor
ブルゴス ブランキネグロ|Burgos Blanquinegro
カディス ピラータ|Cadiz Pirata
カステリョン アルビネグロ|Castellon Albinegro
セウタ カバジェーラ|Ceuta Caballera
コルドバ カリファ|Cordoba Califa
レオン クルトゥーラ|Leon Cultura
ア・コルーニャ ブランキアスル|A Coruna Blanquiazul
エイバル アルメーロ|Eibar Armero
グラナダ ナサリー|Granada Nazari
ウエスカ オセンセ|Huesca Oscense
ラス・パルマス アマリージャ|Las Palmas Amarilla
レガネス ペピネーロ|Leganes Pepinero
マラガ ボケローネ|Malaga Boquerone
ミランダ ハバート|Miranda Jabato
サンタンデール ベルデブランコ|Santander Verdeblanco
サン・セバスティアン サンセ|San Sebastian Sanse
ヒホン ロヒブランコ|Gijon Rojiblanco
バリャドリード プセラーノ|Valladolid Pucelano
サラゴサ マーニョ|Zaragoza Mano
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
ムルシア ピメントネーロ|Murcia Pimentonero
アリカンテ エルクラーノ|Alicante Herculano
イビサ セレスタ|Ibiza Celesta
テネリフェ チチャレロ|Tenerife Chicharrero
アルコルコン アルファレーロ|Alcorcon Alfarero
タラゴナ グラナーテ|Tarragona Granate
アルヘシラス アルビロホ|Algeciras Albirrojo
アンテケラ ブランキベルデ|Antequera Blanquiverde
サバデル アルレキン|Sabadell Arlequin
ポンフェラーダ ベルシアーノ|Ponferrada Berciano
フェロル ベルデ|Ferrol Verde
サモラ サモラーノ|Zamora Zamorano
サラマンカ チャロス|Salamanca Charros
ルーゴ アルビベルメーリョ|Lugo Albivermello
オウレンセ アウリエンセ|Ourense Auriense
メリダ ロマーノ|Merida Romano
イルン ブランキネグロ|Irun Blanquinegro
バラカルド グアルディネグロ|Barakaldo Gualdinegro
カルタヘナ カルタヘネーロ|Cartagena Cartagenero
アルコイ モラリスタ|Alcoy Moralista
''',
    ],
    LeagueTheme.germany: [
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
アウクスブルク フッガーズ|Augsburg Fuggers
ベルリン アイゼルネ|Berlin Eiserne
ブレーメン ヴェーザーズ|Bremen Wesers
ドルトムント シュヴァルツゲルプ|Dortmund Schwarzgelb
フランクフルト アードラース|Frankfurt Adlers
フライブルク ブライスガウ|Freiburg Breisgau
ハンブルク ディノス|Hamburg Dinos
ハイデンハイム ブレンツ|Heidenheim Brenz
ジンスハイム クライヒガウ|Sinsheim Kraichgau
ケルン ガイスベッケ|Koeln Geissboecke
ライプツィヒ シュティーア|Leipzig Stier
レーヴァークーゼン ヴェルケルス|Leverkusen Werkers
マインツ ヌルフュンファー|Mainz Nullfuenfer
メンヒェングラートバッハ フォーレン|Moenchengladbach Fohlen
ミュンヘン バヴァリアンズ|Munich Bavarians
ハンブルク キーツキッカー|Hamburg Kiezkicker
シュトゥットガルト シュヴァーベン|Stuttgart Schwaben
ヴォルフスブルク ヴェルフェ|Wolfsburg Woelfe
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
ビーレフェルト アルミーネン|Bielefeld Arminen
ベルリン アルテダーメ|Berlin Alte Dame
ボーフム ルール|Bochum Ruhr
ブラウンシュヴァイク レーヴェン|Braunschweig Loewen
ダルムシュタット リーリエン|Darmstadt Lilien
ドレスデン エルベ|Dresden Elbe
デュッセルドルフ ラインラント|Duesseldorf Rheinland
エルファースベルク ザール|Elversberg Saar
フュルト クレーブラット|Fuerth Kleeblatt
ハノーファー ローテン|Hannover Roten
カールスルーエ ヴィルトパーカー|Karlsruhe Wildparker
カイザースラウテルン トイフェルス|Kaiserslautern Teufels
キール シュトルヒェ|Kiel Stoerche
マクデブルク ブラウヴァイス|Magdeburg Blauweiss
ミュンスター プロイセン|Muenster Preussen
ニュルンベルク フランケン|Nuernberg Franken
パーダーボルン ゼンネ|Paderborn Senne
ゲルゼンキルヒェン クナッペン|Gelsenkirchen Knappen
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
アーヘン カイザーシュタット|Aachen Kaiserstadt
アウエ ファイルヒェン|Aue Veilchen
コットブス エネルギア|Cottbus Energia
デュースブルク ゼブラス|Duisburg Zebras
エッセン ロートヴァイス|Essen Rotweiss
インゴルシュタット シャンツァー|Ingolstadt Schanzer
レーゲンスブルク ドナウ|Regensburg Donau
ガルプセン ハーフェル|Garbsen Havel
マンハイム ヴァルトホーファー|Mannheim Waldhofer
オスナブリュック リラヴァイス|Osnabrueck Lilaweiss
ザールブリュッケン ザールランダー|Saarbruecken Saarlaender
シュヴァインフルト マイン|Schweinfurt Main
ウルム シュパッツェン|Ulm Spatzen
フェルル ヴェストファーレン|Verl Westfalen
ケルン ヴィクトリアーナ|Koeln Viktoriana
ヴィースバーデン ヘッセン|Wiesbaden Hessen
ロストック コッゲ|Rostock Kogge
ミュンヘン ギージング|Munich Giesing
ザントハウゼン クアプファルツ|Sandhausen Kurpfalz
オルデンブルク フンテ|Oldenburg Hunte
''',
    ],
    LeagueTheme.italy: [
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
ベルガモ オロビカ|Bergamo Orobica
ボローニャ フェルシネア|Bologna Felsinea
カリアリ イゾラーニ|Cagliari Isolani
コモ ラリアーナ|Como Lariana
クレモナ グリジョロッサ|Cremona Grigiorossa
フィレンツェ ヴィオラーナ|Firenze Violana
ジェノヴァ グリフォーネ|Genova Grifone
ミラノ ネラッズーラ|Milano Nerazzurra
トリノ ビアンコネーラ|Torino Bianconera
ローマ アクイラーナ|Roma Aquilana
レッチェ サレンティーナ|Lecce Salentina
ミラノ ロッソネーラ|Milano Rossonera
ナポリ パルテノペア|Napoli Partenopea
パルマ ドゥカーレ|Parma Ducale
ピサ トッレ|Pisa Torre
ローマ ジャッロロッサ|Roma Giallorossa
サッスオーロ ネロヴェルデ|Sassuolo Neroverde
トリノ トーリ|Torino Tori
ウーディネ フリウラーナ|Udine Friulana
ヴェローナ スカリジェラ|Verona Scaligera
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
アヴェッリーノ ルーピ|Avellino Lupi
バーリ ガッレッティ|Bari Galletti
カッラーラ マルミフェラ|Carrara Marmifera
カタンザーロ カラブレーゼ|Catanzaro Calabrese
チェゼーナ カヴァッルッチ|Cesena Cavallucci
エンポリ トスカーナ|Empoli Toscana
キアーヴァリ リグーレ|Chiavari Ligure
カステッランマーレ ヴェスペ|Castellammare Vespe
マントヴァ ヴィルジリアーナ|Mantova Virgiliana
モデナ カナリーニ|Modena Canarini
モンツァ ブリアンツォーラ|Monza Brianzola
パドヴァ ビアンコスクード|Padova Biancoscudo
パレルモ ロザネーラ|Palermo Rosanera
ペスカーラ デルフィーニ|Pescara Delfini
レッジョ エミリアーナ|Reggio Emiliana
ジェノヴァ ブルチェルキアータ|Genova Blucerchiata
スペツィア アクイロッティ|Spezia Aquilotti
ボルツァーノ ズュートティローラー|Bolzano Suedtiroler
ヴェネツィア ラグナーレ|Venezia Lagunare
フロジノーネ チョチャーラ|Frosinone Ciociara
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
テルニ フェーレ|Terni Fere
ペルージャ グリフォンチーニ|Perugia Grifoncini
アレッツォ アマラント|Arezzo Amaranto
アスコリ ピッキオ|Ascoli Picchio
ヴィチェンツァ ラネロッサ|Vicenza Lanerossa
トリエステ アラバルダ|Trieste Alabarda
レッコ ブルチェレステ|Lecco Bluceleste
ノヴァーラ ガウデンツィアーナ|Novara Gaudenziana
ベネヴェント ストレーゲ|Benevento Streghe
カターニア エレファンティ|Catania Elefanti
サレルノ イッポカンポ|Salerno Ippocampo
クロトーネ ピタゴリカ|Crotone Pitagorica
フォッジャ サタネッリ|Foggia Satanelli
トラーパニ ドレパナ|Trapani Drepana
カゼルタ ファルケッティ|Caserta Falchetti
ポテンツァ ルカーナ|Potenza Lucana
ブレシア ロンディネッレ|Brescia Rondinelle
ヴェルチェッリ カザッケ|Vercelli Casacche
サッサリ トッレジーナ|Sassari Torresina
リミニ アドリアーティカ|Rimini Adriatica
''',
    ],
    LeagueTheme.france: [
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
アンジェ アンジュヴァン|Angers Angevin
オセール ブルゴーニュ|Auxerre Bourgogne
ブレスト ピラート|Brest Pirates
ル・アーヴル シエル・マリン|Le Havre Ciel-Marine
ランス サンドール|Lens Sang-d'Or
リール ドーグ|Lille Dogues
ロリアン メルリュ|Lorient Merlus
リヨン ゴーヌ|Lyon Gones
マルセイユ フォセアン|Marseille Phoceens
メス グルナ|Metz Grenat
モナコ プランシパル|Monaco Principal
ナント カナリ|Nantes Canaris
ニース エグロン|Nice Aiglons
パリ ブルーマリン|Paris Bleu-Marine
パリ ルージュブルー|Paris Rouge-Bleu
レンヌ ブルトン|Rennes Bretons
ストラスブール アルザシアン|Strasbourg Alsaciens
トゥールーズ ヴィオレ|Toulouse Violets
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
アミアン ピカール|Amiens Picards
アヌシー サヴォワ|Annecy Savoie
バスティア トゥルキーニ|Bastia Turchini
ブローニュ ブーロネ|Boulogne Boulonnais
クレルモン オーヴェルニュ|Clermont Auvergne
ダンケルク マリティーム|Dunkerque Maritimes
グルノーブル アルパン|Grenoble Alpins
ガンガン アルモール|Guingamp Armor
ラヴァル タンゴ|Laval Tango
ル・マン マンソー|Le Mans Manceaux
モンペリエ パイヤダン|Montpellier Pailladins
ナンシー シャルドン|Nancy Chardons
ポー ベアルネ|Pau Bearnais
サントゥアン オードニアン|Saint-Ouen Audoniens
シャンパーニュ ルージュ|Champagne Rouge
ロデーズ アヴェロン|Rodez Aveyron
サン＝テティエンヌ ヴェール|Saint-Etienne Verts
トロワ シャンプノワ|Troyes Champenois
''',
      // i18n-ignore: 日本語表示用の名前データ(英語は同じ行の後ろ)。
      '''
オーバーニュ プロヴァンス|Aubagne Provence
ブール ブレサン|Bourg Bressans
カーン ノルマン|Caen Normands
シャトールー ベリション|Chateauroux Berrichons
コンカルノー トニエ|Concarneau Thoniers
ディジョン ムタルド|Dijon Moutarde
フルリー エソンヌ|Fleury Essonne
ル・ピュイ ヴレ|Le Puy Velay
オルレアン ロワール|Orleans Loire
パリ トレーズ|Paris Treize
ルーアン ケヴィイ|Rouen Quevilly
ルーアン ディアブル|Rouen Diables
ソショー リオンソー|Sochaux Lionceaux
サン＝ブリユー ブリオシャン|Saint-Brieuc Briochins
ヴァランシエンヌ アテニアン|Valenciennes Atheniens
ヴェルサイユ ロワイヤル|Versailles Royale
ヴィルフランシュ ボージョレ|Villefranche Beaujolais
マルティーグ ヴニーズ|Martigues Venise
''',
    ],
  };
}
