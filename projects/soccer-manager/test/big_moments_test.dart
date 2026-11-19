import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/big_moment.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/big_moment_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('決まったかの判定: 残りを全部勝っても届かないときだけ決まる', () {
    // 自クラブ 60点・残り2。2位 52点・残り2(最大58)→ 優勝決定。
    final rows = [('me', 60, 2), ('b', 52, 2), ('c', 40, 2)];
    expect(ClinchEngine.clinchedTop(rows, 'me', 1), isTrue);
    // 2位が 55点なら最大61で届く → まだ。上位2なら決定。
    final close = [('me', 60, 2), ('b', 55, 2), ('c', 40, 2)];
    expect(ClinchEngine.clinchedTop(close, 'me', 1), isFalse);
    expect(ClinchEngine.clinchedTop(close, 'me', 2), isTrue);
    // 降格: 自クラブ 20点・残り2(最大26)、ほか2クラブが 30点以上 → 下位1は決定。
    final low = [('a', 40, 2), ('b', 30, 2), ('me', 20, 2)];
    expect(ClinchEngine.doomedBottom(low, 'me', 1), isTrue);
    final hope = [('a', 40, 2), ('b', 25, 2), ('me', 20, 2)];
    expect(ClinchEngine.doomedBottom(hope, 'me', 1), isFalse);
  });

  test('史上最高額の獲得は一度だけ場面になり、安い獲得は出ない', () async {
    final gs = GameState();
    await gs.startNewGame('演出FC');
    final p = gs.userTeam.players.first;
    gs.debugCheckRecordSigning(p, 10);
    expect(gs.nextMoment, isNull, reason: '安すぎる獲得は出さない');
    final big = gs.scaledMoney(GameStateMoments.recordMinimum) * 2;
    gs.debugCheckRecordSigning(p, big);
    expect(gs.nextMoment![0], BigMomentKind.recordSigning.name);
    gs.debugCheckRecordSigning(p, big);
    expect(gs.save!.pendingMoments.length, 1, reason: '同じ額では更新ではない');
    await gs.dismissMoment();
    expect(gs.nextMoment, isNull);
    expect(SaveGame.fromJson(gs.save!.toJson()).recordSigningFee, big);
  });

  testWidgets('画面いっぱいの1枚に見出しと説明が出る', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BigMomentView(
          kind: BigMomentKind.relegated, tag: 'T', body: '本文のテスト'),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(BigMomentKind.relegated.headline), findsOneWidget);
    expect(find.text('本文のテスト'), findsOneWidget);
  });
}
