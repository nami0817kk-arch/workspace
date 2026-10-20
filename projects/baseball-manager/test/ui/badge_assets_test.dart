import 'dart:io';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/ui/art/badge_icon.dart';
import 'package:baseball_manager/ui/art/story_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('行動・タブ・背景・節目の絵が、すべて同梱されていて軽い', () {
    final paths = <String>[
      for (final p in Plan.values) planBadgeAsset(p),
      autoYearBadgeAsset,
      ...tabBadgeAssets,
      for (final s in Stage.values) backdropAssetOf(s),
      homeHeroAsset,
      retireImageAsset,
      draftImageAsset,
      championImageAsset,
    ];
    var total = 0;
    for (final a in paths.toSet()) {
      final f = File(a);
      expect(f.existsSync(), isTrue, reason: a);
      final size = f.lengthSync();
      expect(size, lessThan(200 * 1024), reason: '$a が重い');
      total += size;
    }
    // 全部で 1.2MB を超えない(アプリを重くしない)
    expect(total, lessThan(1200 * 1024));
  });

  test('行動の絵は、行動ごとに別のファイル', () {
    final set = {for (final p in Plan.values) planBadgeAsset(p)};
    expect(set.length, Plan.values.length);
  });

  testWidgets('絵が読めなければ、代わりの表示が出る(落ちない)', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: BadgeIcon(
        asset: 'assets/icons/ない.png',
        size: 30,
        fallback: Icon(Icons.star, key: Key('fb')),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('fb')), findsOneWidget);
  });
}
