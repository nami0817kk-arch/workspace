import 'game.dart';
import 'player.dart';

/// ポジションの呼び名。
String positionNickname(Position p) => switch (p) {
      Position.pointGuard => '司令塔',
      Position.shootingGuard => 'シューター',
      Position.smallForward => 'ウイング',
      Position.powerForward => 'パワーフォワード',
      Position.center => '大黒柱',
    };

bool _wentPro(Game g) => g.records.any((r) => r.league.name.startsWith('pro'));

/// 一生につく称号。到達点で決まる。
String careerTitle(Game g) {
  final nick = positionNickname(g.player.position);
  if (g.abroad && g.titles > 0) return '世界を制した$nick';
  if (g.abroad) return '世界に挑んだ$nick';
  if (_wentPro(g) && g.titles >= 3) return '常勝の$nick';
  if (_wentPro(g)) return 'プロで戦い抜いた$nick';
  if (g.titles > 0 && g.secondChance) return '学生王者の$nick';
  if (g.records.isEmpty) return '夢の途中の$nick';
  return '情熱の$nick';
}

String _talent(int potential) {
  if (potential >= 80) return '天賦の才に恵まれた';
  if (potential >= 60) return '確かな素質を持った';
  if (potential >= 45) return '平凡な素質から出発した';
  return '決して恵まれてはいない素質で挑んだ';
}

/// エンディングの文章(段落ごと)。生い立ち・全盛期・ライバル・結末・ひとこと。
List<String> epilogueLines(Game g) {
  final p = g.player;
  final lines = <String>[];

  final traits = p.traits.isEmpty
      ? ''
      : '「${p.traits.map((t) => t.label).join('」「')}」の持ち主だった。';
  lines.add('${_talent(p.potential)}${p.name}は、最終的に'
      '${p.heightCm.toStringAsFixed(0)}cmの${positionNickname(p.position)}になった。$traits');

  if (g.records.isNotEmpty) {
    final best = g.records.reduce((a, b) => b.achievement > a.achievement ? b : a);
    lines.add('いちばん輝いたのは${best.age}歳、${best.league.label}'
        '${best.winter ? 'の冬' : ''}の大会。'
        '${best.champion ? '頂点に立ち、' : ''}平均${best.ppg.toStringAsFixed(1)}得点を記録した。');
  }

  final r = g.rival;
  if (r.games > 0) {
    if (r.wins > r.losses) {
      lines.add('宿敵${r.name}との対戦は${r.wins}勝${r.losses}敗。最後には、あの背中を越えた。');
    } else if (r.wins == r.losses) {
      lines.add('宿敵${r.name}との対戦は${r.wins}勝${r.losses}敗の五分。お互い、最高の好敵手だった。');
    } else {
      lines.add('宿敵${r.name}との対戦は${r.wins}勝${r.losses}敗。届かなかったが、あの存在が自分を強くした。');
    }
  }

  lines.add('${p.age}歳、${g.retiredReason ?? '現役を退いた'}。');

  lines.add(_closing(g));
  return lines;
}

String _closing(Game g) {
  if (g.abroad && g.titles > 0) return '世界の舞台で戦い、勝ち取った栄光。語り継がれる選手になった。';
  if (g.abroad) return '海を渡り、世界最高峰に挑んだ。その経験は、なにものにも代えがたい。';
  if (_wentPro(g)) {
    return g.titles > 0
        ? 'プロとして頂点を知った。ファンの記憶に残る選手だった。'
        : 'プロの世界で戦い抜いた。コートに立ち続けた誇りがある。';
  }
  if (g.records.isEmpty) return '大きな舞台には届かなかった。それでも、バスケは好きなままだ。';
  return 'プロの扉は開かなかった。それでも、仲間とコートを駆けた日々は本物だった。';
}
