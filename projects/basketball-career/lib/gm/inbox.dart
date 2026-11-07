/// 受信箱に届く知らせ。オーナー・選手・リーグ・スタッフから。返事を選ぶものと、読むだけのものがある。
enum Sender {
  owner('オーナー'),
  player('選手'),
  league('リーグ'),
  staff('スタッフ'),

  // 保存は番号なので、増やすときは後ろに足す
  agent('代理人');

  const Sender(this.label);
  final String label;
}

/// 知らせの種類(返事の効き目が種類ごとに決まる)。
enum MsgKind {
  /// 読むだけ。
  info,

  /// 選手が出番を増やしてほしいと言ってきた。0: 先発に入れる、1: 今の役割のまま。
  minutes,

  /// 選手がトレードを希望している。0: 相手を探すと約束する、1: 残ってもらう。
  tradeRequest,
}

class Message {
  Message({
    required this.id,
    required this.season,
    required this.from,
    required this.title,
    required this.body,
    this.kind = MsgKind.info,
    this.choices = const [],
    this.player,
    this.answer,
    this.read = false,
  });

  final int id;
  final int season;
  final Sender from;
  final String title;
  final String body;
  final MsgKind kind;

  /// 返事の候補(空なら読むだけ)。
  final List<String> choices;

  /// 関わる選手の id。
  final int? player;

  /// 選んだ返事の番号(まだなら null)。
  int? answer;
  bool read;

  bool get needsAnswer => choices.isNotEmpty && answer == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        's': season,
        'f': from.index,
        't': title,
        'b': body,
        'k': kind.index,
        if (choices.isNotEmpty) 'c': choices,
        if (player != null) 'p': player,
        if (answer != null) 'a': answer,
        if (read) 'r': true,
      };

  static Message fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as int,
        season: j['s'] as int,
        from: Sender.values[(j['f'] as int).clamp(0, Sender.values.length - 1)],
        title: j['t'] as String,
        body: j['b'] as String,
        kind: MsgKind.values[((j['k'] as int?) ?? 0).clamp(0, MsgKind.values.length - 1)],
        choices: [for (final x in (j['c'] as List? ?? const [])) x as String],
        player: j['p'] as int?,
        answer: j['a'] as int?,
        read: (j['r'] as bool?) ?? false,
      );
}
