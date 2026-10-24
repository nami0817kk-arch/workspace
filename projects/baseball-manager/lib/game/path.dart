import 'dart:math';

import 'career.dart';
import 'player.dart';
import 'skills.dart';
import 'traits.dart';

/// プロに入れなかったときの道。
enum Course {
  university(4),
  corporate(3);

  const Course(this.years);
  final int years;
}

/// 能力の総合評価 0〜99。二刀流は得意なほうで見る。特殊能力も評価に入る(`skillRating`)。
double overall(Player p) {
  double avg(List<Ability> l) =>
      l.map(p.of).fold<int>(0, (a, b) => a + b) / l.length;
  final base = switch (p.role) {
    Role.batter => avg(batterAbilities),
    Role.pitcher => avg(pitcherAbilities),
    Role.twoWay => _twoWayOverall(avg(batterAbilities), avg(pitcherAbilities)),
  };
  return min(100.0, base + skillRating(p));
}

/// 二刀流の総合評価。得意な方が土台で、もう一方も育っているほど上乗せされる
/// (両方を高い水準で使えるのが二刀流の値打ち。練習が分散する分の見返り)。
double _twoWayOverall(double a, double b) {
  final hi = max(a, b), lo = min(a, b);
  return min(100.0, hi + ((lo - 40) * 0.5).clamp(0.0, 12.0));
}

/// 能力7割＋実績3割(0〜100)。実績は大会の成績などで積む(別途)。
double draftScore(Player p, double achievement) =>
    0.7 * overall(p) + 0.3 * achievement.clamp(0, 100) + draftBonus(p.traits);

/// 運を除いた合否ライン(dart run -DBAL_DRAFT=600 で試せる。単位は0.1)。
const draftLine = int.fromEnvironment('BAL_DRAFT', defaultValue: 595) / 10;
const draftLuck = 10.0; // 運の振れ幅(±)

/// ドラフトで指名されるか。能力と実績に運が乗る。
/// 運の幅が決まっているので、大きく上回れば確実、大きく下回れば不可能。
/// `lineShift` は難しさによる合格ラインの上下(負なら指名されやすい)。
bool isDrafted(Player p, double achievement, Random rng,
    {double lineShift = 0}) {
  final luck = (rng.nextDouble() * 2 - 1) * draftLuck;
  return draftScore(p, achievement) + luck >= draftLine + lineShift;
}

/// 指名される確率の目安(画面に出す用)。0〜1。
double draftChance(Player p, double achievement, {double lineShift = 0}) {
  final d = draftScore(p, achievement) - (draftLine + lineShift);
  return ((d + draftLuck) / (2 * draftLuck)).clamp(0.0, 1.0);
}

/// 進路を終えて再びドラフトにかかる年齢。高校卒業は18歳。
int graduationAge(Course r) => proEntryAge + r.years;

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

/// ドラフトの指名順位(1〜6位)。判定の余裕(運を含む得点がラインをどれだけ上回ったか)が大きいほど上位。
/// 結果の見せ方だけで、合否には関わらない。
int draftRound(double margin) {
  if (margin >= 25) return 1;
  if (margin >= 18) return 2;
  if (margin >= 12) return 3;
  if (margin >= 7) return 4;
  if (margin >= 3) return 5;
  return 6;
}

/// 架空の球団名(実在の球団・商標は使わない)。
const draftTeams = [
  '青波ホークス',
  '北斗ベアーズ',
  '朱雀ファルコンズ',
  '紅葉ジャガーズ',
  '銀嶺ライオンズ',
  '黒潮マリナーズ',
  '碧海ドルフィンズ',
  '大和スターズ',
];
