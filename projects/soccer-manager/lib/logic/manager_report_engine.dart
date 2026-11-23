import '../l10n/tr.dart';
import 'board_engine.dart';
import 'economy_scale.dart';

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

  /// 直近の節でこれ以上下がったら、早めに知らせる。
  static const int falloffAlert = 10;

  static ManagerReport build({
    required int rank,
    required int teamCount,
    required int tier,
    required int supporter,
    required int shareholder,
    required int budget,
    required int weeklyNet,
    String? lastResult,
    int? targetRank,
    int? supporterTrend,
    bool preseason = false,
    int? lastSeasonRank,
  }) {
    final lines = <String>[
      preseason
          ? Tr.pick('$tier部 $teamCount チーム・開幕前', 'Tier $tier: $teamCount clubs, pre-season')
          : Tr.pick('$tier部 $teamCount チーム中 $rank 位', 'Tier $tier: ${Tr.ordinal(rank)} of $teamCount'),
      if (lastResult != null) Tr.pick('直近: $lastResult', 'Last: $lastResult'),
      Tr.pick(
          '週の収支 ${weeklyNet >= 0 ? '+' : ''}${formatMoney(weeklyNet)}(資金 ${formatMoney(budget)})',
          'Weekly ${weeklyNet >= 0 ? '+' : ''}${formatMoney(weeklyNet)} (funds ${formatMoney(budget)})'),
    ];

    // いまの順位のまま季を終えたときの、季末の増減(目標を大きく下回ると負)。
    final seasonEndDrop = targetRank == null
        ? 0
        : BoardEngine.confidenceDeltaForSeasonEnd(
            finalRank: rank, targetRank: targetRank);
    final String headline;
    if (supporter <= dangerLine && shareholder <= dangerLine) {
      headline = Tr.pick('オーナー、両方の期待が危うい状況です。手を打ちましょう。',
          'Boss, both fans and shareholders are restless. We need to act.');
    } else if (supporter <= dangerLine) {
      headline = Tr.pick('サポーターの期待が下がっています。成績の立て直しが先です。',
          'The fans are losing patience. Results come first.');
    } else if (supporterTrend != null && supporterTrend <= -falloffAlert) {
      // 下がり続けているなら、危ない線に届く前に言う(2026-11-23。22位で
      // 目標17位でも「大きな問題はありません」と言っていた)。
      headline = Tr.pick(
          'サポーターの期待が直近で$supporterTrend下がっています。オーナー室の広報や試合日のイベントで支えてください。',
          "Supporter expectation is down $supporterTrend lately. PR or a matchday event from the owner's office would help.");
    } else if (!preseason && targetRank != null && seasonEndDrop < 0) {
      headline = Tr.pick(
          '目標の$targetRank位に対していま$rank位です。このまま終わると、季末にサポーターの期待が$seasonEndDrop動きます。',
          'We are ${Tr.ordinal(rank)} against a target of ${Tr.topTarget(targetRank)}. Finish there and supporter expectation moves $seasonEndDrop at the end of the season.');
    } else if (shareholder <= dangerLine) {
      headline = Tr.pick('株主が収支を気にしています。支出を見直してください。',
          'Shareholders are worried about the books. Review spending.');
    } else if (budget < 0) {
      headline = Tr.pick('資金がマイナスです。放置すると株主の期待が下がります。',
          'We are in the red. Shareholders will turn on us if it lasts.');
    } else if (preseason && targetRank != null) {
      // 開幕前は全クラブが勝点0で並ぶだけなので、順位では語らない。
      headline = lastSeasonRank != null
          ? Tr.pick('開幕前です。昨季は$lastSeasonRank位でした。今季の目標は$targetRank位以内です。',
              'Pre-season. We finished ${Tr.ordinal(lastSeasonRank)} last time; the target this season is ${targetRank <= 1 ? 'to win the league' : 'the top $targetRank'}.')
          : Tr.pick('開幕前です。今季の目標は$targetRank位以内です。',
              'Pre-season. The target this season is ${targetRank <= 1 ? 'to win the league' : 'the top $targetRank'}.');
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
