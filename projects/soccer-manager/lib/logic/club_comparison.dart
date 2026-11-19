import '../models/team.dart';
import 'contract_engine.dart';

/// 他のクラブと比べる1つの物差し。
class ComparisonRow {
  /// 自クラブの値。
  final int mine;

  /// リーグの中での順位(1 が一番大きい)。
  final int rank;

  /// 比べたクラブの数(自クラブを含む)。
  final int clubs;

  /// リーグの真ん中の値。
  final int median;

  const ComparisonRow({
    required this.mine,
    required this.rank,
    required this.clubs,
    required this.median,
  });
}

/// 同じリーグのクラブと、選手の価値の合計・年俸の総額・平均の力を比べる。
class ClubComparisonEngine {
  static ComparisonRow _row(
      List<Team> teams, String userId, int Function(Team) value) {
    final values = {for (final t in teams) t.id: value(t)};
    final mine = values[userId] ?? 0;
    final sorted = values.values.toList()..sort();
    final rank = 1 + values.values.where((v) => v > mine).length;
    return ComparisonRow(
      mine: mine,
      rank: rank,
      clubs: teams.length,
      median: sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2],
    );
  }

  /// 選手の価値の合計(万円)。
  static ComparisonRow squadValue(List<Team> teams, String userId) =>
      _row(teams, userId,
          (t) => t.players.fold<int>(0, (s, p) => s + p.marketValue));

  /// 年俸の総額(万円/年)。
  static ComparisonRow wageBill(List<Team> teams, String userId) =>
      _row(teams, userId, (t) => ContractEngine.weeklyWageBill(t) * 52);

  /// 先発の力(チームの総合力)。
  static ComparisonRow strength(List<Team> teams, String userId) =>
      _row(teams, userId, (t) => t.overallRating);
}
