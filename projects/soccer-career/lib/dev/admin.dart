/// 管理画面（開発用）。**公開ビルドには入らない。**
///
/// [kAdmin] は const なので、false のビルドではこの機能を参照している枝ごと
/// ツリーシェイクで落ちる。「隠す」のではなく「入れない」ことで、
/// 解析されても出てこない形にしてある。
///
/// - 手元の `flutter run`（デバッグ）では常に出る
/// - 手元の release で見たいときは
///   `flutter build web --dart-define=SOCCER_ADMIN=true`
/// - 公開ワークフローはこのフラグを渡さないので、公開サイトには入らない
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/scenarios.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/injury.dart';
import '../models/life.dart';
import '../models/player.dart';
import '../models/reputation.dart';
import '../models/traits.dart';
import '../state/career_controller.dart';

/// 管理画面を出すか。
const bool kAdmin =
    bool.fromEnvironment('SOCCER_ADMIN', defaultValue: false) || kDebugMode;

/// 管理画面からの操作。画面に式を書かず、ここに集める。
///
/// 画面はこれを呼ぶだけにしておくと、テストで同じ道を通せる。
class AdminActions {
  const AdminActions(this.controller);

  final CareerController controller;

  CareerState? get _state => controller.state;

  /// 特性を付け外しする。排他は見ない（確かめたい組み合わせを作れるように）。
  Future<void> toggleTrait(Trait trait) async {
    final state = _state;
    if (state == null) return;
    final traits = [...state.player.traits];
    if (traits.contains(trait)) {
      traits.remove(trait);
    } else {
      traits.add(trait);
    }
    await controller.applyAdmin(
        (s) => s.player = s.player.copyWith(traits: traits));
  }

  Future<void> clearTraits() async {
    await controller
        .applyAdmin((s) => s.player = s.player.copyWith(traits: const []));
  }

  /// 詳細能力を1つ動かす。上限は特性を見て決める（超越なら 109 まで）。
  Future<void> bumpDetail(Detail detail, int delta) async {
    await controller.applyAdmin((s) => s.player = s.player.copyWith(
          attributes: s.player.attributes
              .bumpDetail(detail, delta, max: s.player.ceilingFor(detail)),
        ));
  }

  /// 全部の詳細能力を動かす。総合力をまとめて上げ下げしたいとき。
  Future<void> bumpAll(int delta) async {
    await controller.applyAdmin((s) {
      var attributes = s.player.attributes;
      for (final d in Detail.values) {
        attributes = attributes.bumpDetail(d, delta,
            max: s.player.ceilingFor(d));
      }
      s.player = s.player.copyWith(attributes: attributes);
    });
  }

  Future<void> setPotential(int value) async {
    await controller.applyAdmin((s) => s.player = Player.rebuild(
          s.player,
          attributes: s.player.attributes,
          potential: value.clamp(1, 99),
        ));
  }

  Future<void> setAge(int value) async {
    await controller
        .applyAdmin((s) => s.player = s.player.copyWith(age: value.clamp(15, 45)));
  }

  Future<void> setCondition(int value) async {
    await controller.applyAdmin(
        (s) => s.player = s.player.copyWith(condition: value.clamp(0, 100)));
  }

  Future<void> setMorale(int value) async {
    await controller
        .applyAdmin((s) => s.morale = Morale(value: value.clamp(0, 100)));
  }

  Future<void> setFatigue(int value) async {
    await controller
        .applyAdmin((s) => s.fatigue = Fatigue(value: value.clamp(0, 100)));
  }

  Future<void> setManagerTrust(int value) async {
    await controller.applyAdmin((s) => s.relations = Relations(
          manager: value.clamp(0, 100),
          teammates: s.relations.teammates,
        ));
  }

  Future<void> setFame(int value) async {
    await controller.applyAdmin((s) => s.reputation =
        s.reputation.copyWith(fame: value.clamp(0, 100)));
  }

  Future<void> setSavings(int value) async {
    await controller.applyAdmin((s) => s.finances =
        Finances(savings: value, lifestyle: s.finances.lifestyle));
  }

  Future<void> setYellowCards(int value) async {
    await controller.applyAdmin((s) => s.yellowCards = max(0, value));
  }

  Future<void> setSuspension(int value) async {
    await controller.applyAdmin((s) => s.suspension = max(0, value));
  }

  /// 怪我をさせる／治す。復帰明けの挙動を見るときに使う。
  Future<void> setInjury(int matchesOut) async {
    await controller.applyAdmin((s) => s.injury = matchesOut <= 0
        ? null
        : Injury(
            name: '管理画面',
            severity: matchesOut >= 10
                ? InjurySeverity.severe
                : matchesOut >= 4
                    ? InjurySeverity.moderate
                    : InjurySeverity.light,
            matchesOut: matchesOut,
          ));
  }

  /// 局面を指定して試合に入る。条件が揃わないと出ない局面を直接見る。
  void startMatchWith(Scenario scenario) {
    final state = _state;
    if (state == null || state.seasonFinished) return;
    controller.startNextMatch(
      forcedScenarios: [
        for (var i = 0; i < 3; i++) scenario,
      ],
    );
  }

  /// 今のポジションで引ける局面。
  List<Scenario> get scenarios =>
      _state == null ? const [] : ScenarioPool.forPosition(_state!.player.position);

  /// 残りの試合を消化してシーズンを終える。
  ///
  /// 時間を飛ばす操作は自動進行と同じ道を通るので、改変の印は付けない。
  /// 印が指すのは「数字を書き換えた」ことだけ。
  Future<void> finishSeasonNow() async {
    for (var guard = 0; guard < 60; guard++) {
      final state = _state;
      if (state == null || state.seasonFinished) break;
      await controller.simulateMatch();
    }
  }

  /// 年を進める。契約更改は残留（無ければ先頭）で自動的に受ける。
  ///
  /// 引退の条件・帰化の5年・違約金の発動は、普通に遊ぶと数十シーズンかかる。
  Future<void> skipYears(int years) async {
    for (var i = 0; i < years; i++) {
      final state = _state;
      if (state == null || state.retired) break;
      await finishSeasonNow();
      await controller.finishSeason();
      // 契約が残っている間は移籍の話が来ないので、offers は空のことがある。
      // 残留（renewalOffer）はそれとは別に必ずあるので、そちらを先に見る。
      final accepted = controller.renewalOffer ??
          (controller.offers.isEmpty ? null : controller.offers.first);
      if (accepted == null) break;
      await controller.advanceSeason(accepted: accepted);
    }
  }
}
