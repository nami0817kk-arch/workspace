import 'dart:math' as math;

import 'league.dart';
import 'player.dart';

/// ドラフトの指名権。[from] のチームの順位で順番が決まり、[owner] が使う。
class DraftPick {
  DraftPick({required this.season, required this.round, required this.from, required this.owner, this.protect = 0});

  /// 何年目のシーズンのあとのドラフトか。
  final int season;
  final int round;
  final int from;
  int owner;

  /// 上位いくつまで保護されているか(0なら保護なし)。保護の範囲に入ると、指名権は [from] のチームに戻る。
  int protect;

  String when(int nowSeason) => switch (season - nowSeason) {
        0 => '今年',
        1 => '来年',
        final d => '$d年後',
      };

  String label(List<Team> teams, int nowSeason) =>
      '${when(nowSeason)} $round巡目(${teams[from].def.short})${protect > 0 ? '・上位$protect位保護' : ''}';

  Map<String, dynamic> toJson() => {'s': season, 'r': round, 'f': from, 'o': owner, if (protect > 0) 'pr': protect};

  static DraftPick fromJson(Map<String, dynamic> j) => DraftPick(
      season: j['s'] as int, round: j['r'] as int, from: j['f'] as int, owner: j['o'] as int, protect: (j['pr'] as int?) ?? 0);
}

double _curve(int ovr) {
  final x = math.max(0, ovr - 45);
  return x * x / 10;
}

/// [mode] のチームから見た、選手の値打ち。年俸が力に見合わない契約はマイナスにもなる。
double playerValue(Player p, TeamMode mode) {
  final now = _curve(p.ovr), fut = _curve(p.future);
  var v = switch (mode) {
    TeamMode.contend => 0.8 * now + 0.2 * fut,
    TeamMode.balanced => 0.55 * now + 0.45 * fut,
    TeamMode.rebuild => 0.25 * now + 0.75 * fut,
    TeamMode.cutCost => 0.5 * now + 0.5 * fut,
  };
  if (mode == TeamMode.rebuild && p.age >= 29) v *= 0.6;
  final fair = fairSalary(p.ovr, p.age);
  final yrs = math.min(math.max(p.years, 1), 3);
  final k = mode == TeamMode.cutCost ? 0.14 : 0.06;
  v += (fair - p.salary) * yrs * k;
  if (mode == TeamMode.cutCost && p.years <= 1) v += 6;
  return math.max(-60, v);
}

/// 指名権の値打ち。[slotGuess] は1〜30の見込みの順番(1がいちばん早い)。
double pickValue(DraftPick pick, TeamMode mode, int slotGuess, int nowSeason, {int? protect}) {
  var v = pick.round == 1 ? 58 - (slotGuess - 1) * 1.5 : 4.0;
  // 先の年ほど割り引く(どうなるか分からない)。遠い年は順位の見込みも真ん中に寄せる
  final years = (pick.season - nowSeason).clamp(0, 4);
  if (years >= 2 && pick.round == 1) v = (v + 58 - 14 * 1.5) / 2;
  v *= [1.0, 0.85, 0.75, 0.68, 0.62][years];
  // 保護: 保護の範囲に入りそうなら、ほとんど値打ちがない
  final pr = protect ?? pick.protect;
  if (pr > 0 && pick.round == 1) v *= slotGuess <= pr && years == 0 ? 0.15 : 1 - pr / 40;
  if (mode == TeamMode.rebuild) v *= 1.45;
  if (mode == TeamMode.contend) v *= 0.7;
  return v;
}

/// いまの強さの順から見た、そのチームの指名の見込みの順番(弱いほど早い)。
int slotGuess(List<Team> teams, int from) {
  // 強さは一度ずつだけ計算する(並べ替えの比べるたびに計算すると遅い)
  final mine = teams[from].strength;
  return teams.where((t) => t.index != from && t.strength < mine).length + 1;
}

/// トレードの中身。
class TradeOffer {
  TradeOffer({
    required this.partner,
    this.give = const [],
    this.get = const [],
    this.givePicks = const [],
    this.getPicks = const [],
    this.protections = const {},
  });

  /// 出す指名権に付ける保護(指名権の番号 → 上位いくつ)。成立すると指名権に付く。
  final Map<int, int> protections;

  final int partner;

  /// こちらが出す選手と、受け取る選手(id)。
  final List<int> give;
  final List<int> get;

  /// こちらが出す指名権と、受け取る指名権(全体の指名権の並びでの番号)。
  final List<int> givePicks;
  final List<int> getPicks;

  bool get isEmpty => give.isEmpty && get.isEmpty && givePicks.isEmpty && getPicks.isEmpty;

