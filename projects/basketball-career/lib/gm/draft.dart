import 'dart:math' as math;

import 'league.dart';
import 'names.dart';
import 'player.dart';
import 'rng.dart';
import 'trade.dart';

/// ドラフトの候補。本当の力は指名するまで分からず、見えるのは幅([ovrLo]〜[ovrHi] など)だけ。
class Prospect {
  Prospect({required this.player, required this.ovrLo, required this.ovrHi, required this.potLo, required this.potHi, this.scouted = false, this.pickedBy, this.pickNo});

  final Player player;
  int ovrLo, ovrHi, potLo, potHi;

  /// スカウトを送って幅を狭めたか。
  bool scouted;

  /// 指名したチーム(まだなら null)。
  int? pickedBy;

  /// 何番目の指名で取られたか(1始まり。まだなら null)。
  int? pickNo;

  int get mid => ((ovrLo + ovrHi) / 2 * 0.45 + (potLo + potHi) / 2 * 0.55).round();

  Map<String, dynamic> toJson() => {
        'p': player.toJson(),
        'ol': ovrLo,
        'oh': ovrHi,
        'pl': potLo,
        'ph': potHi,
        if (scouted) 's': true,
        if (pickedBy != null) 'by': pickedBy,
        if (pickNo != null) 'no': pickNo,
      };

  static Prospect fromJson(Map<String, dynamic> j) => Prospect(
        player: Player.fromJson(Map<String, dynamic>.from(j['p'] as Map)),
        ovrLo: j['ol'] as int,
        ovrHi: j['oh'] as int,
        potLo: j['pl'] as int,
        potHi: j['ph'] as int,
        scouted: (j['s'] as bool?) ?? false,
        pickedBy: j['by'] as int?,
        pickNo: j['no'] as int?,
      );
}

// ---------------------------------------------------------------- 候補の情報(試合の乱数は使わない。id から決める)

/// id から決まる 0〜[n]-1 の数(同じ候補なら何度見ても同じ)。
int _idBits(Prospect p, int salt, int n) => (((p.player.id * 2654435761) ^ (salt * 40503)) & 0x7FFFFFFF) % n;

/// 経歴。年齢に合わせて、大学の学年か海外のリーグ。
String backgroundOf(Prospect p) {
  final age = p.player.age;
  if (_idBits(p, 1, 100) < 18) return '海外のプロリーグ';
  return '大学${(age - 18).clamp(1, 4)}年';
}

/// コンバイン(身体測定)。垂直跳び(cm)と、コートの4分の3を走る時間(秒)。運動能力が高いほど良い。
({int vertical, double sprint}) combineOf(Prospect p) {
  final ath = p.player.attr(Attr.athletic);
  final big = p.player.pos.big ? 1 : 0;
  final vertical = (58 + (ath - 50) * 0.55 - big * 4 + _idBits(p, 2, 9) - 4).round().clamp(45, 100);
  final sprint = (3.55 - (ath - 50) * 0.008 + big * 0.08 + (_idBits(p, 3, 11) - 5) * 0.01).clamp(3.0, 3.8);
  return (vertical: vertical, sprint: double.parse(sprint.toStringAsFixed(2)));
}

/// 去年の成績(大学か海外。1試合あたり)。力が高いほど良いが、ぶれる。
({double ppg, double rpg, double apg}) amateurStatsOf(Prospect p) {
  final pl = p.player;
  double v(int salt, double base, double k, Attr a) => (base + (pl.attr(a) - 50) * k + (_idBits(p, salt, 21) - 10) * 0.25).clamp(0.5, 35.0);
  final pts = v(4, 9, 0.42, pl.attr(Attr.outside) > pl.attr(Attr.inside) ? Attr.outside : Attr.inside);
  final reb = v(5, pl.pos.big ? 6 : 3, pl.pos.big ? 0.18 : 0.08, Attr.rebound);
  final ast = v(6, pl.pos.guard ? 3.5 : 1.2, pl.pos.guard ? 0.14 : 0.05, Attr.passing);
  return (ppg: double.parse(pts.toStringAsFixed(1)), rpg: double.parse(reb.toStringAsFixed(1)), apg: double.parse(ast.toStringAsFixed(1)));
}

/// 得意と苦手(能力のずれの大きい2つと小さい1つ)。スカウトしたあとだけ見せる。
(List<Attr>, Attr) strengthsOf(Player p) {
  final order = [...Attr.values]..sort((a, b) => p.attrs[b.index].compareTo(p.attrs[a.index]));
  return (order.take(2).toList(), order.last);
}

/// 世間の見立ての点(本当の力に、評判のぶれを足す)。模擬ドラフトの順はこの順。
/// 自分のスカウトでは変わらない(世間の見立てなので)。ぶれは±8あるので、予想の上の候補が本当に上とは限らない。
int consensusOf(Prospect p) => (p.player.ovr * 0.45 + p.player.pot * 0.55).round() + _idBits(p, 7, 17) - 8;

