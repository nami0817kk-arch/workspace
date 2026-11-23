import 'package:flutter/material.dart';

import '../theme/fm_look.dart';

export '../theme/fm_look.dart' show FmLook, FmPalette;

/// Football Manager 風のパネル。見出しの帯(左に太い印)と、細い枠、角の小さい
/// 箱。カードより密で、画面を「帳票の集まり」に見せる。
class FmPanel extends StatelessWidget {
  const FmPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
  });

  final String title;
  final Widget child;

  /// 見出しの右端に置くもの(件数・ボタンなど)。
  final Widget? trailing;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
        boxShadow: FmLook.shadowOf(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(color: scheme.primary, width: 3),
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// FM 風の表の1行(ラベルと値を左右に置く)。
class FmRow extends StatelessWidget {
  const FmRow(
      {super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? scheme.onSurface)),
        ],
      ),
    );
  }
}

/// 角丸の大きさ。横画面(FM 風)では、どの箱も小さい角にそろえる。
double fmRadius(BuildContext context, double normal) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height ? 6 : normal;
}

/// FM 風の暗い配色(案B)。配色と部品の決まりは `theme/fm_look.dart`。
ThemeData fmDarkTheme(ThemeData darkBase) =>
    fmLookTheme(darkBase, FmPalette.dark);

/// FM 風の明るい配色(案A)。
ThemeData fmLightTheme(ThemeData lightBase) =>
    fmLookTheme(lightBase, FmPalette.light);

/// 設定の明暗にかかわらず、中を暗い配色(案B)で描く。
///
/// 試合の画面で使う。芝の絵が主役なので、周りを白くすると芝が浮いて
/// 見え、スコアと実況より絵の縁が目立つ。
class FmDarkOnly extends StatelessWidget {
  const FmDarkOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    if (current.brightness == Brightness.dark) return child;
    final base = current.copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: current.colorScheme.primary, brightness: Brightness.dark),
    );
    return Theme(data: fmDarkTheme(base), child: child);
  }
}

/// 横画面のときだけ、中の画面すべてに FM 風の密なテーマを当てる。
/// ホームの外(その他メニューから開く画面)も同じ見た目にそろう。
///
/// **明暗は設定に従う。** 以前は横画面だけ必ず暗い版に差し替えていて、
/// 設定で「ライトモード」を選んでも横画面(スマホの標準)は暗いままだった。
/// いまのテーマ(MaterialApp が themeMode で選んだもの)の明暗を見る。
class FmThemeScope extends StatelessWidget {
  const FmThemeScope({super.key, required this.child, this.dark, this.light});

  final Widget child;

  /// アプリの暗いテーマ。渡されなければ、いまのテーマの暗い版を作る。
  final ThemeData? dark;

  /// アプリの明るいテーマ。渡されなければ、いまのテーマを使う。
  final ThemeData? light;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= size.height) return child;
    // 文字の大きさは、いまのテーマ(MaterialApp が整えたもの)を土台にし、
    // 配色だけを差し替える。
    final current = Theme.of(context);
    if (current.brightness == Brightness.light) {
      final base = current.copyWith(
          colorScheme: light?.colorScheme ?? current.colorScheme);
      return Theme(data: fmLightTheme(base), child: child);
    }
    final base = current.copyWith(
      brightness: Brightness.dark,
      colorScheme: dark?.colorScheme ??
          ColorScheme.fromSeed(
              seedColor: current.colorScheme.primary,
              brightness: Brightness.dark),
    );
    return Theme(data: fmDarkTheme(base), child: child);
  }
}
