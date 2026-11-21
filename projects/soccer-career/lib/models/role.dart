// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。
// ignore_for_file: prefer_initializing_formals

/// **役割（ロール）。同じポジションでも、求められるものが違う。**
///
/// 総合力はポジションの重み付き平均で出しているので、**そのポジションが
/// 求めないものを伸ばすほど総合力が下がる**。実測（`shape_sim`）で、
/// 中盤の選手を守備一本で育てるとピークが 75.4 → 69.4、代表は 35 → 4 キャップ
/// まで落ちた。「尖らせても潰れない」ところまでは来ていたが、
/// **「尖らせたほうが得」にはなっていなかった**。
///
/// 役割は**重みの置き換え**で、上乗せではない。守備に寄せれば、そのぶん
/// パスやシュートは軽く見られる。**どこを重く見てもらうかを選ぶ**だけ。
///
/// **選べるのは、今の監督が使う役割だけ。** 好きに付け替えられると
/// 「一番高くなる役割を選ぶ」がただの正解になる。欲しい役割が無ければ、
/// 移籍するか監督が代わるのを待つことになる。
library;

import '../l10n/lang.dart';
import 'attributes.dart';
import 'entourage.dart';

enum PlayerRole {
  // ---- GK ----
  sweeperKeeper(
    Say('守備範囲型', 'Sweeper keeper'),
    Position.gk,
    [3, 0, 3, 0, 2, 3, 8],
    [Tactic.possession, Tactic.press],
    Say('後ろから繋ぎ、前に出て刈る。足元と機動力まで見られる。', 'Plays out from the back and comes to sweep. Judged on feet and mobility too.'),
  ),
  shotStopper(
    Say('一対一型', 'Shot stopper'),
    Position.gk,
    [0, 0, 0, 0, 2, 3, 12],
    [Tactic.counter, Tactic.direct],
    Say('ゴール前で止めることに全部を置く。', 'Everything goes into stopping shots in his own box.'),
  ),

  // ---- CB ----
  stopper(
    Say('潰し屋', 'Stopper'),
    Position.cb,
    [1, 0, 1, 0, 9, 6, 0],
    [Tactic.press, Tactic.direct],
    Say('前に出て潰す。当たりと読みで評価される。', 'Steps out and wins it. Judged on contact and reading the game.'),
  ),
  ballPlayingDefender(
    Say('繋ぐCB', 'Ball-playing centre-back'),
    Position.cb,
    [2, 0, 6, 2, 6, 3, 0],
    [Tactic.possession, Tactic.balanced],
    Say('最終ラインから組み立てる。蹴れることが値段になる。', 'Builds from the last line. Being able to pass is what he is paid for.'),
  ),

  // ---- SB ----
  wingBack(
    Say('上がるSB', 'Attacking full-back'),
    Position.sb,
    [7, 1, 4, 6, 2, 2, 0],
    [Tactic.possession, Tactic.counter],
    Say('最後まで駆け上がる。守備の比重は下がる。', 'Runs to the byline. Defending counts for less.'),
  ),
  fullBack(
    Say('締めるSB', 'Shutting full-back'),
    Position.sb,
    [3, 0, 2, 1, 8, 4, 0],
    [Tactic.press, Tactic.direct],
    Say('サイドを閉じる。上がらないぶん、守備で測られる。', 'Closes the flank. He does not go forward, so he is measured on defending.'),
  ),

  // ---- DM ----
  anchor(
    Say('アンカー', 'Anchor'),
    Position.dm,
    [2, 0, 3, 1, 8, 6, 0],
    [Tactic.press, Tactic.direct],
    Say('最終ラインの前を埋める。潰す力がすべて。', 'Fills the space in front of the back line. Breaking play up is everything.'),
  ),
  regista(
    Say('レジスタ', 'Deep-lying playmaker'),
    Position.dm,
    [1, 1, 9, 3, 3, 3, 0],
    [Tactic.possession, Tactic.balanced],
    Say('低い位置から配る。蹴れれば守備は問われない。', 'Distributes from deep. If he can pass, defending is not asked of him.'),
  ),

