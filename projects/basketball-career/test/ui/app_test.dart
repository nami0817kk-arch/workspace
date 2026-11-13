import 'dart:math';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/gm/progress_tab.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GmController> _controller([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  return GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(3));
}

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _closeDialogs(WidgetTester tester) async {
  while (find.text('OK').evaluate().isNotEmpty) {
    await tester.tap(find.text('OK').first);
    await tester.pumpAndSettle();
  }
}

/// 縦に流れる一覧(トレードの画面には、相手を選ぶ横の一覧もある)。
final _vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;

/// ホームの左側(いまやること)の縦に流れる一覧。右の札の一覧や左のメニューとは別。
final _progress = find.descendant(of: find.byType(ProgressTab), matching: find.byType(Scrollable)).first;

void main() {
  testWidgets('はじめの画面から就任し、開幕して20試合を進める', (tester) async {
    _size(tester, 844, 390);
    final c = await _controller();
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('バスケGM'), findsOneWidget);

    await tester.tap(find.text('GMに就任する'));
    await tester.pumpAndSettle();
    // チームを選ぶ: 西地区に切り替えて、いちばん上のチームを見て、GMになる
    expect(find.text('どのチームを任される?'), findsOneWidget);
    await tester.tap(find.text('西地区'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('のGMになる'));
    await tester.pumpAndSettle();
    // はじめてなら、先に遊び方
    expect(find.text('遊び方'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('はじめる'), 300);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.text('1年目のシーズン前'), findsOneWidget);
    expect(c.career!.me.east, isFalse, reason: '西地区のチームを選んだ');

    await tester.tap(find.text('開幕する'));
    await tester.pumpAndSettle();
    expect(c.career!.phase, Phase.season);
    await tester.tap(find.text('次の20試合へ'));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    expect(c.career!.block, 1);
    // 進めたら報告が画面いっぱいに出て、閉じるまで戻らない
    expect(find.text('1〜20試合目の結果'), findsOneWidget);
    expect(find.textContaining('オーナーの目標'), findsWidgets);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('1〜20試合目の結果'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('この20試合'), 300, scrollable: _progress);
    expect(find.textContaining('この20試合'), findsOneWidget);
  });

  testWidgets('トレードの画面で選ぶと相手の反応が出て、釣り合えば成立する', (tester) async {
    _size(tester, 844, 390);
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(teamAtRank(1, 15), seed: 1);
    final car = c.career!;
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('トレード').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('相手の反応が出る'), findsOneWidget);
    // 相手のいちばん下の選手を、こちらのいちばんの選手で取りに行く(相手はきっと受ける)
    final them = car.teams[car.mine == 0 ? 1 : 0];
    final theirs = them.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
    final ours = car.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
    await tester.scrollUntilVisible(find.text(theirs.name), 200, scrollable: _vertical);
    // 下の申し込みの欄に隠れないよう、全体が見える所まで送ってから押す
    await tester.ensureVisible(find.text(theirs.name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(theirs.name).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(ours.name), 300, scrollable: _vertical);
    await tester.ensureVisible(find.text(ours.name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ours.name).last);
    await tester.pumpAndSettle();
    final v = car.judge(TradeOffer(partner: them.index, give: [ours.id], get: [theirs.id]));
    final ok = v.ok;
    expect(find.text(ok ? '受けてくれそう' : v.reason), findsOneWidget);
    if (ok) {
      await tester.tap(find.text('申し込む'));
      await tester.pumpAndSettle();
      expect(car.me.roster.any((p) => p.id == theirs.id), isTrue);
      expect(find.textContaining('トレードが成立した'), findsOneWidget);
    }
  });

  testWidgets('続きは保存され、起動するとはじめの画面から「続きから」で戻れる', (tester) async {
    _size(tester, 844, 390);
    final c = await _controller();
    c.newCareer(teamAtRank(1, 28), seed: 1);
    c.startSeason();
    await tester.pumpWidget(const SizedBox());
    final prefs = await SharedPreferences.getInstance();
    final c2 = GmController(prefs: prefs, seedSource: Random(4));
    await tester.pumpWidget(BasketballCareerApp(controller: c2));
    await tester.pumpAndSettle();
    expect(find.textContaining('続きから'), findsOneWidget);
    await tester.tap(find.textContaining('続きから'));
    await tester.pumpAndSettle();
    expect(find.text('次の20試合へ'), findsOneWidget);
    expect(c2.career!.me.roster.length, c.career!.me.roster.length);
  });

  testWidgets('先発と控えの順の画面を開いて、この順にする(小さいスマホでもはみ出さない)', (tester) async {
    _size(tester, 667, 375);
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(teamAtRank(1, 15), seed: 1);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('チーム').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('先発と控えの順'));
    await tester.pumpAndSettle();
    expect(find.text('先発と控えの順'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('この順にする'));
    await tester.pumpAndSettle();
    expect(c.career!.me.rotation, isNotEmpty);
  });

  testWidgets('まとめて進める: 締め切りまで・シーズンの終わりまで(申し込みが届いたら止まる)', (tester) async {
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(teamAtRank(2, 15), seed: 2);
    c.startSeason();
    await c.simAhead(toDeadline: true);
    final car = c.career!;
    expect(car.block >= tradeDeadlineBlock || car.incoming != null, isTrue);
    var guard = 0;
    while (car.phase == Phase.season && guard++ < 10) {
      car.declineIncoming();
      await c.simAhead(toDeadline: false);
    }
    expect(car.phase, Phase.playoffs);
    expect(car.me.wins + car.me.losses, gamesPerSeason);
  });

  testWidgets('ドラフト: くじを開け、指名すると答え合わせ、終わるとまとめが出る(小さいスマホ)', (tester) async {
    _size(tester, 667, 375);
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(teamAtRank(6, 28), seed: 6);
    c.startSeason();
    final car = c.career!;
    while (car.phase == Phase.season) {
      car.declineIncoming();
      car.playBlock();
    }
    car.playPlayoffs();
    car.fired = false;
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    final off = find.text('オフへ(ドラフト・契約)');
    await tester.scrollUntilVisible(off, 300, scrollable: _progress);
    await tester.tap(off);
    await tester.pumpAndSettle();
    expect(car.phase, Phase.draft);
    expect(find.textContaining('ドラフトくじ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('4番目を開ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部開ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ドラフトへ'));
    await tester.pumpAndSettle();
    var picked = 0;
    var guard = 0;
    while (car.phase == Phase.draft && guard++ < 10) {
      if (car.canDraftPick) {
        final b = find.widgetWithText(FilledButton, '指名').first;
        await tester.ensureVisible(b);
        await tester.pumpAndSettle();
        await tester.tap(b);
        await tester.pumpAndSettle();
        expect(find.textContaining('を指名'), findsOneWidget);
        expect(find.textContaining('本当の力'), findsOneWidget);
        expect(tester.takeException(), isNull);
        picked++;
        await tester.tap(find.text('続ける'));
        await tester.pumpAndSettle();
      } else {
        final b = find.text('この指名を見送る');
        await tester.ensureVisible(b);
        await tester.tap(b);
        await tester.pumpAndSettle();
      }
    }
    expect(picked, greaterThan(0));
    expect(car.phase, Phase.contracts);
    expect(find.textContaining('ドラフトのまとめ'), findsOneWidget);
    expect(find.textContaining('自分の指名($picked人)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('契約へ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ドラフトのまとめ'), findsNothing);
  });

  testWidgets('自由契約: 日を進めるとその日の動きが出て、オフを終えるとまとめが出る(小さいスマホ)', (tester) async {
    _size(tester, 667, 375);
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(teamAtRank(6, 28), seed: 6);
    final car = c.career!;
    var guard = 0;
    while (car.phase != Phase.contracts && guard++ < 600) {
      if (car.phase == Phase.seasonEnd) car.fired = false;
      botStep(car);
    }
    expect(car.phase, Phase.contracts);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    final see = find.text('自由契約の選手を見る');
    await tester.scrollUntilVisible(see, 300, scrollable: _progress);
    await tester.tap(see);
    await tester.pumpAndSettle();
    await tester.tap(find.text('次の日へ'));
    await tester.pumpAndSettle();
    expect(find.text('自由契約 1日目の動き'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('続ける'));
    await tester.pumpAndSettle();
    expect(car.faDay, 1);
    // 進み具合の画面に戻って、オフを終える
    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('オフを終えて、シーズン前へ'));
    await tester.pumpAndSettle();
    if (find.text('終える').evaluate().isNotEmpty) {
      await tester.tap(find.text('終える'));
      await tester.pumpAndSettle();
    }
    expect(car.phase, Phase.preseason);
    expect(find.textContaining('オフのまとめ'), findsOneWidget);
    expect(find.textContaining('入った選手'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('シーズン前へ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('オフのまとめ'), findsNothing);
  });

  testWidgets('トレード: 届いた申し込みを受けると、成立の画面が出る(小さいスマホ)', (tester) async {
    _size(tester, 667, 375);
    final c = await _controller({'gmHowtoSeen': true});
    Career? car;
    for (final seed in [3, 7, 11, 19]) {
      c.newCareer(teamAtRank(10, 28), seed: seed);
      c.startSeason();
      final x = c.career!;
      while (x.phase == Phase.season && (x.incoming == null || !x.canTrade)) {
        x.playBlock();
      }
      if (x.incoming != null && x.judge(x.incoming!).ok) {
        car = x;
        break;
      }
    }
    expect(car, isNotNull);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    final accept = find.widgetWithText(FilledButton, '受ける');
    await tester.scrollUntilVisible(accept, 300, scrollable: _progress);
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(find.textContaining('トレード成立'), findsOneWidget);
    expect(find.textContaining('評価: '), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.textContaining('トレード成立'), findsNothing);
  });

  testWidgets('プレーオフは自分のシリーズを1試合ずつめくり、最後に結果を見てシーズンの終わりへ', (tester) async {
    _size(tester, 667, 375);
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(teamAtRank(0, 15), seed: 4);
    c.startSeason();
    final car = c.career!;
    while (car.phase == Phase.season) {
      car.declineIncoming();
      car.playBlock();
    }
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    final start = find.textContaining(RegExp('プレーオフを戦う|プレーオフの結果を見る'));
    await tester.scrollUntilVisible(start, 300, scrollable: _progress);
    await tester.tap(start);
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    final mine = car.playoffs.where((s) => s.high == car.mine || s.low == car.mine).toList();
    if (mine.isNotEmpty) {
      expect(find.text('第1戦を見る'), findsOneWidget);
      await tester.tap(find.text('第1戦を見る'));
      await tester.pumpAndSettle();
      expect(find.text('第1戦'), findsOneWidget);
    }
    var guard = 0;
    while (find.textContaining('シーズンの終わりへ').evaluate().isEmpty && guard++ < 60) {
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.textContaining('シーズンの終わりへ'));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    expect(car.phase, Phase.seasonEnd);
    expect(find.text('オーナーの評価'), findsOneWidget);
  });

  for (final s in const [Size(667, 375), Size(932, 430), Size(1376, 1032)]) {
    testWidgets('選手の画面は閉じるボタンと外を押して戻れ、画面いっぱいにならない($s)', (tester) async {
      _size(tester, s.width, s.height);
      final c = await _controller({'gmHowtoSeen': true});
      c.newCareer(teamAtRank(1, 15), seed: 1);
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('チーム').first);
      await tester.pumpAndSettle();
      final star = c.career!.me.order.first;
      await tester.scrollUntilVisible(find.text(star.name), 200, scrollable: _vertical);
      await tester.tap(find.text(star.name).first);
      await tester.pumpAndSettle();
      expect(find.text('この選手を放す'), findsOneWidget);
      // 閉じるボタンで戻る
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('この選手を放す'), findsNothing);
      // 板の上に暗い所が残っていて、押すと閉じる
      await tester.tap(find.text(star.name).first);
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.top, greaterThan(40), reason: '画面の上まで覆わない');
      await tester.tapAt(Offset(s.width / 2, sheet.top / 2));
      await tester.pumpAndSettle();
      expect(find.text('この選手を放す'), findsNothing);
    });
  }

  group('どの画面も、小さいスマホ・大きいスマホ・iPad ではみ出さない', () {
    const sizes = [Size(667, 375), Size(844, 390), Size(932, 430), Size(1376, 1032)];

    Future<void> show(WidgetTester tester, GmController c, Size s, {String? tab}) async {
      _size(tester, s.width, s.height);
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      await _closeDialogs(tester);
      if (tab != null) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '$s $tab ${c.career?.phase}');
      await tester.pumpWidget(const SizedBox());
    }

    for (final s in sizes) {
      testWidgets('$s', (tester) async {
        final c = await _controller({'gmHowtoSeen': true});
        await show(tester, c, s); // はじめの画面
        c.newCareer(teamAtRank(1, 1), seed: 1);
        final car = c.career!;
        for (final tab in [null, 'チーム', 'トレード', '補強', 'リーグ']) {
          await show(tester, c, s, tab: tab);
        }
        c.startSeason();
        car.playBlock();
        await show(tester, c, s);
        await show(tester, c, s, tab: 'リーグ');
        while (car.phase == Phase.season) {
          car.playBlock();
        }
        await show(tester, c, s); // プレーオフ前
        car.playPlayoffs();
        await show(tester, c, s); // シーズン終了
        car.fired = false;
        car.toOffseason();
        await show(tester, c, s); // ドラフト
        while (car.phase == Phase.draft) {
          botStep(car);
        }
        await show(tester, c, s); // 契約
        await show(tester, c, s, tab: '補強');
        car.phase = Phase.over;
        await show(tester, c, s);
      });
    }
  });
}
