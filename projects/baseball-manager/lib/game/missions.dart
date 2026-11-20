import 'dart:math';

import 'career.dart';
import 'game.dart';
import 'path.dart' show overall;
import 'player.dart';

/// 育成ミッション(2026-10-28 ユーザー「もう少し育成にやりがいを見出して」)。
///
/// 段階ごとに3〜4つの目標を置き、達成すると経験点(全種類)とやる気がもらえる。
/// 「何を目指して育てるか」の区切りを作る。段階が変わると、その段階の未達成のものは消える(取り返せない)。
/// 判定は行動・振り分け・特殊能力・出来事のあとに `Game.checkMissions` で行う。
class Mission {
  const Mission(this.id, this.stage, this.text, this.check);

  /// 保存に使う(変えない)。
  final String id;
  final Stage stage;
  final String text;
  final bool Function(Game g) check;
}

int _maxAbility(Game g) =>
    abilitiesOf(g.player.role).map(g.player.of).reduce(max);

int _skills(Game g) => g.player.skills.where((s) => !s.negative).length;

/// その段階の大会で `rounds` 勝したか(2勝で全国大会・本大会に出場、3勝で全国で1勝)。
bool _reachedNational(Game g, Stage s, int rounds) =>
    g.records.any((r) => r.stage == s && r.roundsWon >= rounds);

final List<Mission> missions = [
  // 少年(6〜12歳)
  Mission('y-ability', Stage.youth, 'どれか1つの能力を50(Dランク)以上に',
      (g) => _maxAbility(g) >= 50),
  Mission('y-skill', Stage.youth, '特殊能力を1つ取る', (g) => _skills(g) >= 1),
  Mission('y-national', Stage.youth, '夏の学童大会で、全国優勝する',
      (g) => _reachedNational(g, Stage.youth, 4)),
  // 中学(13〜15歳)
  Mission('j-ability', Stage.juniorHigh, 'どれか1つの能力を60(Cランク)以上に',
      (g) => _maxAbility(g) >= 60),
  Mission('j-overall', Stage.juniorHigh, '総合評価を45以上に',
      (g) => overall(g.player) >= 45),
  Mission('j-national', Stage.juniorHigh, '夏の中学大会の、全国大会で1勝する',
      (g) => _reachedNational(g, Stage.juniorHigh, 3)),
  // 高校(16〜18歳)
  Mission('h-ability', Stage.highSchool, 'どれか1つの能力を70(Bランク)以上に',
      (g) => _maxAbility(g) >= 70),
  Mission('h-skills', Stage.highSchool, '特殊能力を合わせて2つ以上に',
      (g) => _skills(g) >= 2),
  Mission('h-national', Stage.highSchool, '全国大会で1勝する(地方大会を制して)',
      (g) => _reachedNational(g, Stage.highSchool, 3)),
  // 大学・社会人
  Mission('p-overall', Stage.pathChoice, '総合評価を60以上に',
      (g) => overall(g.player) >= 60),
  Mission('p-champion', Stage.pathChoice, '大会で優勝する',
      (g) => g.records.any((r) => r.stage == Stage.pathChoice && r.champion)),
  Mission('p-skills', Stage.pathChoice, '特殊能力を合わせて4つ以上に',
      (g) => _skills(g) >= 4),
  // プロ(現役のあいだ、ずっと)
  Mission('r-first', Stage.pro, '一軍で1シーズンを戦い抜く',
      (g) => g.records.any((r) => r.stage == Stage.pro && !r.farm)),
  Mission('r-ability', Stage.pro, 'どれか1つの能力を90(Sランク)以上に',
      (g) => _maxAbility(g) >= 90),
  Mission('r-overall', Stage.pro, '総合評価を75以上に',
      (g) => overall(g.player) >= 75),
  Mission('r-title', Stage.pro, 'タイトルを獲る',
      (g) => g.records.any((r) => r.titles.isNotEmpty)),
];

/// いまの段階のミッション。
List<Mission> missionsFor(Stage s) => [
      for (final m in missions)
        if (m.stage == s) m
    ];

/// ミッションを達成したときにもらえる経験点(全種類)。段階が上がるほど多い。
int missionExp(Stage s) => switch (s) {
      Stage.youth => 6,
      Stage.juniorHigh => 8,
      Stage.highSchool => 10,
      Stage.pathChoice => 12,
      _ => 10,
    };

/// ミッションのやる気の上がり幅。
const missionMorale = 10;
