import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/game/impact.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/ranking.dart';
import 'package:soccer_career/game/weekly_plan.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/ui/attribute_shape.dart';
import 'package:soccer_career/ui/club_identity.dart';
import 'package:soccer_career/ui/pitch_view.dart';
import 'package:soccer_career/ui/player_banner.dart';
import 'package:soccer_career/ui/trait_row.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_career/monetize/monetization.dart';
import 'package:soccer_career/monetize/ad_service.dart';
import 'package:soccer_career/monetize/purchase_service.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/readable_width.dart';
import 'package:soccer_career/models/look.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/challenge.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/ui/screens/create_player_screen.dart';
import 'package:soccer_career/ui/app_theme.dart';
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

/// 保存領域を持たない環境でも回るように、殿堂も差し替えられるようにしておく。
/// 実物は SharedPreferences を待つので、引退させる画面はここを渡さないと止まる。
class MemoryHall implements HallRepository {
  Hall _saved = const Hall();

  @override
  Future<Hall> load() async => _saved;

  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

Future<CareerController> newCareer({
  int seed = 1,
  int age = 20,
  HallRepository? hallRepository,
}) async {
  final controller = CareerController(
    repository: _MemoryRepository(),
    hallRepository: hallRepository,
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
  Monetization? monetization,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) =>
            HubScreen(controller: controller, monetization: monetization),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// タブを開き、節に割れているタブでは札も押す。
Future<void> openTab(WidgetTester tester, String tab, {String? section}) async {
  await tester.tap(find.widgetWithText(Tab, tab));
  await tester.pumpAndSettle();
  if (section != null) {
    await tester.tap(find.text(section));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('拠点は5つのタブに分かれている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    for (final label in ['今週', '選手', '育成', 'クラブ', '記録']) {
      expect(
        find.widgetWithText(Tab, label),
        findsOneWidget,
        reason: '$label タブが無い',
      );
    }
  });

  testWidgets('主要な動作は、スクロールしなくても押せる位置にある', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    // 今週タブでは、カードの中のボタンが主役。FAB は出さない
    // （出すと「区切りまで」など下の操作に被さる）。
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, '試合へ'), findsOneWidget);

    // 他のタブでは、どこに居ても FAB から試合に入れる。
    for (final tab in ['選手', '育成', 'クラブ', '記録']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget, reason: tab);
      expect(
        find.descendant(of: fab, matching: find.text('試合へ')),
        findsOneWidget,
      );
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

  testWidgets('育成のタブで、個人技の取得条件が読めて、狙える', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2000);

    await openTab(tester, '育成', section: '長い目で狙う');

    expect(find.text('個人技を狙う'), findsOneWidget);

