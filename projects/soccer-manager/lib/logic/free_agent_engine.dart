import 'dart:math';

import '../models/player.dart';
import 'player_generator.dart';

/// 移籍金なし(週俸のみ)で獲得できるフリーエージェントのプールを管理する。
class FreeAgentEngine {
  static final Random _rng = Random();

  /// プールの上限。契約切れで加わった選手が多い場合はそちらを優先し、
  /// 生成で埋めるのはこの上限まで。
  ///
  /// 以前は12人で、どの時期も同じだった。実際は夏(7月)に契約の切れた
  /// 選手が数十人単位で所属なしになり、季が進むにつれて行き先が決まって
  /// 減っていく(2026-11-22)。
  static const int maxPoolSize = 60;

  /// 夏(季の切り替わり)に揃える人数。
  static const int summerPoolSize = 40;

  /// [date]の時期に、所属なしの選手が残っている目安の人数。夏は数十人、
  /// 秋に減り、冬からは少数になる。
  static int targetPoolSize(DateTime date) => switch (date.month) {
        7 || 8 => summerPoolSize,
        9 || 10 => 25,
        11 || 12 || 1 => 15,
        _ => 10,
      };

  /// 1週のうちに、目安より多い分の何割が他のクラブと契約して去るか。
  static const double weeklySigningShare = 0.2;

  /// 1週ぶん、所属なしの選手が他のクラブと契約して去る。目安
  /// ([targetPoolSize])より多いときだけ、多い分の2割ほどが抜ける。
  /// 力のある選手ほど先に決まる。去った選手の一覧を返す。
  static List<Player> weeklyDrift(List<Player> pool, DateTime date,
      {Random? rng, Set<String> keep = const {}}) {
    final r = rng ?? _rng;
    final surplus = pool.length - targetPoolSize(date);
    if (surplus <= 0) return const [];
    var leave = (surplus * weeklySigningShare).floor();
    if (leave == 0 && r.nextDouble() < surplus * weeklySigningShare) leave = 1;
    if (leave <= 0) return const [];
    final candidates = [
      for (final p in pool)
        if (!keep.contains(p.id)) p,
    ]..sort((a, b) =>
        (b.overall + r.nextInt(10)).compareTo(a.overall + r.nextInt(10)));
    final gone = candidates.take(leave).toList();
    pool.removeWhere(gone.contains);
    return gone;
  }

  /// シーズン終了時に生成する、所属なしの選手。契約の切れた選手なので、
  /// 30代が多いが、20代半ばの選手も混じる。
  static Player generateVeteran() {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = 40 + _rng.nextInt(36);
    final age = 24 + _rng.nextInt(11);
    final player = PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
      ageOverride: age,
    );
    player.contractYearsRemaining = 0;
    return player;
  }

  /// スカッドが最低人数を割り込んだときの緊急補強で使う選手。
  /// ベテラン中心の通常FA([generateVeteran])をそのまま使い続けると、
  /// 契約満了のたびに30代が入ってくるためスカッドが際限なく高齢化する
  /// (長期実測で平均年齢が26→31歳まで上がることを確認)。緊急補強は
  /// 「クラブが慌てて確保する即戦力」なので、若手〜中堅(21〜29歳)から
  /// 拾ってくる。
  ///
  /// [squadMedian](自クラブの選手の総合の真ん中)を渡すと、その少し下の力の
  /// 選手にする。穴埋めなので主力より上の大物は来ない(5部のクラブに総合76・
  /// 週給が主力の4倍の選手が入り、人件費が年ごとに膨らんでいた)。
  static Player generateEmergencySigning({int? squadMedian}) {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = squadMedian == null
        ? 40 + _rng.nextInt(36)
        : (squadMedian - 6 + _rng.nextInt(7)).clamp(40, 75);
    final age = 21 + _rng.nextInt(9);
    final player = PlayerGenerator.generate(
      position: position,
      strengthTier: tier,
      ageOverride: age,
    );
    player.contractYearsRemaining = 0;
    return player;
  }

  /// プールが[target]人(既定は夏の人数)に達するまで、所属なしの選手を補充する。
  static void topUp(List<Player> pool, {int target = summerPoolSize}) {
    while (pool.length < target && pool.length < maxPoolSize) {
      pool.add(generateVeteran());
    }
  }
}
