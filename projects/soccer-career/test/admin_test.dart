/// 管理画面（開発用）。**公開ビルドに入らないこと**が一番大事な検査。
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/dev/admin.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/look.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started({
  int seed = 3,
  Position position = Position.cm,
  int age = 24,
}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: position, age: age, agent: Agent.pool.first);
  return c;
}

void main() {
  group('公開ビルドに入らない', () {
    test('フラグは const で、既定は環境変数だけで決まる', () {
      // kDebugMode（テストは常にデバッグ）なので true。
      // 大事なのは「実行時に切り替わる値ではない」こと。const だからこそ
      // false のビルドでは、参照している枝ごとツリーシェイクで落ちる。
      const flag = kAdmin;
      expect(flag, isTrue);
      expect(const bool.fromEnvironment('SOCCER_ADMIN'), isFalse,
          reason: 'テストは --dart-define なしで走る');
    });

    test('入口は kAdmin でしか開かない', () {
      // 隠しジェスチャーや合言葉のような、実行時に開く道を作らない。
      final source =
          File('lib/ui/screens/hub_screen.dart').readAsStringSync();
      final admin = source.split('AdminScreen(');
      expect(admin.length, 2, reason: '入口が2か所以上ある');
      expect(source, contains('if (kAdmin)'));
      // **参照そのもの**を囲む。メニュー項目だけを囲んで switch の case を
      // 囲み忘れると、公開ビルドに管理画面が丸ごと残る（実際に残っていた）。
      expect(source, contains("case 'admin' when kAdmin:"));
    });

    test('管理画面を、遊ぶ側のコードが参照していない', () {
      // 参照が増えると、ツリーシェイクで落ちきらなくなる。
      final referrers = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.endsWith('lib/dev/admin.dart')) continue;
        if (path.endsWith('lib/ui/screens/admin_screen.dart')) continue;
        final source = file.readAsStringSync();
        if (source.contains('admin_screen.dart') ||
            source.contains('dev/admin.dart')) {
          referrers.add(path);
        }
      }
      expect(referrers, ['lib/ui/screens/hub_screen.dart']);
    });

    testWidgets('拠点のメニューから開ける（管理ビルドのとき）', (tester) async {
      final controller = await started();
      tester.view.physicalSize = const Size(390, 844);
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

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('管理'), findsOneWidget);
      await tester.tap(find.text('管理'));
      await tester.pumpAndSettle();

      for (final tab in ['特性', '状態', '局面', '時間']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget, reason: tab);
      }
    });
  });

  group('改変の印', () {
    test('管理画面で触ると付き、保存を往復しても残る', () async {
      final c = await started();
      expect(c.state!.tampered, isFalse);
      await AdminActions(c).setMorale(30);
      expect(c.state!.tampered, isTrue);

      final restored = CareerState.fromJson(c.state!.toJson());
      expect(restored.tampered, isTrue);
      // 古い保存データには無いので、既定は false。
      final legacy =
          CareerState.fromJson(c.state!.toJson()..remove('tampered'));
      expect(legacy.tampered, isFalse);
    });

    test('シーズンを跨いでも消えない', () async {
      final c = await started();
      await AdminActions(c).setMorale(30);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);
      expect(c.state!.tampered, isTrue);
    });

    testWidgets('選手のタブに出る', (tester) async {
      final controller = await started();
      await AdminActions(controller).setMorale(30);
      tester.view.physicalSize = const Size(390, 2400);
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
      await tester.tap(find.widgetWithText(Tab, '選手'));
      await tester.pumpAndSettle();
      expect(find.text('管理画面で変更済み'), findsOneWidget);
    });
  });

  group('操作', () {
    test('特性を名指しで付け外しできる（排他は見ない）', () async {
      final c = await started();
      final admin = AdminActions(c);
      await admin.clearTraits();
      expect(c.state!.player.traits, isEmpty);

      // 20人に1人の稀な特性も、1回で付く。
      await admin.toggleTrait(Trait.genius);
      await admin.toggleTrait(Trait.eagleEye);
      expect(c.state!.player.traits, contains(Trait.genius));
      expect(c.state!.player.ceilingFor(Detail.vision), 109);

      await admin.toggleTrait(Trait.genius);
      expect(c.state!.player.traits, isNot(contains(Trait.genius)));
    });

    test('能力の上限は特性を見る。超越なら 109 まで入る', () async {
      final c = await started();
      final admin = AdminActions(c);
      await admin.bumpAll(99);
      expect(c.state!.player.attributes.detail(Detail.vision), 99);

      await admin.toggleTrait(Trait.eagleEye);
      await admin.bumpDetail(Detail.vision, 20);
      expect(c.state!.player.attributes.detail(Detail.vision), 109);
      // 対象でない能力は 99 のまま。
      await admin.bumpDetail(Detail.shortPassing, 20);
      expect(c.state!.player.attributes.detail(Detail.shortPassing), 99);
    });

    test('ポテンシャルを変えても、立つ側と見た目は消えない', () async {
      final c = await started(position: Position.wg);
      c.state!.player = c.state!.player.copyWith(side: Side.left);
      final look = c.state!.player.look;
      await AdminActions(c).setPotential(95);
      expect(c.state!.player.potential, 95);
      expect(c.state!.player.side, Side.left);
      expect(c.state!.player.look, look);
    });

    test('局面を指定して試合に入れる', () async {
      final c = await started(position: Position.cb);
      final admin = AdminActions(c);
      // 守り切る展開でしか出ない「止めるための反則」を直接。
      final stop = ScenarioPool.defence
          .firstWhere((s) => s.options.any((o) => o.isTacticalFoul));
      admin.startMatchWith(stop);
      final match = c.currentMatch!;
      expect(match.current.id, stop.id);
      expect(match.scenarios.every((s) => s.id == stop.id), isTrue);
    });

    test('シーズンを消化して、年を飛ばせる', () async {
      final c = await started(age: 30);
      final admin = AdminActions(c);
      await admin.finishSeasonNow();
      expect(c.state!.seasonFinished, isTrue);

      final year = c.state!.year;
      final age = c.state!.player.age;
      await admin.skipYears(3);
      expect(c.state!.year, year + 3);
      expect(c.state!.player.age, age + 3);
      // 時間を飛ばすのは自動進行と同じ道なので、改変の印は付けない。
      // 印は「数字を書き換えた」ことだけを指す。
      expect(c.state!.tampered, isFalse);
    });
  });

  group('重傷の後遺症', () {
    test('立つ側と見た目を落とさない', () {
      // Player.rebuild が両方を引き継いでいなかった。重傷を負うたびに
      // 逆サイドの選手が中央に戻り、似顔まで別人になっていた。
      const look = PlayerLook(skin: 2, hair: HairStyle.curly, hairColor: 1);
      final player = Player(
        name: 'P',
        age: 24,
        position: Position.wg,
        side: Side.left,
        look: look,
        physique: const Physique(heightCm: 175, weightKg: 70),
        attributes: Attributes(
          pace: 70,
          shooting: 60,
          passing: 60,
          dribbling: 70,
          defending: 40,
          physical: 55,
        ),
        potential: 88,
      );
      final after = Player.rebuild(
        player,
        attributes: player.attributes,
        potential: 80,
      );
      expect(after.side, Side.left);
      expect(after.look, look);
      expect(after.potential, 80);
    });
  });
}
