/// **代理人は、後から変えられる。**
///
/// 実測（12キャリアずつ）で、代理人ごとに届くものは違った——
/// 人脈は届いた話22.3・国の格4.92、交渉は最高年俸13,712、
/// 新人は引退時の貯蓄73,372。ピークはどれも 75.3〜75.6 で変わらない。
/// **それを何も知らない18歳の判断で19シーズン固定していた。**
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';
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
    careerEngine: CareerEngine(random: Random(2)),
    matchEngine: MatchEngine(random: Random(2)),
    random: Random(2),
  );
  await c.startCareer(
    name: 'T',
    position: Position.cm,
    age: 20,
    agent: Agent.pool.first,
  );
  return c;
}

/// リーグ戦を全部消化した状態にする。窓が開くのはシーズンの終わりだけ。
void _finishSeason(CareerState state) {
  for (var i = 0; i < state.fixtures.length; i++) {
    state.results.add(
      MatchResult(
        matchday: i + 1,
        opponentName: 'X',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: 7.0,
        goals: 0,
        assists: 0,
      ),
    );
  }
}

void main() {
  test('シーズンの途中では変えられない', () async {
    final c = await _started();
    c.state!.finances = const Finances(savings: 999999);
    expect(c.canChangeAgent, isFalse);
    expect(c.changeAgent(Agent.pool[1]), isFalse);
    expect(c.state!.agent.name, Agent.pool.first.name);
  });

  test('シーズンの終わりなら、違約金を払って変えられる', () async {
    final c = await _started();
    _finishSeason(c.state!);
    c.state!.finances = const Finances(savings: 999999);
    expect(c.canChangeAgent, isTrue);

    final before = c.state!.finances.savings;
    final fee = c.agentSwitchFee;
    expect(fee, Formulas.agentSwitchFee(c.state!.salary));
    expect(c.changeAgent(Agent.pool[2]), isTrue);
    expect(c.state!.agent.name, Agent.pool[2].name);
    expect(c.state!.finances.savings, before - fee);
  });

  test('払えないなら変えられない', () async {
    final c = await _started();
    _finishSeason(c.state!);
    c.state!.finances = const Finances(savings: 0);
    expect(c.changeAgent(Agent.pool[2]), isFalse);
    expect(c.state!.agent.name, Agent.pool.first.name);
  });

  test('候補に今の代理人は出ない', () async {
    final c = await _started();
    expect(c.agentChoices.any((a) => a.name == c.state!.agent.name), isFalse);
    expect(c.agentChoices.length, Agent.pool.length - 1);
  });

  test('違約金は年俸に比例する。名前が付くほど重い', () {
    expect(
      Formulas.agentSwitchFee(20000),
      greaterThan(Formulas.agentSwitchFee(2000)),
    );
    expect(Formulas.agentSwitchFee(1000), 500);
  });

  test('代理人は保存を往復しても残る', () async {
    final c = await _started();
    _finishSeason(c.state!);
    c.state!.finances = const Finances(savings: 999999);
    c.changeAgent(Agent.pool[3]);
    final back = CareerState.fromJson(c.state!.toJson());
    expect(back.agent.name, Agent.pool[3].name);
  });
}
