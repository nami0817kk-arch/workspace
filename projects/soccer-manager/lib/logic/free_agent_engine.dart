import 'dart:math';

import '../models/player.dart';
import 'economy_scale.dart';
import 'player_generator.dart';
import 'player_popularity.dart';

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
    // 比べるたびに乱数を引くと並べ方の前提(同じ2人は毎回同じ順)が崩れ、
    // sort が RangeError で落ちることがある。乱数は先に1人1回だけ引く。
    final score = <Player, int>{
      for (final p in pool)
        if (!keep.contains(p.id)) p: p.overall + r.nextInt(10),
    };
    final candidates = score.keys.toList()
      ..sort((a, b) => score[b]!.compareTo(score[a]!));
    final gone = candidates.take(leave).toList();
    pool.removeWhere(gone.contains);
    return gone;
  }

  /// 所属なしの選手が求める週俸(万円)。
  ///
  /// 前のクラブの週俸は持ち越さない。他国の1部で大きな年俸をもらっていた
  /// 選手が、契約が切れて所属なしになっても同じ額(年30億を超える額)を
  /// 求め、誰も取れなかった(2026-11-24 の撮影で見つかった)。
  ///
  /// - リーグ: 能力と経験から見合う額([Player.fairWeeklyWage])を、
  ///   自クラブのいる国・部の水準([level]。省くと今の水準)で
  /// - 評判: 名の知れた選手ほど強気(人気0で ×0.9、100で ×1.15)
  /// - 市場: 夏はまだ強気、季が進んで行き先が決まらないほど下げる
  ///   ([marketFactor])
  static int askingWeekly(Player p, DateTime date, {double? level}) {
    final pop = PlayerPopularityEngine.popularity(p);
    final reputation = 0.9 + 0.25 * pop / 100;
    final wage =
        p.fairWeeklyWage(level) * reputation * marketFactor(date);
    return max(minWeeklyWage, wage.round());
  }

  /// 時期ごとの、所属なしの選手の強気さ。夏(7〜8月)は1、秋は0.9、
  /// 冬は0.8、春(2〜6月)は0.75。
  static double marketFactor(DateTime date) => switch (date.month) {
        7 || 8 => 1.0,
        9 || 10 => 0.9,
        11 || 12 || 1 => 0.8,
        _ => 0.75,
      };

  /// プールの全員の週俸を、求める額([askingWeekly])にそろえる。
  /// [keep]の選手(話を進めている選手)は動かさない。
  static void normalizeWages(List<Player> pool, DateTime date,
      {Set<String> keep = const {}}) {
    for (final p in pool) {
      if (keep.contains(p.id)) continue;
      p.wage = askingWeekly(p, date);
    }
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
