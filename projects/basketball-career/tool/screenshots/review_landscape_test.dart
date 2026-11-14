/// 横画面の点検用の画像を作る(ストア掲載用ではない。掲載用は `capture_test.dart`)。
///
/// **CI では回らない。** 手元で:
///
///     flutter test tool/screenshots/review_landscape_test.dart
///     DEVICE=ipad flutter test tool/screenshots/review_landscape_test.dart
///
/// 出力: `build/review_landscape/<端末>/*.png`。撮ったら必ず目で見る(はみ出し・切れ・空白)。
library;

// 生成器はテストの外にあるため、setMockInitialValues が警告になる。実体は flutter test で走らせる。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/rating.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/gm/common.dart';
import 'package:basketball_career/ui/gm/progress_tab.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _device = Platform.environment['DEVICE'] ?? 'iphone';
final _size = _device == 'ipad' ? const Size(1376, 1032) : const Size(844, 390);
final _ratio = _device == 'ipad' ? 1.0 : 2.0;
final _key = GlobalKey();

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final noto = FontLoader('NotoSansJP');
  for (final f in ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf']) {
    noto.addFont(Future.value(ByteData.view(File('assets/fonts/$f').readAsBytesSync().buffer)));
  }
  await noto.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
      await loader.load();
    }
  }
}

Future<GmController> _controller() async => GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(7));

Future<GmController> _with(Career car) async {
  final c = await _controller();
  c.setCareer(car);
  c.pending.clear();
  return c;
}

