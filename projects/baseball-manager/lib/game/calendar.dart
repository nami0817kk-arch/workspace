import 'career.dart';

/// 高校とプロは月単位(12ターン)、それ以外は季節(4ターン)。
/// 年は4月に始まる。
bool isMonthly(Stage s) => s == Stage.highSchool || s == Stage.pro;

int slotsPerYear(Stage s) => isMonthly(s) ? 12 : 4;

/// 1ターンが「季節ひとつぶん」に対して占める割合。月単位は 1/3。
/// 練習の効果・疲労・怪我・出来事は、この割合で小さくなる。
double slotShare(Stage s) => 4 / slotsPerYear(s);

const _months = [
  '4月',
  '5月',
  '6月',
  '7月',
  '8月',
  '9月',
  '10月',
  '11月',
  '12月',
  '1月',
  '2月',
  '3月'
];
const _seasons = ['春', '夏', '秋', '冬'];

String slotLabel(Stage s, int slot) =>
    isMonthly(s) ? _months[slot] : _seasons[slot];

enum Season { spring, summer, autumn, winter }

/// そのターンの季節(背景の絵に使う)。月単位は 4月始まりで、3〜5月が春。
Season seasonOf(Stage s, int slot) {
  if (!isMonthly(s)) return Season.values[slot.clamp(0, 3)];
  const months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
  final m = months[slot.clamp(0, 11)];
  if (m >= 3 && m <= 5) return Season.spring;
  if (m >= 6 && m <= 8) return Season.summer;
  if (m >= 9 && m <= 11) return Season.autumn;
  return Season.winter;
}

/// 夏の大会のターン。月単位は7月、季節は夏。
bool isTournamentSlot(Stage s, int slot) => slot == (isMonthly(s) ? 3 : 1);
