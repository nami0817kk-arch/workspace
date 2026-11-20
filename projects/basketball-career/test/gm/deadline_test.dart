import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('締め切りの前の区切りで知らせが出て、締め切りを迎えると4つの時間帯のまとめが届く', () {
    final c = careerAt(6, 12)..startSeason();
    c.playBlock();
    expect(c.block, tradeDeadlineBlock - 1);
    expect(c.inbox.any((m) => m.title == 'トレードの締め切りが近い'), isTrue);
    expect(c.inbox.any((m) => m.title == '締め切り日のまとめ'), isFalse);
    c.playBlock();
    expect(c.block, tradeDeadlineBlock);
    final m = c.inbox.firstWhere((m) => m.title == '締め切り日のまとめ');
    expect(m.from, Sender.league);
    for (final s in ['朝', '昼', '夕', '直前']) {
      expect(m.body, contains('【$s】'));
    }
    expect(c.log.any((l) => l.contains('トレードの締め切りを迎えた')), isTrue);
    botStep(c);
  });
}
