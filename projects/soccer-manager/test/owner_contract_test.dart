import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// オーナーは雇われる立場ではない(2026-11-23)。理事会との契約の満了で
/// 辞めさせられる流れは無く、任期の知らせは雇っている監督について出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 自クラブが全敗、ほかは全部引き分けで季を終わらせる(最下位)。
  void loseEverything(GameState gs) {
    final userId = gs.userTeam.id;
    for (final f in gs.save!.league.fixtures) {
      final home = f.homeTeamId == userId;
      final away = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: home ? 0 : (away ? 3 : 1),
        awayGoals: away ? 0 : (home ? 3 : 1),
        events: [],
      );
    }
  }

  test('目標を外し期待が低くても、季の終わりに契約切れで辞めさせられない', () async {
    final gs = GameState();
    await gs.startNewGame('続投FC');
    final s = gs.save!;
    s.budget = 99999999;
    s.boardTargetRank = 1;
    // 以前は契約の満了で信頼度45未満なら「解任」(信頼度0)だった。
    s.confidence = 44;
    loseEverything(gs);
    await gs.startNextSeason();

    expect(gs.saleReason, isNull, reason: '期待は残っているので手放さない');
    expect(s.confidence, greaterThan(0));
    expect(
        s.newsLog
            .any((n) => n.text.contains('解任') || n.text.contains('sacked')),
        isFalse);
    expect(
        s.newsLog.any((n) =>
            n.text.contains('理事会と2年') || n.text.contains('two-year contract')),
        isFalse);
  });

  test('雇っている監督が最後の年に入ると、名前つきで知らせる', () async {
    final gs = GameState();
    await gs.startNewGame('任期FC');
    final s = gs.save!;
    s.budget = 99999999;
    s.wageBudget = 99999999;
    if (gs.currentManager == null) {
      await gs.hireStaff(gs.staffCandidatesFor(StaffRole.manager).first.id);
    }
    final m = gs.currentManager!..contractYears = 2;
    loseEverything(gs);
    await gs.startNextSeason();
    // 季の途中で引き抜かれていれば、任期の知らせは出ない(運しだい)。
    if (gs.currentManager?.id != m.id) return;
    expect(m.contractYears, 1);
    expect(gs.lastManagerContractNote, isNotNull);
    expect(gs.lastManagerContractNote, contains(m.name));
    expect(
      s.newsLog.any((n) => n.text == gs.lastManagerContractNote),
      isTrue,
      reason: '監督の任期の知らせはニュースにも残る',
    );
  });

  test('雇っている監督の契約が切れると、去ったことを知らせる', () async {
    final gs = GameState();
    await gs.startNewGame('満了FC');
    final s = gs.save!;
    s.budget = 99999999;
    s.wageBudget = 99999999;
    if (gs.currentManager == null) {
      await gs.hireStaff(gs.staffCandidatesFor(StaffRole.manager).first.id);
    }
    final m = gs.currentManager!..contractYears = 1;
    loseEverything(gs);
    await gs.startNextSeason();
    if (s.newsLog.any(
      (n) => n.text.contains(m.name) && n.text.contains('移った'),
    )) {
      return; // 季の途中で引き抜かれた(運しだい)。
    }
    expect(gs.currentManager?.id, isNot(m.id));
    expect(gs.lastManagerContractNote, contains(m.name));
    expect(gs.saleReason, isNull, reason: '監督が去っても、オーナーは残る');
  });

  test('旧セーブに理事会との契約の値が残っていても読め、書き出しには残さない', () async {
    final gs = GameState();
    await gs.startNewGame('旧FC');
    final json = gs.save!.toJson()..['managerContractYears'] = 1;
    final restored = SaveGame.fromJson(json);
    expect(restored.clubName, gs.save!.clubName);
    expect(restored.toJson().containsKey('managerContractYears'), isFalse);
  });
}
