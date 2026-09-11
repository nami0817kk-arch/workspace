// ignore_for_file: avoid_print
/// **特性は、キャリアをどれだけ変えているか。**
///
/// 「能力値だけだと、そうなるので特性とかの影響度をあげていこう」への
/// 手がかり。能力値も選び方も揃えて、**特性だけを差し替えて**引退まで回す。
/// 結果が動かないなら、特性は名前が付いているだけの飾りということになる。
///
/// `flutter test test/trait_sim.dart` で明示的に走らせる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/traits.dart';

import 'support/career_sim.dart';

void main() {
  test('特性がキャリアを変えるか', () async {
    const seeds = 16;

    Future<void> run(String name, List<Trait> traits) async {
      var overall = 0.0;
      var rating = 0.0;
      var value = 0.0;
      var caps = 0.0;
      var titles = 0.0;
      var goals = 0.0;
      var appearances = 0.0;
      var salary = 0.0;
      var top = 0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            traits: traits,
          ),
          seed,
        );
        overall += career.peakOverall;
        rating += career.averageRating;
        value += career.peakValue;
        caps += career.caps;
        titles += career.leagueTitles + career.cupTitles;
        goals += career.goals;
        appearances += career.appearances;
        salary += career.peakSalary;
        // 最上位の国の1部まで行けたか。
        if (career.bestPrestige >= 5) top++;
      }

      print(
        '${name.padRight(20)} '
        'ピーク ${(overall / seeds).toStringAsFixed(1)}  '
        '評価 ${(rating / seeds).toStringAsFixed(2)}  '
        '値札 ${(value / seeds / 10000).toStringAsFixed(2)}億  '
        '年俸 ${(salary / seeds / 10000).toStringAsFixed(2)}億  '
        '代表 ${(caps / seeds).toStringAsFixed(0)}  '
        'タイトル ${(titles / seeds).toStringAsFixed(1)}  '
        'ゴール ${(goals / seeds).toStringAsFixed(0)}  '
        '出場 ${(appearances / seeds).toStringAsFixed(0)}  '
        '格5 ${top * 100 ~/ seeds}%',
      );
    }

    print('--- 能力値と選び方を揃えて、特性だけ差し替える ---');
    await run('特性なし', const []);
    await run('司令塔＋テンポ', const [Trait.playmaker, Trait.tempoSetter]);
    await run('本番強者＋クラッチ', const [Trait.ironNerve, Trait.clutch]);
    await run('飲み込み＋殻を破る', const [Trait.quickLearner, Trait.breaker]);
    await run('鉄人＋頑丈', const [Trait.ironman, Trait.robust]);
    await run('天才', const [Trait.genius]);
    await run('欠点2つ', const [Trait.lazy, Trait.fragile]);
  }, timeout: const Timeout(Duration(minutes: 60)));

  test('配られる枚数が、選手を変えているか', () async {
    // **特性の数は選手ごとに違う。** 引いた枚数でキャリアを束ね直して、
    // 枚数そのものが結果を動かしているかを見る。
    //
    // **束ごとの人数が要る。** 60キャリアだと 4枚の束が6人しか居らず、
    // ±0.05 の差は引いた特性の当たり外れに埋もれて読めない
    // （実際、欠点の重みを変えても数字が動かず、指標のほうが粗かった）。
    const seeds = 240;
    final byCount = <int, List<Career>>{};

    for (var seed = 0; seed < seeds; seed++) {
      final career = await runCareer(
        Playstyle(
          name: 'x',
          position: Position.cm,
          startAge: 18,
          sim: SimStyle.balanced,
          agent: Agent.pool.first,
        ),
        seed,
      );
      byCount.putIfAbsent(career.strengthCount, () => []).add(career);
    }

    print('--- 引いた長所の枚数で束ねる（$seeds キャリア）---');
    final counts = byCount.keys.toList()..sort();
    for (final count in counts) {
      final group = byCount[count]!;
      double avg(num Function(Career) of) =>
          group.fold<double>(0, (s, c) => s + of(c)) / group.length;
      print(
        '長所$count枚 ${group.length.toString().padLeft(2)}人  '
        'ピーク ${avg((c) => c.peakOverall).toStringAsFixed(1)}  '
        '評価 ${avg((c) => c.averageRating).toStringAsFixed(2)}  '
        '代表 ${avg((c) => c.caps).toStringAsFixed(0)}  '
        '通算ゴール ${avg((c) => c.goals).toStringAsFixed(0)}  '
        '欠点 ${avg((c) => c.flawCount).toStringAsFixed(2)}枚  '
        '稀 ${group.where((c) => c.hadRare).length * 100 ~/ group.length}%',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 60)));

  test('長所が増えても評価が上がらないのはなぜか', () async {
    // 長所の枚数で束ねると 1枚 7.09 / 2枚 7.21 / 3枚 7.19 / 4枚 7.21 で、
    // **2枚から先が平ら**だった。理由は2つ考えられる:
    //   ① 3枚目・4枚目は条件が狭くて、そもそも効く局面が来ない
    //   ② 評価点が上がると移籍で環境が上がり、評価点が戻る
    // 環境を止めた場合と止めない場合の両方で測って、切り分ける。
    const seeds = 16;

    // 中盤の選手が持てる長所を、枚数ちょうどで組む。
    const sets = <String, List<Trait>>{
      '1枚': [Trait.playmaker],
      '2枚': [Trait.playmaker, Trait.tempoSetter],
      '3枚': [Trait.playmaker, Trait.tempoSetter, Trait.clutch],
      '4枚': [
        Trait.playmaker,
        Trait.tempoSetter,
        Trait.clutch,
        Trait.fastStarter,
      ],
    };

    Future<void> run(
      String name,
      List<Trait> traits, {
      required bool free,
    }) async {
      var rating = 0.0;
      var hits = 0.0;
      var apps = 0.0;
      var peak = 0.0;
      var strength = 0.0;
      var caps = 0.0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            traits: traits,
            // 環境を止めるときは、移籍せず能力も固定する。
            staysPut: !free,
            pinAbility: free ? null : 75,
          ),
          seed,
        );
        rating += career.averageRating;
        hits += career.traitHits;
        apps += career.appearances;
        peak += career.peakOverall;
        strength += career.bestPrestige;
        caps += career.caps;
      }

      print(
        '${name.padRight(14)} '
        '評価 ${(rating / seeds).toStringAsFixed(3)}  '
        '効いた局面 ${(hits / max(1, apps)).toStringAsFixed(2)}/試合  '
        'ピーク ${(peak / seeds).toStringAsFixed(1)}  '
        '国の格 ${(strength / seeds).toStringAsFixed(1)}  '
        '代表 ${(caps / seeds).toStringAsFixed(0)}',
      );
    }

    print('--- 普通に回す（移籍あり・能力は成長する）---');
    for (final e in sets.entries) {
      await run(e.key, e.value, free: true);
    }
    print('');
    print('--- 環境を止める（残留し続け、能力は75に固定）---');
    for (final e in sets.entries) {
      await run(e.key, e.value, free: false);
    }
  }, timeout: const Timeout(Duration(minutes: 90)));
}
