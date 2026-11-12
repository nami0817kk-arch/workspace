import 'package:flutter_test/flutter_test.dart';

import 'package:basketball_career/gm/career.dart';

void main() {
  test('読んだ知らせは消せて、返事待ちは残る。閉じると返事が要らない知らせは読んだことになる', () {
    final c = Career.start(seed: 3);
    c.ownerMeeting(2);
    c.startSeason();
    for (var i = 0; i < 4 && c.inbox.length < 3; i++) {
      c.playBlock();
    }
    final before = c.inbox.length;
    expect(before, greaterThan(0), reason: '知らせが来ていない');
    c.readAllMessages();
    expect(c.inbox.where((m) => !m.needsAnswer).every((m) => m.read), isTrue);
    final waiting = c.inbox.where((m) => m.needsAnswer).length;
    expect(c.unread, waiting);
    final removed = c.clearReadMessages();
    expect(c.inbox.length, before - removed);
    expect(c.inbox.where((m) => m.needsAnswer).length, waiting);
    expect(c.inbox.every((m) => !m.read || m.needsAnswer), isTrue);
  });
}
