import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/build.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

void _step(Game g) {
  switch (g.phase) {
    case Phase.season:
      g.choose(recommendedAction(g), recommendedFocus(g.player));
    case Phase.halftime:
      g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
    case Phase.clutch:
      g.resolveClutch(Clutch.drive);
    case Phase.event:
      g.resolveEvent(0);
    case Phase.path:
      if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
    case Phase.retired:
      break;
  }
}

Player _p({double h = 188, Build? style}) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
      age: 17,
      heightCm: h,
      abilities: {for (final a in Ability.values) a: 50},
      style: style);
}

void main() {
  group('目指すプレースタイル', () {
    test('選んだ型の能力は伸びやすく、それ以外は少し伸びにくい。おまかせは1.0', () {
      expect(styleGrowthMultiplier(null, Ability.threePoint), 1.0);
      expect(styleGrowthMultiplier(Build.sharpshooter, Ability.threePoint), greaterThan(1.0));
      expect(styleGrowthMultiplier(Build.sharpshooter, Ability.rebound), lessThan(1.0));
      expect(styleGrowthMultiplier(Build.allRound, Ability.pass), greaterThan(1.0));
      for (final b in Build.values) {
        expect(b == Build.allRound || styleKeys(b).isNotEmpty, isTrue, reason: b.label);
      }
    });

    test('1年の伸びが、選んだ型の能力で大きく、それ以外で小さい', () {
      final none = _p();
      final styled = _p(style: Build.sharpshooter);
      expect(yearlyDelta(styled, Ability.threePoint, Ability.threePoint),
          greaterThan(yearlyDelta(none, Ability.threePoint, Ability.threePoint)));
      expect(yearlyDelta(styled, Ability.rebound, Ability.threePoint),
          lessThan(yearlyDelta(none, Ability.rebound, Ability.threePoint)));
    });

    test('選ぶと、力がまだ弱くてもその型(ブロンズ)になる。選ばなければ自動', () {
      final weak = _p(style: Build.playmaker)
          .copyWith(abilities: {for (final a in Ability.values) a: 25});
      expect(buildOf(weak)?.build, Build.playmaker);
      expect(buildOf(weak)?.tier, 0);
      final auto = weak.copyWith(clearStyle: true);
      expect(auto.style, isNull);
      expect(buildOf(auto), isNull, reason: '弱すぎて型と呼べない');
    });

    test('身長が足りない大型の型は、選んでいても自動の判定になる', () {
      final short = _p(h: 180, style: Build.stretchBig);
      expect(buildOf(short)?.build, isNot(Build.stretchBig));
      final tall = _p(h: 200, style: Build.stretchBig);
      expect(buildOf(tall)?.build, Build.stretchBig);
    });

    test('名前から読み戻せ、知らない名前はおまかせ', () {
      for (final b in Build.values) {
        expect(Build.parse(b.name), b);
      }
      expect(Build.parse('zzz'), isNull);
      expect(Build.parse(null), isNull);
    });

    test('始めるときに選べ、育成中に変えられ、保存で残る', () {
      final g = Game.start('x', rng: Random(2), events: false, style: Build.slasher);
      expect(g.player.style, Build.slasher);
      g.setStyle(Build.lockdown);
      expect(Game.fromJson(g.toJson()).player.style, Build.lockdown);
      g.setStyle(null);
      expect(g.player.style, isNull);
      expect(Game.fromJson(g.toJson()).player.style, isNull);
    });

    test('古いセーブ(型の項目なし)はおまかせで読める', () {
      final j = Game.start('x', rng: Random(2), events: false).toJson();
      (j['player'] as Map<String, dynamic>).remove('style');
      expect(Game.fromJson(j).player.style, isNull);
    });

    test('引退後は変えられない', () {
      final g = Game.start('x', rng: Random(4), events: false);
      var guard = 0;
      while (g.phase != Phase.retired && guard++ < 600) {
        _step(g);
      }
      expect(() => g.setStyle(Build.slasher), throwsStateError);
    });

    test('エンディングに、目指した型への一言が出る(選んだときだけ)', () {
      final chosen = Game.start('x', rng: Random(5), events: false, style: Build.playmaker);
      final auto = Game.start('x', rng: Random(5), events: false);
      for (final g in [chosen, auto]) {
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 600) {
          _step(g);
        }
      }
      expect(epilogueLines(chosen).join('\n'), contains('目指したのは「プレイメーカー」'));
      expect(epilogueLines(auto).join('\n'), isNot(contains('目指したのは')));
    });

    test('どの型を選んでも、おまかせとプロ入り率が大きく変わらない(型が罠にならない)', () {
      double rate(Build? style) {
        var pro = 0;
        const n = 120;
        for (var seed = 0; seed < n; seed++) {
          final g = Game.start('x', rng: Random(seed), events: false, style: style);
          var guard = 0;
          while (g.phase != Phase.retired && guard++ < 600) {
            _step(g);
          }
          if (g.records.any((r) => r.league.name.startsWith('pro'))) pro++;
        }
        return pro / n;
      }

      final base = rate(null);
      for (final b in Build.values) {
        expect((rate(b) - base).abs(), lessThan(0.18), reason: b.label);
      }
    });
  });
}
