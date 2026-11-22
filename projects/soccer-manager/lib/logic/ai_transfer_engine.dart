import 'dart:math';

import '../models/player.dart';
import '../models/team.dart';
import 'contract_engine.dart';
import 'lineup_utils.dart';
import 'transfer_talk_engine.dart';
import 'transfer_value.dart';
import '../l10n/tr.dart';

/// CPU のクラブどうしの移籍1件。
class AiTransferMove {
  final Player player;
  final Team from;
  final Team to;

  /// 移籍金(万円)。
  final int fee;

  /// 主力の大きな移籍か(ニュースに出す)。
  final bool headline;

  const AiTransferMove({
    required this.player,
    required this.from,
    required this.to,
    required this.fee,
    required this.headline,
  });

  /// ニュースの文言(移籍金の額は呼び出し元が整えて足す)。
  String newsWith(String feeLabel) => Tr.pick(
      '${player.name}が${from.name}から${to.name}へ移籍した(移籍金$feeLabel)。',
      '${player.name} has moved from ${from.name} to ${to.name} for $feeLabel.');
}

/// ユーザーが関与しない CPU のクラブどうしの移籍市場。
///
/// 2026-11-23 に作り直した。以前は窓の週に35%で1件だけ、移籍金なしで、
/// 動く選手もランダムだった(1つの窓でリーグ全体で数件)。実際の欧州の
/// リーグでは、1つの窓で数十件が動き、補強はクラブの弱い所を埋める形で、
/// 移籍金はクラブの資金の中で払う。
///
/// いまは窓の間は毎週、クラブの数の[movesPerClubPerWeek]倍ほどの件数を
/// 動かす。買う側は弱いポジション(人数が足りない・先発の力が低い)を選び、
/// そこを上げられる選手を他のクラブから、資金の範囲で言い値
/// ([TransferTalkEngine.askingPrice]。契約の残り年数の係数も入る)で買う。
/// 人数が膨らんだクラブは、控えを格下のクラブへ売って人数を戻す。
class AiTransferEngine {
  /// 窓の1週で、クラブの数に掛ける移籍の件数(20クラブなら約7件)。
  static const double movesPerClubPerWeek = 0.35;

  /// CPUクラブが受け入れ可能なスカッドの上限(ユーザークラブの上限と同じ)。
  /// これがないと「人気クラブ」に選手が際限なく集まってしまう。
  static const int maxSquadSize = 26;

  /// 人数がこれを超えたクラブは、控えを1人売って人数を戻す。
  static const int comfortableSquadSize = 24;

  /// これ以下の人数のクラブからは引き抜かない。
  static const int minSquadToSell = 18;

  /// 補強として見る力の幅: 今のそのポジションの先発の平均より、
  /// 1〜[maxUpgrade]だけ上の選手を狙う(届かない大物は狙わない)。
  static const int maxUpgrade = 12;

  /// ポジションごとの、先発の人数と、最低限ほしい人数。
  static const Map<PositionGroup, (int, int)> _groupNeeds = {
    PositionGroup.gk: (1, 2),
    PositionGroup.def: (4, 7),
    PositionGroup.mid: (4, 7),
    PositionGroup.att: (2, 4),
  };

  /// 資金が分からないクラブの、1つの窓の補強の資金(年俸総額の4割)。
  static int defaultBudget(Team t) =>
      (ContractEngine.weeklyWageBill(t) * 52 * 0.4).round();

