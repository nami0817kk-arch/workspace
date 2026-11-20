import 'dart:math';

import '../l10n/tr.dart';
import '../models/player.dart';

/// 夏の代表の大会の種類。
enum SummerTournamentKind { worldCup, continental }

/// シーズンの前の夏にある代表の大会(偶数年)。
///
/// - 4年に1度(2026・2030…)はワールドカップ、その間の偶数年(2028…)は
///   欧州選手権・コパ・アメリカなどの大陸の大会がある。奇数年は無い。
/// - 出た選手は、決勝のあと[restDays]日休んでからクラブに合流する。
///   それまでは試合に出せない(リーグの開幕に間に合わないこともある)。
/// - 活躍した選手は市場価値が上がる(その年のあいだ)。
///
/// 誰が出たか・どれだけ活躍したかは、選手の id と年から決まる
/// (何度呼んでも同じ。保存しなくてよい)。
class SummerTournament {
  const SummerTournament({
    required this.kind,
    required this.year,
    required this.starts,
    required this.ends,
  });

  final SummerTournamentKind kind;
  final int year;
  final DateTime starts;

  /// 決勝の日。
  final DateTime ends;

  /// 決勝のあとの休み(日)。
  static const int restDays = 24;

  /// 代表に呼ばれる水準(週ごとの代表召集と同じ)。
  static const int minOverall = 78;

  /// [year]年の夏の大会。無い年は null。
  static SummerTournament? of(int year) {
    if (year % 4 == 2) {
      return SummerTournament(
        kind: SummerTournamentKind.worldCup,
        year: year,
        starts: DateTime(year, 6, 11),
        ends: DateTime(year, 7, 19),
      );
    }
    if (year % 4 == 0) {
      return SummerTournament(
        kind: SummerTournamentKind.continental,
        year: year,
        starts: DateTime(year, 6, 12),
        ends: DateTime(year, 7, 14),
      );
    }
    return null;
  }

  String get name => switch (kind) {
        SummerTournamentKind.worldCup =>
          Tr.pick('$year年ワールドカップ', '$year World Cup'),
        SummerTournamentKind.continental => Tr.pick(
            '$year年の大陸選手権(欧州選手権・コパ・アメリカなど)',
            '$year continental championships (Euros, Copa America and others)'),
      };

  /// クラブに合流する日。
  DateTime get returnDate => DateTime(ends.year, ends.month, ends.day + restDays);

  /// 代表の水準の選手のうち、大会に出る割合。ワールドカップの方が出る国が多い。
  double get selectionChance =>
      kind == SummerTournamentKind.worldCup ? 0.8 : 0.6;

  /// [p]がこの大会に出たか。
  bool plays(Player p) =>
      p.overall >= minOverall && _roll(p, 1) < selectionChance;

  /// 大会で上がった市場価値(%)。出ていなければ 0。
  /// 2割は大会の顔になって25%、4割は10%、残りは目立たず上がらない。
  int boostPctFor(Player p) {
    if (!plays(p)) return 0;
    final r = _roll(p, 2);
    if (r < 0.2) return 25;
    if (r < 0.6) return 10;
    return 0;
  }

  double _roll(Player p, int salt) {
    var h = 23 + year * 7 + salt * 101;
    for (final c in p.id.codeUnits) {
      h = (h * 37 + c) & 0x3fffffff;
    }
    return Random(h).nextDouble();
  }
}
