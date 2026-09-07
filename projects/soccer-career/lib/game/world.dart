import 'dart:math';

import '../models/club.dart';
import '../models/country.dart';

/// 世界の定義。国・リーグ・外国人ルールはすべてここに集まる。
///
/// 実在のリーグ名・クラブ名は使わない。写しているのは名前ではなく
/// 「制度」で、そちらが現実感の正体。
class World {
  const World._();

  static const String defaultCountryId = 'yamato';

  static const List<Country> countries = [
    // ---- ヴェスタ連盟（欧州型）----
    Country(
      id: 'albion',
      name: 'アルビオン',
      demonym: 'アルビオン人',
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
        'ブラッド', 'ケンブ', 'ノーサム', 'ウェスト', 'ハル', 'ダン',
        'ソール', 'エヴァー', 'プレス', 'ミッド', 'オーク', 'レイン',
      ],
      clubPatterns: ['{}シティ', '{}ユナイテッド', '{}ローヴァーズ', '{}タウン'],
    ),
    Country(
      id: 'iberica',
      name: 'イベリカ',
      demonym: 'イベリカ人',
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 22],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 3),
      permitRule: PermitRule(required: 4),
      clubStems: [
        'バリ', 'メリ', 'カステ', 'セビ', 'グラナ', 'アル',
        'サラ', 'ヒホ', 'コル', 'バダ', 'ムル', 'レガ',
      ],
      clubPatterns: ['{}CF', 'デポルティーボ{}', '{}バロンピエ', 'CD {}'],
    ),
    Country(
      id: 'germania',
      name: 'ゲルマニア',
      demonym: 'ゲルマニア人',
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 18, 20],
      // 連盟内は完全に自由。育成に定評があり、若手が渡りやすい。
      foreignRule: ForeignRule(confederationFree: true, homegrownRequired: 4),
      clubStems: [
        'ローテン', 'シュヴァル', 'グリュー', 'ハイデ', 'エルベ', 'ノイ',
        'アルト', 'ヴァルト', 'シュタイン', 'ブルク', 'リンデ', 'フェルト',
      ],
      clubPatterns: ['FC {}', '{}04', '{}ベルク', 'SV {}'],
    ),
    Country(
      id: 'latium',
      name: 'ラティウム',
      demonym: 'ラティウム人',
      confederation: Confederation.vesta,
      prestige: 4,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 4),
      permitRule: PermitRule(required: 3),
      clubStems: [
        'ヴェロ', 'モンテ', 'サレル', 'ペルー', 'カリア', 'ウディ',
        'パルマ', 'ブレシ', 'アンコ', 'レッチ', 'ピサ', 'コモ',
      ],
      clubPatterns: ['{}カルチョ', 'AC {}', '{}FC', 'US {}'],
    ),
    Country(
      id: 'gallia',
      name: 'ガリア',
      demonym: 'ガリア人',
      confederation: Confederation.vesta,
      prestige: 4,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        'リヨ', 'ナン', 'レン', 'ブレ', 'モンペ', 'トゥル',
        'アンジェ', 'ロリ', 'クレル', 'メス', 'ニム', 'カン',
      ],
      clubPatterns: ['{}オランピック', 'AS {}', '{}FC', 'スタッド{}'],
    ),
    Country(
      id: 'batavia',
      name: 'バタヴィア',
      demonym: 'バタヴィア人',
      confederation: Confederation.vesta,
      prestige: 3,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 20],
      // 規制が緩い。若い外国人が最初に渡る「踏み台リーグ」。
      foreignRule: ForeignRule(confederationFree: true),
      clubStems: [
        'アムス', 'ロッテ', 'ユト', 'ズヴォ', 'ヘー', 'アル',
        'ブレダ', 'ナイメ', 'ティル', 'フロー', 'デン', 'エメン',
      ],
      clubPatterns: ['{}EC', 'フォルトゥナ{}', '{}FC', 'SC {}'],
    ),
    Country(
      id: 'norden',
      name: 'ノルデン',
      demonym: 'ノルデン人',
      confederation: Confederation.vesta,
      prestige: 2,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [16, 16],
      foreignRule: ForeignRule(confederationFree: true),
      clubStems: [
        'ヴェス', 'オス', 'ベル', 'トロン', 'ウプ', 'マル',
        'ヨン', 'リン', 'オー', 'ハル', 'スン', 'ボー',
      ],
      clubPatterns: ['{}IF', '{}BK', '{}FF', 'IK {}'],
    ),

    // ---- オリエンス連盟（アジア型）----
    Country(
      id: 'yamato',
      name: 'ヤマト',
      demonym: 'ヤマト人',
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
        'アオ', 'ミナ', 'ヒガシ', 'カワ', 'シラ', 'トヨ',
        'ハヤ', 'ミヤ', 'ナガ', 'クロ', 'アカ', 'ソラ',
      ],
      clubPatterns: ['{}FC', '{}ユナイテッド', '{}レイズ', '{}ヴィエント'],
    ),
    Country(
      id: 'shams',
      name: 'シャムス',
      demonym: 'シャムス人',
      confederation: Confederation.oriens,
      prestige: 3,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [16, 16],
      // 資金は潤沢で枠も広い。晩年の高年俸オファーの出どころ。
      foreignRule: ForeignRule(squadLimit: 8, pitchLimit: 6),
      clubStems: [
        'ナス', 'ヒラ', 'ワス', 'カリ', 'ザフ', 'ミス',
        'ラヤ', 'サフ', 'ドゥ', 'アイン', 'バハ', 'ヌール',
      ],
      clubPatterns: ['アル＝{}', '{}SC', 'アル＝{}クラブ', '{}FC'],
    ),

    // ---- アウストラル連盟（南米型）----
    Country(
      id: 'pampa',
      name: 'パンパ',
      demonym: 'パンパ人',
      confederation: Confederation.austral,
      prestige: 4,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        'ロサ', 'コルド', 'メンド', 'サル', 'トゥク', 'ラプ',
        'キル', 'アヴェ', 'バン', 'ヌエ', 'エス', 'ベル',
      ],
      clubPatterns: ['CA {}', '{}アトレティコ', 'CD {}', '{}FC'],
    ),
    Country(
      id: 'serena',
      name: 'セリーナ',
      demonym: 'セリーナ人',
      confederation: Confederation.austral,
      prestige: 3,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        'パウ', 'ミナ', 'バイ', 'ゴイ', 'セア', 'パラ',
        'フォル', 'クリ', 'ヴィト', 'レシ', 'ナタ', 'クイ',
      ],
      clubPatterns: ['{}SC', '{}FC', 'EC {}', 'CR {}'],
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
          strength: (base + (span * (size - 1 - i)) ~/ (size - 1))
              .clamp(20, 92),
          tier: tier,
          countryId: countryId,
        ),
    ];
  }

  /// 国の命名規則からクラブ名を作る。同じ国・同じ部なら常に同じ並び。
  static List<String> _clubNames(Country country, int tier, int size) {
    final names = <String>[];
    final seen = <String>{};
    // 部ごとに開始位置をずらして、上の部と下の部で名前が被らないようにする。
    var i = tier * 7;
    while (names.length < size) {
      final stem = country.clubStems[i % country.clubStems.length];
      final pattern = country.clubPatterns[
          (i ~/ country.clubStems.length) % country.clubPatterns.length];
      final name = pattern.replaceFirst('{}', stem);
      if (seen.add(name)) names.add(name);
      i++;
      if (i > tier * 7 + 400) break; // 念のための打ち切り
    }
    return names;
  }

  /// キャリアを始める国の候補。強豪国だけに偏らないよう全部から選ぶ。
  static Country randomHome(Random random) =>
      countries[random.nextInt(countries.length)];
}
