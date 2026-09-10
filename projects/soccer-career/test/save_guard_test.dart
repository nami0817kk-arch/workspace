/// 保存データの互換の見張り。
///
/// **項目を足したら `fromJson` に既定値を置く**という規約を、手ではなく
/// 機械で守らせる。既定値を忘れると `fromJson` が投げ、`SaveRepository.load`
/// はそれを握り潰して新規扱いにする——つまり**黙ってキャリアが消える**。
/// 更新した途端に消えるのが、このゲームで一番のがっかりなので。
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
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

/// そこそこ進んだキャリア。空の状態だと、埋まっていない項目を見逃す。
Future<CareerState> played({int seed = 5, int matches = 20}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.cm, age: 20, agent: Agent.pool.first);
  for (var i = 0; i < matches; i++) {
    await c.simulateMatch();
  }
  return c.state!;
}

/// JSON の中の、入れ子も含めた全部の鍵を「a.b.c」の形で並べる。
///
/// リストの中は先頭の1つだけ見る（同じ形なので、全部見ても増えない）。
List<String> allKeys(Object? node, [String prefix = '']) {
  if (node is Map) {
    return [
      for (final entry in node.entries) ...[
        '$prefix${entry.key}',
        ...allKeys(entry.value, '$prefix${entry.key}.'),
      ],
    ];
  }
  if (node is List && node.isNotEmpty) {
    return allKeys(node.first, '${prefix}0.');
  }
  return const [];
}

/// 「a.b.c」の鍵を消した写しを返す。消せなければ null。
Map<String, dynamic>? without(Map<String, dynamic> json, String path) {
  final copy =
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  final parts = path.split('.');
  Object? node = copy;
  for (final part in parts.sublist(0, parts.length - 1)) {
    if (node is Map) {
      node = node[part];
    } else if (node is List && part == '0') {
      node = node.isEmpty ? null : node.first;
    } else {
      return null;
    }
  }
  if (node is! Map) return null;
  if (!node.containsKey(parts.last)) return null;
  node.remove(parts.last);
  return copy;
}

/// 初版からある骨格。これが欠けた保存データは、もはやキャリアではない。
///
/// **この一覧を増やすのは、よほどのとき**。後から足した項目がここに入ると、
/// その版から更新した人のキャリアが黙って消える（`SaveRepository.load` は
/// 読めない保存データを消して新規扱いにする）。
/// 新しい項目は `fromJson` に既定値を置くこと。
const structural = {
  'player',
  'player.name',
  'player.age',
  'player.position',
  'player.attributes',
  'player.attributes.details',
  'club',
  'club.id',
  'club.name',
  'club.strength',
  'club.tier',
  'league',
  'league.0.id',
  'league.0.name',
  'league.0.strength',
  'league.0.tier',
  'fixtures',
  'results',
  'results.0.appearance',
  'results.0.assists',
  'history',
  'objective.appearances',
  'objective.contributions',
  'objective.rating',
  'year',
  'table',
  'table.0.clubId',
  'table.0.clubName',
  'table.0.played',
  'table.0.won',
  'table.0.drawn',
  'table.0.lost',
  'table.0.goalsFor',
  'table.0.goalsAgainst',
  'results.0.matchday',
  'results.0.opponentName',
  'results.0.home',
  'results.0.scored',
  'results.0.conceded',
  'results.0.goals',
  'seasonStart.details',
};

void main() {
  group('保存データの互換', () {
    test('骨格の一覧が、実際に骨格だけでできている', () async {
      // 一覧が緩んでいないか。後から足した項目が紛れていたら気付けるように、
      // 数そのものを縛る。増やすときは、なぜ既定値を置けないのかを書く。
      expect(structural.length, 41);
    });

    test('どの項目が欠けても、キャリアは読める', () async {
      // 古い版で保存したデータには、後から足した項目が入っていない。
      // 1つでも既定値を忘れると、その版から更新した人のキャリアが消える。
      final state = await played();
      final json = state.toJson();
      final keys = allKeys(json).toSet().toList()..sort();
      expect(keys.length, greaterThan(80), reason: '鍵の数が少なすぎる');

      final broken = <String>[];
      for (final key in keys) {
        if (structural.contains(key)) continue;
        final stripped = without(json, key);
        if (stripped == null) continue;
        try {
          CareerState.fromJson(stripped);
        } catch (e) {
          broken.add('$key（$e）');
        }
      }
      expect(broken, isEmpty,
          reason: '既定値が無い。この項目を後から足した版から更新すると、'
              'キャリアが黙って消える');

      // 骨格の一覧のほうも、実際に「欠けたら読めない」ことを確かめる。
      // 読めてしまうなら、それは骨格ではないので一覧から外す。
      final softened = <String>[];
      for (final key in structural) {
        final stripped = without(json, key);
        if (stripped == null) continue;
        try {
          CareerState.fromJson(stripped);
          softened.add(key);
        } catch (_) {
          // 読めない = 骨格。正しい。
        }
      }
      expect(softened, isEmpty,
          reason: '既定値があるのに骨格の一覧に入っている。外してよい');
    });

    test('中身が null でも読める', () async {
      // 型が変わった項目や、書き出しに失敗した項目は null で残ることがある。
      final state = await played(seed: 6, matches: 12);
      final json = state.toJson();
      final broken = <String>[];
      for (final key in allKeys(json).toSet()) {
        if (structural.contains(key)) continue;
        final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
        if (!copy.containsKey(key) || key.contains('.')) continue;
        copy[key] = null;
        try {
          CareerState.fromJson(copy);
        } catch (e) {
          broken.add('$key（$e）');
        }
      }
      expect(broken, isEmpty, reason: 'null の項目でキャリアが消える');
    });

    test('往復しても中身が変わらない', () async {
      final state = await played(seed: 7, matches: 15);
      final again = CareerState.fromJson(state.toJson());
      expect(jsonEncode(again.toJson()), jsonEncode(state.toJson()));
    });

    test('引き継ぎコードでも同じことが言える', () async {
      final state = await played(seed: 8, matches: 10);
      final code = SaveRepository.encode(state);
      final back = SaveRepository.decode(code);
      expect(back, isNotNull);
      expect(jsonEncode(back!.toJson()), jsonEncode(state.toJson()));
    });
  });
}
