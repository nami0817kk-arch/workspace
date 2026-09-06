/// 数値バランスの定義。
///
/// 調整はすべてここに集約する。エンジン側に数字を直接書かないこと。
/// 定数を変えると過去のセーブの体感が変わるので、変更時は
/// test/formulas_test.dart の期待値も合わせて見直す。
library;

import 'dart:math';

class Formulas {
  Formulas._();

  /// 強化は買うたびに 1.15 倍ずつ高くなる（放置ゲームの慣習的な伸び）。
  static const double upgradeCostGrowth = 1.15;

  static const int trainingBaseCost = 25;
  static const int coachBaseCost = 100;
  static const int scoutBaseCost = 300;

  /// 放置で回収できる上限。これが無いと数か月放置で一気に終わってしまう。
  static const Duration offlineCap = Duration(hours: 8);

  /// 強化 [level] 回目（0 始まり）を買うのに要る EP。
  static int upgradeCost(int baseCost, int level) =>
      (baseCost * pow(upgradeCostGrowth, level)).floor();

  /// タップ1回の獲得 EP。未強化でも 1 は入る。
  static double epPerTap(int trainingLevel) => 1 + trainingLevel * 1.5;

  /// 放置1秒あたりの獲得 EP。コーチ未雇用なら 0。
  static double epPerSecond(int coachLevel) => coachLevel * 0.5;

  /// 選手を1レベル上げるのに要る EP。レベルが上がるほど重くなる。
  static int trainCost(int playerLevel) => (50 * pow(1.12, playerLevel - 1)).floor();

  /// 選手をもう1人獲得するのに要る EP。人数が増えるほど高い。
  static int scoutCost(int squadSize) =>
      (scoutBaseCost * pow(1.35, squadSize)).floor();

  /// クラブランク [rank] で当たる相手の総合力。
  static int opponentRating(int rank) => 30 + (rank - 1) * 6;

  /// 試合に勝ったときの報酬 EP。
  static double matchReward(int rank) => 200 * pow(1.25, rank - 1).toDouble();

  /// ランクアップに必要な勝利数。
  static int winsForRankUp(int rank) => 2 + rank;
}
