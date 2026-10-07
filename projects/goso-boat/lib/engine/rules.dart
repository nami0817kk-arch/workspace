/// 護送ボートの決まり。画面に依存しない純粋な Dart で書く。
///
/// 決まりは1つだけ: **どこでも（岸・中州・渡っている舟の上）、見張りの力が
/// 囚人の重さ以上でなければ逃げる。** 囚人がいない場所は判定しない。
/// 舟は漕げる人（警官・看守長）がいないと出せない。
library;

/// 登場する役。同じ役の人は区別しない（数だけで状態を表す）。
enum Role {
  /// 警官。見張り1、舟を漕げる。
  police(guard: 1, weight: 0, seats: 1, rows: true, label: '警官'),

  /// 看守長。1人で2人分を見張る。舟を漕げる。
  chief(guard: 2, weight: 0, seats: 1, rows: true, label: '看守長'),

  /// 警察犬。見張り1だが舟は漕げない。
  dog(guard: 1, weight: 0, seats: 1, rows: false, label: '警察犬'),

  /// 囚人。重さ1。
  prisoner(guard: 0, weight: 1, seats: 1, rows: false, label: '囚人'),

  /// ボス。1人で囚人2人分の見張りが要る。
  boss(guard: 0, weight: 2, seats: 1, rows: false, label: 'ボス'),

  /// 手錠でつながった2人組。離れられず、舟の席も2つ使う。
  cuffed(guard: 0, weight: 2, seats: 2, rows: false, label: '手錠の2人');

  const Role({
    required this.guard,
    required this.weight,
    required this.seats,
    required this.rows,
    required this.label,
  });

  final int guard;
  final int weight;
  final int seats;
  final bool rows;
  final String label;

  bool get isGuard => guard > 0;
}

/// 場所。中州のない面は left/right だけを使う。
enum Place { left, right, island }

/// 見張りが足りているか。囚人がいなければ常に安全。
bool isSafe(int guardPower, int prisonerWeight) =>
    prisonerWeight == 0 || guardPower >= prisonerWeight;
