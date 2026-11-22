import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/legacy.dart';
import 'package:basketball_career/gm/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み D-1: GM の名鑑。
void main() {
  test('季を回すと、任期の札・名場面が名鑑に残り、保存して読み直しても同じ', () {
    final c = careerAt(3, 2);
    var guard = 0;
    while (c.season < 5 && guard++ < 6000) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    final t = tenuresOf(c);
    expect(t, isNotEmpty);
    expect(t.first.wins.length, c.history.where((r) => r.season >= t.first.from && r.season <= t.first.to).length);
    final pf = Profile()..recordLegacy(c);
    final back = Profile.fromJson(jsonDecode(jsonEncode(pf.toJson())) as Map<String, dynamic>);
    expect(back.legacy[c.seed]!.tenures.length, t.length);
    expect(back.legacy[c.seed]!.moments, pf.legacy[c.seed]!.moments);
    expect(back.legacy[c.seed]!.legends.map((x) => x.name), pf.legacy[c.seed]!.legends.map((x) => x.name));
  });

  test('殿堂の選手は、次のリーグで伝説の選手になる(若手の憧れ・コーチ候補)', () {
    final pf = Profile();
    pf.legacy[1] = (tenures: const [], legends: const [LegendCard(name: '伝説の男', pos: 'SF', pts: 20000, seasons: 10, note: '', best: '')], moments: const []);
    final c = careerAt(4, 12)..legendNames = pf.legendNames;
    expect(c.legendNames, ['伝説の男']);
    final young = c.me.roster.where((p) => p.age <= 23).firstOrNull;
    if (young != null) expect(c.idolOf(young), '伝説の男');
    c.startSeason();
    expect(c.retirees.any((r) => r[0] == '伝説の男'), isTrue);
    expect(c.legendCoachDone, isTrue);
    final y = Career.fromJson(c.toJson());
    expect(y.legendNames, ['伝説の男']);
    expect(y.legendCoachDone, isTrue);
  });
}
