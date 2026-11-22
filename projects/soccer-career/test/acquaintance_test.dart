// 関わった人に続きを持たせる（2026-11-22）。
//
// - 競争相手と相方は**名簿の実在の人**（以前は乱数で引いた名前で、
//   同じ画面の「同じ枠: 3番目」とは別の世界の人だった）
// - 知り合いは**移籍先の名簿に居て、元の名簿には居ない**
//   （同じ人が2つのクラブに居ない）
// - 引退した人は名簿に出ない
// - 保存に乗り、シーズンを跨いでも残る。古いセーブは空で読む
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/acquaintances.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/squads.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/acquaintance.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/news.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> _start(int seed, {Position position = Position.st}) async {
  final controller = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await controller.startCareer(
    name: '検証',
    position: position,
    age: 20,
    agent: Agent.pool.first,
  );
  return controller;
}

Future<void> _season(CareerController c) async {
  var guard = 0;
  while (c.state!.fixtures.isNotEmpty && guard++ < 200) {
    await c.simulateMatch();
  }
  final offers = [
    if (c.renewalOffer != null) c.renewalOffer!,
    ...c.offers,
  ];
  expect(offers, isNotEmpty);
  await c.advanceSeason(accepted: offers.first);
}

List<Club> _allClubs() => [
  for (final c in World.countries)
    for (var t = 1; t <= c.tiers; t++) ...World.buildLeague(c.id, t),
];

/// 名簿の1人を、別のクラブへ移った知り合いにする。
Acquaintance _movedFrom(Club from, Club to, {int slot = 23}) {
  final p = Squad.of(from, year: 2030).players[slot];
  return Acquaintance(
    seat: p.seat,
    name: p.name,
    position: p.position,
    countryId: p.countryId,
    born: p.born,
    overall: to.strength,
    clubId: to.id,
    bond: Bond.rival,
    metYear: 2029,
  );
}

