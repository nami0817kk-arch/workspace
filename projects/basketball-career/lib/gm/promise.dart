/// GM の約束(2026-11-15、ユーザー「2Kのプレイ動画とか調べて、質を近づける」)。
/// 2K の MyGM では、選手との約束を破ると選手が覚えていて気持ちと相性が下がる。
/// ここでは受信箱の返事が約束になり、期限まで見張って、守った・破ったを返す。
/// どれも乱数を使わない(自動で遊ぶGMは返事をしないので、釣り合いは変わらない)。
library;

enum PromiseKind {
  /// 出番の不満に「先発に入れる」と答えた。2区切りのあいだ先発(上から5人)に置く。
  starter('先発で使う'),

  /// トレードの希望に「相手を探す」と答えた。次の締め切りまでに出す。
  trade('トレードで出す'),

  /// 記者に「優勝を狙う」と答えた。そのシーズンにプレーオフ(プレーイン抜け)へ進む。
  playoffs('プレーオフに出る');

  const PromiseKind(this.label);
  final String label;
}

enum PromiseState { open, kept, broken, voided }

class Promise {
  Promise({required this.kind, required this.season, required this.due, this.player, this.name = '', this.state = PromiseState.open});

  final PromiseKind kind;

  /// 約束したシーズン。
  final int season;

  /// 期限(シーズン×区切りの数＋区切り。[Career.blockIndex] と比べる)。
  final int due;

  /// 関わる選手の id と名前(画面と知らせに出す。選手がいなくなっても名前は残す)。
  final int? player;
  final String name;
  PromiseState state;

  bool get open => state == PromiseState.open;

  /// 画面に出す1行。
  String get line => switch (kind) {
    PromiseKind.starter => '$nameを先発で使う',
    PromiseKind.trade => '$nameのトレード先を探す',
    PromiseKind.playoffs => '$season年目にプレーオフへ進む',
  };

  Map<String, dynamic> toJson() => {'k': kind.index, 's': season, 'd': due, if (player != null) 'p': player, 'n': name, 'st': state.index};

  static Promise fromJson(Map<String, dynamic> j) => Promise(
    kind: PromiseKind.values[((j['k'] as int?) ?? 0).clamp(0, PromiseKind.values.length - 1)],
    season: (j['s'] as int?) ?? 1,
    due: (j['d'] as int?) ?? 0,
    player: j['p'] as int?,
    name: (j['n'] as String?) ?? '',
    state: PromiseState.values[((j['st'] as int?) ?? 0).clamp(0, PromiseState.values.length - 1)],
  );
}

/// GM の言葉の重み(0〜100、はじめ50)。守ると上がり、破ると大きく下がる。返事の効き目に掛かる。
const startWord = 50;
const wordKept = 8;
const wordBroken = 15;

/// 返事の効き目の倍率(重み50で1倍、0で0.4倍、100で1.6倍)。
double wordScale(int word) => 0.4 + word.clamp(0, 100) / 100 * 1.2;

/// 言葉の重みの呼び名。
String wordLabel(int word) => word >= 70
    ? '信用されている'
    : word >= 45
    ? 'ふつう'
    : word >= 25
    ? '疑われている'
    : '信用されていない';
