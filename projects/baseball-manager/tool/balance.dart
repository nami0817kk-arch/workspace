// バランス調整用: 方針を決めて何人も遊ばせ、結果の分布を見る。
//
//   dart run tool/balance.dart            # 全方針
//   dart run tool/balance.dart 3000       # 人数を指定
//   dart run tool/balance.dart 800 hard   # 難しさ(easy / normal / hard)を指定
//
// 「平凡」は練習と休養だけ、「上手い」は特訓・コーチ・交流・弱い能力の底上げを使う。
// 実際の遊び方は両者の間〜上のはず。数字を変えたら、ここで分布を確かめる。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/difficulty.dart';
import 'package:baseball_manager/game/characters.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/invest.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

typedef Policy = void Function(Game g);

void plain(Game g) {
  g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
      abilitiesOf(g.player.role).first);
}

/// 特訓ばかり(疲れたら休む)。極端な遊び方でも、普通より大きく有利にならないかを見る。
void grind(Game g) {
  final abilities = abilitiesOf(g.player.role);
  final focus = ([...abilities]
        ..sort((a, b) => g.player.of(a).compareTo(g.player.of(b))))
      .first;
  g.choose(g.condition.fatigue >= 55 ? Plan.rest : Plan.special, focus);
}

/// 練習試合ばかり(疲れたら休む)。
void matches(Game g) {
  g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.match,
      abilitiesOf(g.player.role).first);
}

/// コーチに教わってばかり(疲れたら休む)。特性を早く集める。
void coachOnly(Game g) {
  g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.lesson,
      abilitiesOf(g.player.role).first);
}

/// 研究(気持ちが上がり少し貯まる)ばかり。
void studyOnly(Game g) {
  g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.study,
      abilitiesOf(g.player.role).first);
}

void skilled(Game g) {
  final abilities = abilitiesOf(g.player.role);
  // いちばん低い能力を重点にする(総合評価は平均なので、底上げが効率的)。
  final focus = ([...abilities]
        ..sort((a, b) => g.player.of(a).compareTo(g.player.of(b))))
      .first;
  final c = g.condition;
  final Plan plan;
  if (c.fatigue >= 70) {
    plan = Plan.rest;
  } else if (c.morale < 35) {
    plan = Plan.social;
  } else if (g.cast.coach != null &&
      g.cast.coach!.tips < tipsNeeded &&
      g.slot % 3 == 0) {
    plan = Plan.lesson;
  } else if (c.fatigue < 30) {
    plan = Plan.special;
  } else {
    plan = Plan.train;
  }
  g.choose(plan, focus);
}

class Result {
  Result(this.madePro, this.proYears, this.peak, this.title, this.twoWay,
      this.titles, this.leagueWins);
  final bool madePro;
  final int proYears;
  final int peak;
  final String title;
  final bool twoWay;
  final List<String> titles;
  final int leagueWins;
}

Result play(int seed, Policy policy, Role role, Difficulty difficulty,
    [Policy? proHook]) {
  final g = Game.newGame(
      name: 't', role: role, rng: Random(seed), difficulty: difficulty);
  var steps = 0;
  while (g.phase != Phase.retired) {
    if (++steps > 6000) throw StateError('終わらない seed=$seed');
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        if (g.stage == Stage.pro && g.player.age >= 36) {
          g.retire();
        } else {
          if (g.stage == Stage.pro && proHook != null) proHook(g);
          if (g.phase == Phase.term) policy(g);
        }
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  final e = g.ending!;
  return Result(e.madePro, e.proYears, e.peakOverall, e.title, e.wasTwoWay,
      e.titles, g.records.where((r) => r.isLeague && r.rank == 1).length);
}

/// プロでの選択(二刀流・海外・投資)を変えたときの差を見る(dart run tool/balance.dart 600 normal pro)。
final Map<String, Policy?> proVariants = {
  'そのまま': null,
  '二刀流': (g) {
    if (g.player.role != Role.twoWay) g.changeRole(Role.twoWay);
  },
  '海外へ': (g) {
    if (g.canMoveOverseas) g.moveOverseas();
  },
  '投資ぜんぶ': (g) {
    for (final i in Invest.values) {
      while (g.money >= (investCost(g.investLevel(i)) ?? 1 << 30)) {
        if (!g.buyInvest(i)) break;
      }
    }
  },
};

void main(List<String> args) {
  if (args.length > 2 && args[2] == 'pro') {
    final n = int.parse(args.first);
    final d = Difficulty.parse(args[1]);
    for (final e in proVariants.entries) {
      for (final role in [Role.batter, Role.pitcher]) {
        final rs = [
          for (var s = 0; s < n; s++) play(s, skilled, role, d, e.value)
        ];
        final pro = rs.where((r) => r.madePro).toList();
        double mean(num Function(Result) f) =>
            pro.isEmpty ? 0 : pro.map(f).reduce((a, b) => a + b) / pro.length;
        print(
            '${e.key} / ${role.name}: プロ${pro.length}人  最高評価 ${mean((r) => r.peak).toStringAsFixed(1)}  タイトル ${mean((r) => r.titles.length).toStringAsFixed(1)}個  リーグ優勝 ${mean((r) => r.leagueWins).toStringAsFixed(1)}回  レジェンド ${(100 * pro.where((r) => r.title == 'レジェンド').length / (pro.isEmpty ? 1 : pro.length)).toStringAsFixed(0)}%');
      }
    }
    return;
  }
  final n = args.isEmpty ? 1500 : int.parse(args.first);
  final difficulty = Difficulty.parse(args.length > 1 ? args[1] : null);
  print('難しさ: ${difficulty.label}');
  final extra = args.length > 2 && args[2] == 'extreme';
  for (final entry in {
    '平凡': plain,
    '上手い': skilled,
    if (extra) '特訓ばかり': grind,
    if (extra) '練習試合ばかり': matches,
    if (extra) 'コーチばかり': coachOnly,
    if (extra) '研究ばかり': studyOnly,
  }.entries) {
    for (final role in [Role.batter, Role.pitcher]) {
      final rs = [
        for (var s = 0; s < n; s++) play(s, entry.value, role, difficulty)
      ];
      final pro = rs.where((r) => r.madePro).toList();
      final titles = <String, int>{};
      for (final r in rs) {
        titles.update(r.title, (v) => v + 1, ifAbsent: () => 1);
      }
      String pct(int x) => (100 * x / n).toStringAsFixed(1);
      print('${entry.key} / ${role.name}: プロ入り ${pct(pro.length)}%  '
          '平均プロ年数 ${pro.isEmpty ? '-' : (pro.map((r) => r.proYears).reduce((a, b) => a + b) / pro.length).toStringAsFixed(1)}  '
          '最高評価平均 ${pro.isEmpty ? '-' : (pro.map((r) => r.peak).reduce((a, b) => a + b) / pro.length).toStringAsFixed(1)}');
      final withTitle = pro.where((r) => r.titles.isNotEmpty).length;
      double meanOf(int Function(Result) f) =>
          pro.isEmpty ? 0 : pro.map(f).reduce((a, b) => a + b) / pro.length;
      print(
          '   タイトル: プロの${pro.isEmpty ? 0 : (100 * withTitle / pro.length).toStringAsFixed(0)}%が1度以上 / '
          '平均${meanOf((r) => r.titles.length).toStringAsFixed(1)}個  '
          'リーグ優勝 平均${meanOf((r) => r.leagueWins).toStringAsFixed(1)}回');
      print(
          '   ${titles.entries.map((e) => '${e.key} ${pct(e.value)}%').join('  ')}');
    }
  }
}
