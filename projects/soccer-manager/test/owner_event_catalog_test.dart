import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/owner_event.dart';

/// 事件の一覧。18種類が揃い、それぞれ見出し・本文・2つの選択肢を持つ。
void main() {
  test('事件は18種類で、それぞれに見出しと本文がある', () {
    expect(OwnerEventKind.values.length, 18);
    final titles = <String>{};
    for (final k in OwnerEventKind.values) {
      expect(k.title, isNotEmpty, reason: '$k');
      expect(k.body, isNotEmpty, reason: '$k');
      titles.add(k.title);
    }
    expect(titles.length, 18, reason: '見出しが重複している');
  });

  test('選択肢の名前は、事件の中で重複しない', () {
    for (final k in OwnerEventKind.values) {
      final labels = k.options.map((o) => o.label).toSet();
      expect(labels.length, k.options.length, reason: '$k');
    }
  });

  test('資金の増減は、現実的な桁(-1500〜+1500万円)に収まる', () {
    for (final k in OwnerEventKind.values) {
      for (final o in k.options) {
        expect(o.fundsDelta, inInclusiveRange(-1500, 1500), reason: '$k');
      }
    }
  });

  test('期待の増減は、-10〜+10に収まる', () {
    for (final k in OwnerEventKind.values) {
      for (final o in k.options) {
        expect(o.supportersDelta, inInclusiveRange(-10, 10), reason: '$k');
        expect(o.shareholdersDelta, inInclusiveRange(-10, 10), reason: '$k');
      }
    }
  });
}
