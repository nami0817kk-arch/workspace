import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/sponsor_engine.dart';
import 'package:soccer_manager/logic/sponsor_slots.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('枠の提示は胸のスポンサーの基準額より小さく、袖が一番大きい', () {
    for (final tier in [1, 3, 5]) {
      final chest = SponsorEngine.generateOffers(60, tier: tier)[1];
      final sleeve = SponsorSlotEngine.offerFor(SponsorSlot.sleeve, 60,
          tier: tier, managerReputation: 50, stadiumLevel: 1);
      final training = SponsorSlotEngine.offerFor(SponsorSlot.training, 60,
          tier: tier, managerReputation: 50, stadiumLevel: 1);
      expect(sleeve.weeklyIncome, lessThan(chest.weeklyIncome));
      expect(training.weeklyIncome, lessThan(sleeve.weeklyIncome));
      expect(sleeve.yearsRemaining, 2);
    }
  });

  test('季の境目で空いた枠に提示が来て、結ぶと週の収入に入り、2年で切れる',
      () async {
    final gs = GameState();
    await gs.startNewGame('枠FC');
    gs.debugRollSlotSponsors();
    for (final slot in SponsorSlot.values) {
      expect(gs.slotSponsorOffer(slot), isNotNull, reason: slot.name);
    }
    expect(gs.slotSponsorWeeklyIncome, 0);

    final offer = gs.slotSponsorOffer(SponsorSlot.sleeve)!;
    expect(await gs.signSlotSponsor(SponsorSlot.sleeve), isTrue);
    expect(gs.slotSponsor(SponsorSlot.sleeve)!.name, offer.name);
    expect(gs.slotSponsorOffer(SponsorSlot.sleeve), isNull);
    expect(gs.slotSponsorWeeklyIncome, offer.weeklyIncome);

    expect(await gs.declineSlotSponsor(SponsorSlot.training), isTrue);
    expect(gs.slotSponsorOffer(SponsorSlot.training), isNull);

    // 1年目の終わり: 袖は残り1年。練習着にはまた提示が来る。
    gs.debugRollSlotSponsors();
    expect(gs.slotSponsor(SponsorSlot.sleeve)!.yearsRemaining, 1);
    expect(gs.slotSponsorOffer(SponsorSlot.sleeve), isNull);
    expect(gs.slotSponsorOffer(SponsorSlot.training), isNotNull);
    // 2年目の終わり: 袖は切れて、新しい提示が来る。
    gs.debugRollSlotSponsors();
    expect(gs.slotSponsor(SponsorSlot.sleeve), isNull);
    expect(gs.slotSponsorOffer(SponsorSlot.sleeve), isNotNull);
  });

  test('枠のスポンサーは保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('保存FC');
    final s = gs.save!;
    s.slotSponsors['sleeve'] =
        SponsorDeal(name: 'A', weeklyIncome: 12, yearsRemaining: 2);
    s.slotSponsorOffers['back'] =
        SponsorDeal(name: 'B', weeklyIncome: 7, yearsRemaining: 2);
    final back = SaveGame.fromJson(s.toJson());
    expect(back.slotSponsors['sleeve']!.weeklyIncome, 12);
    expect(back.slotSponsorOffers['back']!.name, 'B');
  });
}