  /// 窓の1週ぶんの CPU どうしの移籍を動かし、成立したものを返す。
  ///
  /// [teams]からユーザーのクラブ([userTeamId])を除いたクラブの間で動かす。
  /// [seasonProgress]は今のシーズンの進み(0〜1。契約の残りの計算に使う)。
  /// [budgetOf]はクラブが今使える補強の資金(無ければ[defaultBudget])。
  /// [canRegister]を渡すと、行き先のクラブの国の登録の決まり
  /// (SquadRegistration。国籍の枠・国内育成の枠・22歳以上の25人)で
  /// 加えられない選手は取らない。[intensity]は件数の倍率(冬の窓は少なめ)。
  /// [recentlyMoved]に入っている選手(この窓で既に動いた)は動かさず、
  /// 動かした選手をそこへ足す。[reserved]に入っている選手(ユーザーが
  /// 仮契約を結んだ選手など)も動かさない(こちらには足さない)。
  static List<AiTransferMove> runWeek(
    List<Team> teams,
    String userTeamId,
    Random random, {
    double seasonProgress = 0,
    int Function(Team club)? budgetOf,
    bool Function(Team to, Player p)? canRegister,
    double intensity = 1.0,
    Set<String>? recentlyMoved,
    Set<String> reserved = const {},
  }) {
    final moved = recentlyMoved ?? <String>{};
    final r = _Ratings();
    final cpu =
        teams.where((t) => t.id != userTeamId && t.players.isNotEmpty).toList();
    if (cpu.length < 2) return const [];
    final budgets = {
      for (final t in cpu) t.id: budgetOf?.call(t) ?? defaultBudget(t),
    };
    final expected = cpu.length * movesPerClubPerWeek * intensity;
    var target = expected.floor();
    if (random.nextDouble() < expected - target) target++;
    if (target <= 0) return const [];

    // 主力の大きな移籍の線: リーグの市場価値の上位1割。
    final values = [
      for (final t in cpu)
        for (final p in t.players) r.mv(p),
    ]..sort();
    final headlineValue = values[(values.length * 0.9).floor()];

    final moves = <AiTransferMove>[];
    final buyers = [...cpu]..shuffle(random);
    final topIds = <String, Set<String>>{};
    Set<String> topOf(Team t) => topIds.putIfAbsent(t.id, () {
          final sorted = [...t.players]
            ..sort((a, b) => r.ovr(b).compareTo(r.ovr(a)));
          return {for (final p in sorted.take(3)) p.id};
        });

    for (var i = 0; i < buyers.length * 2 && moves.length < target; i++) {
      final buyer = buyers[i % buyers.length];
      if (buyer.players.length >= maxSquadSize) continue;
      final need = _weakestGroup(buyer, random, r);
      if (need == null) continue;
      final pick = _pickSigning(
        buyer: buyer,
        group: need.$1,
        benchmark: need.$2,
        clubs: cpu,
        budget: budgets[buyer.id]!,
        seasonProgress: seasonProgress,
        random: random,
        topOf: topOf,
        canRegister: canRegister,
        moved: moved,
        reserved: reserved,
        r: r,
      );
      if (pick == null) continue;
      final (player, seller, fee) = pick;
      final key = topOf(seller).contains(player.id);
      moves.add(_move(
        player,
        seller,
        buyer,
        fee,
        random,
        r,
        headline: key || r.mv(player) >= headlineValue,
      ));
      moved.add(player.id);
      budgets[buyer.id] = budgets[buyer.id]! - fee;
      // 売った側は、売った額の一部を次の補強に回せる。
      budgets[seller.id] = budgets[seller.id]! + (fee * 0.6).round();
      topIds
        ..remove(buyer.id)
        ..remove(seller.id);

      // 人数が膨らんだら、控えを格下のクラブへ売って戻す。
      if (buyer.players.length > comfortableSquadSize &&
          moves.length < target) {
        final surplus = _sellSurplus(
          seller: buyer,
          clubs: cpu,
          budgets: budgets,
          seasonProgress: seasonProgress,
          random: random,
          canRegister: canRegister,
          moved: moved,
          reserved: reserved,
          r: r,
        );
        if (surplus != null) {
          moved.add(surplus.player.id);
          moves.add(surplus);
          topIds
            ..remove(surplus.from.id)
            ..remove(surplus.to.id);
        }
      }
    }
    return moves;
  }

