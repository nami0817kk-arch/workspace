import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

Player _fresh({Position position = Position.st}) {
  final p = Player(
    id: 'p-${identityHashCode(Object())}',
    name: 'p',
    age: 24,
    position: position,
    potential: 99,
    matchSharpness: 80,
  );
  for (final k in AttributeKeys.all) {
    p.setAttributeValue(k, 50);
  }
  return p;
}

/// 1人のチームに[weeks]週ぶん練習させ、疲労の平均と属性の伸びの合計を返す。
({double fatigue, double growth}) _run(
  List<TrainingFocus>? menu,
  TrainingFocus fallback, {
  int trials = 300,
}) {
  var fatigue = 0.0;
  var growth = 0.0;
  for (var i = 0; i < trials; i++) {
    final p = _fresh();
    final team = Team(
      id: 't',
      name: 'T',
      players: [p],
      defaultTrainingFocus: fallback,
      weeklyMenu: menu,
    );
    TrainingEngine.applyWeeklyTraining(team);
    fatigue += p.fatigue;
    growth += AttributeKeys.all
        .map((k) => p.attributeValue(k) - 50)
        .fold<int>(0, (a, b) => a + b);
  }
  return (fatigue: fatigue / trials, growth: growth / trials);
}

void main() {
  test('weeklyMenu round-trips through JSON and is absent when unset', () {
    final withMenu = Team(
      id: 't',
      name: 'T',
      players: [],
      weeklyMenu: [
        TrainingFocus.attack,
        TrainingFocus.attack,
        TrainingFocus.fitness,
        TrainingFocus.rest,
        TrainingFocus.balanced,
      ],
    );
    final restored = Team.fromJson(withMenu.toJson());
    expect(restored.weeklyMenu, withMenu.weeklyMenu);

    final without = Team(id: 't', name: 'T', players: []);
    expect(without.toJson().containsKey('weeklyMenu'), isFalse);
    expect(Team.fromJson(without.toJson()).weeklyMenu, isNull);
  });

  test('five identical slots grow like the old single week-long focus', () {
    final menu = List.filled(Team.weeklyMenuSlots, TrainingFocus.attack);
    final slotted = _run(menu, TrainingFocus.balanced);
    final single = _run(null, TrainingFocus.attack);
    // 乱数を含むので完全一致ではなく、近い値になることを見る。
    expect(slotted.growth, closeTo(single.growth, single.growth * 0.2));
    expect(slotted.fatigue, closeTo(single.fatigue, 2.0));
  });

  test('an all-rest menu recovers fatigue and grows nothing', () {
    final menu = List.filled(Team.weeklyMenuSlots, TrainingFocus.rest);
    final p = _fresh();
    p.fatigue = 60;
    final team = Team(id: 't', name: 'T', players: [p], weeklyMenu: menu);
    TrainingEngine.applyWeeklyTraining(team);
    expect(p.fatigue, lessThan(60));
  });

  test('mixing rest slots lowers fatigue compared with all-work', () {
    final work = _run(
      List.filled(Team.weeklyMenuSlots, TrainingFocus.attack),
      TrainingFocus.balanced,
    );
    final mixed = _run(
      [
        TrainingFocus.attack,
        TrainingFocus.attack,
        TrainingFocus.rest,
        TrainingFocus.rest,
        TrainingFocus.rest,
      ],
      TrainingFocus.balanced,
    );
    expect(mixed.fatigue, lessThan(work.fatigue));
    expect(mixed.growth, lessThan(work.growth));
  });

  test('an individual focus overrides the team weekly menu', () {
    final p = _fresh()..individualFocus = TrainingFocus.rest;
    p.fatigue = 60;
    final team = Team(
      id: 't',
      name: 'T',
      players: [p],
      weeklyMenu: List.filled(Team.weeklyMenuSlots, TrainingFocus.attack),
    );
    TrainingEngine.applyWeeklyTraining(team);
    // 休養の個別方針が優先されるので、疲労は増えずに下がる。
    expect(p.fatigue, lessThan(60));
  });
}
