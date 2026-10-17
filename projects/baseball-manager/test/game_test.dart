import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// 決まった方針で最後まで遊ぶ。春夏冬は練習、秋は休養。
/// `stopAt` に達したらその都度の判断で止める(null なら引退まで)。
void _autoPlay(Game g, {bool Function(Game)? stop, int proRetireAge = 40}) {
  var steps = 0;
  while (g.phase != Phase.retired) {
    if (++steps > 3000) fail('終わらない');
    if (stop != null && stop(g)) return;
    switch (g.phase) {
      case Phase.term:
        if (g.stage == Stage.pro && g.player.age >= proRetireAge) {
          g.retire();
        } else {
          g.choose(g.term == Term.autumn ? Action.rest : Action.train, Ability.contact);
        }
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Route.university);
      case Phase.retired:
        break;
    }
  }
}

Game _new(int seed, {int? potential, Role role = Role.batter}) => Game.newGame(
    name: 'テスト', role: role, rng: Random(seed), potential: potential);

void main() {
  test('どの乱数でも、6歳から引退まで必ず終わる', () {
    for (var s = 0; s < 60; s++) {
      final g = _new(s);
      _autoPlay(g);
      expect(g.phase, Phase.retired);
      expect(g.ending, isNotNull);
      expect(g.stage, Stage.retired);
      expect(g.player.age, inInclusiveRange(19, maxProAge + 1));
    }
  });

  test('同じ乱数なら同じ人生になる', () {
    final a = _new(5), b = _new(5);
    _autoPlay(a);
    _autoPlay(b);
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(a.ending!.title, b.ending!.title);
  });

  test('素質の高い選手のほうがプロに入りやすい', () {
    int pros(int potential) {
      var n = 0;
      for (var s = 0; s < 120; s++) {
        final g = _new(s, potential: potential);
        _autoPlay(g, proRetireAge: 19);
        if (g.ending!.madePro) n++;
      }
      return n;
    }

    expect(pros(95), greaterThan(pros(5)));
  });

  test('プロにはなれずに終わる人生と、プロになる人生の両方がある', () {
    var pro = 0, no = 0;
    for (var s = 0; s < 200; s++) {
      final g = _new(s);
      _autoPlay(g);
      g.ending!.madePro ? pro++ : no++;
    }
    expect(pro, greaterThan(0));
    expect(no, greaterThan(0));
  });

  test('1年は4季節で、冬の次に年齢が1つ進む', () {
    final g = _new(1);
    var guard = 0;
    while (g.player.age == startAge) {
      if (++guard > 50) fail('年が進まない');
      g.phase == Phase.event
          ? g.resolveEvent(0)
          : g.choose(Action.rest, Ability.contact);
    }
    expect(g.player.age, startAge + 1);
    expect(g.term, Term.spring);
  });

  test('段階に合わない操作は拒否される', () {
    final g = _new(1);
    expect(() => g.resolveEvent(0), throwsStateError);
    expect(() => g.chooseRoute(Route.university), throwsStateError);
    expect(() => g.giveUp(), throwsStateError);
    expect(() => g.retire(), throwsStateError); // プロではない
    expect(() => g.changeRole(Role.twoWay), throwsStateError); // プロではない
    expect(() => g.choose(Action.train, Ability.stuff), throwsArgumentError);
  });

  test('ドラフトに外れると進路を選べて、再挑戦が外れたら終わる', () {
    // 素質ゼロの選手で、必ず外れるまで進める。
    final g = _new(3, potential: 0);
    _autoPlay(g, stop: (g) => g.phase == Phase.pathChoice);
    expect(g.phase, Phase.pathChoice);
    expect(g.stage, Stage.pathChoice);
    g.chooseRoute(Route.corporate);
    expect(g.route, Route.corporate);
    _autoPlay(g);
    expect(g.player.age, anyOf(graduationAge(Route.corporate), greaterThan(21)));
    expect(g.ending, isNotNull);
  });

  test('諦めると、その場で終わる', () {
    final g = _new(3, potential: 0);
    _autoPlay(g, stop: (g) => g.phase == Phase.pathChoice);
    g.giveUp();
    expect(g.phase, Phase.retired);
    expect(g.ending!.madePro, isFalse);
    expect(g.ending!.title, 'プロにはなれなかった');
  });

  test('プロになったら二刀流に転向でき、記録に残る。自分で引退もできる', () {
    for (var s = 0; s < 100; s++) {
      final g = _new(s, potential: 100);
      _autoPlay(g, stop: (g) => g.stage == Stage.pro && g.phase == Phase.term);
      if (g.stage != Stage.pro) continue;
      g.changeRole(Role.twoWay);
      expect(g.player.role, Role.twoWay);
      g.retire();
      expect(g.ending!.wasTwoWay, isTrue);
      expect(g.ending!.madePro, isTrue);
      return;
    }
    fail('100人試してプロになった選手がいない');
  });

  test('投手でも二刀流でも最後まで遊べる', () {
    for (final role in [Role.pitcher, Role.twoWay]) {
      for (var s = 0; s < 20; s++) {
        final g = Game.newGame(name: 't', role: role, rng: Random(s));
        var steps = 0;
        while (g.phase != Phase.retired) {
          if (++steps > 3000) fail('終わらない');
          switch (g.phase) {
            case Phase.term:
              if (g.stage == Stage.pro && g.player.age >= 38) {
                g.retire();
              } else {
                g.choose(Action.train, abilitiesOf(role).last);
              }
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Route.corporate);
            case Phase.retired:
              break;
          }
        }
      }
    }
  });

  test('途中で保存して読み直しても、続きが同じになる', () {
    final a = _new(11);
    _autoPlay(a, stop: (g) => g.player.age >= 14 && g.phase == Phase.term);
    final saved = jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>;
    final b = Game.fromJson(saved, Random(99));
    expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
    expect(b.stage, a.stage);
  });

  test('出来事の最中に保存しても、読み直すと同じ選択肢が出る', () {
    final g = _new(2);
    var guard = 0;
    while (g.phase != Phase.event) {
      if (++guard > 200) fail('出来事が起きない');
      g.choose(Action.rest, Ability.contact);
    }
    final b = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(b.phase, Phase.event);
    expect(b.pendingEvent!.id, g.pendingEvent!.id);
  });

  test('欠けた項目のあるセーブでも読める', () {
    final g = Game.fromJson({}, Random(1));
    expect(g.phase, Phase.term);
    expect(g.player.age, startAge);
    expect(g.turnedPro, isFalse);
  });
}
