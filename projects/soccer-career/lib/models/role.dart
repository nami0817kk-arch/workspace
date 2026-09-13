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

import 'attributes.dart';
import 'entourage.dart';

enum PlayerRole {
  // ---- GK ----
  sweeperKeeper(
    '守備範囲型',
    Position.gk,
    [3, 0, 3, 0, 2, 3, 8],
    [Tactic.possession, Tactic.press],
    '後ろから繋ぎ、前に出て刈る。足元と機動力まで見られる。',
  ),
  shotStopper(
    '一対一型',
    Position.gk,
    [0, 0, 0, 0, 2, 3, 12],
    [Tactic.counter, Tactic.direct],
    'ゴール前で止めることに全部を置く。',
  ),

  // ---- CB ----
  stopper(
    '潰し屋',
    Position.cb,
    [1, 0, 1, 0, 9, 6, 0],
    [Tactic.press, Tactic.direct],
    '前に出て潰す。当たりと読みで評価される。',
  ),
  ballPlayingDefender(
    '繋ぐCB',
    Position.cb,
    [2, 0, 6, 2, 6, 3, 0],
    [Tactic.possession, Tactic.balanced],
    '最終ラインから組み立てる。蹴れることが値段になる。',
  ),

  // ---- SB ----
  wingBack(
    '上がるSB',
    Position.sb,
    [7, 1, 4, 6, 2, 2, 0],
    [Tactic.possession, Tactic.counter],
    '最後まで駆け上がる。守備の比重は下がる。',
  ),
  fullBack(
    '締めるSB',
    Position.sb,
    [3, 0, 2, 1, 8, 4, 0],
    [Tactic.press, Tactic.direct],
    'サイドを閉じる。上がらないぶん、守備で測られる。',
  ),

  // ---- DM ----
  anchor(
    'アンカー',
    Position.dm,
    [2, 0, 3, 1, 8, 6, 0],
    [Tactic.press, Tactic.direct],
    '最終ラインの前を埋める。潰す力がすべて。',
  ),
  regista(
    'レジスタ',
    Position.dm,
    [1, 1, 9, 3, 3, 3, 0],
    [Tactic.possession, Tactic.balanced],
    '低い位置から配る。蹴れれば守備は問われない。',
  ),

  // ---- CM ----
  dynamo(
    'ボックス・トゥ・ボックス',
    Position.cm,
    [4, 2, 3, 2, 7, 6, 0],
    [Tactic.press, Tactic.direct],
    '上下動で試合を消耗させる。走力と守備で測られる。',
  ),
  playmaker(
    '司令塔',
    Position.cm,
    [1, 1, 9, 5, 2, 2, 0],
    [Tactic.possession, Tactic.balanced],
    '中央で持って配る。守備は数えられない。',
  ),

  // ---- AM ----
  shadowStriker(
    'シャドー',
    Position.am,
    [4, 8, 3, 4, 0, 2, 0],
    [Tactic.counter, Tactic.direct],
    '二列目から飛び込む。点を取ることで測られる。',
  ),
  numberTen(
    '10番',
    Position.am,
    [2, 2, 8, 7, 1, 2, 0],
    [Tactic.possession, Tactic.balanced],
    '最後の一本を出す。持って外して配る。',
  ),

  // ---- WG ----
  winger(
    '突破型',
    Position.wg,
    [8, 2, 3, 8, 1, 1, 0],
    [Tactic.counter, Tactic.possession],
    '縦に剥がして上げる。速さと足元だけ。',
  ),
  insideForward(
    '内に入る',
    Position.wg,
    [4, 7, 3, 5, 0, 2, 0],
    [Tactic.counter, Tactic.direct],
    '中へ切れ込んで撃つ。点で測られる。',
  ),

  // ---- ST ----
  poacher(
    '点取り屋',
    Position.st,
    [2, 10, 1, 2, 0, 3, 0],
    [Tactic.counter, Tactic.direct],
    '枠内に流し込むこと以外は問われない。',
  ),
  targetMan(
    '収める役',
    Position.st,
    [1, 4, 4, 2, 0, 8, 0],
    [Tactic.direct, Tactic.possession],
    '当たって収めて、味方を使う。身体と繋ぎで測られる。',
  );

  const PlayerRole(
    this.label,
    this.position,
    this.weights,
    this.tactics,
    this.note,
  );

  final String label;

  /// この役割に就けるポジション。
  final Position position;

  /// 総合力の重み。`Attributes` の既定と同じ並び
  /// （pace / shooting / passing / dribbling / defending / physical / gk）。
  final List<int> weights;

  /// この役割を使う監督の戦術。**ここに無い監督の下では就けない。**
  final List<Tactic> tactics;

  final String note;

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
