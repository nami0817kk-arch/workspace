import 'dart:math';

import 'package:basketball_career/game/build.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/legacy.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Map<Ability, int> a, {double h = 188, int base = 40}) => Player(
      name: 'a',
      age: 20,
      potential: 70,
      heightCm: h,
      heightGenes: 0.5,
      abilities: {for (final x in Ability.values) x: a[x] ?? base},
    );

void main() {
  group('ビルド(タイプ判定)', () {
    test('能力が低すぎれば型なし', () {
      expect(buildOf(_p({}, base: 25)), isNull);
    });

    test('3Pとミドルとフリースローが高ければシャープシューター', () {
      final i = buildOf(_p({Ability.threePoint: 80, Ability.midRange: 75, Ability.freeThrow: 75}))!;
      expect(i.build, Build.sharpshooter);
      expect(i.tier, greaterThanOrEqualTo(2));
    });

    test('ドリブルとパスとスピードならプレイメーカー、ゴール下と体ならスラッシャー', () {
      expect(buildOf(_p({Ability.pass: 85, Ability.dribble: 80, Ability.speed: 75}))!.build, Build.playmaker);
      expect(
          buildOf(_p({Ability.inside: 85, Ability.physical: 80, Ability.speed: 75, Ability.dribble: 40}, h: 192))!
              .build,
          Build.slasher);
    });

    test('ディフェンスとスピードとスタミナならロックダウン、背が高ければリムプロテクター', () {
      final d = {Ability.defense: 85, Ability.speed: 75, Ability.stamina: 75, Ability.rebound: 50, Ability.inside: 40};
      expect(buildOf(_p(d, h: 180))!.build, Build.lockdown);
      final r = {Ability.defense: 85, Ability.rebound: 85, Ability.inside: 80, Ability.speed: 40, Ability.stamina: 40};
      expect(buildOf(_p(r, h: 205))!.build, Build.rimProtector);
    });

    test('ストレッチビッグは196cm以上だけ。低いとシャープシューターになる', () {
      final a = {Ability.threePoint: 85, Ability.rebound: 80, Ability.midRange: 75};
      expect(buildOf(_p(a, h: 205))!.build, Build.stretchBig);
      expect(buildOf(_p(a, h: 185))!.build, isNot(Build.stretchBig));
    });

    test('全部同じくらいならオールラウンダー', () {
      expect(buildOf(_p({}, base: 62))!.build, Build.allRound);
    });

    test('ティアは型に効く能力の平均で上がる(ブロンズ→シルバー→ゴールド→レジェンド)', () {
      int tier(int v) => buildOf(_p({
            Ability.threePoint: v,
            Ability.midRange: v,
            Ability.freeThrow: v,
          }))!
              .tier;
      expect(tier(50), 0);
      expect(tier(62), 1);
      expect(tier(78), 2);
      expect(tier(92), 3);
      expect(tierLabels, hasLength(4));
    });
  });

  group('ビルドの効き', () {
    final shooter = _p({Ability.threePoint: 80, Ability.midRange: 78, Ability.freeThrow: 78});

    test('型に合うプレーだけ勝負どころの成功率が上がる', () {
      final i = buildOf(shooter)!;
      expect(buildClutchBonus(shooter, Clutch.threePoint), closeTo(0.01 * i.level, 1e-9));
      expect(buildClutchBonus(shooter, Clutch.pass), 0);
      expect(buildClutchBonus(shooter, Clutch.defend), 0);
    });

    test('ティアが上がるほど加算が大きい', () {
      double bonus(int v) => buildClutchBonus(
          _p({Ability.threePoint: v, Ability.midRange: v, Ability.freeThrow: v}), Clutch.threePoint);
      expect(bonus(50), lessThan(bonus(62)));
      expect(bonus(62), lessThan(bonus(78)));
      expect(bonus(78), lessThan(bonus(92)));
    });

    test('オールラウンダーはどのプレーも少しだけ上がる', () {
      final a = _p({}, base: 62);
      for (final c in Clutch.values) {
        expect(buildClutchBonus(a, c), greaterThan(0), reason: c.name);
      }
    });

    test('ロックダウンはスティール、リムプロテクターはブロック、プレイメーカーは味方の強さ', () {
      final lock = _p({Ability.defense: 85, Ability.speed: 75, Ability.stamina: 75}, h: 180);
      expect(buildStealMultiplier(lock), greaterThan(1.0));
      expect(buildBlockMultiplier(lock), 1.0);
      final rim = _p({Ability.defense: 85, Ability.rebound: 85, Ability.inside: 80}, h: 205);
      expect(buildBlockMultiplier(rim), greaterThan(1.0));
      final pm = _p({Ability.pass: 85, Ability.dribble: 80, Ability.speed: 75});
      expect(buildTeamBonus(pm), greaterThan(0));
      expect(buildTeamBonus(shooter), 0);
    });
  });

  group('ゲームの中のビルド', () {
    test('ビルドが決まったら知らせ、すぐには言い直さない。保存・復元で残る', () {
      final base = Game.start('x', rng: Random(1), events: false);
      final g = Game(
        eventsEnabled: false,
        player: base.player.copyWith(
          age: 19,
          abilities: {
            for (final a in Ability.values)
              a: (a == Ability.threePoint || a == Ability.midRange || a == Ability.freeThrow) ? 80 : 40,
          },
        ),
        rng: Random(2),
      );
      expect(g.buildLabel, '');
      g.choose(Action.rest, Ability.threePoint);
      expect(g.lastBuildNote, contains('ビルドが決まった'));
      expect(g.buildLabel, contains('シャープシューター'));
      final back = Game.fromJson(g.toJson());
      expect(back.buildLabel, g.buildLabel);
      final j = g.toJson()..remove('buildLabel');
      expect(Game.fromJson(j).buildLabel, '');
    });

    test('エンディングにプレースタイルが出て、実績(ゴールド・レジェンド)がある', () {
      final base = Game.start('x', rng: Random(1), events: false);
      final g = Game(
        eventsEnabled: false,
        player: base.player.copyWith(
          age: 30,
          heightCm: 190,
          abilities: {
            for (final a in Ability.values)
              a: (a == Ability.threePoint || a == Ability.midRange || a == Ability.freeThrow) ? 92 : 45,
          },
        ),
        rng: Random(2),
      );
      expect(epilogueLines(g).any((l) => l.contains('プレースタイル') && l.contains('レジェンド')), isTrue);
      final ids = achievements.where((a) => a.earned(g)).map((a) => a.id);
      expect(ids, containsAll(['build_gold', 'build_legend']));
    });
  });

  group('試合の勢い(連勝・連敗)', () {
    test('勢いの加算は連勝で増え、連敗で減り、±3試合分(±2.4)で頭打ち', () {
      expect(TournamentRun(League.proDomestic).momentum, 0);
      expect(TournamentRun(League.proDomestic, streak: 1).momentum, closeTo(0.8, 1e-9));
      expect(TournamentRun(League.proDomestic, streak: 3).momentum, closeTo(2.4, 1e-9));
      expect(TournamentRun(League.proDomestic, streak: 9).momentum, closeTo(2.4, 1e-9));
      expect(TournamentRun(League.proDomestic, streak: -2).momentum, closeTo(-1.6, 1e-9));
      expect(TournamentRun(League.proDomestic, streak: -9).momentum, closeTo(-2.4, 1e-9));
    });

    test('大会を進めると、直近の連続した勝ち・負けが streak に入る', () {
      final base = Game.start('x', rng: Random(1), events: false);
      final p = base.player.copyWith(
        age: 24,
        abilities: {for (final a in Ability.values) a: 62},
      );
      var checked = 0;
      for (var seed = 0; seed < 40; seed++) {
        final run = TournamentRun(League.proDomestic);
        run.advance(p, form: 1.0, rng: Random(seed));
        final ms = run.matches;
        if (ms.length < 3) continue;
        var n = 0;
        final lastWon = ms.last.won;
        for (var i = ms.length - 1; i >= 0 && ms[i].won == lastWon; i--) {
          n++;
        }
        expect(run.streak, lastWon ? n : -n, reason: 'seed $seed');
        checked++;
      }
      expect(checked, greaterThan(5));
    });

    test('勢いは保存・復元で変わらず、古いセーブは0', () {
      final r = TournamentRun(League.proDomestic, streak: -2);
      expect(TournamentRun.fromJson(r.toJson()).streak, -2);
      expect(TournamentRun.fromJson(r.toJson()..remove('streak')).streak, 0);
    });
  });
}
