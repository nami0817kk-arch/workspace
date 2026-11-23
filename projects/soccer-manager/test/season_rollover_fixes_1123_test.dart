import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/pre_contract.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2026-11-23: 季の切り替え・買い直しで残っていた6件(CPU の先発の欠け・
/// 貸し出しの印・順位の決め方・補充の選手の国籍・自クラブの先発の欠け)を
/// 直した挙動を固定する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> start({LeagueTheme? theme}) async {
    final gs = GameState();
    if (theme == null) {
      await gs.startNewGame('修正FC');
    } else {
      await gs.startNewGame('修正FC', theme: theme);
    }
    return gs;
  }

  /// 季の切り替えの直前(5月31日)にして、季を進める。
  Future<void> rollOver(GameState gs) async {
    final s = gs.save!;
    s.today = DateTime(Player.contractClockYear, 5, 31);
    s.preContractOpenedSeason = s.league.season;
    s.optionDeadlineSeason = s.league.season;
    await gs.startNextSeason();
  }

  List<Team> worldTeams(SaveGame s) => [
        ...s.allTeams,
        for (final l in s.foreignLeagues.values) ...l.teams,
      ];

  /// 先発のうち、名簿にいる選手の数。
  int presentStarters(Team t) {
    final ids = {for (final p in t.players) p.id};
    return t.startingXI.where(ids.contains).length;
  }

  group('1. CPU のクラブは季の切り替えの後も先発11人で戦う', () {
    test('引退・30歳以上の入れ替えの後に先発を組み直す', () {
      for (var round = 0; round < 10; round++) {
        final team = PlayerGenerator.generateSquad(
            id: 'cpu$round', name: 'CPU$round', strengthTier: 55);
        for (final p in team.players) {
          p.age = 34;
        }
        LineupUtils.autoFill(team);
        expect(presentStarters(team), 11);
        RetirementEngine.resolveAndReplaceForCpu(team);
        expect(team.startingXI.length, 11, reason: 'round $round');
        expect(presentStarters(team), 11, reason: 'round $round');
      }
    });

    test('季を進めた後、自国・他国の CPU のクラブの先発は11人', () async {
      final gs = await start();
      await rollOver(gs);
      final s = gs.save!;
      for (final t in worldTeams(s)) {
        if (t.id == s.userTeamId || t.players.length < 11) continue;
        expect(presentStarters(t), 11, reason: t.name);
      }
    });

    test('安全網: 試合の前に、欠けた CPU の先発を埋める', () async {
      final gs = await start();
      final s = gs.save!;
      gs.debugTopUpCpuLineups();
      final cpus = s.league.teams.where((t) => t.id != s.userTeamId).toList();
      final cpu = cpus[0];
      final hurt = cpus[1];
      final keep = cpus[2];
      // 再現: 名簿から居なくなった2人が先発に残っている。
      cpu.startingXI = [...cpu.startingXI.take(9), 'gone1', 'gone2'];
      // 再現: 先発の1人がケガをしている(10人で戦っていた)。
      final injured =
          hurt.players.firstWhere((p) => p.id == hurt.startingXI.first);
      injured.injuryWeeks = 3;
      final keepXI = [...keep.startingXI];
      expect(presentStarters(cpu), 9);
      gs.debugTopUpCpuLineups();
      expect(presentStarters(cpu), 11);
      expect(hurt.startingXI.length, 11);
      expect(hurt.startingXI, isNot(contains(injured.id)));
      // 欠けていないクラブの先発は動かさない。
      expect(keep.startingXI, keepXI);
    });
  });

  group('2. 貸し出し中に契約が切れた選手は、印を消してから出ていく', () {
    test('所属なしへ・仮契約の先へ移る選手に「貸し出し中」が残らない', () async {
      final gs = await start();
      final s = gs.save!;
      final clock = Player.contractClockYear;
      final team = gs.userTeam;
      final bench = team.players
          .where((p) => !team.startingXI.contains(p.id) && !p.isLoan)
          .take(2)
          .toList();
      expect(bench.length, 2);
      for (final p in bench) {
        p
          ..age = 25
          ..contractEndYear = clock
          ..contractOption = false
          ..loanedOutWeeksRemaining = 30
          ..loanedOutUntil = DateTime(clock + 1, 1, 31)
          ..loanedOutToClubName = '貸出先FC'
          ..loanStartOverall = p.overall;
        expect(p.isLoanedOut, isTrue);
      }
      final toFree = bench[0];
      final toClub = bench[1];
      final dest = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
      s.preContracts.add(PreContract(
        playerId: toClub.id,
        playerName: toClub.name,
        fromClubId: s.userTeamId,
        fromClubName: s.clubName,
        toClubId: dest.id,
        toClubName: dest.name,
        wage: toClub.wage,
        endYear: clock + 3,
        option: false,
        signedOn: DateTime(clock, 2, 1),
      ));
      s.freeAgents.clear();

      await rollOver(gs);

      expect(gs.userTeam.players, isNot(contains(toFree)));
      expect(gs.userTeam.players, isNot(contains(toClub)));
      expect(dest.players, contains(toClub));
      expect(s.freeAgents, contains(toFree));
      for (final p in bench) {
        expect(p.isLoanedOut, isFalse, reason: p.name);
        expect(p.loanedOutUntil, isNull);
        expect(p.loanedOutToClubName, isNull);
        expect(p.loanStartOverall, 0);
      }
      // 「ローンから復帰」とは知らせない(出ていく選手なので)。
      expect(gs.lastLoanReturns, isNot(contains(toFree.name)));
      expect(gs.lastContractExpirations, contains(toFree.name));
    });
  });

  group('3. 買い直しの後、手放したクラブの貸し借りが残らない', () {
    test('貸していた選手は戻り、借りていた選手は貸し元へ戻る', () async {
      final gs = await start();
      final s = gs.save!;
      final old = gs.userTeam;
      final oldId = old.id;
      final target = gs.buyoutCandidates.first;
      final parent =
          s.league.teams.firstWhere((t) => t.id != oldId && t.id != target.id);
      final out = old.players.firstWhere((p) => !p.isLoan);
      out
        ..loanedOutWeeksRemaining = 20
        ..loanedOutUntil = DateTime(Player.contractClockYear, 5, 31)
        ..loanedOutToClubName = '貸出先FC'
        ..loanStartOverall = out.overall;
      old.startingXI.remove(out.id);
      Player borrowed(Team from, String name) {
        final p = Player.fromJson({
          ...PlayerGenerator.generate(position: Position.st, strengthTier: 50)
              .toJson(),
          'name': name,
        })
          ..isLoan = true
          ..loanFromClubId = from.id
          ..loanBaseWage = 100
          ..wage = 60
          ..loanEndDate = DateTime(Player.contractClockYear, 6, 30);
        old.players.add(p);
        return p;
      }

      final fromParent = borrowed(parent, 'テスト借用A');
      final fromTarget = borrowed(target, 'テスト借用B');
      old.startingXI[0] = fromParent.id;

      s
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      expect(await gs.buyClub(target.id), isTrue);
      expect(s.userTeamId, target.id);

      final former = s.league.teams.firstWhere((t) => t.id == oldId);
      expect(former.players.where((p) => p.isLoanedOut), isEmpty);
      expect(former.players.where((p) => p.isLoan), isEmpty);
      expect(former.players, contains(out));
      expect(out.loanedOutToClubName, isNull);
      expect(parent.players, contains(fromParent));
      expect(fromParent.isLoan, isFalse);
      expect(fromParent.wage, 100);
      expect(gs.userTeam.players, contains(fromTarget));
      expect(fromTarget.isLoan, isFalse);
      expect(presentStarters(former), 11);
      expect(former.startingXI, isNot(contains(fromParent.id)));
    });
  });

  group('4. 季の切り替えで、順位の決め方(得失点差が先か)が保たれる', () {
    for (final theme in [LeagueTheme.england, LeagueTheme.spain]) {
      test(theme.name, () async {
        final gs = await start(theme: theme);
        final s = gs.save!;
        expect(s.league.goalDiffFirst, theme.goalDifferenceFirst);
        await rollOver(gs);
        expect(s.league.goalDiffFirst, theme.goalDifferenceFirst);
        for (final l in s.otherDivisionLeagues) {
          if (l == null) continue;
          expect(l.goalDiffFirst, theme.goalDifferenceFirst);
        }
        expect(s.foreignLeagues, isNotEmpty);
        for (final e in s.foreignLeagues.entries) {
          final t = LeagueTheme.values.firstWhere((x) => x.name == e.key);
          expect(e.value.goalDiffFirst, t.goalDifferenceFirst, reason: e.key);
        }
      });
    }
  });

  group('5. 季の切り替えで作った選手の名前・国籍・印は、読み込み直しても同じ', () {
    test('export → import で変わらない', () async {
      final gs = await start();
      final s = gs.save!;
      final before = {
        for (final t in worldTeams(s))
          for (final p in t.players) p.id,
      };
      await rollOver(gs);
      final s1 = gs.save!;
      final recruits = [
        for (final t in worldTeams(s1))
          if (t.id != s1.userTeamId)
            for (final p in t.players)
              if (!before.contains(p.id)) p,
      ];
      expect(recruits, isNotEmpty);
      for (final p in recruits) {
        expect(p.nation, isNotNull, reason: p.name);
      }
      String key(Player p) => '${p.name}|${p.nation}|${p.homegrown}';
      final snapshot = {
        for (final t in worldTeams(s1))
          for (final p in t.players) p.id: key(p),
      };
      int homegrownOf(SaveGame save) => save.league.teams
          .expand((t) => t.players)
          .where((p) => p.homegrown)
          .length;
      final homegrown = homegrownOf(s1);

      final gs2 = GameState();
      expect(await gs2.importSaveJson(gs.exportSaveJson()!), isTrue);
      final s2 = gs2.save!;
      final after = {
        for (final t in worldTeams(s2))
          for (final p in t.players) p.id: key(p),
      };
      for (final e in snapshot.entries) {
        expect(after[e.key], e.value, reason: e.key);
      }
      expect(homegrownOf(s2), homegrown);
    });
  });

  group('6. 季の切り替え直後、自クラブの先発は11人', () {
    test('先発の選手が契約満了で抜けても、空いた枠が埋まる', () async {
      final gs = await start();
      final clock = Player.contractClockYear;
      final team = gs.userTeam;
      final byId = {for (final p in team.players) p.id: p};
      final leaving = team.startingXI.take(3).map((id) => byId[id]!).toList();
      for (final p in leaving) {
        p
          ..contractEndYear = clock
          ..contractOption = false;
      }
      final stay = team.startingXI.skip(3).toList();
      await rollOver(gs);
      final after = gs.userTeam;
      for (final p in leaving) {
        expect(after.players, isNot(contains(p)));
      }
      expect(after.startingXI.length, 11);
      expect(presentStarters(after), 11);
      // 残った先発は動かさない(空いた枠だけを埋める)。
      final remaining =
          stay.where((id) => after.players.any((p) => p.id == id)).toList();
      expect(after.startingXI, containsAll(remaining));
    });
  });
}
