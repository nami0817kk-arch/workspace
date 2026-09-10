import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/ranking.dart';
import 'package:soccer_career/game/weekly_plan.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/ui/attribute_shape.dart';
import 'package:soccer_career/ui/club_identity.dart';
import 'package:soccer_career/ui/player_banner.dart';
import 'package:soccer_career/ui/trait_row.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/main.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/readable_width.dart';
import 'package:soccer_career/models/look.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/ui/screens/create_player_screen.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';
import 'package:soccer_career/ui/screens/season_end_screen.dart';

/// 保存しないリポジトリ。端末なしで画面を出すために使う。
class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> newCareer({int seed = 1, int age = 20}) async {
  final controller = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await controller.startCareer(
    name: 'テスト',
    position: Position.cm,
    age: age,
    agent: Agent.pool.first,
  );
  return controller;
}

/// スマホの画面で開く。狭いほうで崩れないことを見たい。
Future<void> pumpHub(
  WidgetTester tester,
  CareerController controller, {
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => HubScreen(controller: controller),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('拠点は5つのタブに分かれている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    for (final label in ['試合', '選手', '育成', 'クラブ', '記録']) {
      expect(find.widgetWithText(Tab, label), findsOneWidget,
          reason: '$label タブが無い');
    }
  });

  testWidgets('主要な動作は、スクロールしなくても押せる位置にある', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    // 試合タブでは、カードの中のボタンが主役。FAB は出さない
    // （出すと「区切りまで」など下の操作に被さる）。
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, '試合へ'), findsOneWidget);

    // 他のタブでは、どこに居ても FAB から試合に入れる。
    for (final tab in ['選手', '育成', 'クラブ', '記録']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget, reason: tab);
      expect(find.descendant(of: fab, matching: find.text('試合へ')),
          findsOneWidget);
    }
  });

  testWidgets('開いてすぐ、次の相手と今の状態が見える', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    expect(find.textContaining('第1節'), findsOneWidget);
    expect(find.text('今の状態'), findsOneWidget);
    // 能力値の一覧は「選手」タブに移した。試合のタブには出さない。
    expect(find.text('詳細能力'), findsNothing);
  });

  testWidgets('練習のタブでは、選んでいるメニューの中身が文字で読める', (tester) async {
    final controller = await newCareer();
    await controller.setMenu(TrainingMenu.athletic);
    // 縦に並ぶものを一度に見たいので、背の高い画面で開く。
    await pumpHub(tester, controller, height: 2000);

    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();

    expect(find.text('今週の練習'), findsOneWidget);
    // ツールチップではなく、本文として出ていること。
    expect(find.text(TrainingMenu.athletic.description), findsOneWidget);
    expect(find.textContaining('消耗 ${TrainingMenu.athletic.conditionCost}'),
        findsOneWidget);
    // 専属スタッフと生活習慣は畳んである。
    expect(find.text('専属スタッフ'), findsOneWidget);
    expect(find.text('世界的 1500万'), findsNothing);
  });

  testWidgets('選手のタブに能力と身体がまとまっている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2000);

    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    expect(find.text('詳細能力'), findsOneWidget);
    expect(find.text('身体'), findsOneWidget);
    expect(find.text('積み上げ'), findsOneWidget);
  });

  testWidgets('選手のタブで、特性がどこで効くかと今季の回数が読める', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2400);

    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    expect(find.text('特性の効き'), findsOneWidget);
    final traits = controller.state!.player.traits;
    expect(traits, isNotEmpty);
    for (final trait in traits) {
      // 名前のチップと、効きの行の両方に出る。
      expect(find.text(trait.label), findsWidgets);
      for (final effect in trait.effects) {
        expect(find.text(effect), findsOneWidget, reason: effect);
      }
    }
    // 回数か「試合の外」かのどちらかが書いてある。
    expect(
        find.textContaining(RegExp('今季|試合の外で効く')), findsAtLeastNWidgets(1));
  });

  testWidgets('クラブのタブに順位表がある', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.widgetWithText(Tab, 'クラブ'));
    await tester.pumpAndSettle();

    expect(find.text('クラブでの立ち位置'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('順位表'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('順位表'), findsOneWidget);
  });

  testWidgets('世の中の反応が画面に出る', (tester) async {
    final controller = await newCareer();
    // デビューの見出しは初戦で出る。話題は新しい順に数件しか出さないので、
    // 何試合も進めると押し出される。
    for (var i = 0; i < 2; i++) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller, height: 2000);

    expect(find.text('最近の話題'), findsOneWidget);
    expect(find.textContaining('デビュー'), findsWidgets);

    // クラブのタブには得点ランキング。
    await tester.tap(find.widgetWithText(Tab, 'クラブ'));
    await tester.pumpAndSettle();
    expect(find.text('得点ランキング'), findsOneWidget);
  });

  testWidgets('選手のタブで、自分が世界のどのあたりかが分かる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2000);

    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    expect(find.text('選手としての水準'), findsOneWidget);
    // 総合力が言葉になっていること。
    final grade = Ranking.gradeFor(controller.state!.player.overall);
    expect(find.text(grade.label), findsOneWidget);
    expect(find.textContaining('クラブの主力を上回っている'), findsOneWidget);
    expect(
        find.textContaining('代表に呼ばれる総合力（${Formulas.callUpOverall}）'),
        findsOneWidget);
  });

  testWidgets('クラブのタブで、リーグが世界の何位か分かる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2400);

    await tester.tap(find.widgetWithText(Tab, 'クラブ'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('リーグの格付け'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    final mine = Ranking.of(
        controller.state!.club.countryId, controller.state!.club.tier);
    expect(
        find.textContaining('世界${mine.rank}位 / ${mine.total}リーグ'),
        findsOneWidget);
    expect(find.text('世界のリーグ一覧'), findsOneWidget);
  });

  testWidgets('育成のタブで、育てる方向を選べる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 3200);

    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('育てる方向'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('0 / ${CareerState.maxFocus}'), findsOneWidget);

    await tester.tap(find.text('項目を選ぶ'));
    await tester.pumpAndSettle();
    // 項目は今の値つきで並ぶ。
    final value = controller.state!.player.attributes.detail(Detail.finishing);
    await tester.tap(find.widgetWithText(
        FilterChip, '${Detail.finishing.label} $value'));
    await tester.pumpAndSettle();
    expect(controller.state!.focus, [Detail.finishing]);
  });

  testWidgets('育成のタブに、練習が試合に出たかが載る', (tester) async {
    final controller = await newCareer();
    await controller.setMenu(TrainingMenu.passingWork);
    for (var i = 0; i < 8; i++) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller, height: 3000);

    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('練習の成果（今季）'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    // 今週の練習の対象は、まだ動いていなくても必ず出す。
    expect(find.text(AttributeKey.passing.label), findsOneWidget);
    expect(find.textContaining('回勝負して'), findsWidgets);
  });

  testWidgets('育成のタブの一番上に、今週の手がかりが出る', (tester) async {
    // 練習を決める場所に、相手と体の状態を持ってくる。
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2400);

    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();

    final state = controller.state!;
    final plan = WeekPlan.of(state);
    expect(find.textContaining(plan.headline), findsOneWidget);
    expect(find.text(plan.reason), findsOneWidget);
    // 次の相手の名前が、育成のタブから読める。
    expect(plan.headline,
        contains(state.opponentFor(state.matchday).name));
  });

  testWidgets('選手タブは、選手証と能力の形で始まる', (tester) async {
    // 白いカードに文字が並ぶだけで、唯一手で描いているもの（似顔）は
    // 64px の丸で隅に居た。
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2600);
    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerBanner), findsOneWidget);
    // 名前・総合力は帯の中に大きく出る。
    expect(find.descendant(
        of: find.byType(PlayerBanner),
        matching: find.text(controller.state!.player.name)),
        findsOneWidget);
    expect(find.descendant(
        of: find.byType(PlayerBanner),
        matching: find.text('${controller.state!.player.overall}')),
        findsOneWidget);

    // 能力の形。棒は残す（正確な値はそちらで読む）。
    final shape = tester.widget<AttributeShape>(find.byType(AttributeShape));
    expect(shape.keys, isNotEmpty);
    expect(shape.keys.contains(AttributeKey.goalkeeping), isFalse,
        reason: 'GK 以外に GK 能力の頂点が出ている');
    expect(find.text(AttributeKey.pace.label), findsWidgets);
  });

  testWidgets('GK の能力の形には GK 能力が入る', (tester) async {
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(5)),
      matchEngine: MatchEngine(random: Random(5)),
      random: Random(5),
    );
    await controller.startCareer(
      name: 'GK',
      position: Position.gk,
      age: 20,
      agent: Agent.pool.first,
    );
    await pumpHub(tester, controller, height: 2600);
    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    final shape = tester.widget<AttributeShape>(find.byType(AttributeShape));
    expect(shape.keys.contains(AttributeKey.goalkeeping), isTrue);
  });

  testWidgets('次の試合は、両クラブのエンブレムで出る', (tester) async {
    // 一番よく見るカードなのに、相手が文字でしか出ていなかった。
    final controller = await newCareer();
    await pumpHub(tester, controller);
    final state = controller.state!;
    expect(find.text(state.club.name), findsWidgets);
    expect(find.text(state.opponentFor(state.matchday).name), findsWidgets);
    // 自分と相手で2つ。
    expect(find.byType(ClubCrest), findsWidgets);
  });

  testWidgets('選手作成で、付く特性を見て引き直せる', (tester) async {
    // 特性は「始めてから分かるもの」にしていたが、2つの長所で選手の性格が
    // ほとんど決まるのに、見えないまま20年ぶんの選択をすることになっていた。
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: CreatePlayerScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('生まれ持った特性'), findsOneWidget);
    // 効き方まで出ている（名前だけでは何が変わるのか分からない）。
    expect(find.byType(TraitRow), findsWidgets);

    List<String> shown() => tester
        .widgetList<TraitRow>(find.byType(TraitRow))
        .map((row) => row.trait.label)
        .toList();

    final before = shown();
    expect(before, isNotEmpty);

    // 引き直せる。同じ引きが続くこともあるので、何度か押して変化を見る。
    var changed = false;
    for (var i = 0; i < 12 && !changed; i++) {
      await tester.tap(find.widgetWithText(TextButton, '引き直す'));
      await tester.pumpAndSettle();
      changed = shown().join() != before.join();
    }
    expect(changed, isTrue, reason: '引き直しても同じ特性のまま');
    expect(find.textContaining('引き直した'), findsOneWidget);

    // ポジションを変えると引き直す（そのポジションで意味を持つものから引く）。
    await tester.tap(find.widgetWithText(ChoiceChip, Position.gk.label));
    await tester.pumpAndSettle();
    for (final row in tester.widgetList<TraitRow>(find.byType(TraitRow))) {
      expect(row.trait.fitsPosition(Position.gk), isTrue,
          reason: '${row.trait.label} は GK に付かないはず');
    }
  });

  testWidgets('引いた特性が、そのまま始めた選手に付く', (tester) async {
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    const picked = [Trait.clutch, Trait.fighter];
    await controller.startCareer(
      name: '検証',
      position: Position.st,
      age: 20,
      agent: Agent.pool.first,
      traits: picked,
    );
    expect(controller.state!.player.traits, picked);
  });

  testWidgets('選手作成で、左右と割り振りを決められる', (tester) async {
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: CreatePlayerScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    // 中央の役割では、立つ側は聞かれない。
    expect(find.text('立つ側'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, Position.sb.label));
    await tester.pumpAndSettle();
    expect(find.text('立つ側'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, Side.left.label), findsOneWidget);

    // 身体も決められる。
    expect(find.textContaining('身長'), findsWidgets);
    expect(find.textContaining('体重'), findsWidgets);

    // 見た目と背番号は畳んである。
    expect(find.text('見た目と背番号'), findsOneWidget);
    await tester.tap(find.text('見た目と背番号'));
    await tester.pumpAndSettle();
    expect(find.text('髪型'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, HairStyle.curly.label),
        findsOneWidget);

    // 出身国も選べる。
    expect(find.text('出身国'), findsOneWidget);

    // 割り振りは、増やしたぶんを削らないと釣り合わない。
    expect(find.text('割り振りは釣り合っている。'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('合計 +1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove_circle_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('割り振りは釣り合っている。'), findsOneWidget);
  });

  testWidgets('元気なのに休んでいると、伸びないと画面に出る', (tester) async {
    final controller = await newCareer();
    controller.state!.autoRestBelow = 0;
    await controller.setMenu(TrainingMenu.rest);
    controller.state!.player =
        controller.state!.player.copyWith(condition: 100);
    await pumpHub(tester, controller);
    expect(find.text('伸びない'), findsOneWidget);

    // 練習していれば出ない。
    await controller
        .setMenu(TrainingMenu.defaultFor(controller.state!.player.position));
    await tester.pumpAndSettle();
    expect(find.text('伸びない'), findsNothing);
  });

  testWidgets('今週の練習が、試合に入る直前に見える', (tester) async {
    // 育成タブを開かないと今の設定が見えず、設定したことを忘れていた。
    final controller = await newCareer();
    await controller.setMenu(TrainingMenu.athletic);
    await pumpHub(tester, controller);

    expect(find.text('今週の練習'), findsOneWidget);
    // 1行にメニュー・踏み込み方・組む相手が並ぶ。
    expect(find.textContaining(TrainingMenu.athletic.label), findsOneWidget);

    // 押すとその場で選び直せる（画面を移らない）。
    await tester.tap(find.text('変える'));
    await tester.pumpAndSettle();
    expect(find.text(TrainingMenu.sprint.label), findsOneWidget);

    await tester.tap(find.text(TrainingMenu.sprint.label));
    await tester.pumpAndSettle();
    expect(controller.state!.menu, TrainingMenu.sprint);
    // 試合タブに残っていて、表示も入れ替わっている。
    expect(find.text('今週の練習'), findsOneWidget);
    expect(find.textContaining(TrainingMenu.sprint.label), findsOneWidget);
  });

  testWidgets('お金の見通しが、雇う画面に出る', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2600);

    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('自分への投資'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.textContaining('今季の見込み'), findsOneWidget);
    expect(find.textContaining('シーズン末の貯蓄'), findsOneWidget);
  });

  testWidgets('次の試合に、出場の見通しが出る', (tester) async {
    final controller = await newCareer();
    for (var i = 0; i < 6; i++) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller, height: 2400);

    final outlook = controller.outlook!;
    expect(find.text(outlook.headline), findsOneWidget);
    expect(find.text(outlook.reason), findsOneWidget);
    // 判定に使う線が書いてある。
    expect(outlook.reason, contains('先発の線'));
  });

  testWidgets('試合の画面で、成功率の内訳が読める', (tester) async {
    final controller = await newCareer();
    controller.startNextMatch();
    final match = controller.currentMatch!;

    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MatchScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    // どの手にも同じだけ効くものは、局面の側に1度だけ。
    final shared = match.sharedFactors.where((f) => f.notable).toList();
    expect(shared, isNotEmpty);
    for (final f in shared.take(2)) {
      expect(
        find.textContaining(f.label),
        findsWidgets,
        reason: '${f.label} が局面に出ていない',
      );
    }
  });

  testWidgets('終わった試合を開くと、その中身が読める', (tester) async {
    // 結果画面を閉じると二度と見られなかった。
    final controller = await newCareer();
    for (var i = 0; i < 4; i++) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller, height: 2400);

    final result = controller.state!.results.last;
    await tester.dragUntilVisible(
      find.text('直近の試合'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.tap(find.text(result.scoreLine).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('vs ${result.opponentName}'), findsWidgets);
    expect(find.text('評価点'), findsOneWidget);
    expect(find.text('ゴール'), findsWidgets);
  });

  testWidgets('シーズン終了で、セーブの持ち出しを促す', (tester) async {
    final controller = await newCareer();
    while (!controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }
    await controller.finishSeason();

    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: SeasonEndScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('セーブの持ち出し'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('引き継ぎコードを出す'), findsOneWidget);
    // まだ一度も控えていないので、その旨が書いてある。
    expect(find.textContaining('この端末の中にしか無い'), findsOneWidget);
  });

  testWidgets('広い画面でも、本文が読める幅で止まる', (tester) async {
    // PC のブラウザで開くと、カードが画面幅いっぱいまで伸びて読めなかった。
    final controller = await newCareer();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: HubScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    for (final label in ['試合', '選手', '育成', 'クラブ', '記録']) {
      await tester.tap(find.widgetWithText(Tab, label));
      await tester.pumpAndSettle();
      final list = tester.getSize(find.byType(ListView).first);
      expect(list.width, lessThanOrEqualTo(ReadableWidth.maxContentWidth),
          reason: '$label タブが画面幅いっぱいに広がっている');
    }
    // タブそのものも同じ幅に収まっている。
    expect(tester.getSize(find.byType(TabBar)).width,
        lessThanOrEqualTo(ReadableWidth.maxContentWidth));
  });

  testWidgets('日本語フォントを同梱して使っている', (tester) async {
    // 指定を外すと Web 版が外部からフォントを取りに行き、取りきれない字が
    // 豆腐（□）で残る。公開中の画面で実際に起きていた。
    await tester.pumpWidget(const SoccerCareerApp());
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, 'NotoSansJP');
    expect(app.darkTheme?.textTheme.bodyMedium?.fontFamily, 'NotoSansJP');
  });

  testWidgets('記録のタブに通算がまとまっている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();

    expect(find.text('通算'), findsOneWidget);
    expect(find.text('試合'), findsWidgets);
    // 1シーズン目でも空にしない。
    expect(find.textContaining('1シーズン目'), findsOneWidget);
  });

  testWidgets('推移のグラフは、2シーズン目から出る', (tester) async {
    final controller = await newCareer(age: 24);
    // 1シーズン目は出さない（点が1つでは形が分からない）。
    await pumpHub(tester, controller, height: 2000);
    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();
    expect(find.text('推移'), findsNothing);

    // 2シーズン分積むと出る。
    for (var i = 0; i < 2; i++) {
      while (!controller.state!.seasonFinished) {
        await controller.simulateMatch();
      }
      await controller.finishSeason();
      await controller.advanceSeason(accepted: controller.renewalOffer!);
    }
    await pumpHub(tester, controller, height: 2000);
    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();
    expect(find.text('推移'), findsOneWidget);
  });

  testWidgets('引き継ぎコードを出せる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引き継ぎコードを出す'));
    await tester.pumpAndSettle();

    expect(find.text('引き継ぎコード'), findsOneWidget);
    expect(find.textContaining('SC1:'), findsOneWidget);
  });

  testWidgets('遊び方ガイドはいつでも開ける', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('遊び方ガイド'), findsOneWidget);

    // 見出しが並んでいて、開くと中身が読める。
    expect(find.text('1週間の流れ'), findsOneWidget);
    await tester.tap(find.text('生まれ持った特性'));
    await tester.pumpAndSettle();
    expect(find.textContaining('長所（'), findsOneWidget);
    expect(find.text('クラッチ'), findsOneWidget);
  });

  testWidgets('シーズンを終えると、主要な動作が切り替わる', (tester) async {
    final controller = await newCareer();
    final state = controller.state!;
    // 日程を消化した状態にする。
    while (!state.seasonFinished) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller);

    expect(
        find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.text('シーズンを終える')),
        findsOneWidget);
  });

  testWidgets('試合の画面は、3つの手を見比べられる', (tester) async {
    final controller = await newCareer();
    controller.startNextMatch();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MatchScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    final match = controller.currentMatch!;
    // 手ごとに成功率が数字と帯で出ている。数字だけだと読み比べになる。
    for (final option in match.current.options) {
      expect(find.text(option.label), findsOneWidget);
    }
    final percent = (match.chanceFor(match.current.options.first) * 100).round();
    expect(find.text('$percent%'), findsWidgets);
    // 相手の戦い方が分かる。
    expect(find.text(match.opponentStyle.label), findsOneWidget);
  });

  testWidgets('シーズン終了の画面が、スマホの幅で崩れない', (tester) async {
    final controller = await newCareer(age: 24);
    while (!controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: SeasonEndScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('シーズン終了'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('オフの過ごし方'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('オフの過ごし方'), findsOneWidget);

    // 契約を選ぶ前に、今季のお金が見えていること。
    await tester.dragUntilVisible(
      find.text('今季のお金'),
      find.byType(ListView).first,
      const Offset(0, 200),
    );
    expect(find.textContaining('今季の見込み'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('契約'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('契約'), findsOneWidget);
  });
}