  /// [t]のいちばん弱いポジションと、そこの先発の平均の総合力。
  /// 人数が足りないポジションを先に埋める。似た弱さなら、ばらつかせる。
  static (PositionGroup, int)? _weakestGroup(
      Team t, Random random, _Ratings r) {
    final byGroup = <PositionGroup, List<int>>{};
    for (final p in t.players) {
      if (p.isLoanedOut) continue;
      byGroup.putIfAbsent(p.position.group, () => []).add(r.ovr(p));
    }
    final all = [for (final l in byGroup.values) ...l]
      ..sort((a, b) => b.compareTo(a));
    if (all.isEmpty) return null;
    final eleven = all.take(11).toList();
    final teamLevel = eleven.reduce((a, b) => a + b) / eleven.length;
    final scored = <(PositionGroup, int, double)>[];
    for (final e in _groupNeeds.entries) {
      final (starters, depth) = e.value;
      final list = [...?byGroup[e.key]]..sort((a, b) => b.compareTo(a));
      final top = list.take(starters).toList();
      final level = top.isEmpty
          ? (teamLevel - 10).round()
          : (top.reduce((a, b) => a + b) / top.length).round();
      final shortage = depth - list.length;
      final score = (shortage > 0 ? 100.0 + shortage * 10 : 0.0) +
          (teamLevel - level) +
          random.nextDouble() * 4;
      scored.add((e.key, level, score));
    }
    scored.sort((a, b) => b.$3.compareTo(a.$3));
    return (scored.first.$1, scored.first.$2);
  }

  /// [group]の選手の人数。
  static int _countIn(Team t, PositionGroup group) =>
      t.players.where((p) => p.position.group == group).length;

  /// [buyer]が[group]を埋めるために買う選手・売るクラブ・移籍金。
  static (Player, Team, int)? _pickSigning({
    required Team buyer,
    required PositionGroup group,
    required int benchmark,
    required List<Team> clubs,
    required int budget,
    required double seasonProgress,
    required Random random,
    required Set<String> Function(Team) topOf,
    required Set<String> moved,
    required Set<String> reserved,
    required _Ratings r,
    bool Function(Team to, Player p)? canRegister,
  }) {
    if (budget <= 0) return null;
    final minKeep = _groupNeeds[group]!.$1 + 1;
    final candidates = <(Player, Team, int, int)>[];
    for (final seller in clubs) {
      if (seller.id == buyer.id) continue;
      if (seller.players.length <= minSquadToSell) continue;
      if (_countIn(seller, group) <= minKeep) continue;
      for (final p in seller.players) {
        if (p.position.group != group) continue;
        if (p.isLoan || p.isLoanedOut || p.isInjured) continue;
        if (moved.contains(p.id) || reserved.contains(p.id)) continue;
        final gain = r.ovr(p) - benchmark;
        if (gain < 1 || gain > maxUpgrade) continue;
        final fee = TransferTalkEngine.askingPrice(
          marketValue: r.mv(p),
          keyPlayer: topOf(seller).contains(p.id),
          starter: seller.startingXI.contains(p.id),
          contractYearsLeft:
              TransferValue.yearsLeft(p.contractYearsRemaining, seasonProgress),
          age: p.age,
          potentialGap: p.potential - r.ovr(p),
        );
        if (fee > budget) continue;
        candidates.add((p, seller, fee, gain));
      }
    }
    // 上がり幅の大きい選手ほど選ばれやすい。登録できなければ次を当たる
    // (登録の判定は重いので、選んだ候補にだけ掛ける)。
    for (var tries = 0; tries < 4 && candidates.isNotEmpty; tries++) {
      final total = candidates.fold<int>(0, (s, c) => s + c.$4 + 2);
      var r = random.nextInt(total);
      var idx = candidates.length - 1;
      for (var i = 0; i < candidates.length; i++) {
        r -= candidates[i].$4 + 2;
        if (r < 0) {
          idx = i;
          break;
        }
      }
      final c = candidates.removeAt(idx);
      if (canRegister?.call(buyer, c.$1) ?? true) return (c.$1, c.$2, c.$3);
    }
    return null;
  }

