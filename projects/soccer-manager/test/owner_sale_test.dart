import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/owner_legacy.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 期待が尽きたら売却を迫られ、実績を殿堂に残して別のクラブを買い直す。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('期待が残っているあいだは、売却を迫られない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(gs.isSaleForced, isFalse);
    expect(gs.saleReason, isNull);
  });

  test('手放す理由は、資金が尽きたときとサポーターの期待が尽きたときだけ', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final s = gs.save!;
    // 株主の期待が尽きても手放さない。
    s.shareholderExpectation = 0;
    expect(gs.saleReason, isNull);
    // 少しの借金では手放さない。
    s.budget = gs.fundsExhaustedLine ~/ 2;
    s.consecutiveNegativeBudgetWeeks = 10;
    expect(gs.saleReason, isNull);
    // 借金が線を超えても、週の締めでマイナスでなければ(一瞬の割り込み)数えない。
    s.budget = gs.fundsExhaustedLine;
    s.consecutiveNegativeBudgetWeeks = 0;
    expect(gs.saleReason, isNull);
    s.consecutiveNegativeBudgetWeeks = 1;
    expect(gs.saleReason, SaleReason.funds);
    // 期待が0でも、最後通告の猶予(3か月)のうちは手放さない。
    s.confidence = 0;
    s.supporterUltimatumUntil = gs.today.add(const Duration(days: 30));
    expect(gs.saleReason, SaleReason.funds);
    // 両方ならサポーターを先に見る(期限を過ぎた)。
    s.supporterUltimatumUntil = DateTime(2000);
    expect(gs.saleReason, SaleReason.supporters);
  });

  test('資金が尽きる線は、その部の年収の目安の半分のマイナス', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(gs.fundsExhaustedLine, lessThan(0));
    final half = GameState.initialBudgetFor(
        gs.currentDivisionTier, gs.currentLeagueTheme);
    expect(gs.fundsExhaustedLine, closeTo(-half, 1),
        reason: '初期資金は年収の半分なので、同じ額のマイナス');
  });

  test('買い直すと、実績が殿堂に残り、期待と資金が初期に戻る', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.budget = gs.fundsExhaustedLine - 5000;
    gs.save!.consecutiveNegativeBudgetWeeks = 12;
    final oldId = gs.save!.userTeamId;

    final candidates = gs.buyoutCandidates;
    expect(candidates, isNotEmpty);
    expect(candidates.length, lessThanOrEqualTo(3));
    expect(candidates.any((t) => t.id == oldId), isFalse);

    final target = candidates.first;
    expect(await gs.buyClub(target.id), isTrue);

    final save = gs.save!;
    expect(save.userTeamId, target.id);
    expect(save.clubName, target.name);
    expect(save.confidence, 60);
    expect(save.shareholderExpectation, 60);
    expect(save.budget, greaterThan(0));
    expect(gs.isSaleForced, isFalse);
    expect(save.ownerLegacies, hasLength(1));
    expect(save.ownerLegacies.single.clubName, 'テストFC');
    expect(save.ownerLegacies.single.reason, SaleReason.funds);
  });

  test('旧セーブの殿堂の「株主」の理由はそのまま読める', () {
    final legacy = OwnerLegacy.fromJson(const {
      'clubName': 'A',
      'reason': 'shareholders',
    });
    expect(legacy.reason, SaleReason.shareholders);
    expect(
        OwnerLegacy.fromJson(const {'clubName': 'B', 'reason': 'funds'}).reason,
        SaleReason.funds);
  });

  test('売却を迫られていないときは買い直せない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final target = gs.buyoutCandidates.first;
    expect(await gs.buyClub(target.id), isFalse);
    expect(gs.save!.userTeamId, isNot(target.id));
  });

  test('殿堂は保存して読み戻せ、無い旧セーブは空で読める', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.ownerLegacies.add(const OwnerLegacy(
      clubName: 'A',
      seasons: 4,
      leagueTitles: 1,
      cupTitles: 2,
      bestRank: 1,
      reason: SaleReason.supporters,
    ));
    final json = gs.save!.toJson();
    final restored = SaveGame.fromJson(json);
    expect(restored.ownerLegacies.single.cupTitles, 2);
    expect(restored.ownerLegacies.single.reason, SaleReason.supporters);

    json.remove('ownerLegacies');
    expect(SaveGame.fromJson(json).ownerLegacies, isEmpty);
  });
}
