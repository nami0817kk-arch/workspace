/// 1試合。4クォーター×2ラウンド(同点なら延長)。
///
/// 毎ラウンド: 手札を5枚引き、スタミナ3。相手の予告を見て、シュートで点を取り、守りで相手の点を削る。
/// 「ラウンド終了」で相手が予告どおりに攻め、守備の分だけ点が減る。最後に点の多いほうが勝ち。
library;

import 'cards.dart';
import 'mates.dart';
import 'opponents.dart';
import 'rng.dart';

/// 1ラウンドの結果(クォーターの点の表に使う)。
class RoundScore {
  const RoundScore(this.mine, this.theirs);
  final int mine;
  final int theirs;
}

/// 画面に流す出来事の一行。
class PlayEvent {
  const PlayEvent(this.text, {this.points = 0, this.guard = 0});
  final String text;
  final int points;
  final int guard;
}

class Battle {
  Battle({
    required List<CardInstance> deck,
    required this.opponent,
    required List<MateDef> mates,
    required this.rng,
  }) : mates = {for (final m in mates) m.effect} {
    drawPile = [for (final c in deck) c.copy()];
    rng.shuffle(drawPile);
    if (this.mates.contains(MateEffect.captain)) rhythm += 1;
    _startRound();
  }

  final Opponent opponent;
  final Set<MateEffect> mates;
  final Rng rng;

  static const regulationRounds = 8;
  static const maxOvertime = 2;
  static const handSize = 5;
  static const maxHand = 10;
  static const baseStamina = 3;

  late List<CardInstance> drawPile;
  final hand = <CardInstance>[];
  final discard = <CardInstance>[];

  /// この試合ではもう使わないカード(流れのカード・1回きり)。
  final exhausted = <CardInstance>[];

  int round = 0;
  int totalRounds = regulationRounds;
  int stamina = 0;
  int guard = 0;
  int mine = 0;
  int theirs = 0;
  int rhythm = 0;
  int setup = 0;
  int zone = 0;
  int extraDraw = 0;
  int clutchBonus = 0;
  int _nextDraw = 0;
  bool passThisRound = false;
  bool _firstShotDone = false;
  bool doubleTeam = false;
  bool stopped = false;
  int _roundMine = 0;
  late Threat intent;
  final rounds = <RoundScore>[];
  final events = <PlayEvent>[];
  bool over = false;

  bool get won => over && mine > theirs;
  bool get isLastRound => round == totalRounds - 1;
  bool get overtime => round >= regulationRounds;

  /// 1〜4、延長は5以上。
  int get quarter => overtime ? 5 + (round - regulationRounds) : round ~/ 2 + 1;
  String get periodLabel => overtime ? '延長${round - regulationRounds + 1}' : '第$quarterクォーター';

  void _startRound() {
    stamina = baseStamina + (mates.contains(MateEffect.sixthMan) && round >= 6 ? 1 : 0);
    guard = zone + (mates.contains(MateEffect.center) ? 2 : 0);
    setup = 0;
    passThisRound = false;
    _firstShotDone = false;
    doubleTeam = false;
    stopped = false;
    _roundMine = 0;
    intent = opponent.intentFor(round, rng);
    var n = handSize + extraDraw + _nextDraw;
    if (round == 0 && mates.contains(MateEffect.playmaker)) n += 2;
    _nextDraw = 0;
    draw(n);
  }

  void draw(int n) {
    for (var i = 0; i < n; i++) {
      if (hand.length >= maxHand) return;
      if (drawPile.isEmpty) {
        if (discard.isEmpty) return;
        drawPile.addAll(discard);
        discard.clear();
        rng.shuffle(drawPile);
      }
      hand.add(drawPile.removeLast());
    }
  }

  bool canPlay(CardInstance c) =>
      !over && hand.contains(c) && !c.def.unplayable && c.cost <= stamina;

