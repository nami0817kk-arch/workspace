/// **引退後の道は、やってきたことで決まる。**
///
/// 引退画面では6つとも自由に選べていた。「やってきたことが、そのまま
/// 次の適性になる」と書いてあるのに、**20年のキャリアが結末に一切
/// 効いていなかった**。しかも殿堂の選手が次のキャリアに現れるのは
/// 監督とコーチだけなので、毎回監督を選ぶのが正解になっていた。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/state/career_controller.dart';

class _Repo implements SaveRepository {
  @override
  Future<CareerState?> load() async => null;
  @override
  Future<void> save(CareerState state) async {}
  @override
  Future<void> clear() async {}
}

Future<CareerController> _started() async {
  final c = CareerController(
    repository: _Repo(),
    careerEngine: CareerEngine(random: Random(6)),
    matchEngine: MatchEngine(random: Random(6)),
    random: Random(6),
  );
  await c.startCareer(
    name: 'T',
    position: Position.cm,
    age: 30,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  test('静かな暮らしは、どのキャリアからでも選べる', () async {
    final c = await _started();
    expect(c.secondCareerBlocked(SecondCareer.quiet), isNull);
    await c.chooseSecondCareer(SecondCareer.quiet);
    expect(c.state!.secondCareer, SecondCareer.quiet);
  });

  test('腕章を巻いていなければ、監督にはなれない', () async {
    final c = await _started();
    c.state!.captain = false;
    expect(c.secondCareerBlocked(SecondCareer.manager), isNotNull);
    await c.chooseSecondCareer(SecondCareer.manager);
    expect(c.state!.secondCareer, isNot(SecondCareer.manager));

    // 腕章とプロ意識が揃えば開く。
    c.state!.captain = true;
    c.state!.player = c.state!.player.copyWith(
      personality: c.state!.player.personality.withAxis(
        PersonalityAxis.professionalism,
        Formulas.managerProfessionalism,
      ),
    );
    expect(c.secondCareerBlocked(SecondCareer.manager), isNull);
    await c.chooseSecondCareer(SecondCareer.manager);
    expect(c.state!.secondCareer, SecondCareer.manager);
  });

  test('貯蓄が足りなければ、実業家にはなれない', () async {
    final c = await _started();
    c.state!.finances = const Finances(savings: 0);
    c.state!.player = c.state!.player.copyWith(
      personality: c.state!.player.personality.withAxis(
        PersonalityAxis.ambition,
        Formulas.entrepreneurAmbition,
      ),
    );
    expect(c.secondCareerBlocked(SecondCareer.entrepreneur), contains('貯蓄'));

    c.state!.finances = Finances(savings: Formulas.entrepreneurSavings);
    expect(c.secondCareerBlocked(SecondCareer.entrepreneur), isNull);
  });

  test('理由は、足りないものを名指しする', () async {
    final c = await _started();
    c.state!.reputation = const Reputation(fame: 0);
    expect(c.secondCareerBlocked(SecondCareer.pundit), contains('知名度'));
    expect(c.secondCareerBlocked(SecondCareer.director), contains('通算出場'));
  });

  test('見立ては、必ず進める道になっている', () async {
    // 見立てが選べない道だと、画面が「そこを目指せ」と言いながら閉じている。
    for (var seed = 0; seed < 20; seed++) {
      final engine = CareerEngine(random: Random(seed));
      final state = engine.startCareer(
        name: 'T',
        position: Position.cm,
        age: 30,
        agent: Agent.pool.first,
      );
      final suggested = engine.secondCareerFor(state);
      expect(
        engine.blockedReason(state, suggested),
        isNull,
        reason: '$seed の見立て ${suggested.label} が選べない',
      );
    }
  });
}
