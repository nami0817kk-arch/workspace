import 'dart:math';

import 'season.dart';

/// 同じ時代を走るライバル。生まれは同い年で、大会の準決勝あたりで毎年ぶつかる。
/// 名前は架空。素質で強さの伸びが決まり、勝ち負けの通算が残る。
class Rival {
  Rival({
    required this.name,
    required this.potential,
    this.wins = 0,
    this.losses = 0,
  });

  final String name;

  /// 素質 0〜100(本人と同じ尺度)。
  final int potential;

  /// こちらから見た通算の勝ち・負け。
  int wins;
  int losses;

  /// 出会う年齢。この年から毎年の大会に現れる。
  static const meetAge = 9;

  /// 引退する年齢(ここまでは現れる)。
  static const retireAge = 36;

  bool activeAt(int age) => age >= meetAge && age <= retireAge;

  /// 年齢ごとの強さの上乗せ(その大会の相手の強さに足す)。
  /// 素質の高いライバルほど大きい。30歳を過ぎると衰える。
  double edgeAt(int age) {
    // 同じ回戦の普通の相手と同じ強さを基準に、素質で上下する(-4〜+4)。
    // 20代半ばを過ぎて衰える。成長期の伸びは、回戦ごとの強さの上昇(リーグ)に含まれている。
    final talent = (potential - 67) / 33 * 4;
    final decline = age > 29 ? (age - 29) * 0.8 : 0.0;
    return talent - decline;
  }

  /// 強さの目安(画面に出す)。リーグの相手の強さに上乗せ分を足した数。
  int levelAt(League league, int age) =>
      (league.oppBase + 2.5 * (league.rounds - 2) + edgeAt(age)).round();

  int get games => wins + losses;

  /// ライバルのその後(エンディングで語る)。素質で決まる。
  String get fate {
    if (potential >= 82) return '$nameは世界最高峰の舞台に立ち、語り継がれる選手になった。';
    if (potential >= 68) return '$nameはプロの第一線で長く活躍した。';
    if (potential >= 52) return '$nameは実業団で活躍し、後に指導者の道へ進んだ。';
    return '$nameは大学でバスケを続け、いまは地元で子どもたちに教えている。';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'potential': potential,
        'wins': wins,
        'losses': losses,
      };

  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
        name: (j['name'] as String?) ?? 'ライバル',
        potential: (j['potential'] as num?)?.toInt() ?? 60,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
      );

  /// 新しいライバル。素質は 45〜90。
  factory Rival.random(Random rng) => Rival(
        name: _rivalName(rng),
        potential: 45 + rng.nextInt(46),
      );
}

const _surnames = [
  '神谷', '黒瀬', '白石', '氷室', '早乙女', '東雲', '九条', '天城', '朝霧', '桐生',
  '鷹野', '月島', '一ノ瀬', '真田', '御影',
];
const _given = [
  'リョウ', 'ツバサ', 'カイト', 'ハヤト', 'ソウタ', 'レン', 'ユウマ', 'シン', 'アキラ', 'ケンゴ',
];

String _rivalName(Random rng) =>
    '${_surnames[rng.nextInt(_surnames.length)]}${_given[rng.nextInt(_given.length)]}';

const _teamPrefix = [
  '北嶺', '南陽', '東雲', '西浜', '青葉', '白鷺', '紅葉', '朝日', '双葉', '桜台',
  '星丘', '翠山', '蒼海', '大和', '緑風',
];

/// リーグに合った、架空の対戦チーム名。
String opponentTeamName(League league, Random rng) {
  final p = _teamPrefix[rng.nextInt(_teamPrefix.length)];
  return switch (league) {
    League.minibasket => '$pミニバスクラブ',
    League.juniorHigh => '$p中学',
    League.highSchool => '$p高校',
    League.university => '$p大学',
    League.corporate => '$pスチール',
    League.proDomestic => '$pホークス',
    League.proAbroad => '$pタイタンズ',
  };
}