  // ---- CM ----
  dynamo(
    Say('ボックス・トゥ・ボックス', 'Box to box'),
    Position.cm,
    [4, 2, 3, 2, 7, 6, 0],
    [Tactic.press, Tactic.direct],
    Say('上下動で試合を消耗させる。走力と守備で測られる。', 'Runs the game into the ground. Measured on running and defending.'),
  ),
  playmaker(
    Say('司令塔', 'Playmaker'),
    Position.cm,
    [1, 1, 9, 5, 2, 2, 0],
    [Tactic.possession, Tactic.balanced],
    Say('中央で持って配る。守備は数えられない。', 'Takes it and spreads it from the middle. Defending does not count.'),
  ),

  // ---- AM ----
  shadowStriker(
    Say('シャドー', 'Shadow striker'),
    Position.am,
    [4, 8, 3, 4, 0, 2, 0],
    [Tactic.counter, Tactic.direct],
    Say('二列目から飛び込む。点を取ることで測られる。', 'Arrives from deep. Measured on goals.'),
  ),
  numberTen(
    Say('10番', 'Number 10'),
    Position.am,
    [2, 2, 8, 7, 1, 2, 0],
    [Tactic.possession, Tactic.balanced],
    Say('最後の一本を出す。持って外して配る。', 'Plays the final ball. Holds it, beats a man, finds the pass.'),
  ),

  // ---- WG ----
  winger(
    Say('突破型', 'Flying winger'),
    Position.wg,
    [8, 2, 3, 8, 1, 1, 0],
    [Tactic.counter, Tactic.possession],
    Say('縦に剥がして上げる。速さと足元だけ。', 'Beats his man outside and crosses. Pace and feet, nothing else.'),
  ),
  insideForward(
    Say('内に入る', 'Inside forward'),
    Position.wg,
    [4, 7, 3, 5, 0, 2, 0],
    [Tactic.counter, Tactic.direct],
    Say('中へ切れ込んで撃つ。点で測られる。', 'Cuts inside and shoots. Measured on goals.'),
  ),

  // ---- ST ----
  poacher(
    Say('点取り屋', 'Poacher'),
    Position.st,
    [2, 10, 1, 2, 0, 3, 0],
    [Tactic.counter, Tactic.direct],
    Say('枠内に流し込むこと以外は問われない。', 'Nothing matters except putting it on target.'),
  ),
  targetMan(
    Say('収める役', 'Target man'),
    Position.st,
    [1, 4, 4, 2, 0, 8, 0],
    [Tactic.direct, Tactic.possession],
    Say('当たって収めて、味方を使う。身体と繋ぎで測られる。', 'Holds it up and brings others in. Measured on physique and link-up.'),
  );

  const PlayerRole(
    Say label,
    this.position,
    this.weights,
    this.tactics,
    Say note,
  ) : _label = label,
      _note = note;

  final Say _label;

  String get label => _label.t;

  /// この役割に就けるポジション。
  final Position position;

  /// 総合力の重み。`Attributes` の既定と同じ並び
  /// （pace / shooting / passing / dribbling / defending / physical / gk）。
  final List<int> weights;

  /// この役割を使う監督の戦術。**ここに無い監督の下では就けない。**
  final List<Tactic> tactics;

  final Say _note;

  String get note => _note.t;

  /// その戦術の監督が、そのポジションに用意している役割。
  ///
  /// 空でも構わない——**「役割なし（そのポジションの標準）」は常に選べる**ので、
  /// 選択肢が無くなることはない。
  static List<PlayerRole> offeredBy(Tactic tactic, Position position) => [
    for (final r in PlayerRole.values)
      if (r.position == position && r.tactics.contains(tactic)) r,
  ];

  static PlayerRole? parse(String? name) {
    for (final r in PlayerRole.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}