  /// シュートなら何点になるか(画面の見込みにも使う)。シュートでなければ、そのカードの点。
  int pointsOf(CardInstance c) {
    final s = c.stats;
    if (c.def.kind != CardKind.shot) return s.points;
    var p = switch (c.def.special) {
      Special.needsPass => passThisRound ? s.points : 1,
      Special.lastRound => isLastRound ? s.bonus : s.points,
      _ => s.points,
    };
    if (c.def.special == Special.afterPass && passThisRound) p += s.bonus;
    p += rhythm + setup;
    if (c.def.tag == ShotTag.three && mates.contains(MateEffect.shooter)) p += 1;
    if (c.def.tag == ShotTag.inside && mates.contains(MateEffect.slasher)) p += 1;
    if (s.cost == 0 && mates.contains(MateEffect.speedster)) p += 1;
    if (!_firstShotDone && mates.contains(MateEffect.ace)) p += 2;
    if (isLastRound && mates.contains(MateEffect.closer)) p += 3;
    if (round >= 6) p += clutchBonus;
    if (c.def.special != Special.ignorePress) p -= intent.press;
    return p < 1 ? 1 : p;
  }

  int guardOf(CardInstance c) {
    final g = c.stats.guard;
    if (g <= 0) return 0;
    return g + (c.def.kind == CardKind.defense && mates.contains(MateEffect.stopper) ? 1 : 0);
  }

  /// カードを出す。出せなければ false。
  bool play(CardInstance c) {
    if (!canPlay(c)) return false;
    final s = c.stats;
    stamina -= s.cost;
    hand.remove(c);

    final pts = pointsOf(c);
    final g = guardOf(c);
    if (c.def.kind == CardKind.shot) {
      setup = 0;
      _firstShotDone = true;
    }
    if (pts > 0) {
      mine += pts;
      _roundMine += pts;
    }
    guard += g;
    stamina += s.stamina;
    if (s.setup > 0) setup += s.setup;
    if (c.def.special != Special.rhythmPower) rhythm += s.rhythm;
    _nextDraw += s.nextDraw;
    if (c.def.isPass) passThisRound = true;
    switch (c.def.special) {
      case Special.halveOpponent:
        doubleTeam = true;
      case Special.stopDrive:
        if (intent.kind == IntentKind.drive || intent.kind == IntentKind.fast) stopped = true;
      case Special.zone:
        zone += s.bonus;
      case Special.gameMaker:
        extraDraw += s.bonus;
      case Special.rhythmPower:
        rhythm += s.rhythm;
      case Special.clutchPower:
        clutchBonus += s.bonus;
      default:
    }
    if (s.fatigue > 0 && !mates.contains(MateEffect.iron)) {
      for (var i = 0; i < s.fatigue; i++) {
        discard.add(CardInstance(card('fatigue')));
      }
    }
    if (c.def.kind == CardKind.power || c.def.exhaust) {
      exhausted.add(c);
    } else {
      discard.add(c);
    }
    if (s.draw > 0) draw(s.draw);
    events.add(PlayEvent(c.name, points: pts, guard: g));
    return true;
  }

  /// 守備を差し引いた、このラウンドの相手の得点(いまの時点の見込み)。
  int get projectedTheirs {
    if (stopped) return 0;
    var left = guard;
    var total = 0;
    for (final h in intent.hits) {
      final cut = left < h ? left : h;
      left -= cut;
      total += h - cut;
    }
    return doubleTeam ? total ~/ 2 : total;
  }

  /// ラウンドを終える。相手が攻め、次のラウンドへ(または試合終了)。
  void endRound() {
    if (over) return;
    final t = projectedTheirs;
    theirs += t;
    rounds.add(RoundScore(_roundMine, t));
    events.add(PlayEvent(stopped ? '相手の${intent.kind.label}を止めた' : '相手の${intent.kind.label}で$t点',
        points: -t));
    discard.addAll(hand);
    hand.clear();
    round++;
    if (round >= totalRounds) {
      if (mine == theirs && totalRounds - regulationRounds < maxOvertime) {
        totalRounds++;
      } else {
        over = true;
        return;
      }
    }
    _startRound();
  }
}
