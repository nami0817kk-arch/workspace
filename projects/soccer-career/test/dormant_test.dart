/// 「作ってあるのに効いていない」ものの見張り。
///
/// このプロジェクトで繰り返し出てくる壊れ方は、機能が無いことではなく
/// **作った仕組みが画面にも判定にも届いていない**こと。
/// 出身国・生活水準・`SelectionOutlook` の離脱・移籍の窓が全部これだった。
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/support.dart';
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

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
    name: '検証',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  group('生活習慣がプロ意識になる', () {
    test('整えた生活は上げ、崩した生活は下げる', () async {
      // `Habits.disciplined` / `reckless` は「プロ意識が上がりやすいか」と
      // 書いてあるのに、どこからも読まれていなかった。
      Future<int> drift(Habits habits) async {
        var total = 0;
        for (var seed = 0; seed < 24; seed++) {
          final c = await started(seed: seed);
          final state = c.state!;
          state.habits = habits;
          // メンターと年齢のぶんが混ざらない条件に寄せる。
          state.mentor = null;
          state.player = state.player.copyWith(age: 25);
          final before = state.player.personality.professionalism;
          final after = Person(random: Random(seed))
              .evolve(state)
              .professionalism;
          total += after - before;
        }
        return total;
      }

      final steady = await drift(const Habits(sleep: 2, diet: 2));
      final plain = await drift(const Habits(sleep: 1, diet: 1));
      final rough = await drift(const Habits(sleep: 0, diet: 0));

      expect(steady, greaterThan(plain), reason: '整えた生活が効いていない');
      expect(rough, lessThan(plain), reason: '崩した生活が効いていない');
    });

    test('毎季必ずは動かさない（練習の効きが膨らむ）', () async {
      // 出来事のときに、繰り返し動かして総合力が膨らんだことがある。
      var moved = 0;
      for (var seed = 0; seed < 40; seed++) {
        final c = await started(seed: seed);
        final state = c.state!;
        state.habits = const Habits(sleep: 2, diet: 2);
        state.mentor = null;
        state.player = state.player.copyWith(age: 25);
        final before = state.player.personality.professionalism;
        final after = Person(random: Random(seed))
            .evolve(state)
            .professionalism;
        if (after > before) moved++;
      }
      expect(moved, lessThan(40), reason: '毎季必ず上がっている');
      expect(moved, greaterThan(5), reason: 'ほとんど上がらない');
    });

    test('性格が動く幅は1シーズンに1〜2点のまま', () async {
      for (var seed = 0; seed < 24; seed++) {
        final c = await started(seed: seed);
        final state = c.state!;
        state.habits = const Habits(sleep: 2, diet: 2);
        final before = state.player.personality;
        final after = Person(random: Random(seed)).evolve(state);
        for (final axis in PersonalityAxis.values) {
          expect(
            (after[axis] - before[axis]).abs(),
            lessThanOrEqualTo(2),
            reason: '$axis が1シーズンで大きく動いた',
          );
        }
      }
    });
  });

  group('移籍の窓が画面に出る', () {
    test('閉じているときは、いつ動くのかまで書く', () async {
      final c = await started();
      expect(c.transferWindow, TransferWindow.closed);
      expect(c.transferWindowLabel, contains(TransferWindow.closed.label));
      expect(c.transferWindowLabel, contains('シーズンの終わり'));
    });

    test('開いていても、契約が残っていればそう書く', () async {
      final c = await started();
      final state = c.state!;
      // 冬の窓に入る節まで進める。
      while (c.transferWindow == TransferWindow.closed &&
          !state.seasonFinished) {
        await c.simulateMatch();
      }
      expect(c.transferWindow.isOpen, isTrue);
      if (state.contractYears > 1) {
        expect(c.transferWindowLabel, contains('契約があと'));
      }
    });
  });

  group('眠っている仕組みを増やさない', () {
    test('Habits の判断は、どれも読まれている', () {
      // 「作ったのに読まれていない」を、次からは自動で気付けるようにする。
      final source = File('lib/models/support.dart').readAsStringSync();
      final getters = RegExp(
        r'^  (?:bool|double|int) get ([a-z][A-Za-z]*)',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toList();
      expect(getters, contains('disciplined'));

      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) => !f.path
                .replaceAll(r'\', '/')
                .endsWith('lib/models/support.dart'),
          )
          .map((f) => f.readAsStringSync())
          .join('\n');

      for (final getter in getters) {
        expect(
          lib,
          contains(getter),
          reason: 'Habits.$getter は作ってあるが、どこからも読まれていない',
        );
      }
    });

    test('Formulas の定数は、どれも読まれている', () {
      // **数字は `Formulas` から引く**というのがこのプロジェクトの決まりだが、
      // 逆向きの腐り方がある——後から入った仕組みが古い定数を置き換えても、
      // 定数だけが残る。実際に4本が誰にも読まれないまま残っていた:
      // `conditionAfterInjury`（→ `RehabPlan.conditionOnReturn`）、
      // `trainingConditionCost` / `restRecovery`（→ `TrainingMenu`）、
      // `pointsDraw`（順位表が `won * 3 + drawn` と直書きしていた）。
      final source = File('lib/game/formulas.dart').readAsStringSync();
      final names = <String>{
        ...RegExp(
          r'^  static (?:const|final) [\w<>?,\s]+ ([a-z][A-Za-z0-9]*)\s*=',
          multiLine: true,
        ).allMatches(source).map((m) => m.group(1)!),
        ...RegExp(
          r'^  static [\w<>?,\s]+ ([a-z][A-Za-z0-9]*)\(',
          multiLine: true,
        ).allMatches(source).map((m) => m.group(1)!),
      };
      expect(names.length, greaterThan(100), reason: '定数を拾えていない');

      final everywhere =
          [
                ...Directory('lib').listSync(recursive: true).whereType<File>(),
                ...Directory('test')
                    .listSync(recursive: true)
                    .whereType<File>(),
              ]
              .where((f) => f.path.endsWith('.dart'))
              .map((f) => f.readAsStringSync())
              .join('\n');

      for (final name in names) {
        final uses = RegExp(r'\b' + name + r'\b').allMatches(everywhere).length;
        expect(
          uses,
          greaterThan(1),
          reason: 'Formulas.$name は定義されているだけで、どこからも読まれていない',
        );
      }
    });

    test('Offseason の持ち物は、どれも判定に届いている', () {
      // オフの4択は `injuryFactor` を持ち、画面にも「怪我も増える」
      // 「怪我が遠のく」と書いてありながら、**どこからも読まれていなかった**。
      // 実測で 鍛え込む（×1.2）21.5回 / 休む（×0.8）22.6回——倍率が逆に出る。
      final source = File('lib/models/life.dart').readAsStringSync();
      final body = source.substring(source.indexOf('enum Offseason'));
      final fields =
          RegExp(r'^  final [A-Za-z<>?]+ ([a-z][A-Za-z]*);', multiLine: true)
              .allMatches(body.substring(0, body.indexOf('\n}')))
              .map((m) => m.group(1)!)
              .where((n) => n != 'label' && n != 'description')
              .toList();
      expect(fields, contains('injuryFactor'));
      expect(fields, contains('growthFactor'));

      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.replaceAll(r'\', '/').endsWith('lib/models/life.dart'),
          )
          .map((f) => f.readAsStringSync())
          .join('\n');

      for (final field in fields) {
        expect(
          lib,
          contains(field),
          reason: 'Offseason.$field は作ってあるが、どこからも読まれていない',
        );
      }
    });
  });
  test('作った getter が、定義だけで残っていない', () {
    // 2026-09-24 に4つ見つかった:
    // `Names.firstDivision` / `secondDivision`（`World.buildLeague` に
    // 置き換わった旧式の一覧）、`CareerState.isCupWeek`（直書きの比較が
    // 残っていた）、`Country.isLenient`（「制限が緩いほど若い外国人が
    // 入り込みやすい」と書いてあるのに、その効きがどこにも無かった）。
    // **書いてある効きが無いものは、次に読む人を騙す。**
    final sources = <String, String>{
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')))
        file.path: file.readAsStringSync(),
    };
    final everywhere = [
      ...sources.values,
      ...Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync()),
    ].join('\n');

    final names = <String>{};
    final pattern = RegExp(
      r'^  (?:static )?[\w<>?,\s]*? get ([a-z][A-Za-z0-9]{3,})\b',
      multiLine: true,
    );
    for (final source in sources.values) {
      names.addAll(pattern.allMatches(source).map((m) => m.group(1)!));
    }
    expect(names.length, greaterThan(150), reason: 'getter を拾えていない');

    final dead = <String>[];
    for (final name in names) {
      final uses = RegExp(r'\b' + name + r'\b').allMatches(everywhere).length;
      if (uses <= 1) dead.add(name);
    }
    expect(dead, isEmpty, reason: '定義だけで、どこからも読まれていない: ${dead.join(', ')}');
  });
}
