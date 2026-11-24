import 'dart:math';

/// 乱数。テストで種を固定できるように、Random を直に使わずここを通す。
class Rng {
  Rng([int? seed]) : _r = Random(seed);
  Random _r;

  /// 自分から新しい種を引き、その種で引き直す（年の初めの保存で使う。種を残せば、同じ年を同じ乱数で流し直せる）。
  int reseed() {
    // 1 << 32 は Web（整数が32ビット）では 0 になって落ちる。どちらでも引ける幅にする。
    final s = _r.nextInt(0x7fffffff);
    _r = Random(s);
    return s;
  }

  /// 残しておいた種から引き直す。
  void setSeed(int s) => _r = Random(s);

  double next() => _r.nextDouble();

  /// a 以上 b 以下の整数。
  int range(int a, int b) => a + _r.nextInt(b - a + 1);

  bool chance(double p) => _r.nextDouble() < p;

  T pick<T>(List<T> l) => l[_r.nextInt(l.length)];

  /// 重み付きで1つ選ぶ。
  T wpick<T>(List<T> items, double Function(T) w) {
    final total = items.fold<double>(0, (s, i) => s + w(i));
    var r = _r.nextDouble() * total;
    for (final i in items) {
      r -= w(i);
      if (r <= 0) return i;
    }
    return items.last;
  }

  /// 標準偏差およそ1の正規乱数。
  double gauss() {
    var u = 0.0;
    for (var i = 0; i < 6; i++) {
      u += _r.nextDouble();
    }
    return (u - 3) / sqrt(0.5);
  }
}

int clampInt(int v, int a, int b) => v < a ? a : (v > b ? b : v);
double clampD(double v, double a, double b) => v < a ? a : (v > b ? b : v);

double _erf(double x) {
  final s = x < 0 ? -1.0 : 1.0;
  x = x.abs();
  final t = 1 / (1 + 0.3275911 * x);
  final y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          exp(-x * x);
  return s * y;
}

/// 標準正規分布の累積分布関数。
double phi(double z) => 0.5 * (1 + _erf(z / sqrt2));

/// 大きな数を「約◯億」のように読みやすくする。
String fmtN(double n) {
  String comma(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  if (n >= 1e12) return '${(n / 1e12).toStringAsFixed(1)}兆';
  if (n >= 1e8) return '${(n / 1e8).toStringAsFixed(1)}億';
  if (n >= 1e4) return '${comma((n / 1e4).round())}万';
  return comma(n.round());
}

const _gengo = <(int, String)>[
  // 生まれは一五二五年から。天文より前の年が「天文-2年」にならないよう、大永・享禄も持つ。
  (1521, '大永'),
  (1528, '享禄'),
  (1532, '天文'),
  (1555, '弘治'),
  (1558, '永禄'),
  (1570, '元亀'),
  (1573, '天正'),
  (1593, '文禄'),
  (1596, '慶長'),
  (1615, '元和'),
  (1624, '寛永'),
  (1644, '正保'),
  (1648, '慶安'),
  (1652, '承応'),
  (1655, '明暦'),
  (1658, '万治'),
  (1661, '寛文'),
];

String gengo(int y) {
  var g = _gengo.first;
  for (final x in _gengo) {
    if (y >= x.$1) g = x;
  }
  final n = y - g.$1 + 1;
  return '${g.$2}${n == 1 ? '元' : n}年';
}