  Map<String, dynamic> toJson() => {
        'p': partner,
        'g': give,
        't': get,
        'gp': givePicks,
        'tp': getPicks,
        if (protections.isNotEmpty) 'pt': {for (final e in protections.entries) '${e.key}': e.value},
      };

  static TradeOffer fromJson(Map<String, dynamic> j) => TradeOffer(
        partner: j['p'] as int,
        give: [for (final x in j['g'] as List) x as int],
        get: [for (final x in j['t'] as List) x as int],
        givePicks: [for (final x in j['gp'] as List) x as int],
        getPicks: [for (final x in j['tp'] as List) x as int],
        protections: {for (final e in ((j['pt'] as Map?) ?? const {}).entries) int.parse(e.key as String): e.value as int},
      );
}

/// 相手の答え。
class TradeVerdict {
  const TradeVerdict(this.ok, this.reason, this.ratio);
  final bool ok;

  /// 断る理由(受けるなら空)。
  final String reason;

  /// 相手が受けるのに要る値打ちに、どれだけ届いているか(1以上で受ける)。
  final double ratio;
}

/// 相手が受け入れるのに要る釣り合い。相手は少し得をしないと受けない。
double requiredValue(double out) => out * 1.08 + 4;

/// 年俸の決まり。トレードのあと上限を超えるなら、受け取る年俸は出す年俸の125%＋100万ドルまでしか増やせない。
String? salaryRuleProblem(Team t, int incoming, int outgoing) {
  final after = t.payroll - outgoing + incoming;
  if (after > hardCap) return '${t.def.short}の年俸の合計が上限(${money(hardCap)})を超える';
  if (after > salaryCap && incoming > outgoing * 1.25 + 10) {
    return '${t.def.short}は年俸の上限を超えるので、受け取る年俸を出す年俸の125%までにする必要がある';
  }
  return null;
}

/// こちら([mine])からの申し込みを、相手がどう見るか。
///
/// [slots] はチームごとの指名の見込みの順番(探す間は変わらないので、先に一度だけ計算して渡せる)。
TradeVerdict judgeTrade(List<Team> teams, List<DraftPick> picks, int mine, TradeOffer o, int nowSeason, {Map<int, int>? slots}) {
  final me = teams[mine], them = teams[o.partner];
  final give = [for (final id in o.give) me.roster.firstWhere((p) => p.id == id)];
  final get = [for (final id in o.get) them.roster.firstWhere((p) => p.id == id)];
  if (o.isEmpty || (give.isEmpty && o.givePicks.isEmpty) || (get.isEmpty && o.getPicks.isEmpty)) {
    return const TradeVerdict(false, '出すものと受け取るものを、どちらも選んでください', 0);
  }
  final myAfter = me.roster.length - give.length + get.length;
  final theirAfter = them.roster.length - get.length + give.length;
  if (myAfter > maxRoster) return const TradeVerdict(false, 'こちらの登録が15人を超える', 0);
  if (theirAfter > maxRoster) return TradeVerdict(false, '${them.def.short}の登録が15人を超える', 0);
  if (theirAfter < minRoster) return TradeVerdict(false, '${them.def.short}の人数が足りなくなる', 0);
  final gs = give.fold(0, (s, p) => s + p.salary), ts = get.fold(0, (s, p) => s + p.salary);
  final mine1 = salaryRuleProblem(me, ts, gs);
  if (mine1 != null) return TradeVerdict(false, mine1, 0);
  final theirs = salaryRuleProblem(them, gs, ts);
  if (theirs != null) return TradeVerdict(false, theirs, 0);
  final mode = them.mode;
  var inV = give.fold(0.0, (s, p) => s + playerValue(p, mode));
  var outV = get.fold(0.0, (s, p) => s + playerValue(p, mode));
  for (final i in o.givePicks) {
    inV += pickValue(picks[i], mode, slots?[picks[i].from] ?? slotGuess(teams, picks[i].from), nowSeason, protect: o.protections[i]);
  }
  for (final i in o.getPicks) {
    outV += pickValue(picks[i], mode, slots?[picks[i].from] ?? slotGuess(teams, picks[i].from), nowSeason);
  }
  final need = requiredValue(outV);
  final ratio = need <= 0 ? 2.0 : inV / need;
  if (ratio >= 1) return TradeVerdict(true, '', ratio);
  return TradeVerdict(false, ratio >= 0.8 ? 'あと少し足りない' : ratio >= 0.5 ? '釣り合っていない' : '話にならない', ratio);
}

