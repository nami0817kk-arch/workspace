import 'package:flutter/material.dart';

import '../game/career.dart';
import '../game/game.dart';
import '../game/season.dart';

/// 画面に出す名前・色。ゲームの規則は持たない。

String stageLabel(Stage s) => switch (s) {
      Stage.minibasket => 'ミニバス',
      Stage.juniorHigh => '中学',
      Stage.highSchool => '高校',
      Stage.college => '大学・実業団',
      Stage.pathChoice => '進路',
      Stage.pro => 'プロ',
      Stage.retired => '引退',
    };

String trackLabel(Game g) => switch (g.track) {
      Track.school => stageLabel(g.stage),
      Track.university => '大学',
      Track.corporate => '実業団',
      Track.pro => g.abroad ? '海外プロ' : '国内プロ',
    };

/// 能力値のランク(G〜S)。
String rankOf(int v) {
  if (v >= 90) return 'S';
  if (v >= 80) return 'A';
  if (v >= 70) return 'B';
  if (v >= 55) return 'C';
  if (v >= 40) return 'D';
  if (v >= 25) return 'E';
  if (v >= 12) return 'F';
  return 'G';
}

Color rankColor(String r) => switch (r) {
      'S' => const Color(0xFFE65100),
      'A' => const Color(0xFFD84315),
      'B' => const Color(0xFFEF6C00),
      'C' => const Color(0xFF2E7D32),
      'D' => const Color(0xFF1565C0),
      'E' => const Color(0xFF546E7A),
      _ => const Color(0xFF78909C),
    };

/// 実績(0〜100)を一言に。
String achievementWord(double a) {
  if (a >= 80) return '全国レベルの活躍';
  if (a >= 60) return '上位に食い込んだ';
  if (a >= 40) return '平均的';
  return 'これから';
}

/// 大会の1試合を一行に。「○ 62-58 (得点 12 / リバウンド 5 / アシスト 3)」。
String matchLine(int index, bool won, int team, int opp, int pts, int reb, int ast,
        {String? clutch, String? opponent, bool rival = false}) =>
    '${index + 1}試合目${opponent == null || opponent.isEmpty ? '' : '(vs ${rival ? 'ライバル ' : ''}$opponent)'} ${won ? '○' : '●'} $team-$opp  得点$pts リバウンド$reb アシスト$ast'
    '${clutch == null ? '' : '  勝負どころ: $clutch'}';

String leagueLabel(League l) => l.label;