    // 候補は畳んである。開くと、取得条件が全部書いてある。
    await tester.dragUntilVisible(
      find.text('狙う技を選ぶ'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('狙う技を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('狙う技を選ぶ'));
    await tester.pumpAndSettle();

    final player = controller.state!.player;
    // 一番遠いものを見る。届いているものは文言が変わる。
    final signature = [...Signature.forPosition(player.position)]
      ..sort(
        (a, b) => player.attributes
            .detail(a.detail)
            .compareTo(player.attributes.detail(b.detail)),
      );
    final target = signature.first;
    final value = player.attributes.detail(target.detail);
    expect(value, lessThan(Signature.requirement));
    await tester.ensureVisible(find.text(target.label));
    await tester.pumpAndSettle();
    // **元になる能力・必要な値・今の値・あと何**。ここが「取得方法」。
    expect(
      find.textContaining(
        '${target.detail.label} $value '
        '（${Signature.requirement}で覚えられる、'
        'あと${Signature.requirement - value}）',
      ),
      findsOneWidget,
    );

    // 押すと狙える。
    await tester.tap(find.text(target.label));
    await tester.pumpAndSettle();
    expect(controller.state!.signatureAim, target);
    expect(find.text('狙っている'), findsOneWidget);
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
    expect(
      find.textContaining('消耗 ${TrainingMenu.athletic.conditionCost}'),
      findsOneWidget,
    );
    // 専属スタッフと生活習慣は畳んである（「長い目で狙う」の側）。
    // **高さ決め打ちで探さない。** タブにカードを足すたびに下端が
    // 画面から出て、この検査が「畳んである」と無関係に落ちる。
    await tester.tap(find.text('長い目で狙う'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('専属スタッフ'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
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
    // 積み上げは「人となり」の側。同じタブの中にあることは変わらない。
    await tester.tap(find.text('人となり'));
    await tester.pumpAndSettle();
    expect(find.text('積み上げ'), findsOneWidget);
  });

  testWidgets('選手のタブで、特性がどこで効くかと今季の回数が読める', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2400);

    await openTab(tester, '選手', section: '人となり');

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
    expect(find.textContaining(RegExp('今季|試合の外で効く')), findsAtLeastNWidgets(1));
  });

  // **タブの高さは、放っておくと静かに伸びる。**
  // カードを1枚足すのは安いので、毎回少しずつ伸びて、気付いたときには
  // 「どのタブもスクロールが多い」になっている。内訳は `test/scroll_sim.dart`。
  testWidgets('どのタブも節も、スマホ2画面に収まる', (tester) async {
    final controller = await newCareer(age: 24);
    for (var i = 0; i < 9; i++) {
      if (controller.pendingEvent != null) {
        await controller.resolveEvent(controller.pendingEvent!.choices.first);
      }
      await controller.simulateMatch();
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpHub(tester, controller);

    // 節に割ってあるタブは、札ごとに見る。
    const keys = {
      '今週': 'tab-match',
      '選手|能力': 'tab-player',
      '選手|人となり': 'tab-player-person',
      '育成|今週決める': 'tab-training',
      '育成|長い目で狙う': 'tab-training-aim',
      'クラブ|立ち位置': 'tab-club',
      'クラブ|この国と、世界': 'tab-club-world',
      '記録|今季': 'tab-career',
      '記録|これまで': 'tab-career-total',
    };
    // タブバーと見出しを引いた見えている高さは 740px、
    // 札のあるタブは 688px。2画面弱＝1600px を上限に置く。
    for (final tab in keys.keys) {
      final parts = tab.split('|');
      await tester.tap(find.widgetWithText(Tab, parts.first));
      await tester.pumpAndSettle();
      if (parts.length > 1) {
        await tester.tap(find.text(parts[1]));
        await tester.pumpAndSettle();
      }
      final list = find.byKey(PageStorageKey(keys[tab]!));
      final state = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      var last = 0.0;
      for (var i = 0; i < 40; i++) {
        final max = state.position.maxScrollExtent;
        if (max <= last) break;
        last = max;
        state.position.jumpTo(max);
        await tester.pumpAndSettle();
      }
      var bottom = 0.0;
      for (var offset = 0.0; offset <= last; offset += 200) {
        state.position.jumpTo(offset);
        await tester.pumpAndSettle();
        final sliver = tester
            .renderObject<RenderViewport>(
              find.descendant(of: list, matching: find.byType(Viewport)),
            )
            .firstChild!;
        final listSliver = sliver is RenderSliverPadding
            ? sliver.child! as RenderSliverList
            : sliver as RenderSliverList;
        RenderBox? child = listSliver.firstChild;
        while (child != null) {
          final data = child.parentData! as SliverMultiBoxAdaptorParentData;
          final foot = (data.layoutOffset ?? 0) + child.size.height;
          if (foot > bottom) bottom = foot;
          child = listSliver.childAfter(child);
        }
      }
      expect(16 + bottom + 96, lessThan(1600), reason: '$tab がスマホ2画面を超えている');
      state.position.jumpTo(0);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('クラブのタブに順位表がある', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await openTab(tester, 'クラブ');
    // 既定は「立ち位置」の側。
    expect(find.text('クラブでの立ち位置'), findsOneWidget);

    await tester.tap(find.text('この国と、世界'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('順位表'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('順位表'), findsOneWidget);
  });

  testWidgets('選んだ方針の効きが、本文に出る', (tester) async {
    final controller = await newCareer();
    await controller.setDirective(Directive.playingTime);
    await pumpHub(tester, controller);

    await tester.tap(find.widgetWithText(Tab, 'クラブ'));
    await tester.pumpAndSettle();
    // ツールチップに隠すと、スマホでは長押ししないと読めない。
    await tester.dragUntilVisible(
      find.text(Directive.playingTime.effect),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text(Directive.playingTime.effect), findsOneWidget);
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
    await openTab(tester, 'クラブ', section: 'この国と、世界');
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
    // 代表の線は国の格で動く。判定と同じ数字が出ていること。
    final line = Formulas.callUpLineFor(
      World.byId(controller.state!.nationalTeam).prestige,
    );
    expect(find.textContaining('代表の線（総合力$line）'), findsOneWidget);
  });

  testWidgets('クラブのタブで、リーグが世界の何位か分かる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2400);

    await openTab(tester, 'クラブ', section: 'この国と、世界');

    await tester.dragUntilVisible(
      find.text('リーグの格付け'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    final mine = Ranking.of(
      controller.state!.club.countryId,
      controller.state!.club.tier,
    );
    expect(
      find.textContaining('世界${mine.rank}位 / ${mine.total}リーグ'),
      findsOneWidget,
    );
    expect(find.text('世界のリーグ一覧'), findsOneWidget);
  });

  testWidgets('育成のタブで、育てる方向を選べる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 3200);

    await openTab(tester, '育成', section: '長い目で狙う');
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
    await tester.tap(
      find.widgetWithText(FilterChip, '${Detail.finishing.label} $value'),
    );
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

    await openTab(tester, '育成', section: '長い目で狙う');

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
    expect(plan.headline, contains(state.opponentFor(state.matchday).name));
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
    expect(
      find.descendant(
        of: find.byType(PlayerBanner),
        matching: find.text(controller.state!.player.name),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PlayerBanner),
        matching: find.text('${controller.state!.player.overall}'),
      ),
      findsOneWidget,
    );

    // 能力の形。棒は残す（正確な値はそちらで読む）。
    final shape = tester.widget<AttributeShape>(find.byType(AttributeShape));
    expect(shape.keys, isNotEmpty);
    expect(
      shape.keys.contains(AttributeKey.goalkeeping),
      isFalse,
      reason: 'GK 以外に GK 能力の頂点が出ている',
    );
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

  testWidgets('選手を作る場所に、挑戦の達成数が出る', (tester) async {
    // 挑戦は殿堂の中にあるので、開かないと存在に気付かない。
    // 次の選手を作る瞬間が、追うものを見せる場所。
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    controller.hall = const Hall().add(
      Legend.fromJson({'name': '点取り屋', 'goals': 250}),
    );
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: CreatePlayerScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('挑戦 1/${Challenge.values.length}'),
      findsOneWidget,
    );
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
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: CreatePlayerScreen(controller: controller),
      ),
    );
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
      expect(
        row.trait.fitsPosition(Position.gk),
        isTrue,
        reason: '${row.trait.label} は GK に付かないはず',
      );
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
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: CreatePlayerScreen(controller: controller),
      ),
    );
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
    expect(
      find.widgetWithText(ChoiceChip, HairStyle.curly.label),
      findsOneWidget,
    );

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
    controller.state!.player = controller.state!.player.copyWith(
      condition: 100,
    );
    await pumpHub(tester, controller);
    expect(find.text('伸びない'), findsOneWidget);

    // 練習していれば出ない。
    await controller.setMenu(
      TrainingMenu.defaultFor(controller.state!.player.position),
    );
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

    await openTab(tester, '育成', section: '長い目で狙う');
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
    // 判定に使う線が書いてある（離脱中なら、そちらの理由が先に来る）。
    if (!controller.state!.injured && !controller.state!.suspended) {
      expect(outlook.reason, contains('先発の線'));
    }
  });

  testWidgets('試合の画面で、成功率の内訳が読める', (tester) async {
    final controller = await newCareer();
    controller.startNextMatch();
    final match = controller.currentMatch!;

    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MatchScreen(controller: controller),
      ),
    );
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

    // 「直近の試合」は記録タブへ移した（今週の画面は決めることだけにする）。
    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();

    final result = controller.state!.results.last;
    await tester.dragUntilVisible(
      find.text('直近の試合'),
      find.byType(ListView).last,
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
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SeasonEndScreen(controller: controller),
      ),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: HubScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['今週', '選手', '育成', 'クラブ', '記録']) {
      await tester.tap(find.widgetWithText(Tab, label));
      await tester.pumpAndSettle();
      final list = tester.getSize(find.byType(ListView).first);
      expect(
        list.width,
        lessThanOrEqualTo(ReadableWidth.maxContentWidth),
        reason: '$label タブが画面幅いっぱいに広がっている',
      );
    }
    // タブそのものも同じ幅に収まっている。
    expect(
      tester.getSize(find.byType(TabBar)).width,
      lessThanOrEqualTo(ReadableWidth.maxContentWidth),
    );
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

    await openTab(tester, '記録', section: 'これまで');

    expect(find.text('通算'), findsOneWidget);
    expect(find.text('試合'), findsWidgets);
    // 1シーズン目でも空にしない。
    expect(find.textContaining('1シーズン目'), findsOneWidget);
  });

