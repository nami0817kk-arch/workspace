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

import '../game/formulas.dart';
import '../game/match_engine.dart';
import '../game/ranking.dart';
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

/// 「いま何が効いているか」を1行にしたもの。
class ImpactLine {
  const ImpactLine(this.label, this.value);

  final String label;
  final String value;
}

/// 書き換えた結果、ゲームの側で何がどうなるか。
///
/// **ここに式を書かない。** 全部、実際に判定している関数から引く
/// （`Ranking.gradeFor` / `SelectionOutlook` / `MatchEngine.injuryChance` /
/// `MatchEngine.conditionModifier` / `CareerState.budget`）。
/// 別に書くと、数字を触ったときに管理画面だけが嘘をつく。
///
/// 値をいじれるようにしただけでは「それで何が変わるのか」が見えなかった、
/// という指摘への答え。変える場所と、効く先を同じ画面に置く。
class AdminImpact {
  const AdminImpact(this.lines);

  final List<ImpactLine> lines;

  static AdminImpact of(CareerController controller) {
    final state = controller.state;
    if (state == null) return const AdminImpact([]);
    final player = state.player;
    final grade = Ranking.gradeFor(player.overall);
    final outlook = controller.outlook;
    final budget = state.budget;

    // 代表の線まであといくつか。招集の判定と同じ数字を見る。
    final toCallUp = Formulas.callUpOverall - player.overall;
    // コンディションが局面の成功率に効く量。判定と同じ関数。
    final condition = MatchInProgress.conditionModifier(player.condition);
    // 今のまま練習した週に怪我をする確率。判定と同じ関数。
    final injury = controller.injuryChanceNow;
    final headroom = player.potential - player.overall;
    final toBan = Formulas.yellowCardsForBan - state.yellowCards;
    final transcend = player.transcendDetail;

    return AdminImpact([
      ImpactLine(
        '総合力',
        '${player.overall}（${grade.label}）'
            '${toCallUp > 0 ? ' ・ 代表の線まであと$toCallUp' : ' ・ 代表の線を超えている'}',
      ),
      // 理由は SelectionOutlook 自身に書かせる。離脱・出場停止・登録外は
      // 評価点の話ではないので、平均を出しても意味が無い。
      ImpactLine(
        '次の試合',
        outlook == null ? '—' : '${outlook.headline} ・ ${outlook.reason}',
      ),
      ImpactLine(
        '局面の成功率',
        'コンディション ${player.condition} で '
            '${_percent(condition)}（気持ちと波はこれとは別に効く）',
      ),
      ImpactLine(
        '練習した週の怪我',
        '${(injury * 100).toStringAsFixed(1)}%'
            '${state.injured ? ' ・ いま離脱中（残り${state.injury!.matchesOut}試合）' : ''}',
      ),
      ImpactLine(
        '伸びしろ',
        headroom > 0
            ? 'ポテンシャルまであと $headroom'
            : transcend == null
                ? 'ポテンシャルに到達（もう伸びない）'
                : 'ポテンシャルに到達。${transcend.label}だけ '
                    '${player.attributes.detail(transcend)} → '
                    '${player.ceilingFor(transcend)} まで伸びる',
      ),
      ImpactLine(
        '今季のお金',
        '手取り ${_yen(budget.net)} → シーズン末 '
            '${_yen(state.projectedSavings)}'
            '${state.willRunOut ? ' ・ 尽きるとスタッフが離れる' : ''}',
      ),
      ImpactLine(
        '規律',
        state.suspended
            ? '出場停止 あと${state.suspension}試合'
            : '警告 ${state.yellowCards}枚（あと$toBan枚で1試合の出場停止）',
      ),
    ]);
  }

  /// 前後で変わった行だけを「総合力 72 → 77」の形にする。
  ///
  /// 何をしたら何が動いたのかは、並べて見せないと分からない。
  static List<String> diff(AdminImpact before, AdminImpact after) => [
        for (var i = 0; i < after.lines.length && i < before.lines.length; i++)
          if (before.lines[i].value != after.lines[i].value)
            '${after.lines[i].label} ${before.lines[i].value}'
                ' → ${after.lines[i].value}',
      ];

  static String _percent(double value) {
    final n = (value * 100).round();
    return n >= 0 ? '+$n%' : '$n%';
  }

  static String _yen(int man) =>
      man >= 10000 ? '${(man / 10000).toStringAsFixed(1)}億円' : '$man万円';
}

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
