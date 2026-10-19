import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/rival_story.dart';
import 'package:flutter_test/flutter_test.dart';

Game _until(bool Function(Game) stop, {int seed = 1}) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: 90);
  var n = 0;
  while (g.phase != Phase.retired && !stop(g) && n++ < 4000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return g;
}

void main() {
  rivalTests();
  logTests();
  test('ドラフトの見込みは、高校2年(17歳)から出て、能力で変わる', () {
    final y = Game.newGame(name: 't', role: Role.batter, rng: Random(1));
    expect(y.draftOutlook, isNull);
    final g = _until((g) =>
        g.stage == Stage.highSchool &&
        g.player.age == 17 &&
        g.phase == Phase.term);
    expect(g.draftOutlook, isNotNull);
    for (final a in abilitiesOf(Role.batter)) {
      g.adminSetAbility(a, 99);
    }
    expect(g.draftOutlook, 'ほぼ確実');
    for (final a in abilitiesOf(Role.batter)) {
      g.adminSetAbility(a, 0);
    }
    expect(g.draftOutlook, 'かなり厳しい');
  });

  test('戦力外の警告は、プロで総合が低い年が続いているときだけ', () {
    final g = _until((g) => g.stage == Stage.pro && g.phase == Phase.term);
    expect(g.stage, Stage.pro);
    g.lowYears = 0;
    expect(g.releaseWarning, isNull);
    g.lowYears = 1;
    expect(g.releaseWarning, releaseYears - 1);
    expect(g.draftOutlook, isNull); // プロになったら出ない
  });
}

void logTests() {
  test('年が変わるたびに、ログに「── N歳 ──」の見出しが入る', () {
    final g = _until((g) => g.player.age >= 9);
    final heads = g.log.where((l) => l.startsWith('── ')).toList();
    expect(heads, contains('── 7歳 ──'));
    expect(heads, contains('── 8歳 ──'));
    expect(heads.length, g.player.age - 6);
  });
}

void rivalTests() {
  test('ライバルの球団は、自分と同じなら別の球団に替わる', () {
    final s = storyOf('ひかる', 90);
    expect(s.avoiding(null).team, s.team);
    expect(s.avoiding('べつの球団').team, s.team);
    final other = s.avoiding(s.team);
    expect(other.team, isNot(s.team));
    expect(draftTeams, contains(other.team));
    expect(other.name, s.name);
  });
}
