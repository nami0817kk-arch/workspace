/// 数値の表示形式。
///
/// 放置ゲームは桁がすぐ大きくなるので、4桁以上は k / M / B に丸める。
library;

String formatEp(double value) {
  if (value < 1000) {
    // 小数第1位まで。ただし整数のときは小数を出さない
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
  const units = ['k', 'M', 'B', 'T'];
  var scaled = value / 1000;
  var unitIndex = 0;
  while (scaled >= 1000 && unitIndex < units.length - 1) {
    scaled /= 1000;
    unitIndex++;
  }
  return '${scaled.toStringAsFixed(scaled >= 100 ? 0 : 1)}${units[unitIndex]}';
}
