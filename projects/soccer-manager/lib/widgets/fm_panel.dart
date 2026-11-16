import 'package:flutter/material.dart';

/// Football Manager 風のパネル。見出しの帯(左に太い印)と、細い枠、角の小さい
/// 箱。カードより密で、画面を「帳票の集まり」に見せる。
class FmPanel extends StatelessWidget {
  const FmPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(color: scheme.primary, width: 3),
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.only(left: 9, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
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
  const FmRow({super.key, required this.label, required this.value, this.valueColor});

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

/// 横画面で使う、Football Manager 風の密な見た目。角の小さい細枠の箱、
/// 詰めた一覧、小さいボタン。既存のテーマの色はそのまま使う。
ThemeData fmDenseTheme(ThemeData base) {
  final scheme = base.colorScheme;
  // 文字も一回り小さくして、1画面の情報量を増やす。見出しは明朝(セリフ)を
  // やめ、小さい太字にそろえる(FM の見出しは小さく、太い)。
  final body = base.textTheme.bodyMedium?.fontFamily;
  var text = base.textTheme.apply(fontSizeFactor: 0.93);
  TextStyle? head(TextStyle? s, double size) => s?.copyWith(
      fontFamily: body, fontSize: size, fontWeight: FontWeight.bold);
  text = text.copyWith(
    headlineMedium: head(text.headlineMedium, 19),
    headlineSmall: head(text.headlineSmall, 17),
    titleLarge: head(text.titleLarge, 15),
    titleMedium: head(text.titleMedium, 13.5),
    titleSmall: head(text.titleSmall, 12.5),
  );
  return base.copyWith(
    textTheme: text,
    // 見出しの帯。明朝(セリフ)をやめ、太字の小さい字で、少し濃い下地にする。
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHighest,
      toolbarHeight: 40,
      titleTextStyle: TextStyle(
        fontFamily: base.textTheme.bodyMedium?.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 6),
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
  );
}

/// 角丸の大きさ。横画面(FM 風)では、どの箱も小さい角にそろえる。
double fmRadius(BuildContext context, double normal) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height ? 4 : normal;
}

/// FM 風の暗い配色。白地ではなく、暗い青灰の下地に、少し明るい箱を重ね、
/// 強調は青。箱ごとに明るさを1段ずつ上げて、枠線と合わせて層を見せる。
ThemeData fmDarkTheme(ThemeData darkBase) {
  const surface = Color(0xFF0F151D);
  const accent = Color(0xFF4FA3F7);
  final scheme = darkBase.colorScheme.copyWith(
    brightness: Brightness.dark,
    surface: surface,
    surfaceContainerLowest: const Color(0xFF0B1017),
    surfaceContainerLow: const Color(0xFF151C26),
    surfaceContainer: const Color(0xFF19222D),
    surfaceContainerHigh: const Color(0xFF1E2833),
    surfaceContainerHighest: const Color(0xFF263241),
    outline: const Color(0xFF5A6B7F),
    outlineVariant: const Color(0xFF2C3846),
    onSurface: const Color(0xFFE6EBF1),
    onSurfaceVariant: const Color(0xFF9BA9BA),
    primary: accent,
    onPrimary: const Color(0xFF06121F),
    primaryContainer: const Color(0xFF1B3550),
    onPrimaryContainer: const Color(0xFFD3E6FA),
    secondary: const Color(0xFFD4AE5A),
    onSecondary: const Color(0xFF1A1407),
    tertiaryContainer: const Color(0xFF3A3020),
    onTertiaryContainer: const Color(0xFFF2E3BC),
    errorContainer: const Color(0xFF4A2327),
    onErrorContainer: const Color(0xFFFFD9DB),
  );
  final themed = darkBase.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
    dividerColor: scheme.outlineVariant,
  );
  final dense = fmDenseTheme(themed);
  return dense.copyWith(
    // 文字の色も暗い下地に合わせる(明るい版の黒い文字のままだと読めない)。
    textTheme: dense.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    primaryTextTheme: dense.primaryTextTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    iconTheme: dense.iconTheme.copyWith(color: scheme.onSurface),
    scaffoldBackgroundColor: surface,
    navigationBarTheme: themed.navigationBarTheme.copyWith(
      backgroundColor: scheme.surfaceContainer,
    ),
    inputDecorationTheme: themed.inputDecorationTheme.copyWith(
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    ),
  );
}

/// 横画面のときだけ、中の画面すべてに FM 風の暗い密なテーマを当てる。
/// ホームの外(その他メニューから開く画面)も同じ見た目にそろう。
/// 横画面は設定の明暗にかかわらず暗い見た目で固定する(縦画面は設定どおり)。
class FmThemeScope extends StatelessWidget {
  const FmThemeScope({super.key, required this.child, this.dark});

  final Widget child;

  /// アプリの暗いテーマ。渡されなければ、いまのテーマの暗い版を作る。
  final ThemeData? dark;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= size.height) return child;
    // 文字の大きさは、いまのテーマ(MaterialApp が整えたもの)を土台にし、
    // 配色だけを暗い版に差し替える。
    final current = Theme.of(context);
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