/// 模擬ドラフトの予想順位(残っている候補の中で、1始まり)。
Map<Prospect, int> mockRanks(List<Prospect> pool) {
  final open = pool.where((p) => p.pickedBy == null).toList()..sort((a, b) => consensusOf(b).compareTo(consensusOf(a)));
  return {for (var i = 0; i < open.length; i++) open[i]: i + 1};
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
/// ドラフトの層を厚くする候補の数(指名の数＋8人に足す。合わせて約100人)。
const deepProspects = 32;

/// [deep] なら、どれも下の層(2巡目の後半〜指名されない層。たまに隠れた逸材)。
List<Prospect> makeProspects(Rng rng, int Function() nextId, int count, {String Function()? name, bool deep = false}) {
  final list = <Prospect>[];
  for (var i = 0; i < count; i++) {
    // 上位の候補ほど伸びしろが大きい。たまに隠れた逸材がいる
    final tier = deep ? 3 : i < 5 ? 0 : i < 18 ? 1 : 2;
    final age = 19 + rng.nextInt(4);
    var ovr = [58, 52, 46, 42][tier] + rng.nextInt(9);
    var pot = ovr + [22, 18, 12, 10][tier] + rng.nextInt(10) - (age - 19) * 2;
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

/// 新人の年俸と年数(何番目の指名か、0始まり)。1巡目は4年(最後の2年はチームの選択権、年俸は指名順)、2巡目は2年。
/// 1番目で1,400万ドル、30番目で360万ドルほど(2025-26 の実際の新人の年俸の表に近い)。
(int, int) rookieContract(int overall) {
  if (overall < teamDefs.length) {
    return ((140 - overall * 3.6).round().clamp(35, 140), 4);
  }
  return (minSalary, 2);
}

/// 新人の契約のうち、チームの選択権の年数(1巡目は最後の2年)。
int rookieOptionYears(int overall) => overall < teamDefs.length ? 2 : 0;

/// くじの重み(シーズンの成績が悪い順)。プレーオフに出なかった14チームで、上位4つの順番を決める。
const lotteryWeights = [140, 140, 140, 125, 105, 90, 75, 60, 45, 30, 20, 15, 10, 5];

/// くじで決める順番の数。
const lotteryPicks = 4;

/// 直前の [draftOrder] で、保護のために元のチームへ戻った指名権(番号)。
final conveyedBack = <int>[];

/// いまの順位のままならの、くじで全体1位を引く見込み(チームの番号 → 0〜1)。
/// 地区の上位8つ(6位までとプレーインの勝ち抜けの見込み)を除いた14チームで、成績の悪い順に重みを付ける。
Map<int, double> lotteryOdds(List<Team> teams) {
  final inPo = {
    for (final east in [true, false]) ...standings(teams, east: east).take(8).map((t) => t.index),
  };
  final lottery = standings(teams).reversed.map((t) => t.index).where((i) => !inPo.contains(i)).toList();
  final total = [for (var i = 0; i < lottery.length; i++) lotteryWeights[math.min(i, lotteryWeights.length - 1)]].fold(0, (a, b) => a + b);
  return {for (var i = 0; i < lottery.length; i++) lottery[i]: lotteryWeights[math.min(i, lotteryWeights.length - 1)] / total};
}

/// ドラフトの順番(1巡目と2巡目)。くじで1〜4番を決め、残りは成績の悪い順。
/// 返すのは、指名権の並び([picks])の番号の列。
List<int> draftOrder(List<Team> teams, List<DraftPick> picks, int season, List<int> playoffTeamsIdx, Rng rng) {
  conveyedBack.clear();
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
    for (final (k, from) in list.indexed) {
      final i = picks.indexWhere((p) => p.season == season && p.round == round && p.from == from);
      if (i < 0) continue;
      // 保護の範囲(上位 protect 位まで)に入ったら、指名権は元のチームに戻る
      final pk = picks[i];
      if (round == 1 && pk.protect > 0 && k < pk.protect && pk.owner != pk.from) {
        pk.owner = pk.from;
        conveyedBack.add(i);
      }
      order.add(i);
    }
  }
  return order;
}

/// 相手のチームが選ぶ候補。本当の力を少しぶれて見ている。立て直し中のチームは伸びしろを重く見る。
/// [counts] はそのチームのポジションごとの人数。足りないポジションの候補を少し高く見る。
Prospect aiDraftChoice(List<Prospect> pool, TeamMode mode, Rng rng, {Map<Pos, int>? counts}) {
  final open = pool.where((p) => p.pickedBy == null).toList();
  Prospect? best;
  var bestScore = -1e9;
  for (final p in open) {
    final w = mode == TeamMode.rebuild ? 0.7 : mode == TeamMode.contend ? 0.45 : 0.6;
    final have = counts?[p.player.pos] ?? 2;
    final need = have == 0 ? 6 : have == 1 ? 3 : have >= 4 ? -4 : 0;
    final s = p.player.ovr * (1 - w) + p.player.pot * w + rng.nextInt(9) - 4 + need;
    if (s > bestScore) {
      bestScore = s.toDouble();
      best = p;
    }
  }
  return best!;
}
