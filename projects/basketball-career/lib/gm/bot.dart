import 'career.dart';
import 'draft.dart';
import 'player.dart';

/// 自動で任期を進めるGM(釣り合いを測る・テスト用)。
///
/// [trades] が false なら、トレードは一切しない素朴な遊び方。true なら、届いた申し込みを自分の見方で得なときだけ受ける。
void botStep(Career c, {bool trades = false, bool scouting = true}) {
  switch (c.phase) {
    case Phase.preseason:
      _fillRoster(c);
      c.startSeason();
      if (c.phase == Phase.preseason) {
        // 始められない(人数が多すぎる・年俸が高すぎる)なら、力の低い順に放す
        final worst = c.me.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
        c.release(worst.id);
      }
    case Phase.season:
      final o = c.incoming;
      if (o != null && trades) {
        final give = c.me.roster.where((p) => o.give.contains(p.id)).fold(0, (s, p) => s + p.ovr);
        final get = c.teams[o.partner].roster.where((p) => o.get.contains(p.id)).fold(0, (s, p) => s + p.ovr);
        if (get >= give) c.acceptIncoming();
      }
      c.playBlock();
    case Phase.playoffs:
      c.playPlayoffs();
    case Phase.seasonEnd:
      // 任期に上限は無いので、釣り合いを測る・テストでは careerSeasons 年で打ち切る
      if (c.history.length >= careerSeasons) {
        c.endCareer();
      } else {
        c.toOffseason();
      }
    case Phase.draft:
      if (c.myTurn) {
        final open = c.prospects.where((p) => p.pickedBy == null).toList()..sort((a, b) => b.mid.compareTo(a.mid));
        if (scouting) {
          for (final p in open.take(3)) {
            c.scoutProspect(p);
          }
          open.sort((a, b) => b.mid.compareTo(a.mid));
        }
        if (!c.canDraftPick) {
          c.passPick();
        } else {
          c.pickProspect(open.first);
        }
      }
    case Phase.contracts:
      for (final id in [...c.expiring]) {
        final p = c.me.roster.firstWhere((x) => x.id == id);
        if (p.ovr >= 62 && c.resignProblem(p) == null) {
          c.resign(id, c.askOf(p, c.me).maxYears);
        } else {
          c.letGo(id);
        }
      }
      // 空きがあれば、いちばん力の高い自由契約の選手を取る
      for (final p in [...c.freeAgents]) {
        if (c.me.roster.length >= 13) break;
        if (p.ovr < 60) continue;
        if (c.signProblem(p) == null) {
          c.signFreeAgent(p.id, 2);
        } else if (c.bidProblem(p) == null && c.me.roster.length - c.expiring.length + c.bids.values.where((l) => l.any((b) => b.team == c.mine)).length < 13) {
          c.bid(p.id, 2, 1.0);
        }
      }
      c.finishContracts();
    case Phase.over:
      break;
  }
}

void _fillRoster(Career c) {
  while (c.me.roster.length < minRoster) {
    final cheap = c.freeAgents.where((p) => c.signProblem(p) == null).toList();
    if (cheap.isEmpty) return;
    c.signFreeAgent(cheap.first.id, 1);
  }
}

/// 任期の終わりまで進める。
Career botPlayCareer(int seed, {int team = 0, bool trades = false}) {
  final c = Career.start(seed: seed, team: team);
  var guard = 0;
  while (c.phase != Phase.over && guard++ < 2000) {
    botStep(c, trades: trades);
  }
  return c;
}

/// テスト用: 候補を見える幅の真ん中で並べる。
List<Prospect> byMid(Career c) => c.prospects.where((p) => p.pickedBy == null).toList()..sort((a, b) => b.mid.compareTo(a.mid));

/// [seed] のリーグで、強さが [rank] 番目(0始まり)のチーム。
int teamAtRank(int seed, int rank) {
  final c = Career.start(seed: seed);
  // 強さが同じチームがあると順位が抜けるので、並べてから数える
  final order = [for (var i = 0; i < c.teams.length; i++) i]..sort((a, b) => c.strengthRank(a) != c.strengthRank(b) ? c.strengthRank(a) - c.strengthRank(b) : a - b);
  return order[rank];
}

/// テスト用: [seed] のリーグで、強さが [rank] 番目のチームを任されて始める。
Career careerAt(int seed, int rank) => Career.start(seed: seed, team: teamAtRank(seed, rank));
