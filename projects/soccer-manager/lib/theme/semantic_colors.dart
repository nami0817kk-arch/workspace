import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';

/// 「良い/悪い」を色だけで伝える箇所向けの配色ヘルパー。
/// 色覚サポートモードが有効な場合、赤緑ではなく青とオレンジを使う。
class SemanticColors {
  static bool _colorblind(BuildContext context) =>
      context.watch<SettingsController>().colorblindMode;

  static bool _light(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  /// 良い知らせの色。明暗で濃さを変える。1つの固定色(green.shade600)は
  /// 白地で 3.3:1、暗い箱で 4.3:1 と、どちらでも AA に届かなかった。
  static Color positive(BuildContext context) => _colorblind(context)
      ? (_light(context) ? const Color(0xFF1558B0) : const Color(0xFF7DB8FF))
      : (_light(context) ? const Color(0xFF1B7A3A) : const Color(0xFF6CD48C));

  static Color negative(BuildContext context) => _colorblind(context)
      ? (_light(context) ? const Color(0xFFB04A00) : const Color(0xFFFFB066))
      : (_light(context) ? const Color(0xFFC62828) : const Color(0xFFFF8A80));

  static Color neutral(BuildContext context) => Colors.blueGrey;

  /// 補足説明・注記など、本文より控えめに見せたい文字の色。
  ///
  /// `Colors.grey` (#9E9E9E) を直接使うと、明るいテーマの背景に対して
  /// コントラスト比が 2.55 しかなく、WCAG AA の 4.5 を大きく下回る
  /// (12px の注記で実測)。薄すぎて読めない文字になる。
  ///
  /// 単一の固定色では両テーマを満たせない。明るい背景に合う濃さ(#616161)は
  /// 暗い背景で 3.19 しか出ず、暗い背景に合う薄さは明るい背景で落ちる。
  /// Material 3 の onSurfaceVariant は、その配色の surface に対して十分な
  /// コントラストが出るよう定義されているので、それを使う。
  static Color subtleText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// 色の付いた文字・アイコン(注意の橙・星の黄・負傷の赤など)を、いまの
  /// 地で読める濃さに寄せる。色相はそのままで、明るい地なら暗く、暗い地
  /// なら明るくする。
  ///
  /// 画面ごとに `Colors.orange` や `Colors.amber` を直書きしていた箇所は、
  /// 暗い地では読めても白い地では 1.6〜2.8:1 しか出ず読めなかった
  /// (明るい見た目を足したとき、tool/art/contrast_audit.dart で実測)。
  /// [min] は文字なら 4.5、星などの飾りのアイコンなら 3.0。
  static Color ink(BuildContext context, Color color, {double min = 4.5}) =>
      readableOn(color, Theme.of(context).colorScheme.surfaceContainerLow,
          min: min);

  /// [color] を [background] の上で [min] 以上の差が出るまで暗く(明るく)する。
  static Color readableOn(Color color, Color background, {double min = 4.5}) {
    final darken = background.computeLuminance() > 0.4;
    var hsl = HSLColor.fromColor(color.withValues(alpha: 1));
    for (var i = 0; i < 25 && contrast(hsl.toColor(), background) < min; i++) {
      final l = hsl.lightness + (darken ? -0.03 : 0.03);
      hsl = hsl.withLightness(l.clamp(0.0, 1.0));
    }
    return hsl.toColor().withValues(alpha: color.a);
  }

  /// WCAG のコントラスト比。
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
