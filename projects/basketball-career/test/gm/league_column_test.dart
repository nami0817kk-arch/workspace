import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

Career _started(int seed) {
  final c = careerAt(seed, 15);
  while (c.phase != Phase.season) {
    botStep(c);
  }
  return c;
}

void main() {
  test('リーグの話題は、両地区の首位と得点王争いを出し、締め切り前はうわさも出す', () {
    final c = _started(3);
    expect(c.leagueColumn, isEmpty, reason: '開幕前は出さない');
    c.playBlock();
    final col = c.leagueColumn;
    // ignore: avoid_print
    print(col.join('\n'));
    expect(col.where((x) => x.startsWith('東地区')).length, 1);
    expect(col.where((x) => x.startsWith('西地区')).length, 1);
    expect(col.any((x) => x.startsWith('得点王争い')), isTrue);
    expect(col.any((x) => x.startsWith('うわさ')), isTrue);
    // 乱数を使わないので、何度見ても同じ
    expect(c.leagueColumn, col);
  });

  test('自分のトレードと指名にファンが反応し、保存される(見ても乱数は動かない)', () {
    final c = careerAt(5, 15);
    var guard = 0;
    while (c.fanPosts.isEmpty && guard++ < 3000) {
      botStep(c);
    }
    expect(c.fanPosts, isNotEmpty, reason: '自動で遊ぶうちに、トレード・補強・指名のどれかが起きる');
    for (final f in c.fanPosts) {
      expect(f.contains('|'), isTrue);
      expect(int.tryParse(f.split('|').first), isNotNull);
    }
    expect(c.fanPosts.length, lessThanOrEqualTo(Career.fanLimit));
    final back = Career.fromJson(c.toJson());
    expect(back.fanPosts, c.fanPosts);
  });
}
