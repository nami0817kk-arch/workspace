/// オフのサマーリーグ(2026-11-19、ユーザー「オフシーズンに出来ること増やしたい」)。
/// 契約の時期に、若手(24歳まで・リーグ2年目まで)を4試合に出す。出来が良いと少し伸び、気持ちが上がる。
/// 出た選手は性格が分かる。GM が押したときだけ動き、リーグの乱数とは別の乱数を使う
/// (自動で遊ぶGMは押さないので、釣り合いは変わらない)。
library;

import 'player.dart';

/// サマーリーグの試合数。
const summerGames = 4;

/// サマーリーグに出す人数の上限(力の高い順)。
const summerMaxPlayers = 8;

/// サマーリーグに出られる選手(24歳まで、またはリーグ2年目まで)。
bool summerEligible(Player p) => p.age <= 24 || p.exp <= 1;

/// サマーリーグの1人分の成績。
class SummerLine {
  const SummerLine({required this.id, required this.name, required this.pts, required this.reb, required this.ast, required this.grade, this.delta = 0, this.mood = 0});

  final int id;
  final String name;

  /// 1試合あたりの得点・リバウンド・アシスト。
  final int pts, reb, ast;

  /// 出来(A〜D)。
  final String grade;

  /// 伸びた OVR。
  final int delta;

  /// 気持ちの動き。
  final int mood;

  Map<String, dynamic> toJson() => {'i': id, 'n': name, 'p': pts, 'r': reb, 'a': ast, 'g': grade, if (delta != 0) 'd': delta, if (mood != 0) 'm': mood};

  static SummerLine fromJson(Map<String, dynamic> j) => SummerLine(
        id: (j['i'] as int?) ?? 0,
        name: (j['n'] as String?) ?? '',
        pts: (j['p'] as int?) ?? 0,
        reb: (j['r'] as int?) ?? 0,
        ast: (j['a'] as int?) ?? 0,
        grade: (j['g'] as String?) ?? 'C',
        delta: (j['d'] as int?) ?? 0,
        mood: (j['m'] as int?) ?? 0,
      );
}

/// 出来の呼び名。
String summerGradeText(String g) => switch (g) {
      'A' => '目立った',
      'B' => 'まずまず',
      'C' => 'ふつう',
      _ => '苦しんだ',
    };
