import 'dart:io';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/art/badge_icon.dart';
import 'package:baseball_manager/ui/art/story_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('行動・タブ・背景・節目の絵が、すべて同梱されていて軽い', () {
    final paths = <String>[
      for (final p in Plan.values) planBadgeAsset(p),
      autoYearBadgeAsset,
      pitcherTrainBadgeAsset,
      ...tabBadgeAssets,
      for (final s in Stage.values) backdropAssetOf(s),
      homeHeroAsset,
      retireImageAsset,
      draftImageAsset,
      championImageAsset,
      titleImageAsset,
      nationalImageAsset,
      worldImageAsset,
      stageImageAsset,
      traitImageAsset,
    ];
    var total = 0;
    for (final a in paths.toSet()) {
      final f = File(a);
      expect(f.existsSync(), isTrue, reason: a);
      final size = f.lengthSync();
      expect(size, lessThan(200 * 1024), reason: '$a が重い');
      total += size;
    }
    // 全部で 1.6MB を超えない(アプリを重くしない)。2026-11-03 に節目の絵5枚と投手の練習の絵を足して
    // 約1.4MB になったので 1.2MB から上げた(同梱のフォントは約12MBあり、絵はその1割ほど)。
    expect(total, lessThan(1600 * 1024));
  });

  test('投球の能力を重点にした「練習」は投げる絵、打撃なら打つ絵', () {
    expect(planBadgeAsset(Plan.train, Ability.stuff), pitcherTrainBadgeAsset);
    expect(planBadgeAsset(Plan.train, Ability.contact), isNot(pitcherTrainBadgeAsset));
    expect(planBadgeAsset(Plan.rest, Ability.stuff), isNot(pitcherTrainBadgeAsset));
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