/// 申し込みを成立させる(選手と指名権を入れ替える)。
void applyTrade(List<Team> teams, List<DraftPick> picks, int mine, TradeOffer o) {
  final me = teams[mine], them = teams[o.partner];
  final give = [for (final id in o.give) me.roster.firstWhere((p) => p.id == id)];
  final get = [for (final id in o.get) them.roster.firstWhere((p) => p.id == id)];
  me.roster
    ..removeWhere(give.contains)
    ..addAll(get);
  them.roster
    ..removeWhere(get.contains)
    ..addAll(give);
  for (final i in o.givePicks) {
    picks[i].owner = o.partner;
    final pr = o.protections[i];
    if (pr != null && picks[i].round == 1) picks[i].protect = pr;
  }
  for (final i in o.getPicks) {
    picks[i].owner = mine;
  }
}

/// 相手から届く申し込みを作る。相手が欲しい選手を1人選び、相手の見方で少し得になる組み合わせを返す。作れなければ null。
TradeOffer? makeIncomingOffer(List<Team> teams, List<DraftPick> picks, int mine, int partner, int nowSeason) {
  final me = teams[mine], them = teams[partner];
  final mode = them.mode;
  final wanted = [...me.roster]..sort((a, b) => playerValue(b, mode).compareTo(playerValue(a, mode)));
  // いちばんの選手ではなく、2〜5番目あたりを狙う(主力を毎回取りに来ないように)
  for (final target in wanted.skip(1).take(4)) {
    final tv = playerValue(target, mode);
    if (tv < 15) continue;
    // 相手は、受け取る値打ちの8割前後で出せる選手を探す
    final pool = [...them.roster]..sort((a, b) => playerValue(b, mode).compareTo(playerValue(a, mode)));
    for (final cand in pool) {
      final cv = playerValue(cand, mode);
      if (cv > tv * 0.92 || cv < tv * 0.55) continue;
      final o = TradeOffer(partner: partner, give: [target.id], get: [cand.id]);
      final v = judgeTrade(teams, picks, mine, o, nowSeason);
      if (v.ok) return o;
    }
  }
  return null;
}

/// [from] のチームから見た、出すものの惜しさ(小さいほど出しやすい)。
double _cost(List<Team> teams, List<DraftPick> picks, int from, Object asset, int nowSeason, Map<int, int> slots) {
  final mode = teams[from].mode;
  if (asset is Player) return playerValue(asset, mode).clamp(0.5, 1e9);
  final i = asset as int;
  return pickValue(picks[i], mode, slots[picks[i].from]!, nowSeason);
}

/// 相手([partner])から [get] と [getPicks] を受け取るのに、[from] が出せばよい組み合わせを探す(「相手に聞く」)。
/// 出すものは、[from] から見て惜しくない順に、1つ・2つ・3つの組み合わせを試す。[exclude] の選手は出さない。見つからなければ null。
TradeOffer? findPackage(List<Team> teams, List<DraftPick> picks, int from, int partner,
    {required List<int> get, List<int> getPicks = const [], List<int> exclude = const [], required int nowSeason}) {
  final me = teams[from];
  final assets = <Object>[
    ...me.roster.where((p) => !exclude.contains(p.id)),
    for (var i = 0; i < picks.length; i++)
      if (picks[i].owner == from) i,
  ];
  if (assets.isEmpty) return null;
  final st = {for (final t in teams) t.index: t.strength};
  final slots = {for (final t in teams) t.index: teams.where((u) => st[u.index]! < st[t.index]!).length + 1};
  final cost = {for (final a in assets) a: _cost(teams, picks, from, a, nowSeason, slots)};
  assets.sort((a, b) => cost[a]!.compareTo(cost[b]!));
  TradeOffer offerOf(List<Object> give) => TradeOffer(
        partner: partner,
        give: [for (final a in give) if (a is Player) a.id],
        givePicks: [for (final a in give) if (a is int) a],
        get: get,
        getPicks: getPicks,
      );
  TradeOffer? best;
  var bestCost = double.infinity;
  void tryGive(List<Object> give) {
    final c = give.fold(0.0, (s, a) => s + cost[a]!);
    if (c >= bestCost) return;
    final o = offerOf(give);
    if (judgeTrade(teams, picks, from, o, nowSeason, slots: slots).ok) {
      best = o;
      bestCost = c;
    }
  }

  // 1つなら全部を試す。2つ・3つの組み合わせは、膨らまないように惜しくない順の10個までで
  for (final a in assets) {
    tryGive([a]);
  }
  final small = assets.take(10).toList();
  for (var i = 0; i < small.length; i++) {
    for (var j = i + 1; j < small.length; j++) {
      tryGive([small[i], small[j]]);
    }
  }
  if (best == null) {
    for (var i = 0; i < small.length; i++) {
      for (var j = i + 1; j < small.length; j++) {
        for (var k = j + 1; k < small.length; k++) {
          tryGive([small[i], small[j], small[k]]);
        }
      }
    }
  }
  return best;
}
