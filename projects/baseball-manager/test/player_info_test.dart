import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life_log.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:baseball_manager/ui/player_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Game _play(int seed,
    {int? potential, bool Function(Game)? stop, int proRetireAge = 36}) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: potential);
  var steps = 0;
  while (g.phase != Phase.retired && !(stop?.call(g) ?? false)) {
    if (++steps > 4000) fail('終わらない');
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        if (g.stage == Stage.pro && g.player.age >= proRetireAge) {
          g.retire();
        } else {
          g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
              Ability.contact);
        }
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
  group('人生の節目の記録', () {
    test('始まりと、段階が変わるたびの進学が記録される', () {
      final g = _play(1, potential: 100);
      final stages = g.lifeLog.where((e) => e.kind == 'stage').toList();
      expect(stages.first.age, 6);
      expect(stages.first.text, contains('少年野球'));
      expect(stages.map((e) => e.text).join(),
          allOf(contains('中学'), contains('高校')));
      final mid = stages.firstWhere((e) => e.text.contains('中学'));
      expect(mid.age, 13);
    });

    test('ドラフトの結果と引退の理由が残る', () {
      for (var s = 0; s < 40; s++) {
        final g = _play(s, potential: 100);
        if (!g.ending!.madePro) continue;
        expect(
            g.lifeLog.any((e) => e.kind == 'draft' && e.text.contains('プロ入り')),
            isTrue);
        final r = g.lifeLog.last;
        expect(r.kind, 'retire');
        expect(r.age, g.player.age);
        return;
      }
      fail('プロになった選手がいない');
    });

    test('プロを諦めた/進路を選んだ記録', () {
      final g =
          _play(3, potential: 0, stop: (g) => g.phase == Phase.pathChoice);
      expect(g.lifeLog.last.text, contains('指名されなかった'));
      g.chooseRoute(Course.corporate);
      expect(g.lifeLog.last.text, '社会人で再挑戦');
      final h = _play(3, potential: 0, stop: (g) => g.phase == Phase.pathChoice)
        ..giveUp();
      expect(h.lifeLog.last.text, 'プロを諦めた');
    });

    test('特殊能力の習得・転向が記録される', () {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(5), potential: 60);
      g.adminSetCoachTeaches(Skill.chance);
      g.adminSetCoachTips(4);
      expect(g.lifeLog.last.kind, 'trait');
      expect(g.lifeLog.last.text, contains('チャンス○'));
      // 出来事で増えた特性も記録される。
      final h = Game.newGame(
          name: 't', role: Role.batter, rng: Random(6), potential: 60);
      h.adminSetTraits({});
      h.pendingEvent = events.firstWhere((e) => e.id == 'winter-menu');
      h.phase = Phase.event;
      h.resolveEvent(0);
      expect(h.lifeLog.last.text, contains('努力家'));
    });

    test('節目は保存して読み直せる。古いセーブは空', () {
      final g = _play(2, potential: 100, stop: (g) => g.player.age >= 14);
      final q = Game.fromJson(
          jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
          Random(1));
      expect(q.lifeLog.map((e) => e.toJson()).toList(),
          g.lifeLog.map((e) => e.toJson()).toList());
      expect(Game.fromJson({}, Random(1)).lifeLog, isEmpty);
    });
  });

  group('年表', () {
    test('年齢順に並び、同じ年は 節目→成績→引退 の順', () {
      final t = timelineOf(
        const [
          LifeEvent(30, 'retire', '引退'),
          LifeEvent(19, 'draft', 'ドラフトで指名され、プロ入り'),
          LifeEvent(6, 'stage', '少年野球を始めた'),
          LifeEvent(30, 'trait', '特性を習得'),
        ],
        const [
          SeasonRecord(
              age: 30,
              stage: Stage.pro,
              line: Line(),
              rank: 1,
              titles: ['首位打者']),
          SeasonRecord(
              age: 12,
              stage: Stage.youth,
              line: Line(),
              roundsWon: 4,
              rounds: 4),
        ],
      );
      expect(t.map((e) => e.age).toList(), [6, 12, 19, 30, 30, 30, 30]);
      expect(t.map((e) => e.kind).toList(), [
        'stage',
        'champion',
        'draft',
        'trait',
        'champion',
        'title',
        'retire'
      ]);
      expect(t[1].text, '全国優勝'); // 少年の夏の学童大会
      expect(t[4].text, 'リーグ優勝');
      expect(t[5].text, 'タイトル獲得: 首位打者');
    });

    test('優勝していない年・タイトルの無い年は載らない', () {
      final t = timelineOf(const [], const [
        SeasonRecord(
            age: 10, stage: Stage.youth, line: Line(), roundsWon: 1, rounds: 4),
        SeasonRecord(age: 25, stage: Stage.pro, line: Line(), rank: 4),
      ]);
      expect(t, isEmpty);
    });
  });

  group('選手情報の写し', () {
    test('育成中の選手から写せる(能力・特性・成績・経歴)', () {
      final g = _play(4, potential: 80, stop: (g) => g.player.age >= 16);
      g.adminSetTraits({Trait.clutch});
      final s = PlayerSnapshot.fromGame(g);
      expect(s.name, 't');
      expect(s.age, g.player.age);
      expect(s.abilities, g.player.abilities);
      expect(s.traits, {Trait.clutch});
      expect(s.records.length, g.records.length);
      expect(s.events.length, g.lifeLog.length);
      expect(s.endingTitle, isNull);
      expect(s.rivalName, g.cast.rival!.name);
    });

    test('引退後は称号が入る。保存して読み直しても同じ', () {
      final g = _play(7, potential: 90);
      final s = PlayerSnapshot.fromGame(g);
      expect(s.endingTitle, g.ending!.title);
      final q = PlayerSnapshot.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(q.toJson()), jsonEncode(s.toJson()));
    });

    test('欠けた項目は既定値で読める(殿堂の古い記録)', () {
      final s = PlayerSnapshot.fromJson({});
      expect(s.name, '名無し');
      expect(s.records, isEmpty);
      expect(s.traits, isEmpty);
      expect(s.stage, Stage.retired);
      expect(
          PlayerSnapshot.fromJson({
            'traits': ['genius', 'zzz']
          }).traits,
          {Trait.genius});
    });

    test('総合評価と素質の星', () {
      final s = PlayerSnapshot.fromJson({
        'role': 'batter',
        'abilities': {
          'contact': 80,
          'power': 60,
          'speed': 40,
          'fielding': 60,
          'trajectory': 60,
          'arm': 60,
          'catching': 60
        },
      });
      expect(overallOf(s), closeTo(60, 1e-9));
      expect(potentialStars(0), '★☆☆☆☆');
      expect(potentialStars(41), '★☆☆☆☆');
      expect(potentialStars(42), '★★☆☆☆');
      expect(potentialStars(50), '★★☆☆☆');
      expect(potentialStars(60), '★★★☆☆');
      expect(potentialStars(70), '★★★★☆');
      expect(potentialStars(100), '★★★★★');
    });
  });
}
