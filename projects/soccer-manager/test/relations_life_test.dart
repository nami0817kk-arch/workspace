import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/dynamics_engine.dart';
import 'package:soccer_manager/logic/player_terms_engine.dart';
import 'package:soccer_manager/logic/relations_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 選手同士の関係・私生活の出来事・代理人の個性の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('関係', () {
    test('仲の良し悪しは対称で、自分自身とは無い', () async {
      final gs = GameState();
      await gs.startNewGame('関係FC');
      final ps = gs.userTeam.players;
      for (final a in ps) {
        expect(RelationsEngine.areFriends(a, a), isFalse);
        for (final b in ps) {
          expect(RelationsEngine.areFriends(a, b),
              RelationsEngine.areFriends(b, a));
          expect(RelationsEngine.areAtOdds(a, b),
              RelationsEngine.areAtOdds(b, a));
          if (RelationsEngine.areFriends(a, b)) {
            expect(RelationsEngine.areAtOdds(a, b), isFalse);
          }
        }
      }
      // 25人ほどいれば、仲の良い組はたいてい何組かある。
      final pairs = [
        for (final a in ps)
          for (final b in ps)
            if (a.id.compareTo(b.id) < 0 && RelationsEngine.areFriends(a, b))
              1,
      ];
      expect(pairs, isNotEmpty);
    });

    test('先発に仲の良い選手がいれば機嫌が上がる', () async {
      final gs = GameState();
      await gs.startNewGame('関係FC');
      final team = gs.userTeam;
      final xi = [
        for (final p in team.players)
          if (team.startingXI.contains(p.id)) p,
      ];
      final p = xi.firstWhere(
          (p) =>
              xi.any((q) => RelationsEngine.areFriends(p, q)) &&
              !xi.any((q) => RelationsEngine.areAtOdds(p, q)),
          orElse: () => xi.first);
      if (!xi.any((q) => RelationsEngine.areFriends(p, q))) return; // 組が無い
      p.happiness = 50;
      RelationsEngine.applyWeekly(team);
      expect(p.happiness, 51);
    });

    test('仲の良い選手を売ると、残った友人が寂しがる', () async {
      Tr.language = AppLanguage.japanese;
      addTearDown(() => Tr.language = AppLanguage.system);
      final gs = GameState();
      await gs.startNewGame('関係FC');
      final team = gs.userTeam;
      // チームリーダーを売ると別の動揺も重なるので、リーダーでない選手で見る。
      final seller = team.players.firstWhere((a) =>
          !DynamicsEngine.isTeamLeader(team, a.id) &&
          team.players.any((b) => RelationsEngine.areFriends(a, b)));
      final friend =
          team.players.firstWhere((b) => RelationsEngine.areFriends(seller, b));
      friend.happiness = 60;
      expect(await gs.sellPlayer(seller.id), isTrue);
      expect(friend.happiness, 60 - RelationsEngine.friendLeftPenalty);
      expect(gs.save!.newsLog.any((n) => n.text.contains('寂しがっている')),
          isTrue);
    });
  });

  group('私生活', () {
    test('結婚は1回だけ。結婚していれば子どもが生まれることがある', () async {
      final gs = GameState();
      await gs.startNewGame('私生活FC');
      final p = gs.userTeam.players.firstWhere((p) => p.age >= 24 && p.age <= 35);
      for (var i = 0; i < 30; i++) {
        gs.debugLifeEvent(p, year: 2027 + i);
      }
      final ev = gs.lifeEventsOf(p.id);
      expect(ev.where((e) => e == 'married').length, lessThanOrEqualTo(1));
      expect(ev.where((e) => e == 'child').length, lessThanOrEqualTo(3));
      if (ev.contains('child')) {
        expect(ev.indexOf('married'), lessThan(ev.indexOf('child')));
      }
      // 同じ年にホームシック・不幸は重ならない。
      expect(ev.toSet().length + ev.where((e) => e == 'child').length - (ev.contains('child') ? 1 : 0),
          ev.length);
    });

    test('私生活の出来事は保存して読み戻せる', () async {
      final gs = GameState();
      await gs.startNewGame('私生活FC');
      final p = gs.userTeam.players.first;
      gs.save!.lifeEvents[p.id] = ['married', 'child'];
      final copy = SaveGame.fromJson(gs.save!.toJson());
      expect(copy.lifeEvents[p.id], ['married', 'child']);
    });
  });

  group('代理人', () {
    test('強気な代理人ほど望む額が高く、早く席を立つ。手数料も高い', () {
      expect(AgentStyle.hardball.demandFactor,
          greaterThan(AgentStyle.calm.demandFactor));
      expect(AgentStyle.hardball.walkAwayRatio,
          greaterThan(AgentStyle.calm.walkAwayRatio));
      expect(AgentStyle.hardball.feePercent,
          greaterThan(AgentStyle.calm.feePercent));
      expect(
          PlayerTermsEngine.judge(
              effective: 75, demand: 100, round: 1, walkAway: 0.8),
          TermsReplyKind.walkAway);
      expect(
          PlayerTermsEngine.judge(
              effective: 75, demand: 100, round: 1, walkAway: 0.6),
          TermsReplyKind.counter);
    });

    test('代理人の個性は選手ごとに決まり、3種類とも出る', () async {
      final gs = GameState();
      await gs.startNewGame('代理人FC');
      final styles = {
        for (final t in gs.save!.allTeams)
          for (final p in t.players) RelationsEngine.agentOf(p),
      };
      expect(styles, AgentStyle.values.toSet());
      final p = gs.userTeam.players.first;
      expect(RelationsEngine.agentOf(p), RelationsEngine.agentOf(p));
    });
  });
}
