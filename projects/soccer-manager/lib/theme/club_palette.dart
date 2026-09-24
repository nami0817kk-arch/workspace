import 'dart:math';

import 'package:flutter/material.dart';

/// チームIDから決定論的に決まるクラブカラー。
///
/// エンブレム(ClubEmblem)とピッチ上のユニフォーム(PitchGame)が別々に色を
/// 決めていると、同じクラブなのに画面ごとに色が変わってしまう。導出を
/// ここ1箇所に置いて、両方から同じ値を引く。
class ClubPalette {
  /// 色相(0..360)。この1つの値からすべての色を導く。
  final double hue;

  const ClubPalette.fromHue(this.hue);

  /// クラブ名に色の語が入っていれば、その色を使う。無ければIDから決める。
  ///
  /// 「紅獅子ユナイテッド」が緑、「青嵐フットボールクラブ」が橙で描かれて
  /// いた。名前に書いてある色と、エンブレムやユニフォームの色が無関係だと、
  /// 作り手が決めた色には見えない。名前で色が決まるクラブだけ、名前に従う。
  factory ClubPalette.of(String teamId, {String? clubName}) {
    final named = clubName == null ? null : hueForName(clubName);
    return ClubPalette.fromHue(
        named ?? Random(teamId.hashCode).nextDouble() * 360);
  }

  /// 名前に含まれる色の語から色相を引く。見つからなければ null。
  ///
  /// 白・黒・灰・銀は色相で表せない(彩度の話になる)ため入れていない。
  /// 入れると「灰色ウニオン」が赤みの灰色のような中途半端な色になる。
  static double? hueForName(String name) {
    final lower = name.toLowerCase();
    for (final entry in _hueWords.entries) {
      if (lower.contains(entry.key.toLowerCase())) return entry.value;
    }
    return null;
  }

  /// 色の語と色相。長い語を先に見る(「青薔薇」を「青」より先に拾う必要は
  /// ないが、「黄金」が「黄」と別の色になるような組み合わせで効く)。
  // i18n-ignore: 画面に出す文言ではなく、クラブ名を照合するための語彙。
  static const Map<String, double> _hueWords = {
    // 日本語
    '紅葉': 20,
    '黄金': 45,
    '紺碧': 205,
    '紫紺': 270,
    '青薔薇': 215,
    '鳶色': 25,
    '橄欖': 75,
    '常盤': 150,
    '緑陰': 120,
    '青嵐': 210,
    '紅': 0,
    '赤': 0,
    '朱': 10,
    '橙': 28,
    '黄': 48,
    '緑': 120,
    '翠': 140,
    '碧': 190,
    '蒼': 205,
    '青': 215,
    '紺': 225,
    '紫': 280,
    '菫': 275,
    '桜': 340,
    '桃': 345,
    '薔薇': 350,
    // 英語
    'crimson': 350,
    'scarlet': 5,
    'red': 0,
    'amber': 40,
    'gold': 45,
    'olive': 75,
    'emerald': 150,
    'fern': 120,
    'green': 120,
    'azure': 200,
    'navy': 225,
    'blue': 215,
    'violet': 280,
    'purple': 285,
    'rose': 345,
  };

  /// エンブレムの地の色。
  Color get base => HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();

  /// エンブレムの差し色。
  Color get accent =>
      HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.30).toColor();

  /// ピッチ上のユニフォーム色。芝の緑の上でも沈まないよう、
  /// エンブレムの地の色より明るくする。
  Color get kit => HSLColor.fromAHSL(1, hue, 0.72, 0.58).toColor();

  /// ユニフォームの縁取り。芝と同系色のクラブでも輪郭が見えるようにする。
  Color get kitOutline => HSLColor.fromAHSL(1, hue, 0.50, 0.18).toColor();

  /// ゴールキーパーのユニフォーム。実際の試合と同じく、自チームの
  /// フィールドプレーヤーと必ず違う色にする。補色を取れば、どんな
  /// クラブカラーでも自動的に離れる。
  Color get keeperKit =>
      HSLColor.fromAHSL(1, (hue + 180) % 360, 0.75, 0.62).toColor();

  Color get keeperOutline =>
      HSLColor.fromAHSL(1, (hue + 180) % 360, 0.50, 0.18).toColor();

  ClubPalette shiftedHue(double degrees) =>
      ClubPalette.fromHue((hue + degrees) % 360);

  /// 2つの色相の隔たり(0..180)。
  static double hueDistance(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  /// [home] と見分けがつく色を返す。近すぎるときだけ色相をずらす。
  ///
  /// クラブの色はIDから決まるので、青いクラブ同士の対戦がふつうに起きる。
  /// 実際のサッカーがアウェイユニフォームで解決しているのと同じことをする。
  ClubPalette distinguishedFrom(ClubPalette home) =>
      hueDistance(hue, home.hue) < minimumHueSeparation
          ? shiftedHue(140)
          : this;

  /// これ以上近い色相同士は、芝の上で見分けがつかないとみなす。
  static const double minimumHueSeparation = 45;
}
