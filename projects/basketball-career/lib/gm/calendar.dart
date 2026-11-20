/// シーズンの暦(2026-11-19、ユーザー「試合と日付の進め方について、品質を上げたい」)。
/// 1節(全チームが1試合ずつ)に1つの日付を当てる。開幕は10月21日、ふつうは2日おき、13節ごとに3日空く。
/// 41試合目のあと(トレードの締め切り・オールスター・カップ戦)は7日の休み。最終戦は4月中旬。
/// 乱数は使わず、シーズンの年(1年目は2026年の秋に開幕)で曜日が決まる。
library;

import 'league.dart';

/// 開幕の年(1年目は2026年)。
int seasonYear(int season) => 2025 + season;

/// [round] 節目(0始まり)の、開幕からの日数。
int roundOffset(int round) {
  var d = 0;
  for (var r = 1; r <= round; r++) {
    d += r == blockStart(tradeDeadlineBlock) ? 7 : (r % 13 == 0 ? 3 : 2);
  }
  return d;
}

/// [season] の [round] 節目の日付。
DateTime roundDate(int season, int round) => DateTime.utc(seasonYear(season), 10, 21).add(Duration(days: roundOffset(round)));

const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

/// 「11月3日(月)」。
String dateLabel(DateTime d) => '${d.month}月${d.day}日(${_weekdays[d.weekday - 1]})';

/// 「11/3」。
String dateShort(DateTime d) => '${d.month}/${d.day}';

/// 節の日付の見出し(「11月3日(月)」)。
String roundLabel(int season, int round) => dateLabel(roundDate(season, round.clamp(0, gamesPerSeason - 1)));

/// トレードの締め切りの日(41試合目の日)。
DateTime deadlineDate(int season) => roundDate(season, blockStart(tradeDeadlineBlock) - 1);

/// オールスターの日(締め切りのあとの休みの真ん中)。
DateTime allStarDate(int season) => deadlineDate(season).add(const Duration(days: 4));

/// [season] の、[from] 節目から先で、同じ月のうちに残っている節の数([from] を含む)。
int roundsLeftInMonth(int season, int from) {
  if (from >= gamesPerSeason) return 0;
  final m = roundDate(season, from).month;
  var n = 0;
  for (var r = from; r < gamesPerSeason && roundDate(season, r).month == m; r++) {
    n++;
  }
  return n;
}

/// オフの時期の目安(見出し用)。
const offseasonMonths = {
  'playoffs': '4月中旬〜6月',
  'seasonEnd': '6月',
  'draft': '6月下旬',
  'contracts': '7月',
  'preseason': '9月下旬',
};
