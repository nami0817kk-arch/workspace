import 'dart:math';

import '../l10n/lang.dart';
import '../models/club.dart';
import '../models/country.dart';
import 'formulas.dart';

/// 世界の定義。国・リーグ・外国人ルールはすべてここに集まる。
///
/// **国名は実在のもの**（2026-09-08 に架空から変更）。国名は地名であって
/// 商標ではないので、そのまま使える。**リーグ名とクラブ名は架空のまま**
/// にする。ここは商標があり、公開と収益化の前提と衝突する。
///
/// **国のIDは変えない。** `club.id` が "albion-t1-c0" のようにIDを含んでいて、
/// 変えると既存の保存データが読めなくなる。表示名だけを差し替えてある。
class World {
  const World._();

  static const String defaultCountryId = 'yamato';

  static const List<Country> countries = [
    // ---- 欧州 ----
    Country(
      id: 'albion',
      name: Say('イングランド', 'England'),
      demonym: Say('イングランド人', 'English'),
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 24, 20],
      foreignRule: ForeignRule(
        confederationFree: false,
        squadLimit: 17,
        homegrownRequired: 8,
      ),
      // 世界で最も厳しい労働許可。若手はまず入れない。
      permitRule: PermitRule(required: 6),
      clubStems: [
        Say('ブラッド', 'Brad'), Say('ケンブ', 'Camb'), Say('ノーサム', 'Northam'), Say('ウェスト', 'West'), Say('ハル', 'Hull'), Say('ダン', 'Dun'),
        Say('ソール', 'Sal'), Say('エヴァー', 'Ever'), Say('プレス', 'Pres'), Say('ミッド', 'Mid'), Say('オーク', 'Oak'), Say('レイン', 'Rayne'),
        Say('サウス', 'South'), Say('グレイ', 'Grey'), Say('ストーン', 'Stone'), Say('ベル', 'Bell'), Say('アッシュ', 'Ash'), Say('クリフ', 'Cliff'),
      ],
      clubPatterns: [Say('{}シティ', '{} City'), Say('{}ユナイテッド', '{} United'), Say('{}ローヴァーズ', '{} Rovers'), Say('{}タウン', '{} Town')],
    ),
    Country(
      id: 'iberica',
      name: Say('スペイン', 'Spain'),
      demonym: Say('スペイン人', 'Spanish'),
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 22],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 3),
      permitRule: PermitRule(required: 4),
      clubStems: [
        Say('バリ', 'Vall'), Say('メリ', 'Meri'), Say('カステ', 'Caste'), Say('セビ', 'Sevi'), Say('グラナ', 'Grana'), Say('アル', 'Al'),
        Say('サラ', 'Zara'), Say('ヒホ', 'Gijo'), Say('コル', 'Cor'), Say('バダ', 'Bada'), Say('ムル', 'Mur'), Say('レガ', 'Lega'),
        Say('トレ', 'Tor'), Say('ヘレ', 'Jere'), Say('カディ', 'Cadi'), Say('ラコ', 'Laco'), Say('エル', 'El'), Say('ビゴ', 'Vigo'),
      ],
      clubPatterns: [Say('{}CF', '{}CF'), Say('デポルティーボ{}', 'Deportivo {}'), Say('{}バロンピエ', '{} Balompie'), Say('CD {}', 'CD {}')],
    ),
    Country(
      id: 'germania',
      name: Say('ドイツ', 'Germany'),
      demonym: Say('ドイツ人', 'German'),
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 18, 20],
      // 連盟内は完全に自由。育成に定評があり、若手が渡りやすい。
      foreignRule: ForeignRule(confederationFree: true, homegrownRequired: 4),
      clubStems: [
        Say('ローテン', 'Roten'), Say('シュヴァル', 'Schwarz'), Say('グリュー', 'Grun'), Say('ハイデ', 'Heide'), Say('エルベ', 'Elbe'), Say('ノイ', 'Neu'),
        Say('アルト', 'Alt'), Say('ヴァルト', 'Wald'), Say('ボーフ', 'Boch'), Say('ブルク', 'Burg'), Say('リンデ', 'Linde'), Say('フェルト', 'Feld'),
        Say('グラウ', 'Grau'), Say('ホーエン', 'Hohen'), Say('タール', 'Tal'), Say('バッハ', 'Bach'), Say('ケーニヒ', 'Konig'), Say('ゾンネ', 'Sonne'),
      ],
      clubPatterns: [Say('FC {}', 'FC {}'), Say('{}04', '{}04'), Say('{}ベルク', '{}berg'), Say('SV {}', 'SV {}')],
    ),
    Country(
      id: 'latium',
      name: Say('イタリア', 'Italy'),
      demonym: Say('イタリア人', 'Italian'),
      confederation: Confederation.vesta,
      prestige: 4,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 4),
      permitRule: PermitRule(required: 3),
      clubStems: [
        Say('ヴェロ', 'Vero'), Say('モンテ', 'Monte'), Say('サレル', 'Saler'), Say('ペルー', 'Peru'), Say('カリア', 'Caglia'), Say('ウディ', 'Udi'),
        Say('パルマ', 'Parma'), Say('ブレシ', 'Bresci'), Say('アンコ', 'Anco'), Say('レッチ', 'Lecc'), Say('ピサ', 'Pisa'), Say('コモ', 'Como'),
        Say('クレモ', 'Cremo'), Say('テルニ', 'Terni'), Say('アヴェ', 'Ave'), Say('カタン', 'Catan'), Say('メッシ', 'Messi'), Say('ノヴァ', 'Nova'),
      ],
      clubPatterns: [Say('{}カルチョ', '{} Calcio'), Say('AC {}', 'AC {}'), Say('{}FC', '{}FC'), Say('US {}', 'US {}')],
    ),
    Country(
      id: 'gallia',
      name: Say('フランス', 'France'),
      demonym: Say('フランス人', 'French'),
      confederation: Confederation.vesta,
      prestige: 4,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        Say('リヨ', 'Lyo'), Say('ナン', 'Nan'), Say('レン', 'Ren'), Say('ブレ', 'Bre'), Say('モンペ', 'Montpe'), Say('トゥル', 'Toul'),
        Say('アンジェ', 'Ange'), Say('ロリ', 'Lori'), Say('クレル', 'Cler'), Say('メス', 'Metz'), Say('ニム', 'Nim'), Say('カン', 'Caen'),
        Say('ナンシ', 'Nancy'), Say('ディジョ', 'Dijo'), Say('アミ', 'Ami'), Say('ラヴァ', 'Lava'), Say('ポー', 'Pau'), Say('グルノ', 'Greno'),
      ],
      clubPatterns: [Say('{}オランピック', '{} Olympique'), Say('AS {}', 'AS {}'), Say('{}FC', '{}FC'), Say('スタッド{}', 'Stade {}')],
    ),
    Country(
      id: 'batavia',
      name: Say('オランダ', 'Netherlands'),
      demonym: Say('オランダ人', 'Dutch'),
      confederation: Confederation.vesta,
      prestige: 3,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 20],
      // 規制が緩い。若い外国人が最初に渡る「踏み台リーグ」。
      foreignRule: ForeignRule(confederationFree: true),
      clubStems: [
        Say('アムス', 'Ams'), Say('ロッテ', 'Rotte'), Say('ユト', 'Utre'), Say('ズヴォ', 'Zwo'), Say('ヘー', 'Hee'), Say('アル', 'Al'),
        Say('ブレダ', 'Breda'), Say('ナイメ', 'Nijme'), Say('ティル', 'Til'), Say('フロー', 'Flo'), Say('デン', 'Den'), Say('エメン', 'Emmen'),
        Say('ハー', 'Haa'), Say('ライ', 'Lei'), Say('ドル', 'Dor'), Say('ヘル', 'Hel'), Say('ワー', 'Waa'), Say('アペル', 'Apel'),
      ],
      clubPatterns: [Say('{}EC', '{}EC'), Say('フォルトゥナ{}', 'Fortuna {}'), Say('{}FC', '{}FC'), Say('SC {}', 'SC {}')],
    ),
    Country(
      id: 'norden',
      name: Say('スウェーデン', 'Sweden'),
      demonym: Say('スウェーデン人', 'Swedish'),
      confederation: Confederation.vesta,
      prestige: 2,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [16, 16],
      foreignRule: ForeignRule(confederationFree: true),
      clubStems: [
        Say('ヴェス', 'Vast'), Say('オス', 'Os'), Say('ベル', 'Bell'), Say('トロン', 'Tron'), Say('ウプ', 'Upp'), Say('マル', 'Mal'),
        Say('ヨン', 'Jon'), Say('リン', 'Lin'), Say('オー', 'Ore'), Say('ハル', 'Hull'), Say('スン', 'Sund'), Say('ボー', 'Bo'),
        Say('ヴィボ', 'Vibo'), Say('エス', 'Es'), Say('ラン', 'Ran'), Say('ヘル', 'Hel'), Say('サン', 'San'), Say('ノル', 'Nor'),
      ],
      clubPatterns: [Say('{}IF', '{}IF'), Say('{}BK', '{}BK'), Say('{}FF', '{}FF'), Say('IK {}', 'IK {}')],
    ),

    // ---- アジア ----
    Country(
      id: 'yamato',
      name: Say('日本', 'Japan'),
      demonym: Say('日本人', 'Japanese'),
      confederation: Confederation.oriens,
      prestige: 3,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 22, 20],
      // 外国人5枠。提携国の選手は枠外という、実在する仕組み。
      foreignRule: ForeignRule(
        squadLimit: 5,
        pitchLimit: 4,
        partnerCountries: ['shams', 'pampa'],
      ),
      clubStems: [
        Say('アオ', 'Ao'), Say('ミナ', 'Mina'), Say('ヒガシ', 'Higashi'), Say('カワ', 'Kawa'), Say('シラ', 'Shira'), Say('トヨ', 'Toyo'),
        Say('ハヤ', 'Haya'), Say('ミヤ', 'Miya'), Say('ナガ', 'Naga'), Say('クロ', 'Kuro'), Say('アカ', 'Aka'), Say('ソラ', 'Sora'),
        Say('シオ', 'Shio'), Say('モリ', 'Mori'), Say('ウミ', 'Umi'), Say('カゼ', 'Kaze'), Say('ホシ', 'Hoshi'), Say('ツキ', 'Tsuki'),
      ],
      clubPatterns: [Say('{}FC', '{}FC'), Say('{}ユナイテッド', '{} United'), Say('{}レイズ', '{} Rays'), Say('{}ヴィエント', '{} Viento')],
    ),
    Country(
      id: 'shams',
      name: Say('サウジアラビア', 'Saudi Arabia'),
      demonym: Say('サウジアラビア人', 'Saudi'),
      confederation: Confederation.oriens,
      prestige: 3,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [16, 16],
      // 資金は潤沢で枠も広い。晩年の高年俸オファーの出どころ。
      foreignRule: ForeignRule(squadLimit: 8, pitchLimit: 6),
      clubStems: [
        Say('ナス', 'Nas'), Say('ヒラ', 'Hila'), Say('ワス', 'Was'), Say('カリ', 'Qadi'), Say('ザフ', 'Zafr'), Say('ミス', 'Mis'),
        Say('ラヤ', 'Raya'), Say('サフ', 'Safa'), Say('ドゥ', 'Duh'), Say('アイン', 'Ain'), Say('バハ', 'Baha'), Say('ヌール', 'Nour'),
        Say('サラ', 'Zara'), Say('ジャジ', 'Jazi'), Say('ファ', 'Fay'), Say('カウ', 'Kaw'), Say('マジ', 'Maji'), Say('タイ', 'Tai'),
      ],
      clubPatterns: [Say('アル＝{}', 'Al-{}'), Say('{}SC', '{}SC'), Say('アル＝{}クラブ', 'Al-{} Club'), Say('{}FC', '{}FC')],
    ),

    // ---- 南米 ----
    Country(
      id: 'pampa',
      name: Say('アルゼンチン', 'Argentina'),
      demonym: Say('アルゼンチン人', 'Argentine'),
      confederation: Confederation.austral,
      prestige: 4,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        Say('ロサ', 'Rosa'), Say('コルド', 'Cordo'), Say('メンド', 'Mendo'), Say('サル', 'Sal'), Say('トゥク', 'Tucu'), Say('ラプ', 'Lapl'),
        Say('キル', 'Quil'), Say('アヴェ', 'Ave'), Say('バン', 'Ban'), Say('ヌエ', 'Nue'), Say('エス', 'Es'), Say('ベル', 'Bell'),
        Say('サンタ', 'Santa'), Say('パラ', 'Para'), Say('エント', 'Entre'), Say('チャコ', 'Chaco'), Say('フフ', 'Juju'), Say('リオ', 'Rio'),
      ],
      clubPatterns: [Say('CA {}', 'CA {}'), Say('{}アトレティコ', '{} Atletico'), Say('CD {}', 'CD {}'), Say('{}FC', '{}FC')],
    ),
    Country(
      id: 'serena',
      name: Say('ブラジル', 'Brazil'),
      demonym: Say('ブラジル人', 'Brazilian'),
      confederation: Confederation.austral,
      prestige: 3,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        Say('パウ', 'Pau'), Say('ミナ', 'Mina'), Say('バイ', 'Bai'), Say('ゴイ', 'Goi'), Say('セア', 'Cea'), Say('パラ', 'Para'),
        Say('フォル', 'Forta'), Say('クリ', 'Cri'), Say('ヴィト', 'Vito'), Say('レシ', 'Reci'), Say('ナタ', 'Nata'), Say('クイ', 'Cui'),
        Say('マナ', 'Mana'), Say('ベレ', 'Bele'), Say('サン', 'San'), Say('ジョア', 'Joa'), Say('カン', 'Caen'), Say('アラ', 'Ara'),
      ],
      clubPatterns: [Say('{}SC', '{}SC'), Say('{}FC', '{}FC'), Say('EC {}', 'EC {}'), Say('CR {}', 'CR {}')],
    ),
  ];

  static Country byId(String id) =>
      countries.firstWhere((c) => c.id == id, orElse: () => countries.last);

  static List<Country> inConfederation(Confederation c) =>
      countries.where((x) => x.confederation == c).toList();

  /// その国のその部のリーグを組み立てる。
  ///
  /// クラブ名は地名と命名の型の組み合わせで作る。決め打ちの名簿を国ごとに
  /// 持つと数百件になり、増やすたびに破綻する。
  static List<Club> buildLeague(String countryId, int tier) {
    final country = byId(countryId);
    final size = country.clubsInTier(tier);
    final names = _clubNames(country, tier, size);

    // 上の部ほど強く、同じ部の中でも幅を持たせる。格が高い国ほど全体に強い。
    final base = 30 + country.prestige * 6 - (tier - 1) * 16;
    final span = 26;

    return [
      for (var i = 0; i < size; i++)
        Club(
          id: '$countryId-t$tier-c$i',
          name: names[i],
          // **上に本物の強豪を置く**（`Formulas.leagueGiants`）。
          //
          // 等間隔の梯子だった頃は、格5の1部が 60〜86 に均等に並んでいて、
          // 首位と 6位の差が 7 しか無かった。そこに自分の持ち上げ（`starLift`
          // 最大 +16）が乗るので、**中位のクラブに居ても優勝できてしまう**
          // （実測で リーグ優勝の中姮が 4回/19季、無冠のキャリア 18%）。
          strength:
              (base +
                      (span * (size - 1 - i)) ~/ (size - 1) +
                      (i < Formulas.leagueGiants.length
                          ? Formulas.leagueGiants[i]
                          : 0))
                  .clamp(20, 92),
          tier: tier,
          countryId: countryId,
        ),
    ];
  }

  /// 国の命名規則からクラブ名を作る。
  ///
  /// 地名 × 命名の型で全組み合わせを作り、部ごとに**重ならないように切り出す**。
  /// 部ごとに開始位置をずらすだけだと、組み合わせが一周して上の部と名前が被る。
  static List<String> _clubNames(Country country, int tier, int size) {
    final pool = <String>[];
    // 型を外側に回すと、同じ地名が別の型で近くに並ばない。
    for (final pattern in country.clubPatterns) {
      for (final stem in country.clubStems) {
        pool.add(pattern.t.replaceFirst('{}', stem.t));
      }
    }

    // その部より上の部が使った分だけ飛ばす。
    var offset = 0;
    for (var t = 1; t < tier; t++) {
      offset += country.clubsInTier(t);
    }

    assert(offset + size <= pool.length,
        tr('${country.name}: クラブ名が足りない（${pool.length} 件で ${offset + size} 件必要）', '${country.name}: not enough club names (${pool.length} for ${offset + size} needed)'));
    return [
      for (var i = 0; i < size; i++) pool[(offset + i) % pool.length],
    ];
  }

  /// **ID からクラブ名を作り直す。**
  ///
  /// 名前は保存データに文字列で乗っているので、言語を切り替えても
  /// 昔のまま残る。ID（`albion-t1-c0`）は不変なので、そこから作り直す。
  /// 知らない形の ID には `null` を返し、呼ぶ側が保存の文字列に戻る。
  static String? clubNameFor(String id) {
    final m = _clubId.firstMatch(id);
    if (m == null) return null;
    final countryId = m.group(1)!;
    final country = countries.firstWhere(
      (c) => c.id == countryId,
      orElse: () => countries.first,
    );
    if (country.id != countryId) return null;
    final tier = int.parse(m.group(2)!);
    final index = int.parse(m.group(3)!);
    if (tier < 1 || tier > country.tiers) return null;
    final size = country.clubsInTier(tier);
    if (index < 0 || index >= size) return null;
    return _namesFor(country, tier, size)[index];
  }

  /// 作った名前を覚えておく。**順位表は20クラブぶんを毎回描く**ので、
  /// そのたびに 4型×18地名 の組み合わせを作り直すと重い。
  /// **言語も鍵に入れる**——入れないと、切り替えても古い名前が残る。
  static final Map<String, List<String>> _nameCache = {};

  static List<String> _namesFor(Country country, int tier, int size) =>
      _nameCache.putIfAbsent(
        '${country.id}-t$tier-${currentLang.code}',
        () => _clubNames(country, tier, size),
      );

  static final RegExp _clubId = RegExp(r'^(.+)-t(\d+)-c(\d+)$');

  /// キャリアを始める国の候補。強豪国だけに偏らないよう全部から選ぶ。
  static Country randomHome(Random random) =>
      countries[random.nextInt(countries.length)];
}