  testWidgets('推移のグラフは、2シーズン目から出る', (tester) async {
    final controller = await newCareer(age: 24);
    // 1シーズン目は出さない（点が1つでは形が分からない）。
    await pumpHub(tester, controller, height: 2000);
    await openTab(tester, '記録', section: 'これまで');
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
    // 見出しが増えたので、画面の下にあることがある。スクロールして探す。
    await tester.dragUntilVisible(
      find.text('生まれ持った特性とコツ'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('生まれ持った特性とコツ'));
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
        matching: find.text('シーズンを終える'),
      ),
      findsOneWidget,
    );
  });

  test('テーマの書体が、文字の表まで届いている', () {
    // **`ThemeData(textTheme: ...)` を明示すると `fontFamily` はそこに
    // 適用されない。** 自前で組んだ表を渡した瞬間、全部が既定の書体に
    // 落ちて**日本語がまるごと豆腐（□）になる**（実際になった）。
    // `font_test` は「その文字がフォントにあるか」しか見ないので拾えない
    // ——書き出して目で見るまで分からなかった。
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = appTheme(
        const Color(0xFF1B5E3F),
        brightness,
        fontFamily: 'NotoSansJP',
      );
      for (final style in [
        theme.textTheme.bodyMedium,
        theme.textTheme.titleLarge,
        theme.textTheme.labelSmall,
        theme.textTheme.headlineSmall,
      ]) {
        expect(
          style?.fontFamily,
          'NotoSansJP',
          reason: '文字の表に書体が乗っていない（豆腐になる）',
        );
      }
    }
  });

  testWidgets('試合の画面は、3つの手を見比べられる', (tester) async {
    final controller = await newCareer();
    controller.startNextMatch();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MatchScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final match = controller.currentMatch!;
    // 手ごとに成功率が数字と帯で出ている。数字だけだと読み比べになる。
    for (final option in match.current.options) {
      expect(find.text(option.label), findsOneWidget);
    }
    final percent = (match.chanceFor(match.current.options.first) * 100)
        .round();
    expect(find.text('$percent%'), findsWidgets);
    // 相手の戦い方が分かる。
    expect(find.text(match.opponentStyle.label), findsOneWidget);
    // 局面がピッチの絵になっていて、その場所が言葉でも添えてある。
    expect(find.byType(PitchView), findsOneWidget);
    expect(find.text(match.current.spot.label), findsOneWidget);

    // **局面のカードは、スクロールできる枠の3分の2までに収める。**
    // ここが太ると、3つの手が丸ごと画面の外に出る——実測で
    // 433px（枠の81%）あった頃は、18の手のうち16が外に出ていた
    // （`test/scroll_sim.dart` の「match screen fold」）。
    // カードを1行増やすのは安いので、放っておくと静かに伸びる。
    final view = tester.renderObject<RenderBox>(
      find.byType(SingleChildScrollView).first,
    );
    final card = tester.renderObject<RenderBox>(
      find.descendant(of: find.byType(Card), matching: find.byType(PitchView)),
    );
    final cardBox = card.parent! as RenderBox;
    expect(
      cardBox.size.height,
      lessThan(view.size.height * 2 / 3),
      reason: '局面のカードが枠の3分の2を超えている',
    );
  });

  testWidgets('シーズン終了の画面が、スマホの幅で崩れない', (tester) async {
    final controller = await newCareer(age: 24);
    while (!controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SeasonEndScreen(controller: controller),
      ),
    );
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

  testWidgets('始められない理由が、ボタンの下に書いてある', (tester) async {
    // ボタンが灰色なだけでは、2画面ぶんスクロールした先で
    // 何が足りないのか分からなかった。
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: CreatePlayerScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('キャリアを始める'),
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('選手名を入れる'), findsOneWidget);
    expect(find.textContaining('代理人を選ぶ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'テスト');
    await tester.pumpAndSettle();
    expect(find.textContaining('選手名を入れる'), findsNothing);
    expect(find.textContaining('代理人を選ぶ'), findsOneWidget);
  });

  testWidgets('試合の途中では「戻る」で抜けられない', (tester) async {
    // 抜けると次に「試合へ」を押した瞬間に同じ節が引き直され、
    // 選んだ手が消える（Android の戻るボタン・ブラウザの戻る）。
    final controller = await newCareer();
    controller.startNextMatch();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MatchScreen(controller: controller),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);

    // maybePop は PopScope が止めたときも true を返す（止めるのも「処理」）。
    // 見るのは画面が残っているかどうか。
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
  });

  testWidgets('シーズン終了の画面は「戻る」で抜けられない', (tester) async {
    // initState で finishSeason() を済ませているので、抜けて入り直すと
    // 大陸カップの結果が二度確定する。
    final controller = await newCareer();
    while (!controller.state!.seasonFinished) {
      if (controller.pendingEvent != null) {
        await controller.resolveEvent(controller.pendingEvent!.choices.first);
      }
      await controller.simulateMatch();
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SeasonEndScreen(controller: controller),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // maybePop は PopScope が止めたときも true を返す（止めるのも「処理」）。
    // 見るのは画面が残っているかどうか。
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(SeasonEndScreen), findsOneWidget);
  });

  testWidgets('タブを行き来しても、スクロール位置が戻らない', (tester) async {
    // 鍵が無いと TabBarView が画面外のタブを捨て、育成タブで下まで見て
    // 試合タブへ戻り、また育成へ行くと先頭に戻されていた。
    final controller = await newCareer();
    await pumpHub(tester, controller);
    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.widgetWithText(Tab, '今週'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();
    final after = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(after, before);
  });

  testWidgets('今シーズンの成績に、出た試合と出なかった試合が出る', (tester) async {
    // 自分が出る試合はそのぶんクラブが強いのに、それが見える場所が無かった。
    //
    // **このテストは長いあいだ何も見ていなかった。** カードは記録タブに
    // あるのに開かないまま探していて、しかも「出なかった試合がまだ無い種
    // もある」と `return` していたので、その種では**素通りして緑になる**。
    // 実際その種は出なかった試合が 0 で、毎回 return していた。
    // 開く・出る側も出ない側も必ず見る、の2つを直した。
    final controller = await newCareer();
    for (var i = 0; i < 20; i++) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller, height: 2400);
    await openTab(tester, '記録');
    expect(find.textContaining('今シーズンの成績'), findsOneWidget);

    final impact = Impact.of(controller.state!.leagueResults);
    if (impact.comparable) {
      expect(
        find.textContaining('出た試合 ${impact.with_.label}'),
        findsOneWidget,
      );
      expect(
        find.textContaining('出なかった試合 ${impact.without.label}'),
        findsOneWidget,
      );
    } else {
      // 比べるだけの材料が無いなら、**出さない**のが正しい。
      expect(find.textContaining('出なかった試合'), findsNothing);
    }
  });


  testWidgets('広告と課金は、渡したときだけメニューに出る', (tester) async {
    // **ブラウザ版とテストには広告も課金も無い。** 出す仕組みを
    // 無条件に置くと、繋がらないストアのボタンが並ぶことになる。
    final controller = await newCareer();
    await pumpHub(tester, controller);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('広告・応援'), findsNothing);
  });

  testWidgets('広告・応援の画面が開き、売り物は2つだけ', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final money = Monetization(
      ads: NoAdService(),
      purchases: NoPurchaseService(),
    );
    await money.initialize();
    final controller = await newCareer();
    await pumpHub(tester, controller, monetization: money);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('広告・応援'));
    await tester.pumpAndSettle();

    // 見出しとボタンで2つ出る。
    expect(find.text('広告を消す'), findsWidgets);
    expect(find.text('応援する'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '広告を消す'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '応援する'), findsOneWidget);
    // iOS の審査要件。
    expect(find.text('購入を復元'), findsOneWidget);
    // 強くなるものを売っていないことを、最初に書く。
    expect(find.textContaining('強くなるものは売っていない'), findsOneWidget);
    // ストアに繋がらない環境では押せない。
    final buy = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '広告を消す'),
    );
    expect(buy.onPressed, isNull);
  });

  testWidgets('引退した季も、広告の機会として数える', (tester) async {
    // 引退はシーズン終了の画面から行くので、`_endSeason` の広告を
    // そのまま通る（`retire()` が最後の季を履歴に足す）。
    // **キャリアで一番最後の1回**なので、落とすとそのまま消える。
    SharedPreferences.setMockInitialValues({});
    final money = Monetization(
      ads: NoAdService(),
      purchases: _FakeStoreForUi(available: true),
    );
    await money.initialize();

    final controller = await newCareer(age: 21);
    while (!controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }
    await controller.finishSeason();
    final before = controller.state!.history.length;
    await controller.retire();
    final after = controller.state!.history.length;

    expect(after, before + 1, reason: '引退した季が履歴に入っていない');
    expect(controller.state!.retired, isTrue);
    expect(money.shouldShowSeasonAd(seasonsPlayed: after), isTrue);
  });

  testWidgets('広告が出るようになってから、消せることをシーズン終了に書く', (tester) async {
    // **⋮ の奥にしか置いていなかった。** 広告が出ることは分かっても、
    // 消せることを知らないままになる。広告が出る場所で伝える。
    Future<Monetization> money({bool bought = false, bool store = true}) async {
      SharedPreferences.setMockInitialValues(
        bought ? {'monetize.noAds': true} : {},
      );
      final m = Monetization(
        ads: NoAdService(),
        purchases: _FakeStoreForUi(available: store),
      );
      await m.initialize();
      return m;
    }

    Future<void> open(CareerController c, Monetization m) async {
      tester.view.physicalSize = const Size(390, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: SeasonEndScreen(controller: c, monetization: m),
        ),
      );
      await tester.pumpAndSettle();
    }

    final controller = await newCareer();
    while (!controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }
    await controller.finishSeason();

    // 1季目。まだ広告は出ないので、勧めない。
    expect(controller.state!.history.length, lessThan(Monetization.adsFromSeason));
    await open(controller, await money());
    expect(find.widgetWithText(OutlinedButton, '広告を消す'), findsNothing);

    // 広告が出るようになった頃。
    // 季末の画面では履歴がまだ増えていない（増えるのは advanceSeason）。
    for (var i = controller.state!.history.length;
        i < Monetization.adsFromSeason;
        i++) {
      controller.state!.history.add(
        SeasonRecord(
          year: 2026 + i,
          clubName: controller.state!.club.name,
          tier: controller.state!.club.tier,
          leaguePosition: 5,
          stats: const SeasonStats(
            appearances: 0,
            goals: 0,
            assists: 0,
            averageRating: 0,
          ),
          salary: 1000,
          caps: 0,
          objectiveMet: false,
          countryId: controller.state!.countryId,
        ),
      );
    }
    await open(controller, await money());
    expect(find.widgetWithText(OutlinedButton, '広告を消す'), findsOneWidget);

    // 買った人には出さない。
    await open(controller, await money(bought: true));
    expect(find.widgetWithText(OutlinedButton, '広告を消す'), findsNothing);

    // ストアに繋がらない環境（ブラウザ版）にも出さない。
    await open(controller, await money(store: false));
    expect(find.widgetWithText(OutlinedButton, '広告を消す'), findsNothing);
  });
}

/// 価格まで返す偽のストア。`monetize_test` の偽物は本文側に置いてあるので、
/// ここでは画面に必要なぶんだけ持つ。
class _FakeStoreForUi implements PurchaseService {
  _FakeStoreForUi({required this.available});

  final bool available;

  @override
  set onDelivered(void Function(Product product)? callback) {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> priceOf(Product product) async => available ? '¥400' : null;

  @override
  Future<PurchaseOutcome> buy(Product product) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}
