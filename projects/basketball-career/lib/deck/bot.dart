/// 自動で遊ぶ人(釣り合いを測る・テストで1シーズン通す)。人よりは下手な、欲張りな打ち方。
library;

import 'battle.dart';
import 'cards.dart';
import 'run.dart';

/// そのカードを今出す値打ち(大きいほど先に出す)。0以下なら出さない。
double cardValue(Battle b, CardInstance c) {
  if (!b.canPlay(c)) return -1;
  final s = c.stats;
  final left = b.totalRounds - b.round;
  final threat = b.projectedTheirs;
  var v = 0.0;
  if (c.def.kind == CardKind.shot) {
    // 組み立てが手札にあり、まだ出していないなら、シュートは後回し
    v += b.pointsOf(c);
  } else {
    v += s.points;
  }
  final g = b.guardOf(c);
  if (g > 0) v += g < threat ? g : threat;
  switch (c.def.special) {
    case Special.halveOpponent:
      v += threat / 2;
    case Special.stopDrive:
      if (b.intent.kind.name == 'drive' || b.intent.kind.name == 'fast') v += threat;
    case Special.zone:
      v += s.bonus * (left - 1) * 0.7;
    case Special.gameMaker:
      v += s.bonus * (left - 1) * 1.0;
    case Special.rhythmPower:
      v += s.rhythm * (left - 1) * 1.2;
    case Special.clutchPower:
      final q4 = b.totalRounds - (b.round > 6 ? b.round : 6);
      v += s.bonus * q4 * 1.0;
    default:
  }
  v += s.draw * 1.6 + s.stamina * 2.0 + s.nextDraw * 1.2;
  final shotsLeft = b.hand.where((h) => h != c && h.def.kind == CardKind.shot).length;
  if (s.setup > 0 && shotsLeft > 0) v += s.setup;
  if (c.def.kind == CardKind.shot && s.rhythm > 0) v += s.rhythm * (left - 1) * 0.8;
  v -= s.fatigue * 1.5;
  if (c.def.isPass && shotsLeft > 0) v += 0.5;
  return v / (s.cost == 0 ? 0.6 : s.cost);
}

/// 1ラウンド分を打つ(ラウンドの終了は呼ばない)。
void botPlayRound(Battle b) {
  for (var guard = 0; guard < 30; guard++) {
    CardInstance? best;
    var bestV = 0.0;
    // 0コストの組み立てを先に
    for (final c in b.hand) {
      var v = cardValue(b, c);
      if (c.def.kind == CardKind.play && c.cost == 0) v += 5;
      if (v > bestV) {
        bestV = v;
        best = c;
      }
    }
    if (best == null) return;
    b.play(best);
  }
}

void botPlayBattle(Battle b) {
  while (!b.over) {
    botPlayRound(b);
    b.endRound();
  }
}

/// 1シーズンを最後まで自動で。
void botPlayRun(RunState r) {
  for (var steps = 0; steps < 500 && !r.over; steps++) {
    botStep(r);
  }
}

/// 1歩進める(試合なら1試合を最後まで)。
void botStep(RunState r) {
    switch (r.phase) {
      case Phase.map:
        final ch = r.choices;
        NodeType pick = ch.first;
        int score(NodeType t) => switch (t) {
              NodeType.boss => 100,
              NodeType.elite => r.hearts >= 2 ? 6 : 1,
              NodeType.game => 5,
              NodeType.practice => r.hearts == 1 ? 7 : 4,
              NodeType.shop => r.money >= 100 ? 6 : 2,
              NodeType.event => 3,
            };
        for (final t in ch) {
          if (score(t) > score(pick)) pick = t;
        }
        r.choose(pick);
      case Phase.battle:
        botPlayBattle(r.battle!);
        r.finishBattle();
      case Phase.reward:
        CardInstance? best;
        for (final c in r.rewardCards) {
          if (best == null || c.def.rarity.index > best.def.rarity.index) best = c;
        }
        r.takeReward(best);
      case Phase.mateReward:
        r.takeMate(r.rewardMates.isEmpty ? null : r.rewardMates.first);
      case Phase.practice:
        if (r.hearts == 1) {
          r.rest();
        } else {
          final up = r.deck.where((c) => c.canUpgrade).toList()
            ..sort((a, b) => b.def.rarity.index.compareTo(a.def.rarity.index));
          if (up.isEmpty) {
            r.rest();
          } else {
            r.upgrade(up.first);
          }
        }
      case Phase.shop:
        for (final it in r.shopItems) {
          if (!it.sold && r.money >= it.price && (it.mate != null || it.card!.def.rarity.index >= Rarity.uncommon.index)) {
            r.buy(it);
          }
        }
        final basic = r.deck.where((c) => c.def.id == 'jumper' && !c.upgraded).toList();
        if (basic.isNotEmpty && r.money >= r.removalPrice) r.removeCard(basic.first);
        r.leaveShop();
      case Phase.event:
        r.resolveEvent(r.rng.nextInt(r.event!.choices.length));
      case Phase.finished:
        return;
    }
}