Future<void> _shoot(WidgetTester t, String name, GmController c, {Future<void> Function(WidgetTester)? act}) async {
  t.view.physicalSize = _size * _ratio;
  t.view.devicePixelRatio = _ratio;
  await t.pumpWidget(RepaintBoundary(key: _key, child: KeyedSubtree(key: ValueKey(name), child: BasketballCareerApp(controller: c))));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
  if (act != null) await act(t);
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 700)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
  expect(t.takeException(), isNull, reason: '$name で例外');
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/review_landscape/$_device')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester t, String text, {bool first = false}) async {
  final f = first ? find.text(text).first : find.text(text).last;
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('横画面の点検', (t) async {
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({'gmHowtoSeen': true});
    await _shoot(t, '1_title', await _controller());
    await _shoot(t, '2_teampick', await _controller(), act: (t) => _tap(t, 'GMに就任する'));

    final pre = careerAt(2, 20);
    await _shoot(t, '3_home_preseason', await _with(pre));

    final mid = careerAt(3, 12)..startSeason();
    mid.playBlock();
    await _shoot(t, '4_home_season', await _with(mid));
    await _shoot(t, '4d_box_score', await _with(careerAt(3, 12)..startSeason()), act: (t) async {
      await _tap(t, '次の20試合へ');
      await t.pumpAndSettle();
      final list = find.textContaining('試合ごとの結果');
      await t.scrollUntilVisible(list, 200, scrollable: find.byType(Scrollable).last);
      await t.pumpAndSettle();
      await t.tap(list);
      await t.pumpAndSettle();
      final row = find.byType(GameRow).first;
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      await t.tap(row);
      await t.pumpAndSettle();
    });
    final rep = careerAt(3, 12)..startSeason();
    await _shoot(t, '4b_block_report', await _with(rep), act: (t) async {
      await _tap(t, '次の20試合へ');
    });
    final po = careerAt(4, 3)..startSeason();
    while (po.phase == Phase.season) {
      po.declineIncoming();
      po.playBlock();
    }
    await _shoot(t, '4c_playoff_run', await _with(po), act: (t) async {
      final b = find.textContaining(RegExp('プレーオフを戦う|プレーオフの結果を見る'));
      await t.ensureVisible(b);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(b);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 500));
        if (i < 3 && find.byType(FilledButton).evaluate().isNotEmpty) await t.tap(find.byType(FilledButton).last);
      }
    });
    await _shoot(t, '5_team', await _with(mid), act: (t) => _tap(t, 'チーム', first: true));
    await _shoot(t, '6_trade', await _with(mid), act: (t) => _tap(t, 'トレード', first: true));
    // 選手を選んだあと(相手の反応・強さと勝ち数の見込みの変化)
    await _shoot(t, '6c_trade_offer', await _with(mid), act: (t) async {
      await _tap(t, 'トレード', first: true);
      // 相手のいちばん上の選手を選ぶ(一覧は画面に入った分しか作られないので、行の部品で探す)
      await t.ensureVisible(find.byType(PlayerRow).first);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byType(PlayerRow).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    });
    // トレード成立の画面(届いた申し込みを受ける)
    Career? offered;
    for (final seed in [3, 7, 11, 19]) {
      final x = careerAt(10, seed)..startSeason();
      while (x.phase == Phase.season && (x.incoming == null || !x.canTrade)) {
        x.playBlock();
      }
      if (x.incoming != null && x.judge(x.incoming!).ok) {
        offered = x;
        break;
      }
    }
    if (offered != null) {
      await _shoot(t, '6b_trade_done', await _with(offered), act: (t) async {
        final b = find.widgetWithText(FilledButton, '受ける');
        await t.scrollUntilVisible(b, 300, scrollable: find.descendant(of: find.byType(ProgressTab), matching: find.byType(Scrollable)).first);
        await t.ensureVisible(b);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(b);
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 150));
        }
      });
    }
    await _shoot(t, '5b_policy', await _with(mid), act: (t) async {
      await _tap(t, 'チーム', first: true);
      await _tap(t, 'チームの方針');
    });
    await _shoot(t, '5c_team_tiles', await _with(mid), act: (t) async {
      await _tap(t, 'チーム', first: true);
      await t.drag(find.byType(Scrollable).last, const Offset(0, -120));
      await t.pump(const Duration(milliseconds: 300));
    });
    await _shoot(t, '8b_history', await _with(mid), act: (t) async {
      await _tap(t, 'リーグ', first: true);
      await t.scrollUntilVisible(find.text('歴代の優勝・表彰・殿堂'), 300, scrollable: find.byType(Scrollable).last);
      await _tap(t, '歴代の優勝・表彰・殿堂');
    });
    await _shoot(t, '7_market', await _with(mid), act: (t) => _tap(t, '補強', first: true));
    await _shoot(t, '8_league', await _with(mid), act: (t) => _tap(t, 'リーグ', first: true));
    await _shoot(t, '9_inbox', await _with(mid), act: (t) => _tap(t, '受信箱', first: true));

    final draft = careerAt(5, 28);
    var guard = 0;
    while (draft.phase != Phase.draft && guard++ < 400) {
      if (draft.phase == Phase.seasonEnd) draft.fired = false;
      botStep(draft);
    }
    Career toDraft() {
      final d = careerAt(5, 28);
      var g = 0;
      while (d.phase != Phase.draft && g++ < 400) {
        if (d.phase == Phase.seasonEnd) d.fired = false;
        botStep(d);
      }
      return d;
    }

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
    }

    await _shoot(t, '10a_lottery', await _with(toDraft()), act: settle);
    await _shoot(t, '10b_lottery_open', await _with(toDraft()), act: (t) async {
      await settle(t);
      await _tap(t, '全部開ける');
    });
    Future<void> openDraft(WidgetTester t) async {
      await settle(t);
      await _tap(t, '全部開ける');
      await _tap(t, 'ドラフトへ');
      await settle(t);
    }

    await _shoot(t, '10_draft', await _with(draft), act: openDraft);
    await _shoot(t, '10c_pick_reveal', await _with(toDraft()), act: (t) async {
      await openDraft(t);
      final b = find.widgetWithText(FilledButton, '指名').first;
      await t.ensureVisible(b);
      await t.pumpAndSettle();
      await t.tap(b);
      await t.pumpAndSettle();
    });
    await _shoot(t, '10d_draft_summary', await _with(toDraft()), act: (t) async {
      await openDraft(t);
      for (var i = 0; i < 8 && find.textContaining('ドラフトのまとめ').evaluate().isEmpty; i++) {
        final pick = find.widgetWithText(FilledButton, '指名');
        final pass = find.text('この指名を見送る');
        final b = pass.evaluate().isNotEmpty ? pass : pick.first;
        await t.ensureVisible(b);
        await t.pumpAndSettle();
        await t.tap(b);
        await t.pumpAndSettle();
        if (find.text('続ける').evaluate().isNotEmpty) {
          await t.tap(find.text('続ける'));
          await t.pumpAndSettle();
        }
      }
    });
    // シーズンの終わり(GM の格の内訳と、任期を終えるボタンまで送って撮る)
    final end = careerAt(4, 3);
    guard = 0;
    while (end.phase != Phase.seasonEnd && guard++ < 100) {
      botStep(end);
    }
    final progress = find.descendant(of: find.byType(ProgressTab), matching: find.byType(Scrollable)).first;
    await _shoot(t, '12_seasonend_top', await _with(end));
    await _shoot(t, '13_seasonend_rating', await _with(end),
        act: (t) => t.scrollUntilVisible(find.text('GMの格 Lv${end.gmLevel}(${ratingNameOf(end.gmLevel)})'), 200, scrollable: progress));
    await _shoot(t, '13b_skills', await _with(end), act: (t) async {
      await t.scrollUntilVisible(find.textContaining('GMの技能'), 200, scrollable: progress);
      await _tap(t, 'GMの技能(使える点 ${end.skillPoints})');
    });
    await _shoot(t, '14_seasonend_bottom', await _with(end),
        act: (t) => t.scrollUntilVisible(find.text('ここで任期を終える'), 300, scrollable: progress));
    // 契約の画面(1巡目の新人の選択権が保留になっている)
    final opt = careerAt(6, 8);
    final rookie = opt.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b)
      ..years = 3
      ..optionYears = 2
      ..age = 21;
    guard = 0;
    while (opt.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(opt);
    }
    opt.toOffseason();
    while (opt.phase != Phase.contracts && guard++ < 400) {
      botStep(opt);
    }
    await _shoot(t, '15_contracts_option', await _with(opt),
        act: (t) => t.scrollUntilVisible(find.text('使う(年俸 ${money(opt.optionSalary(rookie))})'), 200, scrollable: progress));
    // 自由契約の1日の発表(大物に申し込んでから日を進める)と、オフのまとめ
    Career toContracts() {
      final d = careerAt(6, 28);
      var g = 0;
      while (d.phase != Phase.contracts && g++ < 600) {
        if (d.phase == Phase.seasonEnd) d.fired = false;
        botStep(d);
      }
      final target = d.freeAgents.where((p) => d.isBigFa(p) && d.bidProblem(p) == null).firstOrNull;
      if (target != null) d.bid(target.id, 2, 1.05);
      return d;
    }

    await _shoot(t, '15b_fa_day', await _with(toContracts()), act: (t) async {
      await _tap(t, '補強', first: true);
      await _tap(t, '次の日へ');
      await settle(t);
    });
    await _shoot(t, '15c_off_summary', await _with(toContracts()), act: (t) async {
      await t.scrollUntilVisible(find.text('自由契約の選手を見る'), 300, scrollable: progress);
      await _tap(t, 'オフを終えて、シーズン前へ');
      if (find.text('終える').evaluate().isNotEmpty) await _tap(t, '終える');
      await settle(t);
    });
    final over = botPlayCareer(8, team: teamAtRank(8, 15));
    await _shoot(t, '11_over', await _with(over));
  });
}