void main() {
  test('最初の競争相手と相方は、名簿の実在の人', () async {
    final c = await _start(3);
    final s = c.state!;
    final squad = Squad.of(s.club, year: s.year, known: s.acquaintances);
    for (final t in [s.competitor!, s.partner!]) {
      expect(t.seat, isNotNull, reason: '${t.kind} に席が無い（乱数で引いた人のまま）');
      final p = squad.players.where((p) => p.seat == t.seat).toList();
      expect(p, hasLength(1), reason: '${t.name} が名簿に居ない');
      expect(p.single.name, t.name);
    }
    // 競争相手は同じ枠の人。
    expect(
      squad.players.firstWhere((p) => p.seat == s.competitor!.seat)
          .competesWith(s.player.position),
      isTrue,
    );
  });

  test('1季終えると競争相手と相方を覚えていて、次の季にも残る', () async {
    final c = await _start(5);
    await _season(c);
    final bonds = c.state!.acquaintances.map((a) => a.bond).toSet();
    expect(bonds, containsAll([Bond.rival, Bond.partner]));
    final first = c.state!.acquaintances.map((a) => a.seat).toSet();
    await _season(c);
    // **渡し忘れると毎年オフに全員忘れる**（狙いで先に踏んだ形）。
    final second = c.state!.acquaintances.map((a) => a.seat).toSet();
    // 上限（30人）より少ないうちは、誰も忘れない。
    expect(second.containsAll(first), isTrue);
  });

  test('知り合いは移籍先の名簿に居て、元の名簿には居ない', () {
    final league = World.buildLeague(World.countries.first.id, 1);
    final from = league.last;
    final to = league.first;
    final a = _movedFrom(from, to);

    final there = Squad.of(to, year: 2030, known: [a]);
    final back = Squad.of(from, year: 2030, known: [a]);
    expect(there.players.where((p) => p.seat == a.seat), hasLength(1));
    expect(back.players.where((p) => p.seat == a.seat), isEmpty);
    expect(back.players.where((p) => p.name == a.name), isEmpty);

    // 枠の人数は変えない（登録の定員と名簿の形がずれないように）。
    for (final squad in [there, back]) {
      expect(squad.players, hasLength(Squad.size));
      for (final f in ScenarioFamily.values) {
        final base = Squad.of(squad.club, year: 2030);
        expect(
          squad.players.where((p) => p.position.family == f).length,
          base.players.where((p) => p.position.family == f).length,
          reason: '${squad.club.id} の $f',
        );
      }
    }
  });

  test('引退した知り合いは、どの名簿にも出ない', () {
    final league = World.buildLeague(World.countries.first.id, 1);
    final a = _movedFrom(league.last, league.first).copyWith(retiredYear: 2029);
    for (final club in [league.first, league.last]) {
      final squad = Squad.of(club, year: 2030, known: [a]);
      expect(squad.players.where((p) => p.seat == a.seat), isEmpty);
    }
  });

  test('何季か回しても、同じ人が2つのクラブに居ない', () async {
    final c = await _start(7, position: Position.cm);
    for (var i = 0; i < 4; i++) {
      await _season(c);
    }
    final s = c.state!;
    expect(s.acquaintances, isNotEmpty);
    final clubs = _allClubs();
    for (final a in s.acquaintances) {
      final found = [
        for (final club in clubs)
          if (Squad.of(club, year: s.year, known: s.acquaintances)
              .players
              .any((p) => p.seat == a.seat))
            club.id,
      ];
      if (a.retired) {
        expect(found, isEmpty, reason: '${a.name} は引退したのに名簿に居る');
      } else {
        expect(found, [a.clubId], reason: '${a.name} が $found に居る');
      }
    }
  });

  test('覚えておくのは上限まで、記事にするのは1季3本まで', () {
    final clubs = World.buildLeague(World.countries.first.id, 1);
    final people = [
      for (final club in clubs)
        for (var slot = 20; slot < 25; slot++)
          _movedFrom(club, club, slot: slot),
    ];
    expect(people.length, greaterThan(Formulas.acquaintanceKeep));
    final next = Acquaintances.advance(
      people,
      year: 2031,
      nextClub: clubs.first,
    );
    expect(next.people.length, lessThanOrEqualTo(Formulas.acquaintanceKeep));
    expect(
      next.news.length,
      lessThanOrEqualTo(Formulas.acquaintanceNewsPerSeason),
    );
    expect(next.news.every((n) => n.kind == NewsKind.people), isTrue);
  });

  test('器は席から決まり、引き直せない', () {
    const seat = 'albion-t1-c0#5#0';
    expect(Acquaintances.ceilingOf(seat), Acquaintances.ceilingOf(seat));
    for (var i = 0; i < 30; i++) {
      final v = Acquaintances.ceilingOf('x-t1-c$i#$i#0');
      expect(v, inInclusiveRange(-6, 6));
    }
  });

  test('保存して読み戻しても、知り合いは同じ', () async {
    final c = await _start(9);
    await _season(c);
    final s = c.state!;
    final back = CareerState.fromJson(s.toJson());
    expect(
      back.acquaintances.map((a) => a.toJson()).toList(),
      s.acquaintances.map((a) => a.toJson()).toList(),
    );
    expect(back.competitor?.seat, s.competitor?.seat);
  });

  test('知り合いを知らない保存データは、空で読む。壊れた1人は捨てる', () async {
    final c = await _start(9);
    final json = c.state!.toJson()..remove('acquaintances');
    expect(CareerState.fromJson(json).acquaintances, isEmpty);

    final good = _movedFrom(
      World.buildLeague(World.countries.first.id, 1).first,
      World.buildLeague(World.countries.first.id, 1).last,
    );
    json['acquaintances'] = [
      {'name': '席が無い'},
      'こわれている',
      good.toJson(),
    ];
    final read = CareerState.fromJson(json).acquaintances;
    expect(read.map((a) => a.seat), [good.seat]);
  });
}
