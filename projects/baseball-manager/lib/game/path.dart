import 'dart:math';

import 'career.dart';
import 'player.dart';

/// プロに入れなかったときの道。
enum Route {
  university(4),
  corporate(3);

  const Route(this.years);
  final int years;
}

/// 能力の総合評価 0〜99。二刀流は得意なほうで見る。
double overall(Player p) {
  double avg(List<Ability> l) =>
      l.map(p.of).fold<int>(0, (a, b) => a + b) / l.length;
  return switch (p.role) {
    Role.batter => avg(batterAbilities),
    Role.pitcher => avg(pitcherAbilities),
    Role.twoWay => max(avg(batterAbilities), avg(pitcherAbilities)),
  };
}

/// 能力7割＋実績3割(0〜100)。実績は大会の成績などで積む(別途)。
double draftScore(Player p, double achievement) =>
    0.7 * overall(p) + 0.3 * achievement.clamp(0, 100);

const draftLine = 55.0; // 運を除いた合否ライン
const draftLuck = 10.0; // 運の振れ幅(±)

/// ドラフトで指名されるか。能力と実績に運が乗る。
/// 運の幅が決まっているので、大きく上回れば確実、大きく下回れば不可能。
bool isDrafted(Player p, double achievement, Random rng) {
  final luck = (rng.nextDouble() * 2 - 1) * draftLuck;
  return draftScore(p, achievement) + luck >= draftLine;
}

/// 指名される確率の目安(画面に出す用)。0〜1。
double draftChance(Player p, double achievement) {
  final d = draftScore(p, achievement) - draftLine;
  return ((d + draftLuck) / (2 * draftLuck)).clamp(0.0, 1.0);
}

/// 進路を終えて再びドラフトにかかる年齢。高校卒業は18歳。
int graduationAge(Route r) => proEntryAge + r.years;

/// 再挑戦の機会は1度だけ。外れたら引退(これも結末の一つ)。
bool hasSecondChance({required bool alreadyRetried}) => !alreadyRetried;

/// 戦力外の基準。総合評価がこれを下回る年が続くと解雇される。
const releaseLine = 35.0;
const releaseYears = 2;

/// 今年の評価を踏まえた「低迷の連続年数」。基準を上回れば0に戻る。
int nextLowYears(Player p, int lowYears) =>
    overall(p) < releaseLine ? lowYears + 1 : 0;

bool isReleased(int lowYears) => lowYears >= releaseYears;

/// 強制引退(戦力外 or 年齢)か。自分で決める引退は `canChooseRetire`。
bool mustRetire(Player p, int lowYears) =>
    isReleased(lowYears) || p.age > maxProAge;

/// 引退を自分で選べるのはプロの段階だけ。
bool canChooseRetire(Stage s) => s == Stage.pro;
