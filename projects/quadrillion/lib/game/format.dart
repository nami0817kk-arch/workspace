/// 数の見せ方（試作の yen / pct / trim と同じ結果になるように、JS の数の書き方をまねる）。
library;

import '../l10n/lang.dart';

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

/// 金額を今の言語で書く（日本語は 兆・億・万円、英語は ¥ と K / M / B / T / Q）
String yen(double v) => L.en ? yenEn(v) : yenJa(v);

/// 英語の金額。円のまま、桁を K（千）M（百万）B（十億）T（兆）Q（千兆）で書く（例: ¥3.51T・¥29.9B）
String yenEn(double v) {
  if (!v.isFinite) return '-';
  final a = v.abs(), s = v < 0 ? '-' : '';
  // 一つ下の桁で丸めると1000になる額（999.5K など）は、上の桁にする（1.1.0+38。前は「¥1,000K」と出た）
  bool up(double unit, double below) => a >= unit || jsRound(a / below) >= 1e3;
  if (up(1e15, 1e12)) return '$s¥${trim(a / 1e15)}Q';
  if (up(1e12, 1e9)) return '$s¥${trim(a / 1e12)}T';
  if (up(1e9, 1e6)) return '$s¥${trim(a / 1e9)}B';
  if (up(1e6, 1e3)) return '$s¥${trim(a / 1e6)}M';
  if (up(1e3, 1)) return '$s¥${trim(a / 1e3)}K';
  return '$s¥${jsNum(jsRound(a))}';
}

String yenJa(double v) {
  if (!v.isFinite) return '-';
  final a = v.abs(), s = v < 0 ? '-' : '';
  // 一つ下の桁で丸めると1万になる額（9,999.5万円など）は、上の桁にする（1.1.0+38。前は「10,000万円」と出た）
  bool up(double unit, double below) => a >= unit || jsRound(a / below) >= 1e4;
  if (up(1e16, 1e12)) return '$s${trim(a / 1e16)}京円';
  if (up(1e12, 1e8)) return '$s${trim(a / 1e12)}兆円';
  if (up(1e8, 1e4)) return '$s${trim(a / 1e8)}億円';
  if (up(1e4, 1)) return '$s${commas(jsRound(a / 1e4))}万円';
  return '$s${jsNum(jsRound(a))}円';
}

String pct(double v) => '${v > 0 && v < 1 ? v.toStringAsFixed(2) : jsNum(jsRound(v * 10) / 10)}%';

/// 「何倍」の数（1.1.0+27）。100倍までは小数1桁、1万倍までは整数、1万倍からは上2桁に丸めて
/// 日本語は「約91万」「約1.2億」、英語は「about 910,000」と書く（908607.6倍のような桁の多い数を出さない）
String timesL(double x) {
  if (!x.isFinite) return '-';
  if (x < 100) return x.toStringAsFixed(1);
  if (x < 1e4) return commas(jsRound(x));
  var e = 0;
  for (var v = x; v >= 10; v /= 10) {
    e++;
  }
  var unit = 1.0;
  for (var i = 0; i < e - 1; i++) {
    unit *= 10;
  }
  final r = jsRound(x / unit) * unit;
  if (L.en) return 'about ${commas(r)}';
  if (r >= 1e8) return '約${jsNum(double.parse((r / 1e8).toStringAsFixed(r >= 1e9 ? 0 : 1)))}億';
  return '約${jsNum(double.parse((r / 1e4).toStringAsFixed(r >= 1e5 ? 0 : 1)))}万';
}
