import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/rival_story.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ライバルの進路', () {
    test('素質70以上は高卒でプロ、50〜69は大学を経て、未満はプロにならない', () {
      final high = storyOf('宮坂 凛', 85);
      expect(high.proAge, 18);
      expect(high.college, isFalse);
      expect(high.draftRound, 1);
      final mid = storyOf('宮坂 凛', 60);
      expect(mid.proAge, 22);
      expect(mid.college, isTrue);
      final low = storyOf('宮坂 凛', 45);
      expect(low.proAge, isNull);
      expect(low.retireAge, 30);
    });

    test('同じ名前・素質なら毎回同じ。球団は架空の名前', () {
      final a = storyOf('宮坂 凛', 80);
      final b = storyOf('宮坂 凛', 80);
      expect(a.team, b.team);
      expect(a.retireAge, b.retireAge);
      expect(draftTeamsContain(a.team), isTrue);
    });

    test('素質が高いほど、長く現役を続ける', () {
      expect(
          storyOf('a', 90).retireAge, greaterThan(storyOf('a', 72).retireAge));
    });
  });

  group('知らせ', () {
    test('進路の知らせは19歳に1回、引退の知らせは引退の翌年に1回', () {
      for (final t in [45, 60, 75, 90]) {
        final s = storyOf('宮坂 凛', t);
        final all = <int, List<String>>{
          for (var age = 6; age <= 50; age++) age: rivalNews(s, age),
        };
        expect(all[19], hasLength(1), reason: 'talent $t');
        expect(
            all.values.expand((x) => x).where((l) => l.contains('引退')).length,
            1,
            reason: 'talent $t');
        expect(all[s.retireAge + 1]!.any((l) => l.contains('引退')), isTrue);
        for (final l in all.values.expand((x) => x)) {
          expect(l, contains('宮坂 凛'));
          expect(RegExp(r'[a-z]{3,}').hasMatch(l), isFalse, reason: l);
        }
      }
    });

    test('高卒プロは19歳に入団の知らせ、大学組は大学進学→23歳に入団', () {
      final high = storyOf('宮坂 凛', 85);
      expect(rivalNews(high, 19).single, contains('ドラフト1位で入団'));
      final mid = storyOf('宮坂 凛', 60);
      expect(rivalNews(mid, 19).single, contains('大学に進学'));
      expect(rivalNews(mid, 23).single, contains('${mid.team}にドラフト'));
      final low = storyOf('宮坂 凛', 45);
      expect(rivalNews(low, 19).single, contains('社会人'));
    });

    test('プロの途中は5年ごとに活躍を伝える', () {
      final s = storyOf('宮坂 凛', 85); // proAge 18
      expect(rivalNews(s, 23).any((l) => l.contains('プロ5年目')), isTrue);
      expect(rivalNews(s, 24), isEmpty);
    });
  });

  group('いまの様子', () {
    test('年齢で変わる', () {
      final s = storyOf('宮坂 凛', 85);
      expect(rivalStatus(s, 12), contains('同い年'));
      expect(rivalStatus(s, 25), contains('${s.team}でプレー中'));
      expect(rivalStatus(s, s.retireAge + 1), contains('引退'));
      final mid = storyOf('宮坂 凛', 60);
      expect(rivalStatus(mid, 20), contains('大学'));
      final low = storyOf('宮坂 凛', 45);
      expect(rivalStatus(low, 25), contains('社会人'));
    });
  });

  group('ゲームの中', () {
    test('年が進むと、ライバルの知らせがログに出る。保存してもライバルの素質は残る', () {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(3), potential: 90);
      final talent = g.cast.rival!.talent;
      var n = 0;
      while (g.phase != Phase.retired && n++ < 4000) {
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
      expect(g.log.any((l) => l.startsWith('ライバルの')), isTrue);
      final snap = PlayerSnapshot.fromJson(PlayerSnapshot.fromGame(g).toJson());
      expect(snap.rivalTalent, talent);
      expect(PlayerSnapshot.fromJson({}).rivalTalent, isNull);
    });
  });
}

bool draftTeamsContain(String t) => draftTeams.contains(t);
