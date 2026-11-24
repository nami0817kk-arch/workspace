import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/policy_engine.dart';
import 'package:soccer_manager/models/budget_plan.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/state/game_state.dart';

/// オフシーズン(季の終わり〜開幕前)にだけ変えられるもの: 予算の配り方・
/// クラブの見た目・チケットの値段・クラブの方針(2026-11-25)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('開幕前はオフシーズン。1節進むとシーズン中で、4つとも変えられない', () async {
    final gs = GameState();
    await gs.startNewGame('時期FC');
    expect(gs.isOffseason, isTrue);
    expect(gs.canChangeClubLook, isTrue);
    expect(gs.canChangeClubPolicy, isTrue);

    await gs.playNextMatchdayQuickSim();
    expect(gs.isOffseason, isFalse);
    final s = gs.save!;
    final plan = s.budgetPlan.shares;
    final pricing = s.ticketPricing;
    final policy = s.clubPolicy;
    final look = gs.currentClubLook;

    expect(await gs.setBudgetPlan(BudgetPlan.youthFocus()), isFalse);
    expect(await gs.setBudgetShare(BudgetCategory.signing, 60), isFalse);
    expect(s.budgetPlan.shares, plan);
    expect(
        await gs.setTicketPricing(pricing == TicketPricing.premium
            ? TicketPricing.budget
            : TicketPricing.premium),
        isFalse);
    expect(s.ticketPricing, pricing);
    expect(gs.canChangeClubPolicy, isFalse);
    expect(await gs.setClubPolicy(ClubPolicy.values
            .firstWhere((p) => p != policy)), isFalse);
    expect(s.clubPolicy, policy);
    expect(gs.canChangeClubLook, isFalse);
    expect(await gs.setClubLook(look.copyWith(hue: (look.hue + 90) % 360)),
        isFalse);
  });

  test('最終節のあとはオフシーズン。方針は来季の分として持ち、季を越すと入れ替わる',
      () async {
    final gs = GameState();
    await gs.startNewGame('時期FC');
    await gs.setClubPolicy(ClubPolicy.balanced);
    await gs.simulateAheadMatchdays(60);
    final s = gs.save!;
    final id = s.userTeamId;
    expect(
        s.league.fixtures
            .where((f) => f.homeTeamId == id || f.awayTeamId == id)
            .every((f) => f.result != null),
        isTrue);
    expect(gs.isOffseason, isTrue, reason: '最終節のあと');
    expect(gs.isPreseason, isFalse);

    // 予算とチケットはすぐ変わる。
    expect(await gs.setBudgetPlan(BudgetPlan.youthFocus()), isTrue);
    expect(await gs.setTicketPricing(TicketPricing.premium), isTrue);
    expect(s.ticketPricing, TicketPricing.premium);

    // 方針は今季の採点が済むまで今季のまま。
    expect(await gs.setClubPolicy(ClubPolicy.profit), isTrue);
    expect(gs.clubPolicy, ClubPolicy.balanced);
    expect(gs.nextClubPolicy, ClubPolicy.profit);
    // 保存しても来季の方針は残る。古いセーブ(項目なし)も読める。
    final json = s.toJson();
    expect(SaveGame.fromJson(json).pendingClubPolicy, ClubPolicy.profit);
    json.remove('pendingClubPolicy');
    expect(SaveGame.fromJson(json).pendingClubPolicy, isNull);

    await gs.startNextSeason();
    expect(gs.clubPolicy, ClubPolicy.profit);
    expect(gs.save!.pendingClubPolicy, isNull);
    expect(gs.isPreseason, isTrue);
  });

  test('見た目は、季の終わりと次の開幕前を合わせて1回まで(2季目から)', () async {
    final gs = GameState();
    await gs.startNewGame('時期FC');
    await gs.simulateAheadMatchdays(60);
    await gs.startNextSeason();
    // 2季目の開幕前。1季目を終えたので変えると期待が下がる。
    expect(gs.clubLookChangeCosts, isTrue);
    expect(gs.canChangeClubLook, isTrue);
    final look = gs.currentClubLook;
    expect(await gs.setClubLook(look.copyWith(hue: (look.hue + 90) % 360)),
        isTrue);
    expect(gs.canChangeClubLook, isFalse);
    expect(gs.clubLookChangedThisOffseason, isTrue);

    // 2季目を終えると、次のオフシーズンとして1回変えられる。
    await gs.simulateAheadMatchdays(60);
    expect(gs.isOffseason, isTrue);
    expect(gs.canChangeClubLook, isTrue);
    final look2 = gs.currentClubLook;
    expect(
        await gs.setClubLook(look2.copyWith(hue: (look2.hue + 90) % 360)),
        isTrue);
    // 季を越して開幕前になっても、同じオフシーズンなのでもう変えられない。
    await gs.startNextSeason();
    expect(gs.isPreseason, isTrue);
    expect(gs.canChangeClubLook, isFalse);
  });
}
