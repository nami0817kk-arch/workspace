import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/app/save.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/endings_catalog.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:shared_preferences/shared_preferences.dart';

Game _finishedLife(int seed, {int minAge = 20}) {
  for (var tries = 0; tries < 100; tries++) {
    final rng = Rng(seed + tries * 1000);
    final g = Game(rng: rng);
    g.start(rollBirth(rng));
    final r = Rng(seed + tries);
    var n = 0;
    while (!g.finished && n++ < 3000) {
      g.choose(r.range(0, g.prompt!.choices.length - 1));
    }
    if (g.age >= minAge) return g;
  }
  throw StateError('人生が見つからない');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('終わった人生の最期が図鑑に載り、同じ最期は数だけ増える', () async {
    final store = SaveStore();
    final g = _finishedLife(1);
    expect(await store.recordEnding(g), isTrue);
    expect(await store.recordEnding(g), isFalse);
    final d = await store.dex();
    final key = buildEnding(g).key;
    expect(d.keys, [key]);
    expect(d[key]!.count, 2);
    expect(d[key]!.title, buildEnding(g).title);
    expect(key, isNot(contains(g.l.name)));
  });

  test('手書きの最期でない古い記録は、図鑑に数えない', () async {
    SharedPreferences.setMockInitialValues({
      'ranse.dex.v1': '{"child/byo/":{"k":"child/byo/","t":"病に倒れた幼い命","x":"…","w":"child","d":"byo","n":"太郎","a":31,"y":1597,"c":1}}',
    });
    final store = SaveStore();
    expect(await store.dex(), isEmpty);
    final g = _finishedLife(5);
    expect(await store.recordEnding(g), isTrue);
    expect((await store.dex()).keys, [buildEnding(g).key]);
  });

  test('記す途中で次の人生が始まっても、図鑑にはその人生の名前と歳が残る', () async {
    final store = SaveStore();
    final g = _finishedLife(3);
    final name = g.l.name, age = g.age;
    final key = buildEnding(g).key;
    final pending = store.recordEnding(g);
    // 記している途中で、同じ Game に次の人生を始める。
    g.start(rollBirth(Rng(99)));
    await pending;
    final d = await store.dex();
    expect(d[key]!.name, name);
    expect(d[key]!.age, age);
  });

  testWidgets('タイトルから図鑑を開くと、見た最期が道ごとに並ぶ', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final g = _finishedLife(2);
    await SaveStore().recordEnding(g);
    final e = buildEnding(g);

    final c = AppController(rng: Rng(1));
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('最期の図鑑　1 ／ ${kHandEndings.length}'), findsOneWidget);
    await tester.tap(find.text('最期の図鑑　1 ／ ${kHandEndings.length}'));
    await tester.pumpAndSettle();
    expect(find.textContaining('見た最期 1 ／ '), findsOneWidget);
    // 希少度ごとの数: 見た1本の希少度だけが 1、ほかは 0。合わせて 1001 本。
    final def = kHandEndings.firstWhere((d) => 'hand:${d.id}' == e.key);
    for (final t in Tier.values) {
      final all = kHandEndings.where((d) => d.tier == t).length;
      final seen = t == def.tier ? 1 : 0;
      final w = tester.widget<Text>(find.byKey(ValueKey('dex-tier-${t.name}')));
      expect(w.data, endsWith('$seen ／ $all'));
    }
    await tester.scrollUntilVisible(find.text(e.title), 200);
    expect(find.text(e.title), findsOneWidget);
    expect(find.textContaining(kTierNames[def.tier]!), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
