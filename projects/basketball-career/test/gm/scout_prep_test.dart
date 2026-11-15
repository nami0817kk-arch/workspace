import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('スカウトの報告に向け先を答えると下調べが進み、ドラフトの初めにその分野の候補が調べ済みになる', () {
    final c = careerAt(5, 20)..startSeason();
    c.playBlock();
    final m = c.inbox.firstWhere((m) => m.kind == MsgKind.scoutFocus);
    expect(m.needsAnswer, isTrue);
    expect(m.choices, hasLength(ScoutFocus.values.length));
    // 答えるまでは下調べはたまらない
    expect(c.scoutPrep.every((v) => v == 0), isTrue);
    c.answer(m.id, ScoutFocus.bigs.index);
    expect(c.scoutFocus, ScoutFocus.bigs);
    var guard = 0;
    while (c.phase == Phase.season && guard++ < 10) {
      c.declineIncoming();
      c.playBlock();
    }
    expect(c.scoutPrep[ScoutFocus.bigs.index], greaterThanOrEqualTo(60));
    // 保存しても残る
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.scoutFocus, ScoutFocus.bigs);
    expect(back.scoutPrep, c.scoutPrep);
    final prep = c.scoutPrep[ScoutFocus.bigs.index];
    guard = 0;
    while (c.phase != Phase.draft && guard++ < 200) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    expect(c.phase, Phase.draft);
    final scouted = c.prospects.where((p) => p.scouted).toList();
    expect(c.prepScouted, (prep ~/ 25).clamp(0, 4));
    expect(scouted.length, c.prepScouted);
    expect(scouted.every((p) => p.player.pos.big), isTrue);
    expect(scouted.every((p) => p.player.traitsKnown), isTrue);
    // 本当の力は幅の中に入る
    for (final p in scouted) {
      expect(p.player.ovr, inInclusiveRange(p.ovrLo, p.ovrHi));
      expect(p.player.pot, inInclusiveRange(p.potLo, p.potHi));
    }
    expect(c.scoutPrep.every((v) => v == 0), isTrue, reason: 'ドラフトで使い切る');
  });

  test('答えなければ下調べは進まない(自動で遊ぶ GM の釣り合いを変えない)', () {
    final c = careerAt(5, 20)..startSeason();
    var guard = 0;
    while (c.phase != Phase.draft && guard++ < 200) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    expect(c.prepScouted, 0);
    expect(c.prospects.where((p) => p.scouted), isEmpty);
  });

  test('媒体ごとの模擬ドラフトは順位が少しずつ違い、どれも全員に順位が付く', () {
    final c = careerAt(5, 20)..startSeason();
    var guard = 0;
    while (c.phase != Phase.draft && guard++ < 200) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    final rs = [for (var m = 0; m < mockMedia.length; m++) mediaRanks(c.prospects, m)];
    for (final r in rs) {
      expect(r.length, c.prospects.where((p) => p.pickedBy == null).length);
    }
    final differ = c.prospects.where((p) => rs[0][p] != rs[1][p] || rs[1][p] != rs[2][p]).length;
    expect(differ, greaterThan(10));
  });
}
