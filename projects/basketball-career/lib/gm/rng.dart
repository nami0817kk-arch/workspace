/// 種から決まる乱数(xorshift32)。状態を数ひとつで保存できるので、途中から再開しても同じ流れになる。
class Rng {
  Rng(int seed) : _s = _fix(seed);

  int _s;

  static int _fix(int seed) {
    final s = seed & 0xFFFFFFFF;
    return s == 0 ? 0x9E3779B9 : s;
  }

  int get state => _s;
  set state(int v) => _s = _fix(v);

  int next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  /// 0〜n-1。
  int nextInt(int n) {
    assert(n > 0);
    return next() % n;
  }

  /// 確率 p で true。
  bool chance(double p) => nextInt(10000) < (p * 10000).round();

  T pick<T>(List<T> list) => list[nextInt(list.length)];

  /// 重み付きで1つ選ぶ。
  T weighted<T>(Map<T, int> weights) {
    final total = weights.values.fold(0, (a, b) => a + b);
    var r = nextInt(total);
    for (final e in weights.entries) {
      if (r < e.value) return e.key;
      r -= e.value;
    }
    return weights.keys.last;
  }

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }
}
