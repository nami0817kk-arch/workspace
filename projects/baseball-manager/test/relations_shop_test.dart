// お金の使い道(買い物)と、関係を生かす操作(交流の相手・頼みごと)(2026-10-28)。
import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/epilogue.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/relations.dart';
import 'package:baseball_manager/game/shop.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Game _pro(int seed) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: 100);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 4000) {
    g.autoSpend();
    if (g.stage == Stage.pro && g.phase == Phase.term) break;
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

Game _proGame() {
  for (var s = 0; s < 60; s++) {
    final g = _pro(s);
    if (g.stage == Stage.pro) return g;
  }
  fail('プロになれない');
}

Game _kid([int seed = 1]) =>
    Game.newGame(name: 'み', role: Role.batter, rng: Random(seed), potential: 60);

Game _roundTrip(Game g) => Game.fromJson(
    jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));

void main() {
  group('お金の使い道', () {
    test('アマのうちは買えない', () {
      final g = _kid();
      g.money = 100000;
      expect(g.shopBlock(ShopItem.care), 'プロの間だけ');
      expect(g.buyShop(ShopItem.care), isFalse);
    });

    test('施術は年3回まで・お金が減る・年をまたぐとまた使える', () {
      final g = _proGame();
      g.money = 100000;
      g.condition = g.condition.copyWith(fatigue: 90);
      for (var i = 0; i < 3; i++) {
        expect(g.buyShop(ShopItem.care), isTrue);
      }
      expect(g.condition.fatigue, 0);
      expect(g.money, 100000 - 3 * ShopItem.care.cost);
      expect(g.shopBlock(ShopItem.care), '今年はもう使った');
      final back = _roundTrip(g);
      expect(back.shopThisYear[ShopItem.care], 3);
    });

    test('合宿は重点の種類に多く経験点が入る', () {
      final g = _proGame();
      g.money = 100000;
      final before = g.exp.of(Category.batting);
      expect(g.buyShop(ShopItem.camp, Ability.power), isTrue);
      expect(g.exp.of(Category.batting), before + 15);
    });

    test('用具はその年だけ効き、保存しても残る', () {
      final g = _proGame();
      g.money = 100000;
      expect(g.gearActive, isFalse);
      expect(g.buyShop(ShopItem.gear), isTrue);
      expect(g.gearActive, isTrue);
      expect(_roundTrip(g).gearActive, isTrue);
    });

    test('寄付と家は一生に一度。実績とエピローグにつながる', () {
      final g = _proGame();
      g.money = 100000;
      expect(g.buyShop(ShopItem.donate), isTrue);
      expect(g.shopBlock(ShopItem.donate), '購入済み');
      if (g.cast.family != null) expect(g.buyShop(ShopItem.house), isTrue);
      final back = _roundTrip(g);
      expect(back.purchases, contains(ShopItem.donate));
      final snap = PlayerSnapshot.fromGame(back);
      expect(snap.purchases, contains('donate'));
      final hero = achievements.firstWhere((a) => a.id == 'hometown-hero');
      expect(hero.check(snap), isTrue);
      final again = PlayerSnapshot.fromJson(
          jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>);
      expect(again.purchases, contains('donate'));
      expect(
          epilogueOf(
                  const Ending(
                      title: 'レギュラー',
                      madePro: true,
                      proYears: 10,
                      peakOverall: 70,
                      championships: 0,
                      wasTwoWay: false),
                  't',
                  purchases: const ['donate'])
              .contains('寄付した地元の球場'),
          isTrue);
    });
  });

  group('関係を生かす操作', () {
    test('絆が足りないと頼めず、足りると年1回だけ頼める(絆を使う)', () {
      final g = _kid();
      final fam = g.cast.family!;
      fam.bond = 40;
      expect(g.favorBlock(fam), '絆50で頼める');
      fam.bond = 60;
      g.condition = g.condition.copyWith(fatigue: 50);
      expect(g.askFavor(fam), isTrue);
      expect(g.condition.fatigue, 25);
      expect(fam.bond, 60 - favorBondCost);
      expect(g.favorBlock(fam), '今年はもう頼んだ');
      expect(_roundTrip(g).favorsUsed, contains(fam.id));
    });

    test('ライバルは絆30から合同練習を申し込める', () {
      final g = _kid();
      final r = g.cast.rival!;
      r.bond = 30;
      final before = g.exp.of(Category.batting);
      expect(g.askFavor(r, Ability.contact), isTrue);
      expect(g.exp.of(Category.batting), greaterThanOrEqualTo(before + 10));
    });

    test('コーチに個別に見てもらうと、コーチのコツが増える', () {
      final g = _kid();
      final c = g.cast.coach!;
      if (c.teaches == null) return;
      c.bond = 60;
      final tips = c.tips;
      expect(g.askFavor(c), isTrue);
      expect(c.tips == tips + 1 || c.tips == 0, isTrue); // 4つで満タンになって0に戻る
    });

    test('仲間に自主練を頼むと、次の練習は必ずその仲間とタッグ', () {
      final g = _kid(5);
      final mate = g.cast.teammates.first;
      mate.bond = 60;
      expect(g.askFavor(mate), isTrue);
      expect(g.tagMateId, mate.id);
      expect(_roundTrip(g).tagMateId, mate.id);
      g.choose(Plan.train, Ability.contact);
      if (!g.condition.injured || g.log.any((l) => l.contains('友情タッグ'))) {
        expect(g.log.any((l) => l.contains('${mate.name}と友情タッグ')), isTrue);
      }
      expect(g.tagMateId, isNull);
    });

    test('交流の相手を選ぶと、その人の絆が上がる(保存される)', () {
      final g = _kid(7);
      final mate = g.cast.teammates.last;
      g.setSocialTarget(mate);
      final b = mate.bond;
      g.choose(Plan.social, Ability.contact);
      expect(mate.bond, greaterThanOrEqualTo(b + socialTargetBond));
      expect(_roundTrip(g).socialTargetId, mate.id);
    });

    test('コーチに教わると、コーチとの絆が育つ', () {
      final g = _kid(9);
      final c = g.cast.coach!;
      final b = c.bond;
      g.choose(Plan.lesson, Ability.contact);
      if (g.cast.coach == c) expect(c.bond, greaterThanOrEqualTo(b + lessonBond));
    });

    test('古いセーブは、相手なし・頼みごとなしで読める', () {
      final j = jsonDecode(jsonEncode(_kid().toJson())) as Map<String, dynamic>
        ..remove('socialTargetId')
        ..remove('favorsUsed')
        ..remove('purchases')
        ..remove('shopThisYear')
        ..remove('gearAge');
      final g = Game.fromJson(j, Random(1));
      expect(g.socialTarget, isNull);
      expect(g.favorsUsed, isEmpty);
      expect(g.purchases, isEmpty);
      expect(g.gearActive, isFalse);
    });
  });
}
