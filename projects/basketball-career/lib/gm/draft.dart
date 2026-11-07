import 'dart:math' as math;

import 'league.dart';
import 'names.dart';
import 'player.dart';
import 'rng.dart';
import 'trade.dart';

/// ドラフトの候補。本当の力は指名するまで分からず、見えるのは幅([ovrLo]〜[ovrHi] など)だけ。
class Prospect {
  Prospect({required this.player, required this.ovrLo, required this.ovrHi, required this.potLo, required this.potHi, this.scouted = false, this.pickedBy});

  final Player player;
  int ovrLo, ovrHi, potLo, potHi;

  /// スカウトを送って幅を狭めたか。
  bool scouted;

  /// 指名したチーム(まだなら null)。
  int? pickedBy;

  int get mid => ((ovrLo + ovrHi) / 2 * 0.45 + (potLo + potHi) / 2 * 0.55).round();

  Map<String, dynamic> toJson() => {
        'p': player.toJson(),
        'ol': ovrLo,
        'oh': ovrHi,
        'pl': potLo,
        'ph': potHi,
        if (scouted) 's': true,
        if (pickedBy != null) 'by': pickedBy,
      };

  static Prospect fromJson(Map<String, dynamic> j) => Prospect(
        player: Player.fromJson(Map<String, dynamic>.from(j['p'] as Map)),
        ovrLo: j['ol'] as int,
        ovrHi: j['oh'] as int,
        potLo: j['pl'] as int,
        potHi: j['ph'] as int,
        scouted: (j['s'] as bool?) ?? false,
        pickedBy: j['by'] as int?,
      );
}

/// 見える幅を作る。真ん中は本当の値から少しずれる(幅の中のどこに本当の値があるかは分からない)。
(int, int) _range(Rng rng, int truth, int half) {
  final shift = rng.nextInt(half + 1) * (rng.chance(0.5) ? 1 : -1);
  final lo = truth - half + shift, hi = truth + half + shift;
  // 本当の値は必ず幅の中に入れる
  return (math.min(lo, truth).clamp(30, 99), math.max(hi, truth).clamp(30, 99));
}

/// その年の候補を作る(指名の数より多め)。
/// [name] を渡すと、その名前の作り方を使う(リーグの中で重ならないように)。
List<Prospect> makeProspects(Rng rng, int Function() nextId, int count, {String Function()? name}) {
  final list = <Prospect>[];
  for (var i = 0; i < count; i++) {
    // 上位の候補ほど伸びしろが大きい。たまに隠れた逸材がいる
    final tier = i < 5 ? 0 : i < 18 ? 1 : 2;
    final age = 19 + rng.nextInt(4);
    var ovr = [58, 52, 46][tier] + rng.nextInt(9);
    var pot = ovr + [22, 18, 12][tier] + rng.nextInt(10) - (age - 19) * 2;
    if (rng.chance(0.08)) pot += 10;
    ovr = ovr.clamp(40, 70);
    pot = pot.clamp(ovr + 3, 95);
    final p = Player(
      id: nextId(),
      name: name?.call() ?? randomName(rng),
      pos: Pos.values[rng.nextInt(Pos.values.length)],
      age: age,
      ovr: ovr,
      pot: pot,
      salary: minSalary,
      years: 2,
    );
    final (ol, oh) = _range(rng, ovr, 7);
    final (pl, ph) = _range(rng, pot, 11);
    list.add(Prospect(player: p, ovrLo: ol, ovrHi: oh, potLo: pl, potHi: ph));
  }
  rng.shuffle(list);
  return list;
}

/// スカウトを送る。幅が狭まる。
void scout(Prospect p, Rng rng) {
  if (p.scouted) return;
  p.scouted = true;
  final (ol, oh) = _range(rng, p.player.ovr, 2);
  final (pl, ph) = _range(rng, p.player.pot, 4);
  p
    ..ovrLo = ol
    ..ovrHi = oh
    ..potLo = pl
    ..potHi = ph;
}

/// 新人の年俸(何番目の指名か、0始まり)。1巡目は3年、2巡目は2年。
(int, int) rookieContract(int overall) {
  if (overall < teamDefs.length) {
    return ((105 - overall * 2.8).round().clamp(22, 105), 3);
  }
  return (minSalary, 2);
}

/// くじの重み(シーズンの成績が悪い順)。プレーオフに出なかった14チームで、上位4つの順番を決める。
const lotteryWeights = [140, 140, 140, 125, 105, 90, 75, 60, 45, 30, 20, 15, 10, 5];

/// くじで決める順番の数。
const lotteryPicks = 4;

/// ドラフトの順番(1巡目と2巡目)。くじで1〜4番を決め、残りは成績の悪い順。
/// 返すのは、指名権の並び([picks])の番号の列。
List<int> draftOrder(List<Team> teams, List<DraftPick> picks, int season, List<int> playoffTeamsIdx, Rng rng) {
  // 成績の悪い順
  final worst = standings(teams).reversed.map((t) => t.index).toList();
  final lottery = worst.where((i) => !playoffTeamsIdx.contains(i)).toList();
  final rest = worst.where(playoffTeamsIdx.contains).toList();
  final weights = {for (var i = 0; i < lottery.length; i++) lottery[i]: lotteryWeights[math.min(i, lotteryWeights.length - 1)]};
  final top = <int>[];
  for (var k = 0; k < lotteryPicks && weights.isNotEmpty; k++) {
    final t = rng.weighted(weights);
    top.add(t);
    weights.remove(t);
  }
  final firstRound = [...top, ...lottery.where((t) => !top.contains(t)), ...rest];
  final secondRound = [...worst];
  final order = <int>[];
  for (final (round, list) in [(1, firstRound), (2, secondRound)]) {
    for (final from in list) {
      final i = picks.indexWhere((p) => p.season == season && p.round == round && p.from == from);
      if (i >= 0) order.add(i);
    }
  }
  return order;
}

/// 相手のチームが選ぶ候補。本当の力を少しぶれて見ている。立て直し中のチームは伸びしろを重く見る。
Prospect aiDraftChoice(List<Prospect> pool, TeamMode mode, Rng rng) {
  final open = pool.where((p) => p.pickedBy == null).toList();
  Prospect? best;
  var bestScore = -1e9;
  for (final p in open) {
    final w = mode == TeamMode.rebuild ? 0.7 : mode == TeamMode.contend ? 0.45 : 0.6;
    final s = p.player.ovr * (1 - w) + p.player.pot * w + rng.nextInt(9) - 4;
    if (s > bestScore) {
      bestScore = s.toDouble();
      best = p;
    }
  }
  return best!;
}
