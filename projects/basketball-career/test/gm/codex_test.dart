import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/codex.dart';
import 'package:basketball_career/gm/combos.dart';
import 'package:basketball_career/gm/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み B-3: 図鑑。
void main() {
  test('図鑑の項目は重ならず、種類ごとにある', () {
    final keys = codexEntries.map((e) => e.key).toList();
    expect(keys.toSet().length, keys.length);
    for (final k in CodexKind.values) {
      expect(codexEntries.where((e) => e.kind == k), isNotEmpty, reason: k.label);
    }
  });

  test('見つけたものが図鑑に入り、任期をまたいで(保存して読み直しても)残る。前のものは上書きしない', () {
    final c = careerAt(3, 12)..startSeason();
    c.comboSecs[Combo.pnr.index] = comboDiscoverSecs;
    final pf = Profile();
    final got = pf.syncCodex(c);
    expect(pf.codex.containsKey('combo:pnr'), isTrue);
    expect(got.map((e) => e.key), contains('combo:pnr'));
    final note = pf.codex['combo:pnr'];
    // もう一度合わせても、新しくは入らない
    expect(pf.syncCodex(c), isEmpty);
    final back = Profile.fromJson(jsonDecode(jsonEncode(pf.toJson())) as Map<String, dynamic>);
    expect(back.codex['combo:pnr'], note);
    // 別の任期(始め直し)でも残る
    final d = careerAt(4, 12);
    back.syncCodex(d);
    expect(back.codex['combo:pnr'], note);
  });

  test('季を回すと、ドラフトの年や組み合わせが見つかる', () {
    final c = careerAt(5, 12);
    var guard = 0;
    while (c.season < 3 && guard++ < 3000) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    final found = discoveriesOf(c);
    expect(found.keys.where((k) => k.startsWith('draft:')), isNotEmpty);
    for (final k in found.keys) {
      expect(codexEntries.any((e) => e.key == k), isTrue, reason: k);
    }
  });
}
