import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 中身が空のまま並ぶ画面に、開放条件が出ているかを固定するテスト。
///
/// 表彰・シーズン成績・ベストイレブンはシーズンを1つ終えるまで、殿堂は選手が
/// 引退するまで「まだ記録がありません」しか出ない。20項目のうち4つが、始めた
/// ばかりの利用者にとって空振りになっていた。項目を隠すのではなく、いつ開くかを
/// 見せて目標として機能させる方針(利用者判断)。
///
/// 条件は実データの生成タイミングに合わせてある。ずれると「開いているのに
/// 空」または「埋まっているのに閉じたまま」になる。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  QuickAccessDestination byLabel(String label) =>
      quickAccessDestinations.firstWhere((d) => d.label == label);

  test('始めた直後は、シーズンをまたぐ4画面が未開放になる', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    for (final label in const ['個人タイトル', 'シーズン成績', 'ベストイレブン', '殿堂']) {
      final reason = byLabel(label).lockedReason?.call(game);
      expect(reason, isNotNull, reason: '$label に開放条件が出ていない');
      expect(reason, isNotEmpty);
    }
  });

  test('開放条件には、いつ開くかが具体的に出る', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    // 残り節数が分かるなら数を出す。「そのうち開きます」では目標にならない。
    expect(game.remainingMatchdaysThisSeason, greaterThan(0));
    final reason = byLabel('シーズン成績').lockedReason!(game)!;
    expect(reason, contains('${game.remainingMatchdaysThisSeason}節'));
  });

  test('シーズンを終えると3画面が開き、殿堂は引退者が出るまで閉じたまま', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    // シーズン成績が入った状態を作る(実際は startNextSeason で追加される)。
    game.save!.seasonHistory.add(SeasonRecord(
      season: 1,
      clubName: 'テストFC',
      leagueName: 'テストリーグ',
      divisionTier: 1,
      finalRank: 1,
      teamCount: 20,
      played: 38,
      won: 20,
      draw: 10,
      lost: 8,
      goalsFor: 60,
      goalsAgainst: 40,
    ));

    for (final label in const ['個人タイトル', 'シーズン成績', 'ベストイレブン']) {
      expect(byLabel(label).lockedReason?.call(game), isNull,
          reason: '$label がシーズン終了後も開いていない');
    }
    // 殿堂は引退者が出て初めて埋まる。条件を分けてある。
    expect(byLabel('殿堂').lockedReason?.call(game), isNotNull,
        reason: '殿堂が引退者なしで開いてしまっている');
  });

  test('常に中身がある画面には開放条件を付けない', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    // クラブニュースは1節進めば埋まる。開始直後こそ空だが、画面自身が
    // 「節を進めると記録されます」と案内しており、閉じる意味がない。
    for (final label in const ['トレーニング', '移籍市場', 'カレンダー', 'クラブニュース']) {
      expect(byLabel(label).lockedReason?.call(game), isNull,
          reason: '$label は常に開けるべき');
    }
  });
}
