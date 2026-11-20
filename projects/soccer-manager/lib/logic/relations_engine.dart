import '../l10n/tr.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 代理人の個性。選手との条件の交渉の厳しさが変わる。
enum AgentStyle { hardball, standard, calm }

extension AgentStyleInfo on AgentStyle {
  String get label => switch (this) {
        AgentStyle.hardball => Tr.pick('強気', 'Hardball'),
        AgentStyle.standard => Tr.pick('ふつう', 'Standard'),
        AgentStyle.calm => Tr.pick('穏やか', 'Easy-going'),
      };

  String get description => switch (this) {
        AgentStyle.hardball => Tr.pick('望む額が1割高く、離れた額だとすぐ席を立つ。手数料は8%',
            'Asks 10% more and walks out sooner. Takes an 8% fee'),
        AgentStyle.standard => Tr.pick('ふつうの交渉。手数料は5%',
            'A normal negotiation. Takes a 5% fee'),
        AgentStyle.calm => Tr.pick('望む額が5%安く、粘り強く話を聞く。手数料は4%',
            'Asks 5% less and listens for longer. Takes a 4% fee'),
      };

  /// 望む年俸に掛ける倍率。
  double get demandFactor => switch (this) {
        AgentStyle.hardball => 1.1,
        AgentStyle.standard => 1.0,
        AgentStyle.calm => 0.95,
      };

  /// 望む額のこれより下なら席を立つ。
  double get walkAwayRatio => switch (this) {
        AgentStyle.hardball => 0.8,
        AgentStyle.standard => 0.7,
        AgentStyle.calm => 0.6,
      };

  /// 代理人の手数料(移籍金に対する%)。
  int get feePercent => switch (this) {
        AgentStyle.hardball => 8,
        AgentStyle.standard => 5,
        AgentStyle.calm => 4,
      };
}

/// 選手同士の関係(仲の良い・悪い)と代理人。どれも保存せず、選手の id と
/// 人柄から毎回同じ答えを出す。
class RelationsEngine {
  const RelationsEngine._();

  static int _hash(String s) =>
      s.codeUnits.fold<int>(29, (a, c) => (a * 31 + c) % 2147483647);

  /// 選手の代理人の個性(3割が強気、2割が穏やか)。
  static AgentStyle agentOf(Player p) {
    final r = _hash('${p.id}#agent') % 10;
    if (r < 3) return AgentStyle.hardball;
    if (r < 5) return AgentStyle.calm;
    return AgentStyle.standard;
  }

  /// 仲間の輪(5つ)。同じ輪で、年の差が6以内なら仲が良い。
  static int _circle(String id) => _hash('$id#circle') % 5;

  static bool areFriends(Player a, Player b) =>
      a.id != b.id &&
      _circle(a.id) == _circle(b.id) &&
      (a.age - b.age).abs() <= 6;

  /// 仲が悪い: どちらも気性が荒く(15以上)輪が違う、または相性が悪い組
  /// (組の17に1つ)。
  static bool areAtOdds(Player a, Player b) {
    if (a.id == b.id || areFriends(a, b)) return false;
    if (a.traits.temperament >= 15 &&
        b.traits.temperament >= 15 &&
        _circle(a.id) != _circle(b.id)) {
      return true;
    }
    final key = a.id.compareTo(b.id) < 0 ? '${a.id}|${b.id}' : '${b.id}|${a.id}';
    return _hash(key) % 17 == 0;
  }

  static List<Player> friendsOf(Player p, Team team) =>
      [for (final q in team.players) if (areFriends(p, q)) q];

  static List<Player> atOddsWith(Player p, Team team) =>
      [for (final q in team.players) if (areAtOdds(p, q)) q];

  /// 節ごと: 先発に仲の良い選手がいれば機嫌が+1、仲の悪い選手が先発に
  /// いれば1人につき-1(最大-2)。先発の選手だけが対象。
  static void applyWeekly(Team team) {
    final xi = [
      for (final p in team.players)
        if (team.startingXI.contains(p.id)) p,
    ];
    for (final p in xi) {
      var d = 0;
      if (xi.any((q) => areFriends(p, q))) d += 1;
      final odds = xi.where((q) => areAtOdds(p, q)).length;
      d -= odds.clamp(0, 2);
      if (d != 0) p.happiness = (p.happiness + d).clamp(0, 100);
    }
  }

  /// 仲の良い選手が去ったときに、残った選手の機嫌が下がる量。
  static const int friendLeftPenalty = 5;
}
