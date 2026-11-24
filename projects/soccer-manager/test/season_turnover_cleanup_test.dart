import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 季の替わりで古い札を片付ける・部の名前の出し方を1つにする(2026-11-25)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('部の名前は「部の名前(N部)」の1つの書き方。保存したリーグ名からも同じ', () {
    expect(LeagueTheme.england.divisionTitle(3), 'リーグ・ディビジョン1(3部)');
    expect(LeagueTheme.england.divisionTitle(1), 'プレミア・ディビジョン(1部)');
    // シーズン成績は保存したリーグ名(1部の名前)と部から作る。
    expect(divisionTitleFor(LeagueTheme.england.label, 3),
        LeagueTheme.england.divisionTitle(3));
    // 国を引けない名前でも壊れない。
    expect(divisionTitleFor('謎のリーグ', 2), '謎のリーグ(2部)');
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('中盤の理事会レビューは、季の途中だけ出す(最終節のあとは出さない)', () async {
    final gs = GameState();
    await gs.startNewGame('片付けFC');
    await gs.playNextMatchdayQuickSim();
    gs.save!.pendingBoardReviewMessage = '講評';
    expect(gs.pendingBoardReviewMessage, '講評');

    await gs.simulateAheadMatchdays(60);
    gs.save!.pendingBoardReviewMessage = '講評';
    expect(gs.isOffseason, isTrue);
    expect(gs.pendingBoardReviewMessage, isNull, reason: '季末の状況に残さない');
    expect(gs.openDecisionCount, gs.inboxActions.length);
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('季を越すと、前の季の最後の試合の「今日の一面」を消す', () async {
    final gs = GameState();
    await gs.startNewGame('片付けFC');
    await gs.simulateAheadMatchdays(60);
    gs.save!.frontPageHeadline ??= '前の季の見出し';
    await gs.startNextSeason();
    expect(gs.save!.frontPageHeadline, isNull);
    expect(gs.save!.frontPageQuote, isNull);
    expect(gs.save!.pendingBoardReviewMessage, isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
