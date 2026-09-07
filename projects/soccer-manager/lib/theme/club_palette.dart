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

  factory ClubPalette.of(String teamId) =>
      ClubPalette.fromHue(Random(teamId.hashCode).nextDouble() * 360);

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
