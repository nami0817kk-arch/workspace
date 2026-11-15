import '../l10n/tr.dart';

/// 監督からオーナーへの週次報告。
class ManagerReport {
  const ManagerReport({required this.headline, required this.lines});

  /// 一言。監督の口調で、いまのクラブの状態を言い切る。
  final String headline;

  /// 数字の報告。順位・直近の結果・資金の見通しなど。
  final List<String> lines;
}

class ManagerReportEngine {
  const ManagerReportEngine._();

  /// この値以下は「危うい」。
  static const int dangerLine = 35;

  /// この値以上は「順調」。
  static const int goodLine = 65;

  static ManagerReport build({
    required int rank,
    required int teamCount,
    required int tier,
    required int supporter,
    required int shareholder,
    required int budget,
    required int weeklyNet,
    String? lastResult,
  }) {
    final lines = <String>[
      Tr.pick('$tier部 $teamCount チーム中 $rank 位', 'Tier $tier: $rank of $teamCount'),
      if (lastResult != null) Tr.pick('直近: $lastResult', 'Last: $lastResult'),
      Tr.pick(
          '週の収支 ${weeklyNet >= 0 ? '+' : ''}$weeklyNet万円(資金 $budget万円)',
          'Weekly ${weeklyNet >= 0 ? '+' : ''}$weeklyNet (funds $budget)'),
    ];

    final String headline;
    if (supporter <= dangerLine && shareholder <= dangerLine) {
      headline = Tr.pick('オーナー、両方の期待が危うい状況です。手を打ちましょう。',
          'Boss, both fans and shareholders are restless. We need to act.');
    } else if (supporter <= dangerLine) {
      headline = Tr.pick('サポーターの期待が下がっています。成績の立て直しが先です。',
          'The fans are losing patience. Results come first.');
    } else if (shareholder <= dangerLine) {
      headline = Tr.pick('株主が収支を気にしています。支出を見直してください。',
          'Shareholders are worried about the books. Review spending.');
    } else if (budget < 0) {
      headline = Tr.pick('資金がマイナスです。放置すると株主の期待が下がります。',
          'We are in the red. Shareholders will turn on us if it lasts.');
    } else if (supporter >= goodLine && shareholder >= goodLine) {
      headline = Tr.pick('順調です。このまま任せてください。',
          'All good. Leave it to me.');
    } else {
      headline = Tr.pick('大きな問題はありません。引き続き見ていきます。',
          'No major problems. I will keep watching.');
    }
    return ManagerReport(headline: headline, lines: lines);
  }
}