  /// [seller]の控えを1人、人数に余裕があって払えるクラブへ売る。
  static AiTransferMove? _sellSurplus({
    required Team seller,
    required List<Team> clubs,
    required Map<String, int> budgets,
    required double seasonProgress,
    required Random random,
    required Set<String> moved,
    required Set<String> reserved,
    required _Ratings r,
    bool Function(Team to, Player p)? canRegister,
  }) {
    final bench = seller.players
        .where((p) =>
            !seller.startingXI.contains(p.id) &&
            !p.isLoan &&
            !p.isLoanedOut &&
            !moved.contains(p.id) &&
            !reserved.contains(p.id) &&
            _countIn(seller, p.position.group) >
                _groupNeeds[p.position.group]!.$2)
        .toList()
      ..sort((a, b) => r.ovr(a).compareTo(r.ovr(b)));
    if (bench.isEmpty) return null;
    final player = bench.first;
    final fee = TransferTalkEngine.askingPrice(
      marketValue: r.mv(player),
      keyPlayer: false,
      starter: false,
      contractYearsLeft: TransferValue.yearsLeft(
          player.contractYearsRemaining, seasonProgress),
      age: player.age,
      potentialGap: player.potential - r.ovr(player),
    );
    final destinations = clubs
        .where((t) =>
            t.id != seller.id &&
            t.players.length < comfortableSquadSize - 1 &&
            r.level(t) <= r.ovr(player) + 3 &&
            budgets[t.id]! >= fee)
        .toList()
      ..shuffle(random);
    for (final to in destinations.take(4)) {
      if (!(canRegister?.call(to, player) ?? true)) continue;
      budgets[to.id] = budgets[to.id]! - fee;
      budgets[seller.id] = budgets[seller.id]! + (fee * 0.6).round();
      return _move(player, seller, to, fee, random, r, headline: false);
    }
    return null;
  }

  /// [player]を[from]から[to]へ移す。
  static AiTransferMove _move(
    Player player,
    Team from,
    Team to,
    int fee,
    Random random,
    _Ratings r, {
    required bool headline,
  }) {
    from.players.remove(player);
    final wasStarter = from.startingXI.remove(player.id);
    if (from.captainId == player.id) from.captainId = null;
    if (from.viceCaptainId == player.id) from.viceCaptainId = null;
    if (from.penaltyTakerId == player.id) from.penaltyTakerId = null;
    if (from.freeKickTakerId == player.id) from.freeKickTakerId = null;
    if (from.cornerTakerId == player.id) from.cornerTakerId = null;
    if (from.manMarkerId == player.id) from.manMarkerId = null;
    if (from.setPieceDefenderId == player.id) from.setPieceDefenderId = null;
    if (wasStarter) LineupUtils.autoFill(from);
    to.players.add(player);
    player.isTransferListed = false;
    // 新しいクラブとの契約(18歳未満は3年まで)。
    ContractEngine.applyCpuClubContract(player, 2 + random.nextInt(3));
    // 移籍直後の不満度は、元クラブでの状態からの落差(環境変化)を軽く
    // 反映しつつ、より力のあるクラブへの移籍ならやや上向きにする。
    final moveUp = r.level(to) >= r.level(from);
    player.happiness = (player.happiness + (moveUp ? 8 : -8)).clamp(40, 90);
    return AiTransferMove(
      player: player,
      from: from,
      to: to,
      fee: fee,
      headline: headline,
    );
  }
}

/// 1週の処理のあいだ、選手の総合力と市場価値を覚えておく(どちらも
/// 能力から毎回計算する重い値で、同じ選手を何度も見るため)。
class _Ratings {
  final _ovr = Map<Player, int>.identity();
  final _mv = Map<Player, int>.identity();

  int ovr(Player p) => _ovr[p] ??= p.overall;
  int mv(Player p) => _mv[p] ??= p.marketValue;

  /// クラブの力(選手の総合力の平均。[Team.overallRating]と同じ)。
  int level(Team t) {
    if (t.players.isEmpty) return t.overallRating;
    final sum = t.players.fold<int>(0, (s, p) => s + ovr(p));
    return (sum / t.players.length).round();
  }
}
