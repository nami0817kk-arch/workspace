/// コツ。キャリアの終盤に1つだけ、自分がやってきたことから特性が身に付く。
///
/// 特性は**生まれ持ったもの**で、伸ばせない——という前提でずっと来た。
/// そのぶん、20年やってきたことが選手の「性質」には一切乗らなかった。
/// パスばかり選び続けた選手も、最後まで司令塔にはならない。
///
/// ここで開けるのは**1つだけ**。しかも:
/// - 何度もその場面で勝負してきた能力からしか出ない（`Trait.knackKey`）
/// - 生まれつきでしか手に入らないもの（早熟・稀なもの・欠点）は出さない
/// - 出す3つは**キャリアから決まる**ので、待っても引き直せない
library;

import '../models/attributes.dart';
import '../models/career.dart';
import '../models/traits.dart';

class Knacks {
  const Knacks._();

  /// 掴むのに要る試合経験。だいたい10シーズン出続けたあたり。
  static const int experienceNeeded = 350;

  /// 掴むのに要る「練習で大成功した週」。
  ///
  /// **経験点では買わせない。** 自動で振る側（既定）は経験点が貯まらないので、
  /// 値段を経験点にすると、既定のまま遊ぶ人だけ一生掴めなくなる。
  /// 積み上がるのは追い込んだ週のほうで、そちらは誰でも積める。
  static const int greatWeeksNeeded = 26;

  /// その場面で選んできた回数。ここを下回るカテゴリからは出さない。
  static const int momentsNeeded = 40;

  /// 出す数。
  static const int offerCount = 3;

  /// もう掴んだか、まだ条件に届いていないか。
  static bool canLearn(CareerState state) =>
      !state.learnedKnack &&
      state.development.experience >= experienceNeeded &&
      state.development.greatWeeks >= greatWeeksNeeded &&
      offer(state).isNotEmpty;

  /// あと何が足りないか。届いていれば null。
  ///
  /// 「まだ出ない」のか「もう掴んだ」のかが分からないのが一番困る。
  static String? missing(CareerState state) {
    if (state.learnedKnack) return 'コツは1つだけ。もう掴んでいる';
    final development = state.development;
    if (development.experience < experienceNeeded) {
      return '試合経験があと${experienceNeeded - development.experience}';
    }
    if (development.greatWeeks < greatWeeksNeeded) {
      return '練習の大成功があと${greatWeeksNeeded - development.greatWeeks}回';
    }
    if (offer(state).isEmpty) {
      return '同じ場面で$momentsNeeded回は勝負していないと、掴むものが無い';
    }
    return null;
  }

  /// **いちばん勝負してきた場面の回数。** 取得条件の3つ目。
  ///
  /// `missing` は「今いちばん足りないもの」を1つ返すので、残り2つが
  /// どこまで来ているのかが見えなかった。3つ全部を並べるために要る。
  static int bestMoments(CareerState state) {
    var best = 0;
    for (final count in state.development.choices.values) {
      if (count > best) best = count;
    }
    return best;
  }

  /// 掴める候補。**キャリアから決まるので、待っても引き直せない。**
  ///
  /// 引き直せると「良いコツが出るまで待つ」が最適解になり、
  /// 何をやってきたかが関係なくなる。
  static List<Trait> offer(CareerState state) {
    final player = state.player;
    final choices = state.development.choices;
    // よく選んできたカテゴリから順に。
    final keys = [
      for (final key in AttributeKey.values)
        if ((choices[key] ?? 0) >= momentsNeeded) key,
    ]..sort((a, b) => (choices[b] ?? 0).compareTo(choices[a] ?? 0));
    if (keys.isEmpty) return const [];

    // **1つの場面からは1つだけ出す。**
    //
    // 以前は上位のカテゴリから順に3つ埋めていたので、一番よく選ぶ場面の
    // 候補だけで枠が埋まり、しかも並び順の先頭が必ず取られた——実測で
    // CM の90%が「司令塔」、GK の97%が「反応の鬼」、CB の82%が「鉄壁」。
    // **同じポジションなら同じコツ**になっていた。
    // 場面ごとに1つずつにすると、3つの候補が**キャリアの形**を映す。
    final picked = <Trait>[];
    for (final key in keys) {
      if (picked.length >= offerCount) break;
      final candidates = [
        for (final trait in Trait.knacks)
          if (trait.knackKey == key &&
              !player.traits.contains(trait) &&
              trait.fitsPosition(player.position) &&
              player.traits.every((t) => Trait.compatible(t, trait)) &&
              picked.every((p) => Trait.compatible(p, trait)))
            trait,
      ];
      if (candidates.isEmpty) continue;
      picked.add(candidates[_pick(player.name, key) % candidates.length]);
    }
    return picked;
  }

  /// その選手にとって、その場面から出るのはどれか。
  ///
  /// **待っても引き直せないこと**が要（引き直せると「良いコツが出るまで
  /// 待つ」が最適解になり、何をやってきたかが関係なくなる）。
  /// 経験値のような育つ数字ではなく、**選手を決めた時点で決まっているもの**
  /// から出す。文字コードの和にしてあるのは、`String.hashCode` が
  /// 実行ごとに変わるため（クラブの見た目と同じ理屈）。
  static int _pick(String name, AttributeKey key) {
    var sum = key.index * 7;
    for (final unit in name.codeUnits) {
      sum += unit;
    }
    return sum;
  }
}
