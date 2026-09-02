import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';

/// 「良い/悪い」を色だけで伝える箇所向けの配色ヘルパー。
/// 色覚サポートモードが有効な場合、赤緑ではなく青とオレンジを使う。
class SemanticColors {
  static bool _colorblind(BuildContext context) =>
      context.watch<SettingsController>().colorblindMode;

  static Color positive(BuildContext context) =>
      _colorblind(context) ? Colors.blue.shade700 : Colors.green.shade600;

  static Color negative(BuildContext context) =>
      _colorblind(context) ? Colors.orange.shade800 : Colors.redAccent;

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
}
