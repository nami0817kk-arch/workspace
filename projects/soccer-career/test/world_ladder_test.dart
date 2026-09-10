/// 世界の格が、キャリアの中で階段になっているか。
///
/// 「1部到達 100%」を平坦さの証拠として見ていたが、**測ったら違った** —
/// 19シーズン・550試合を戦うプロが、どこかの1部には届く。これは普通のこと。
/// 平坦だったのは**到達する国の格**のほうで、
/// 実測で 3部相当:24% / 4:32% / **5:43%** と、半分近くが最上位の国に流れ着いていた。
///
/// 直したのは1点だけ。**上の国へは一段ずつしか上がれない**。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/player.dart';

CareerState careerIn(String countryId, {int overall = 90, int caps = 60}) {
  final engine = CareerEngine(random: Random(3));
  final state = engine.startCareer(
    name: '検証',
    position: Position.cm,
    age: 26,
    agent: Agent.pool.last,
    countryId: countryId,
  );
  state.club = World.buildLeague(countryId, 1).first;
  state.caps = caps;
  state.player = Player.rebuild(
    state.player,
    attributes: Attributes.fromDetails(
        {for (final d in Detail.values) d: overall}),
    potential: 99,
  );
  return state;
}

void main() {
  group('上の国へは一段ずつ', () {
    /// その国から声のかかる国の、格の上限。
    int reachFrom(String countryId, {int overall = 90, int caps = 60}) {
      final state = careerIn(countryId, overall: overall, caps: caps);
      final countries =
          CareerEngine(random: Random(3)).reachableCountries(state);
      return countries.map((c) => c.prestige).reduce(max);
    }

    test('格3の国から、いきなり格5へは行けない', () {
      // 一気に2段上がれると、19シーズンあれば誰でも最上位に着く。
      final here = World.byId('yamato').prestige;
      expect(here, 3);
      expect(reachFrom('yamato'), lessThanOrEqualTo(here + 1));
    });

    test('一段ずつなら上がっていける', () {
      // 格4の国に居れば、格5の話は来る。
      expect(World.byId('latium').prestige, 4);
      expect(reachFrom('latium'), 5);
    });

    test('力も名前も無ければ、上の話は来ない', () {
      final weak = reachFrom('yamato', overall: 60, caps: 0);
      expect(weak, lessThanOrEqualTo(World.byId('yamato').prestige));
    });

    test('今いる国は、格に関係なく候補に残る', () {
      // 上限を掛けても、自分の国が候補から落ちてはいけない。
      final state = careerIn('albion', overall: 60, caps: 0);
      final countries =
          CareerEngine(random: Random(3)).reachableCountries(state);
      expect(countries.any((c) => c.id == 'albion'), isTrue,
          reason: '自分の国が候補から落ちている');
    });
  });
}
