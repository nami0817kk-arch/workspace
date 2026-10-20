// やり込み要素の強さを測る: 特性(レア)ごと・天賦ごとに何人も遊ばせ、
// 「何も持たない」場合との差(プロ入り率・最高評価・レジェンド率)を見る。
// また、覚醒が一生のうちにどれくらいの人に起きるかも数える。
//
//   dart run tool/talent_audit.dart        # 各条件300人
//   dart run tool/talent_audit.dart 600
//
// 強すぎる(レジェンド率が基準の2倍を超える等)特性は、効き方を弱める。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/traits.dart';

class Result {
  int n = 0, pro = 0, legend = 0, awakened = 0, proAwakened = 0, titled = 0, titledAwakened = 0;
  double peak = 0;
  void add(Game g) {
    n++;
    if (g.ending!.madePro) pro++;
    if (g.ending!.title == 'レジェンド') legend++;
    if (g.awakened) awakened++;
    if (g.awakened && g.ending!.madePro) proAwakened++;
    final t = g.records.any((r) => r.titles.isNotEmpty) ||
        g.records.any((r) => r.isLeague && r.rank == 1);
    if (t) {
      titled++;
      if (g.awakened) titledAwakened++;
    }
    peak += g.ending!.peakOverall;
  }

  String line() =>
      'プロ入り ${(100 * pro / n).toStringAsFixed(1)}%  最高評価 ${(peak / n).toStringAsFixed(1)}  '
      'レジェンド ${(100 * legend / n).toStringAsFixed(1)}%  覚醒 ${(100 * awakened / n).toStringAsFixed(1)}%(プロの${pro == 0 ? 0 : (100 * proAwakened / pro).round()}%、タイトル・優勝経験者の${titled == 0 ? 0 : (100 * titledAwakened / titled).round()}%)';
}

/// 上手い遊び方(いちばん低い能力を重点・疲れたら休む・経験点はおまかせ)で最後まで。
Game play(int seed, Role role,
    {Set<Trait>? traits, Map<Ability, int>? gifts, int? potential}) {
  final g = Game.newGame(
      name: 'a', role: role, rng: Random(seed), potential: potential);
  if (traits != null) g.adminSetTraits(traits);
  if (gifts != null) {
    g.player = g.player.copyWith(gifts: gifts);
  }
  var guard = 0;
  while (g.phase != Phase.retired && guard++ < 5000) {
    switch (g.phase) {
      case Phase.term:
        g.autoSpend();
        final abilities = abilitiesOf(g.player.role);
        final focus = ([...abilities]
              ..sort((a, b) => g.player.of(a).compareTo(g.player.of(b))))
            .first;
        g.choose(g.condition.fatigue >= 65 ? Plan.rest : Plan.train, focus);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return g;
}

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 300;
  for (final role in [Role.batter, Role.pitcher]) {
    print('── ${role == Role.batter ? '打者' : '投手'} ──');
    Result run(
        {Set<Trait>? traits, Map<Ability, int>? gifts, int offset = 0}) {
      final r = Result();
      for (var i = 0; i < n; i++) {
        r.add(play(offset + i, role, traits: traits, gifts: gifts));
      }
      return r;
    }

    final base = run(traits: const {});
    print('基準(特性なし・天賦なし)   ${base.line()}');
    for (final t in rareTraits) {
      if (!t.appliesTo(role)) continue;
      final r = run(traits: {t});
      print('${t.label.padRight(8, '　')}${r.line()}');
    }
    final all = {for (final a in Ability.values) a: 2};
    final none = {for (final a in Ability.values) a: -2};
    print('天賦すべて+2           ${run(traits: const {}, gifts: all).line()}');
    print('天賦すべて-2           ${run(traits: const {}, gifts: none).line()}');
    // ふつうに始めたときの覚醒の割合(生まれつきの抽選もそのまま)
    final nat = Result();
    for (var i = 0; i < n; i++) {
      nat.add(play(10000 + i, role));
    }
    print('ふつうに始めた場合         ${nat.line()}');
  }
}
