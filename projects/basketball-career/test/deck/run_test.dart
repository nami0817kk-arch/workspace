import 'dart:convert';

import 'package:basketball_career/deck/bot.dart';
import 'package:basketball_career/deck/cards.dart';
import 'package:basketball_career/deck/mates.dart';
import 'package:basketball_career/deck/run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 保存して読み直す(JSON の文字列を通す)。
RunState _reload(RunState r) => RunState.fromJson(jsonDecode(jsonEncode(r.toJson())))!;

/// 試合に負ける(相手に点を取らせるだけ)。
void _lose(RunState r) {
  final b = r.battle!;
  while (!b.over) {
    b.endRound();
  }
}

void main() {
  test('大会は8つの行き先。最後が決勝、その前は練習か部室、どの階にも試合がある', () {
    for (var seed = 1; seed < 60; seed++) {
      final r = RunState(seed: seed);
      expect(r.map, hasLength(RunState.floorsPerStage));
      expect(r.map.last, [NodeType.boss]);
      expect(r.map[RunState.floorsPerStage - 2], [NodeType.practice, NodeType.shop]);
      for (var f = 0; f < RunState.floorsPerStage - 2; f++) {
        expect(r.map[f].any((t) => t == NodeType.game || t == NodeType.elite), isTrue, reason: 'seed $seed floor $f');
        expect(r.map[f].toSet(), hasLength(r.map[f].length), reason: '同じ行き先が重なっている');
      }
      expect(r.map[0].contains(NodeType.elite) || r.map[1].contains(NodeType.elite), isFalse,
          reason: '強豪は3階目から');
    }
  });

  test('始めは10枚・部費60・気持ち3', () {
    final r = RunState(seed: 1);
    expect(r.deck, hasLength(10));
    expect(r.money, 60);
    expect(r.hearts, 3);
    expect(r.phase, Phase.map);
  });

  test('普通の試合に負けると気持ちが1つ減り、次の階へ。0で終わり', () {
    final r = RunState(seed: 2);
    for (var i = 0; i < 3; i++) {
      // 試合のある行き先を選ぶ
      final t = r.choices.firstWhere((t) => t == NodeType.game || t == NodeType.elite);
      final floor = r.floor;
      r.choose(t);
      _lose(r);
      r.finishBattle();
      if (i < 2) {
        expect(r.hearts, 2 - i);
        expect(r.floor, floor + 1);
        expect(r.phase, Phase.map);
      }
    }
    expect(r.over, isTrue);
    expect(r.champion, isFalse);
  });

  test('決勝に負けたら敗退。動画で1回だけやり直せる', () {
    final r = RunState(seed: 3);
    r.floor = RunState.floorsPerStage - 1;
    r.choose(NodeType.boss);
    expect(r.opponent!.boss, isTrue);
    _lose(r);
    r.finishBattle();
    expect(r.over, isTrue);
    expect(r.canRetry, isTrue);
    r.retryBoss();
    expect(r.phase, Phase.battle);
    _lose(r);
    r.finishBattle();
    expect(r.over, isTrue);
    expect(r.canRetry, isFalse);
  });

  test('勝つと部費とカードの候補。取ると次の階、取らなくてもよい', () {
    final r = RunState(seed: 4);
    r.choose(NodeType.game);
    botPlayBattle(r.battle!);
    if (!r.battle!.won) return; // まれに負ける種なら飛ばす
    final before = r.money;
    r.finishBattle();
    expect(r.phase, Phase.reward);
    expect(r.money, greaterThan(before));
    expect(r.rewardCards, hasLength(3));
    expect(r.rewardCards.map((c) => c.def.id).toSet(), hasLength(3), reason: '候補が重ならない');
    final pick = r.rewardCards.first;
    r.takeReward(pick);
    expect(r.deck, contains(pick));
    expect(r.floor, 1);
  });

  test('練習で1枚強くする・休むと気持ちが戻る', () {
    final r = RunState(seed: 5);
    r.phase = Phase.practice;
    final c = r.deck.first;
    r.upgrade(c);
    expect(c.upgraded, isTrue);
    expect(r.phase, Phase.map);
    r.phase = Phase.practice;
    r.hearts = 1;
    r.rest();
    expect(r.hearts, 2);
  });

  test('部室: 買える・外す値段は使うたびに上がる・部費が足りなければ買えない', () {
    final r = RunState(seed: 6);
    r.money = 1000;
    r.map[0] = [NodeType.shop, NodeType.game];
    r.choose(NodeType.shop);
    expect(r.phase, Phase.shop);
    expect(r.shopItems.where((s) => s.card != null), isNotEmpty);
    final it = r.shopItems.first;
    r.buy(it);
    expect(it.sold, isTrue);
    expect(r.money, 1000 - it.price);
    final p1 = r.removalPrice;
    r.removeCard(r.deck.first);
    expect(r.removalPrice, greaterThan(p1));
    r.money = 0;
    final left = r.shopItems.firstWhere((s) => !s.sold);
    r.buy(left);
    expect(left.sold, isFalse);
    r.leaveShop();
    expect(r.phase, Phase.map);
  });

  test('仲間は5人まで', () {
    final r = RunState(seed: 7);
    r.mates.addAll(allMates.take(maxMates));
    r.money = 1000;
    r.phase = Phase.shop;
    r.shopItems = [ShopItem.mate(allMates.last, 100)];
    r.buy(r.shopItems.first);
    expect(r.mates, hasLength(maxMates));
  });

  test('出来事の選択肢はどれを選んでも進み、気持ちは0にならない', () {
    for (final e in allEvents) {
      for (var i = 0; i < e.choices.length; i++) {
        final r = RunState(seed: 8);
        r.hearts = 1;
        r.money = 100;
        r.phase = Phase.event;
        r.event = e;
        r.resolveEvent(i);
        expect(r.phase, Phase.map, reason: '${e.id} $i');
        expect(r.hearts, greaterThanOrEqualTo(1));
        expect(r.lastMessage, e.choices[i].result);
      }
    }
  });

  test('どの局面で保存して読み直しても、最後まで遊べる', () {
    for (var seed = 10; seed < 40; seed++) {
      var r = RunState(seed: seed);
      for (var steps = 0; steps < 400 && !r.over; steps++) {
        r = _reload(r);
        botStep(r);
      }
      expect(r.over, isTrue, reason: 'seed $seed が終わらない');
      final back = _reload(r);
      expect(back.over, isTrue);
      expect(back.champion, r.champion);
      expect(back.deck.length, r.deck.length);
    }
  });

  test('試合の途中で閉じたら、同じ試合を始めから', () {
    final r = RunState(seed: 11);
    r.choose(NodeType.game);
    final first = r.battle!.intent.total;
    final hand = [for (final c in r.battle!.hand) c.def.id];
    r.battle!.play(r.battle!.hand.first);
    final back = _reload(r);
    expect(back.phase, Phase.battle);
    expect(back.battle!.round, 0);
    expect(back.battle!.mine, 0);
    expect(back.battle!.intent.total, first);
    expect([for (final c in back.battle!.hand) c.def.id], hand);
  });

  test('壊れた保存は読まない', () {
    expect(RunState.fromJson(null), isNull);
    expect(RunState.fromJson({'v': 1}), isNull);
    expect(RunState.fromJson({'rng': 1, 'deck': [], 'map': []}), isNull);
  });

  group('釣り合い(自動で遊ぶ人で測る)', () {
    ({double champ, double win}) measure(int n, {int dif = 0, bool takeRewards = true}) {
      var champs = 0, games = 0, wins = 0;
      for (var i = 0; i < n; i++) {
        final r = RunState(seed: 500 + i * 131, difficulty: dif);
        for (var steps = 0; steps < 500 && !r.over; steps++) {
          if (r.phase == Phase.battle) {
            botPlayBattle(r.battle!);
            games++;
            if (r.battle!.won) wins++;
          }
          if (!takeRewards && r.phase == Phase.reward) {
            r.takeReward(null);
            continue;
          }
          botStep(r);
        }
        if (r.champion) champs++;
      }
      return (champ: champs / n, win: wins / games);
    }

    test('難しさ0: 下手な打ち方でも試合はたいてい勝てるが、優勝は難しい', () {
      final m = measure(150);
      expect(m.win, inInclusiveRange(0.7, 0.95));
      expect(m.champ, inInclusiveRange(0.05, 0.4));
    });

    test('カードを集めないと勝ち上がれない(選び方が効く)', () {
      final take = measure(120);
      final skip = measure(120, takeRewards: false);
      expect(take.champ, greaterThan(skip.champ * 2 + 0.03));
    });

    test('難しさを上げると勝ちにくくなる', () {
      expect(measure(100, dif: 8).champ, lessThan(measure(100).champ));
    });
  });

  test('カードの番号から引ける', () {
    expect(card('jumper').name, 'ジャンプシュート');
  });
}
