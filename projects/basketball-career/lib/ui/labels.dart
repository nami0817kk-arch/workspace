import 'package:flutter/material.dart';

import '../game/career.dart';
import '../game/game.dart';
import '../game/match.dart';
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
        {String? clutch, String? opponent, bool rival = false, int fouls = 0, bool fouledOut = false}) =>
    '${index + 1}試合目${opponent == null || opponent.isEmpty ? '' : '(vs ${rival ? 'ライバル ' : ''}$opponent)'} ${won ? '○' : '●'} $team-$opp  得点$pts リバウンド$reb アシスト$ast'
    '${clutch == null ? '' : '  勝負どころ: $clutch'}'
    '${fouledOut ? '  ファウル5(退場)' : (fouls >= 4 ? '  ファウル$fouls' : '')}';

String leagueLabel(League l) => l.label;

/// 大会の名前(日本代表は世界大会、ほかは季節つき)。
String tournamentName(League l, bool winter) =>
    l == League.national ? '日本代表の世界大会' : '${l.label}の${winter ? '冬' : '夏'}の大会';

/// 試合の流れを一言で。クォーターの得点から読み取る。無ければ null。
String? matchStory(MatchResult m) {
  if (m.teamQuarters.length < 4 || m.oppQuarters.length < 4) return null;
  final half = (m.teamQuarters[0] + m.teamQuarters[1]) -
      (m.oppQuarters[0] + m.oppQuarters[1]);
  final c = m.clutch;
  if (c != null && m.clutchSuccess == true && m.won) {
    return '勝負どころで${c.label}を決めて勝ち切った。';
  }
  if (c != null && m.clutchSuccess == false && !m.won) {
    return '勝負どころの${c.label}が決まらず、悔しい敗戦。';
  }
  if (m.won && half <= -5) return '前半の劣勢から、後半で逆転した。';
  if (!m.won && half >= 5) return '前半のリードを守れなかった。';
  if (m.won && m.margin >= 15) return '終始リードの圧勝。';
  if (!m.won && m.margin <= -15) return '力の差を見せつけられた。';
  if (m.margin.abs() <= 3) return '最後までもつれる接戦だった。';
  return null;
}

/// 試合の見どころ(個人の活躍の一言)。目立ったものから最大2つ。点の基準はチームの得点に対する割合で見る
/// (点数の規模がリーグごとに違うため)。延長・退場・ダブルダブル・3Pの量・守備の数字など。
/// 勝負どころの時計の一言(「第4Q 残り14秒」。1行に収まる短さ)。同じ試合ならいつも同じ秒数。
String clutchClock(MatchState s) {
  final secs = 6 + ((s.team * 7 + s.opp * 13 + s.points) % 19);
  return '第4Q 残り$secs秒';
}

/// `doubleCount` はその大会で何度目のダブルダブル(以上)か。2度目からは「今大会n度目」と添える(スターだと毎試合並ぶため)。
List<String> matchHighlights(MatchResult m, {int doubleCount = 1}) {
  final out = <String>[];
  final share = m.teamScore == 0 ? 0.0 : m.points / m.teamScore;
  final cats = [
    m.points >= 10,
    m.rebounds >= 10,
    m.assists >= 10,
    m.steals >= 10,
    m.blocks >= 10,
  ].where((x) => x).length;
  if (m.vsRival && m.tag.contains('決勝') && !m.tag.contains('準決勝')) {
    out.add(m.won ? '宿敵との決勝で勝った。' : '宿敵との決勝で敗れた。');
  }
  if (m.overtimes > 0) {
    out.add(m.won
        ? '${m.overtimes > 1 ? '${m.overtimes}度の' : ''}延長の末に勝ち切った。'
        : '${m.overtimes > 1 ? '${m.overtimes}度の' : ''}延長の末に力尽きた。');
  }
  if (cats >= 3) {
    out.add('トリプルダブル(${m.points}点${m.rebounds}リバウンド${m.assists}アシスト)${doubleCount > 1 ? '。今大会$doubleCount度目' : ''}。');
  } else if (cats == 2) {
    out.add('ダブルダブル(${m.points}点・${m.rebounds >= 10 ? '${m.rebounds}リバウンド' : '${m.assists}アシスト'})${doubleCount > 1 ? '。今大会$doubleCount度目' : ''}。');
  }
  if (share >= 0.40 && m.points >= 15) {
    out.add('チームの${(share * 100).round()}%にあたる${m.points}点を一人で挙げた。');
  } else if (m.threes >= 5) {
    out.add('3Pを${m.threes}本沈めた。');
  }
  if (m.fouledOut) out.add('ファウル5つで退場してしまった。');
  if (m.steals >= 4) out.add('${m.steals}スティールで流れを変えた。');
  if (m.blocks >= 4) out.add('${m.blocks}ブロックでゴール下を守り切った。');
  final b = m.box;
  if (!b.isEmpty && b.fgAttempts >= 10 && b.fgMade / b.fgAttempts >= 0.65) {
    out.add('シュート${b.fgAttempts}本中${b.fgMade}本を決める高確率。');
  }
  return out.take(2).toList();
}
