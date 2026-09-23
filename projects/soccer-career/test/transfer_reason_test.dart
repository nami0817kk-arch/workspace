/// 移籍の話が来ない理由が、判定と同じ順番で画面に出ること。
///
/// 「日本1部から移籍出来ない」という報告の正体は、契約が残り1年になっても
/// 出場10試合・平均評価6.7に届いていなければ話が来ないのに、画面が
/// 「話が来る」としか書いていなかったこと。
///
/// 続く「自動で進めると移籍できない」は、契約年数そのものだった。
/// 契約中は行き先が上のクラブに狭まるだけになったので、その線も文に出す。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
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

Future<CareerController> _career({String? country}) async {
  final controller = CareerController(
    repository: _Repo(),
    careerEngine: CareerEngine(random: Random(3)),
    matchEngine: MatchEngine(random: Random(3)),
    random: Random(3),
  );
  await controller.startCareer(
    name: 'T',
    position: Position.cm,
    age: 26,
    agent: Agent.pool.first,
    countryId: country,
  );
  return controller;
}

/// シーズンを終わらせたうえで、出場と評価だけを作る。
/// 窓が開くのはシーズンの終わりなので、そこまで進めないと文が出ない。
void _play(CareerState state, {required int matches, required double rating}) {
  state.results.clear();
  final total = state.fixtures.length;
  for (var i = 0; i < total; i++) {
    state.results.add(
      MatchResult(
        matchday: i + 1,
        opponentName: 'X',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: i < matches ? Appearance.start : Appearance.benched,
        rating: i < matches ? rating : null,
        goals: 0,
        assists: 0,
      ),
    );
  }
}

void main() {
  test('出場が足りないときは、あと何試合かを書く', () async {
    final controller = await _career();
    final state = controller.state!;
    state.contractYears = 1;
    _play(state, matches: 4, rating: 7.2);
    final label = controller.transferWindowLabel;
    expect(label, contains('あと${Formulas.transferOfferAppearances - 4}試合'));
  });

  test('評価が足りないときは、その数字と線を書く', () async {
    final controller = await _career();
    final state = controller.state!;
    state.contractYears = 1;
    // クラブの器を超えていると評価の門を通ってしまうので、釣り合わせる。
    state.club = Club(
      id: state.club.id,
      name: state.club.name,
      strength: state.player.overall,
      tier: state.club.tier,
      countryId: state.club.countryId,
    );
    _play(state, matches: 20, rating: 6.4);
    final label = controller.transferWindowLabel;
    expect(label, contains('6.40'));
    expect(label, contains('${Formulas.transferOfferRating}'));
  });

  test('契約が残っているときは、上のクラブに限られると書く', () async {
    final controller = await _career();
    final state = controller.state!;
    state.contractYears = 3;
    _play(state, matches: 20, rating: 7.4);
    final label = controller.transferWindowLabel;
    expect(label, contains('契約があと3年'));
    expect(label, contains('上のクラブ'));
    expect(label, contains('話が来る'));
  });

  test('契約が残っていて出来が足りなければ、超える線を書く', () async {
    final controller = await _career();
    final state = controller.state!;
    state.contractYears = 3;
    _play(state, matches: 20, rating: 6.8);
    final label = controller.transferWindowLabel;
    expect(label, contains('6.80'));
    expect(label, contains('${Formulas.transferUnderContractRating}'));
  });

  test('両方満たしていれば「話が来る」と書く', () async {
    final controller = await _career();
    final state = controller.state!;
    state.contractYears = 1;
    _play(state, matches: 20, rating: 7.2);
    expect(controller.transferWindowLabel, contains('話が来る'));
  });

  test('契約が残っていれば、そちらを先に言う', () async {
    final controller = await _career();
    final state = controller.state!;
    state.contractYears = 3;
    _play(state, matches: 2, rating: 5.0);
    expect(controller.transferWindowLabel, contains('あと3年'));
  });

  test('どこまで声がかかるかと、一段上げるのに要るものを書く', () async {
    final controller = await _career(country: 'yamato');
    final state = controller.state!;
    expect(World.byId(state.club.countryId).prestige, 3);

    // 名前が無いうちは、同じ格の国まで。**何が足りないかを書く**——
    // 「日本1部から移籍できない」はここが見えないことだった。
    expect(controller.transferReachLabel, contains('格3の国まで'));
    expect(controller.transferReachLabel, contains('代表10キャップ'));

    // 代表に呼ばれれば、一段上がる。
    state.caps = 10;
    expect(controller.transferReachLabel, contains('格4の国まで'));

    // 最上位の国だけは、さらに名前が要る。
    expect(
      controller.transferReachLabel,
      contains('${Formulas.eliteCaps}キャップ'),
    );
  });
}
