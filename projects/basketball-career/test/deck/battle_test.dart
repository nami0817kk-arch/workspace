import 'dart:io';

import 'package:basketball_career/deck/battle.dart';
import 'package:basketball_career/deck/cards.dart';
import 'package:basketball_career/deck/mates.dart';
import 'package:basketball_career/deck/opponents.dart';
import 'package:basketball_career/deck/rng.dart';
import 'package:flutter_test/flutter_test.dart';

/// 決まった予告を出す相手(試すため)。
class _FixedOpponent extends Opponent {
  _FixedOpponent(this.fixed) : super(name: '試し高校', style: OppStyle.balance, stage: 0);
  final Intent fixed;
  @override
  Intent intentFor(int round, Rng rng) => fixed;
}

Battle _battle(List<String> ids,
    {Intent intent = const Intent(IntentKind.shot, [5]), List<MateDef> mates = const [], int seed = 1}) {
  final deck = [for (final id in ids) CardInstance(card(id))];
  return Battle(deck: deck, opponent: _FixedOpponent(intent), mates: mates, rng: Rng(seed));
}

CardInstance _inHand(Battle b, String id) => b.hand.firstWhere((c) => c.def.id == id);

void main() {
  group('カード', () {
    test('名前と番号がそろい、文が数字と合う', () {
      final ids = <String>{};
      for (final c in allCards) {
        expect(ids.add(c.id), isTrue, reason: '番号が重なっている: ${c.id}');
        expect(c.text(false), isNotEmpty, reason: c.id);
        if (c.kind != CardKind.status) {
          expect(c.text(true) != c.text(false) || c.plus.cost != c.base.cost, isTrue,
              reason: '強くしても何も変わらない: ${c.id}');
        }
        final p = c.base.points;
        if (p > 0 && c.special == Special.none) expect(c.text(false), contains('$p点'));
        if (c.base.guard > 0) expect(c.text(false), contains('守備${c.base.guard}'));
      }
    });

    test('絵のファイルがある', () {
      for (final c in allCards) {
        expect(File('assets/art/icons/${c.icon}.png').existsSync(), isTrue, reason: c.id);
      }
    });

    test('始めのデッキは10枚、報酬には基本と状態が出ない', () {
      expect(starterDeck(), hasLength(10));
      for (final c in rewardPool()) {
        expect(c.rarity, isNot(anyOf(Rarity.starter, Rarity.status)));
      }
      expect(rewardPool(locked: {'dunk'}).any((c) => c.id == 'dunk'), isFalse);
    });

    test('保存して戻すと同じカード(強くしたかも)', () {
      final c = CardInstance(card('dunk'), upgraded: true);
      final back = CardInstance.fromJson(c.toJson())!;
      expect(back.def.id, 'dunk');
      expect(back.upgraded, isTrue);
      expect(back.name, 'ダンク＋');
      expect(CardInstance.fromJson({'id': 'nope'}), isNull);
    });
  });

  group('試合', () {
    test('5枚引いてスタミナ3。出すとスタミナが減り、点が入る', () {
      final b = _battle(List.filled(10, 'jumper'));
      expect(b.hand, hasLength(5));
      expect(b.stamina, 3);
      expect(b.play(b.hand.first), isTrue);
      expect(b.stamina, 2);
      expect(b.mine, 2);
      expect(b.hand, hasLength(4));
    });

    test('スタミナが足りないカードは出せない', () {
      final b = _battle(List.filled(10, 'deepthree'));
      expect(b.play(b.hand.first), isTrue);
      expect(b.canPlay(b.hand.first), isFalse);
      expect(b.play(b.hand.first), isFalse);
    });

    test('守備は相手の点を前から削る。連続攻撃は1本ずつ', () {
      final b = _battle(List.filled(10, 'defense'), intent: const Intent(IntentKind.combo, [4, 4]));
      b.play(b.hand.first); // 守備3
      expect(b.projectedTheirs, 5);
      b.play(b.hand.first); // 守備6
      expect(b.projectedTheirs, 2);
      b.endRound();
      expect(b.theirs, 2);
      expect(b.rounds.single.theirs, 2);
    });

    test('パスのあとはアリウープが大きく、ないと1点', () {
      final b = _battle(['alleyoop', 'pass', 'jumper', 'jumper', 'jumper'], seed: 3);
      final a = _inHand(b, 'alleyoop');
      expect(b.pointsOf(a), 1);
      b.play(_inHand(b, 'pass'));
      // パスの「次のシュート+1」も乗る
      expect(b.pointsOf(a), 6 + 1);
      b.play(a);
      expect(b.mine, 7);
      expect(b.setup, 0, reason: 'シュートを打ったら上乗せは消える');
    });

    test('堅い守りはシュートを減らす(最低1点)。フローターは邪魔されない', () {
      final b = _battle(['bank', 'floater', 'jumper', 'jumper', 'jumper'],
          intent: const Intent(IntentKind.press, [2], press: 2));
      expect(b.pointsOf(_inHand(b, 'bank')), 1);
      expect(b.pointsOf(_inHand(b, 'jumper')), 1);
      expect(b.pointsOf(_inHand(b, 'floater')), 3);
    });

    test('ダブルチームで半分、チャージングはドライブを止める', () {
      final b = _battle(List.filled(10, 'doubleteam'), intent: const Intent(IntentKind.shot, [9]));
      b.play(b.hand.first);
      expect(b.projectedTheirs, 4);
      final c = _battle(List.filled(10, 'charge'), intent: const Intent(IntentKind.drive, [9]));
      c.play(c.hand.first);
      expect(c.projectedTheirs, 0);
      final d = _battle(List.filled(10, 'charge'), intent: const Intent(IntentKind.three, [9]));
      d.play(d.hand.first);
      expect(d.projectedTheirs, 9 - 2, reason: 'ドライブでなければ、ただの守備2');
    });

    test('流れのカードは試合ずっと効き、手札に戻らない', () {
      final b = _battle(['zone', 'hothand', 'gamemaker', 'jumper', 'jumper', 'jumper', 'jumper', 'jumper', 'jumper', 'jumper'],
          seed: 5);
      for (final id in ['zone', 'hothand']) {
        if (b.hand.any((c) => c.def.id == id)) b.play(_inHand(b, id));
      }
      final zone = b.zone, rhythm = b.rhythm;
      b.endRound();
      expect(b.guard, zone, reason: '毎ラウンドのはじめに守備');
      expect(b.rhythm, rhythm);
      expect(b.exhausted.every((c) => c.def.kind == CardKind.power), isTrue);
      expect([...b.hand, ...b.drawPile, ...b.discard].any((c) => c.def.kind == CardKind.power && b.exhausted.contains(c)),
          isFalse);
    });

    test('疲労は捨て札に入り、出せない。御影がいれば入らない', () {
      final b = _battle(List.filled(10, 'hustle'));
      b.play(b.hand.first);
      expect(b.discard.where((c) => c.def.id == 'fatigue'), hasLength(1));
      final iron = _battle(List.filled(10, 'hustle'), mates: [mateById['iron']!]);
      iron.play(iron.hand.first);
      expect(iron.discard.where((c) => c.def.id == 'fatigue'), isEmpty);
      expect(iron.canPlay(CardInstance(card('fatigue'))), isFalse);
    });

    test('8ラウンドで終わる。同点なら延長', () {
      final b = _battle(List.filled(10, 'handsup'), intent: const Intent(IntentKind.shot, [0]));
      for (var i = 0; i < 8; i++) {
        expect(b.over, isFalse);
        b.endRound();
      }
      // 0対0の同点 → 延長
      expect(b.over, isFalse);
      expect(b.periodLabel, '延長1');
      b.endRound();
      b.endRound();
      expect(b.over, isTrue, reason: '延長は2回まで');
      expect(b.won, isFalse, reason: '最後まで同点なら負け');
    });

    test('クォーターの表示', () {
      final b = _battle(List.filled(10, 'jumper'));
      expect(b.periodLabel, '第1クォーター');
      b.endRound();
      b.endRound();
      expect(b.periodLabel, '第2クォーター');
    });

    test('ブザービーターは最後のラウンドで大きい', () {
      final b = _battle(List.filled(10, 'buzzer'), intent: const Intent(IntentKind.shot, [0]));
      expect(b.pointsOf(b.hand.first), 2);
      for (var i = 0; i < 7; i++) {
        b.endRound();
      }
      expect(b.isLastRound, isTrue);
      expect(b.pointsOf(b.hand.first), 9);
    });

    test('仲間の得意が点に乗る', () {
      final b = _battle(List.filled(10, 'three'), mates: [mateById['shooter']!, mateById['ace']!]);
      final c = b.hand.first;
      expect(b.pointsOf(c), 4 + 1 + 2);
      b.play(c);
      expect(b.pointsOf(b.hand.first), 4 + 1, reason: 'エースは最初の1本だけ');
      final cap = _battle(List.filled(10, 'jumper'), mates: [mateById['captain']!]);
      expect(cap.pointsOf(cap.hand.first), 3);
    });

    test('同じ種なら同じ試合になる', () {
      List<int> play(int seed) {
        final b = Battle(
            deck: starterDeck(),
            opponent: Opponent(name: 'x', style: OppStyle.fast, stage: 1),
            mates: const [],
            rng: Rng(seed));
        final out = <int>[];
        while (!b.over) {
          out.add(b.intent.total);
          if (b.hand.isNotEmpty && b.canPlay(b.hand.first)) b.play(b.hand.first);
          b.endRound();
        }
        return [...out, b.mine, b.theirs];
      }

      expect(play(42), play(42));
      expect(play(42), isNot(play(43)));
    });

    test('手札は10枚まで', () {
      final b = _battle(List.filled(20, 'pass'));
      for (var i = 0; i < 10; i++) {
        if (b.hand.isEmpty) break;
        b.play(b.hand.first);
      }
      expect(b.hand.length, lessThanOrEqualTo(Battle.maxHand));
    });
  });

  group('相手', () {
    test('予告は1点以上で、段階が上がるほど強い', () {
      double avg(int stage, {bool boss = false}) {
        final rng = Rng(7);
        var sum = 0;
        for (var i = 0; i < 400; i++) {
          final o = makeOpponent(rng, stage: stage, boss: boss);
          final it = o.intentFor(i % 8, rng);
          expect(it.hits.every((h) => h >= 1), isTrue);
          sum += it.total;
        }
        return sum / 400;
      }

      expect(avg(1), greaterThan(avg(0)));
      expect(avg(2), greaterThan(avg(1)));
      expect(avg(0, boss: true), greaterThan(avg(0)));
    });

    test('相手の名前は自分の学校と違い、保存して戻せる', () {
      final rng = Rng(9);
      for (var i = 0; i < 100; i++) {
        final o = makeOpponent(rng, stage: i % 3, elite: i.isEven);
        expect(o.name, isNot(startsWith('朝日')));
        final back = Opponent.fromJson(o.toJson());
        expect(back.name, o.name);
        expect(back.style, o.style);
        expect(back.elite, o.elite);
      }
    });
  });
}
