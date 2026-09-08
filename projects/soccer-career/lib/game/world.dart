import 'dart:math';

import '../models/club.dart';
import '../models/country.dart';

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
      name: 'イングランド',
      demonym: 'イングランド人',
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
        'サウス', 'グレイ', 'ストーン', 'ベル', 'アッシュ', 'クリフ',
      ],
      clubPatterns: ['{}シティ', '{}ユナイテッド', '{}ローヴァーズ', '{}タウン'],
    ),
    Country(
      id: 'iberica',
      name: 'スペイン',
      demonym: 'スペイン人',
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 22],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 3),
      permitRule: PermitRule(required: 4),
      clubStems: [
        'バリ', 'メリ', 'カステ', 'セビ', 'グラナ', 'アル',
        'サラ', 'ヒホ', 'コル', 'バダ', 'ムル', 'レガ',
        'トレ', 'ヘレ', 'カディ', 'ラコ', 'エル', 'ビゴ',
      ],
      clubPatterns: ['{}CF', 'デポルティーボ{}', '{}バロンピエ', 'CD {}'],
    ),
    Country(
      id: 'germania',
      name: 'ドイツ',
      demonym: 'ドイツ人',
      confederation: Confederation.vesta,
      prestige: 5,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 18, 20],
      // 連盟内は完全に自由。育成に定評があり、若手が渡りやすい。
      foreignRule: ForeignRule(confederationFree: true, homegrownRequired: 4),
      clubStems: [
        'ローテン', 'シュヴァル', 'グリュー', 'ハイデ', 'エルベ', 'ノイ',
        'アルト', 'ヴァルト', 'シュタイン', 'ブルク', 'リンデ', 'フェルト',
        'グラウ', 'ホーエン', 'タール', 'バッハ', 'ケーニヒ', 'ゾンネ',
      ],
      clubPatterns: ['FC {}', '{}04', '{}ベルク', 'SV {}'],
    ),
    Country(
      id: 'latium',
      name: 'イタリア',
      demonym: 'イタリア人',
      confederation: Confederation.vesta,
      prestige: 4,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 4),
      permitRule: PermitRule(required: 3),
      clubStems: [
        'ヴェロ', 'モンテ', 'サレル', 'ペルー', 'カリア', 'ウディ',
        'パルマ', 'ブレシ', 'アンコ', 'レッチ', 'ピサ', 'コモ',
        'クレモ', 'テルニ', 'アヴェ', 'カタン', 'メッシ', 'ノヴァ',
      ],
      clubPatterns: ['{}カルチョ', 'AC {}', '{}FC', 'US {}'],
    ),
    Country(
      id: 'gallia',
      name: 'フランス',
      demonym: 'フランス人',
      confederation: Confederation.vesta,
      prestige: 4,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        'リヨ', 'ナン', 'レン', 'ブレ', 'モンペ', 'トゥル',
        'アンジェ', 'ロリ', 'クレル', 'メス', 'ニム', 'カン',
        'トゥー', 'ディジョ', 'アミ', 'ラヴァ', 'ポー', 'グルノ',
      ],
      clubPatterns: ['{}オランピック', 'AS {}', '{}FC', 'スタッド{}'],
    ),
    Country(
      id: 'batavia',
      name: 'オランダ',
      demonym: 'オランダ人',
      confederation: Confederation.vesta,
      prestige: 3,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [18, 20],
      // 規制が緩い。若い外国人が最初に渡る「踏み台リーグ」。
      foreignRule: ForeignRule(confederationFree: true),
      clubStems: [
        'アムス', 'ロッテ', 'ユト', 'ズヴォ', 'ヘー', 'アル',
        'ブレダ', 'ナイメ', 'ティル', 'フロー', 'デン', 'エメン',
        'ハー', 'ライ', 'ドル', 'ヘル', 'ワー', 'ズウォ',
      ],
      clubPatterns: ['{}EC', 'フォルトゥナ{}', '{}FC', 'SC {}'],
    ),
    Country(
      id: 'norden',
      name: 'スウェーデン',
      demonym: 'スウェーデン人',
      confederation: Confederation.vesta,
      prestige: 2,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [16, 16],
      foreignRule: ForeignRule(confederationFree: true),
      clubStems: [
        'ヴェス', 'オス', 'ベル', 'トロン', 'ウプ', 'マル',
        'ヨン', 'リン', 'オー', 'ハル', 'スン', 'ボー',
        'ヴィボ', 'エス', 'ラン', 'ヘル', 'サン', 'ノル',
      ],
      clubPatterns: ['{}IF', '{}BK', '{}FF', 'IK {}'],
    ),

    // ---- アジア ----
    Country(
      id: 'yamato',
      name: '日本',
      demonym: '日本人',
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
        'シオ', 'モリ', 'ウミ', 'カゼ', 'ホシ', 'ツキ',
      ],
      clubPatterns: ['{}FC', '{}ユナイテッド', '{}レイズ', '{}ヴィエント'],
    ),
    Country(
      id: 'shams',
      name: 'サウジアラビア',
      demonym: 'サウジアラビア人',
      confederation: Confederation.oriens,
      prestige: 3,
      calendar: LeagueCalendar.autumnSpring,
      tierSizes: [16, 16],
      // 資金は潤沢で枠も広い。晩年の高年俸オファーの出どころ。
      foreignRule: ForeignRule(squadLimit: 8, pitchLimit: 6),
      clubStems: [
        'ナス', 'ヒラ', 'ワス', 'カリ', 'ザフ', 'ミス',
        'ラヤ', 'サフ', 'ドゥ', 'アイン', 'バハ', 'ヌール',
        'サラ', 'ジャジ', 'ファ', 'カウ', 'マジ', 'タイ',
      ],
      clubPatterns: ['アル＝{}', '{}SC', 'アル＝{}クラブ', '{}FC'],
    ),

    // ---- 南米 ----
    Country(
      id: 'pampa',
      name: 'アルゼンチン',
      demonym: 'アルゼンチン人',
      confederation: Confederation.austral,
      prestige: 4,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        'ロサ', 'コルド', 'メンド', 'サル', 'トゥク', 'ラプ',
        'キル', 'アヴェ', 'バン', 'ヌエ', 'エス', 'ベル',
        'サンタ', 'パラ', 'エント', 'チャコ', 'フフ', 'リオ',
      ],
      clubPatterns: ['CA {}', '{}アトレティコ', 'CD {}', '{}FC'],
    ),
    Country(
      id: 'serena',
      name: 'ブラジル',
      demonym: 'ブラジル人',
      confederation: Confederation.austral,
      prestige: 3,
      calendar: LeagueCalendar.springAutumn,
      tierSizes: [20, 20],
      foreignRule: ForeignRule(confederationFree: true, squadLimit: 5),
      clubStems: [
        'パウ', 'ミナ', 'バイ', 'ゴイ', 'セア', 'パラ',
        'フォル', 'クリ', 'ヴィト', 'レシ', 'ナタ', 'クイ',
        'マナ', 'ベレ', 'サン', 'ジョア', 'カン', 'アラ',
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

  /// 国の命名規則からクラブ名を作る。
  ///
  /// 地名 × 命名の型で全組み合わせを作り、部ごとに**重ならないように切り出す**。
  /// 部ごとに開始位置をずらすだけだと、組み合わせが一周して上の部と名前が被る。
  static List<String> _clubNames(Country country, int tier, int size) {
    final pool = <String>[];
    // 型を外側に回すと、同じ地名が別の型で近くに並ばない。
    for (final pattern in country.clubPatterns) {
      for (final stem in country.clubStems) {
        pool.add(pattern.replaceFirst('{}', stem));
      }
    }

    // その部より上の部が使った分だけ飛ばす。
    var offset = 0;
    for (var t = 1; t < tier; t++) {
      offset += country.clubsInTier(t);
    }

    assert(offset + size <= pool.length,
        '${country.name}: クラブ名が足りない（${pool.length} 件で ${offset + size} 件必要）');
    return [
      for (var i = 0; i < size; i++) pool[(offset + i) % pool.length],
    ];
  }

  /// キャリアを始める国の候補。強豪国だけに偏らないよう全部から選ぶ。
  static Country randomHome(Random random) =>
      countries[random.nextInt(countries.length)];
}
