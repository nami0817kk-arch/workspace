/// 受信箱に届く知らせ。オーナー・選手・リーグ・スタッフから。返事を選ぶものと、読むだけのものがある。
enum Sender {
  owner('オーナー'),
  player('選手'),
  league('リーグ'),
  staff('スタッフ'),

  // 保存は番号なので、増やすときは後ろに足す
  agent('代理人'),
  press('記者');

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

  /// 記者の質問。0: 強気に答える、1: 慎重に答える、2: はぐらかす。
  press,

  /// シーズン初めのオーナーとの目標の話し合い。0: 受ける、1: 下げてもらう、2: もっと上を約束する。
  /// 最初の区切りを進めるまでに答える(答えなければ受けたことになる)。保存は番号なので後ろに足す。
  ownerGoal,

  /// スカウトの報告と、次に見に行く先([ScoutFocus] の番号を返事で選ぶ)。
  scoutFocus,

  /// 選手の出来事: 契約最終年に燃えている。0: 残ってほしいと伝える、1: 結果を見てから。
  storyContract,

  /// 選手の出来事: 新人がプロの壁に当たった。0: 出番を増やす、1: じっくり育てる。
  storyRookie,

  /// 選手の出来事: ベテランが引退を考えている。0: もう1年と頼む、1: 本人に任せる。
  storyVeteran,

  /// オフの面談(2026-11-19)。気持ちの低い選手が話をしに来た。
  /// 0: 来季は先発で使うと約束する、1: トレード先を探すと約束する、2: チームの考えを説明する。
  offTalk,

  /// オフの出来事(2026-11-19): 合宿の場所。0: 地元で公開練習、1: 遠くで合宿、2: 選手を休ませる。
  offCamp,

  /// オフの出来事: 代表に呼ばれた。0: 送り出す、1: 休ませたいと断る。
  offNational,

  /// オフの出来事: 長く在籍した選手が引退した。0: 背番号を永久欠番にする、1: 記念の映像を流す。
  offRetire,

  /// シーズン前の記者の順位予想(2026-11-19)。0: 予想を覆してみせる、1: 妥当な予想だ。
  forecast,

  /// シーズン前の方針の宣言(2026-11-19)。0: 優勝を狙う、1: 若手を育てる、2: 立て直す、3: 宣言しない。
  declare,
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
