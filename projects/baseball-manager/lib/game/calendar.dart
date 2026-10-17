import 'career.dart';

/// 高校とプロは月単位(12ターン)、それ以外は季節(4ターン)。
/// 年は4月に始まる。
bool isMonthly(Stage s) => s == Stage.highSchool || s == Stage.pro;

int slotsPerYear(Stage s) => isMonthly(s) ? 12 : 4;

/// 1ターンが「季節ひとつぶん」に対して占める割合。月単位は 1/3。
/// 練習の効果・疲労・怪我・出来事は、この割合で小さくなる。
double slotShare(Stage s) => 4 / slotsPerYear(s);

const _months = ['4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月', '1月', '2月', '3月'];
const _seasons = ['春', '夏', '秋', '冬'];

String slotLabel(Stage s, int slot) => isMonthly(s) ? _months[slot] : _seasons[slot];

/// 夏の大会のターン。月単位は7月、季節は夏。
bool isTournamentSlot(Stage s, int slot) => slot == (isMonthly(s) ? 3 : 1);
