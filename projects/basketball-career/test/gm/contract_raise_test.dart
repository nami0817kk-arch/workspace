import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自分の選手は最長5年、ほかのチームの選手は4年、30歳からは短い', () {
    final c = careerAt(6, 8);
    final mine = c.me.roster.first..age = 25;
    expect(c.askOf(mine, c.me).maxYears, ownMaxYears);
    mine.age = 31;
    expect(c.askOf(mine, c.me).maxYears, 2);
    final other = c.teams[(c.mine + 1) % c.teams.length].roster.first..age = 25;
    expect(c.askOf(other, c.me).maxYears, 4);
  });

  test('再契約すると毎年の昇給が付き、年俸が少しずつ上がる。1年契約には付かない', () {
    final c = careerAt(6, 8);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
    }
    c.toOffseason();
    guard = 0;
    while (c.phase != Phase.contracts && guard++ < 200) {
      botStep(c);
    }
    final p = c.me.roster.first
      ..morale = 80
      ..age = 25;
    c.expiring = [p.id];
    c.resign(p.id, 1);
    expect(p.raise, 0);
    c.expiring = [p.id];
    c.resign(p.id, 4);
    expect(p.years, 4);
    expect(p.raise, ownRaisePct);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.me.roster.firstWhere((x) => x.id == p.id).raise, ownRaisePct);
  });
}
