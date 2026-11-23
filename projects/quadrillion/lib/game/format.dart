/// 数の見せ方（試作の yen / pct / trim と同じ結果になるように、JS の数の書き方をまねる）。
library;

/// JS の Math.round（.5 は上へ）
double jsRound(double x) => (x + 0.5).floorToDouble();

/// JS の String(number) と同じ書き方（整数なら小数点を付けない）
String jsNum(double x) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? 'Infinity' : '-Infinity';
  if (x == x.truncateToDouble() && x.abs() < 1e21) return x.toInt().toString();
  return x.toString();
}

/// JS の toLocaleString()（3桁ごとのカンマ。整数のみで使う）
String commas(double x) {
  final neg = x < 0;
  final s = x.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (neg ? '-' : '') + b.toString();
}

String trim(double x) {
  if (x >= 100) return commas(jsRound(x));
  if (x >= 10) return jsNum(double.parse(x.toStringAsFixed(1)));
  return jsNum(double.parse(x.toStringAsFixed(2)));
}

String yen(double v) {
  if (!v.isFinite) return '-';
  final a = v.abs(), s = v < 0 ? '-' : '';
  if (a >= 1e16) return '$s${trim(a / 1e16)}京円';
  if (a >= 1e12) return '$s${trim(a / 1e12)}兆円';
  if (a >= 1e8) return '$s${trim(a / 1e8)}億円';
  if (a >= 1e4) return '$s${commas(jsRound(a / 1e4))}万円';
  return '$s${jsNum(jsRound(a))}円';
}

String pct(double v) => '${v > 0 && v < 1 ? v.toStringAsFixed(2) : jsNum(jsRound(v * 10) / 10)}%';
