import 'package:basketball_career/gm/block_report.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('区切りを進めた報告は、この間の勝ち負け・試合・出来事を数える', () {
    final c = Career.start(seed: 7);
    c.ownerMeeting(2);
    c.startSeason();
    final s = BlockSnapshot.of(c);
    c.playBlock();
    final r = BlockReport.make(c, s);
    expect(r.played, c.roundAt);
    expect(r.games.length, r.played);
    expect(r.wins, c.me.wins);
    expect(r.fromGame, 1);
    expect(r.toGame, c.roundAt);
    expect(r.rankAfter, c.confRank);
    // 出来事はログの新しい分だけ(「n年目 」は取る)
    expect([...r.myNews, ...r.leagueNews].every((e) => !e.contains('年目 ')), isTrue);
  });

  test('週で進めた続きの区切りは、進めた分だけを数える', () {
    final c = Career.start(seed: 11);
    c.ownerMeeting(2);
    c.startSeason();
    c.playWeek();
    final s = BlockSnapshot.of(c);
    final before = c.roundAt;
    c.playBlock();
    final r = BlockReport.make(c, s);
    expect(r.fromGame, before + 1);
    expect(r.played, c.roundAt - before);
    expect(r.wins + r.losses, c.me.wins + c.me.losses - s.wins - s.losses);
  });

  test('締め切りをまたぐと deadlinePassed、最後の区切りで seasonOver', () {
    final c = Career.start(seed: 3);
    c.ownerMeeting(2);
    c.startSeason();
    var sawDeadline = false;
    BlockReport? last;
    while (c.phase == Phase.season) {
      final s = BlockSnapshot.of(c);
      c.playBlock();
      last = BlockReport.make(c, s);
      sawDeadline |= last.deadlinePassed;
    }
    expect(sawDeadline, isTrue);
    expect(last!.seasonOver, isTrue);
  });
}
