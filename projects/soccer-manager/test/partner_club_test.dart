import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/partner_club_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 提携クラブ: 毎季の提携費を払い、2つの期待が少し上がる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('提携FC');
    return game;
  }

  test('他クラブと提携でき、自クラブや存在しないクラブとは結べない', () async {
    final game = await newGame();
    final other = game.partnerCandidates.first;
    expect(game.partnerClub, isNull);
    expect(await game.setPartnerClub(other.id), isTrue);
    expect(game.partnerClub?.id, other.id);

    expect(await game.setPartnerClub(game.save!.userTeamId), isFalse);
    expect(await game.setPartnerClub('none'), isFalse);
    expect(game.partnerClub?.id, other.id, reason: '失敗しても提携は変わらない');
  });

  test('候補に自クラブは入らない', () async {
    final game = await newGame();
    expect(game.partnerCandidates.any((t) => t.id == game.save!.userTeamId),
        isFalse);
    expect(game.partnerCandidates, isNotEmpty);
  });

  test('季末に提携費が引かれ、2つの期待が上がる', () async {
    final game = await newGame();
    final save = game.save!;
    await game.setPartnerClub(game.partnerCandidates.first.id);
    save.budget = 500000;
    save.confidence = 50;
    save.shareholderExpectation = 50;

    game.debugSettlePartnerClub();

    // 提携費は部の規模で掛かる(3部から始まる。2026-11-22)。
    expect(save.budget, 500000 - game.partnerSeasonCost);
    expect(save.confidence, 50 + PartnerClubEngine.supportersBonus);
    expect(save.shareholderExpectation, 50 + PartnerClubEngine.shareholdersBonus);
    expect(game.partnerClub, isNotNull);
  });

  test('資金が足りない季は提携が解消され、何も引かれない', () async {
    final game = await newGame();
    final save = game.save!;
    await game.setPartnerClub(game.partnerCandidates.first.id);
    save.budget = PartnerClubEngine.seasonCost - 1;
    save.confidence = 50;

    game.debugSettlePartnerClub();

    expect(game.partnerClub, isNull);
    expect(save.budget, PartnerClubEngine.seasonCost - 1);
    expect(save.confidence, 50);
  });

  test('提携しないなら、季末は何も起きない', () async {
    final game = await newGame();
    final save = game.save!;
    save.budget = 5000;
    game.debugSettlePartnerClub();
    expect(save.budget, 5000);
  });

  test('解消でき、提携は保存して読み戻せる', () async {
    final game = await newGame();
    final id = game.partnerCandidates.first.id;
    await game.setPartnerClub(id);
    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.partnerClubId, id);

    await game.clearPartnerClub();
    expect(game.partnerClub, isNull);

    final old = SaveGame.fromJson(game.save!.toJson()..remove('partnerClubId'));
    expect(old.partnerClubId, isNull);
  });
}
