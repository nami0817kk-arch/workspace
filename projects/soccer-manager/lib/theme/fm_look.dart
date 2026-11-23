import 'package:flutter/material.dart';

/// 横画面(FM 風)の配色と部品の決まりを、この1か所に置く。
///
/// 以前は暗い配色だけが `fm_panel.dart` に直書きされていて、設定で
/// 「ライトモード」を選んでも横画面は暗いままだった(2026-11-24 指摘
/// 「画面が暗い。ユーザビリティ性のない画面」)。明るい版と暗い版を同じ形の
/// [FmPalette] で持ち、[fmLookTheme] が部品(ボタン・タブ・箱)まで組む。
///
/// 決まり:
/// - 地(surface)と箱(surfaceContainerLow)は、見て分かる段差を付ける。
///   以前の暗い版は 0F151D と 151C26 で、箱が地に溶けていた。
/// - 文字は onSurface(本文)と onSurfaceVariant(補足)の2段。どちらも
///   箱の地に対して WCAG AA(4.5:1)以上。
/// - 押せるものは押せる見た目にする。主な操作は塗り(FilledButton)、
///   次の操作は枠つき(OutlinedButton、枠は主役の色)、文字だけの
///   ボタンは「見送る」のような控えめな操作だけ。
@immutable
class FmPalette {
  const FmPalette({
    required this.brightness,
    required this.surface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.topBar,
    required this.sidebar,
    required this.panelShadow,
  });

  final Brightness brightness;
  final Color surface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color outline;
  final Color outlineVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  /// 上の帯(クラブ名・資金・進むボタン)の地。
  final Color topBar;

  /// 左のメニューの地。
  final Color sidebar;

  /// 箱の影。明るい版だけ、白い箱を薄い灰の地から浮かせるのに使う。
  final Color? panelShadow;

  bool get isLight => brightness == Brightness.light;

  /// 案B: 暗いまま見やすく。地を少し明るい紺にし、箱を1段はっきり明るく、
  /// 補足の字も濃くする。
  static const dark = FmPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF131C27),
    surfaceContainerLowest: Color(0xFF0F1720),
    surfaceContainerLow: Color(0xFF1D2836),
    surfaceContainer: Color(0xFF212D3C),
    surfaceContainerHigh: Color(0xFF263345),
    surfaceContainerHighest: Color(0xFF2D3C50),
    outline: Color(0xFF7D8FA5),
    outlineVariant: Color(0xFF3B4B60),
    onSurface: Color(0xFFF2F5F8),
    onSurfaceVariant: Color(0xFFBDC9D7),
    primary: Color(0xFF5AADFF),
    onPrimary: Color(0xFF04121F),
    primaryContainer: Color(0xFF1F4268),
    onPrimaryContainer: Color(0xFFDCEBFF),
    secondary: Color(0xFFE0BC6A),
    onSecondary: Color(0xFF1A1407),
    secondaryContainer: Color(0xFF34414F),
    onSecondaryContainer: Color(0xFFEFF3F7),
    tertiaryContainer: Color(0xFF453822),
    onTertiaryContainer: Color(0xFFF6E7C1),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF2A0606),
    errorContainer: Color(0xFF55262B),
    onErrorContainer: Color(0xFFFFE3E3),
    topBar: Color(0xFF243142),
    sidebar: Color(0xFF18222F),
    panelShadow: null,
  );

  /// 案A: 明るい配色。薄い灰の地に白い箱、濃い文字、主役は青。
  static const light = FmPalette(
    brightness: Brightness.light,
    surface: Color(0xFFECF0F4),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF4F6F9),
    surfaceContainerHigh: Color(0xFFEDF1F5),
    surfaceContainerHighest: Color(0xFFE2E8EF),
    outline: Color(0xFF8391A2),
    outlineVariant: Color(0xFFD3DBE4),
    onSurface: Color(0xFF111A24),
    onSurfaceVariant: Color(0xFF4A5766),
    primary: Color(0xFF1D62C9),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCE8FB),
    onPrimaryContainer: Color(0xFF0D2F61),
    secondary: Color(0xFF8E6A17),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE6ECF3),
    onSecondaryContainer: Color(0xFF16212E),
    tertiaryContainer: Color(0xFFFFF0D2),
    onTertiaryContainer: Color(0xFF4F3A00),
    error: Color(0xFFC62828),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDE7E7),
    onErrorContainer: Color(0xFF6E1414),
    topBar: Color(0xFFFFFFFF),
    sidebar: Color(0xFFFFFFFF),
    panelShadow: Color(0x14000000),
  );

  ColorScheme applyTo(ColorScheme base) => base.copyWith(
        brightness: brightness,
        surface: surface,
        surfaceContainerLowest: surfaceContainerLowest,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: outline,
        outlineVariant: outlineVariant,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surfaceTint: Colors.transparent,
      );
}

/// 画面ごとの部品が引く、配色の追加の札(上の帯・左のメニュー・箱の影)。
/// ColorScheme に無い場所の色は、直書きせずにここから引く。
@immutable
class FmLook extends ThemeExtension<FmLook> {
  const FmLook({
    required this.topBar,
    required this.sidebar,
    required this.panelShadow,
  });

  final Color topBar;
  final Color sidebar;
  final Color? panelShadow;

  static FmLook? of(BuildContext context) =>
      Theme.of(context).extension<FmLook>();

  /// 箱の影(無ければ空)。
  static List<BoxShadow> shadowOf(BuildContext context) {
    final c = of(context)?.panelShadow;
    if (c == null) return const [];
    return [BoxShadow(color: c, blurRadius: 4, offset: const Offset(0, 1))];
  }

  @override
  FmLook copyWith({Color? topBar, Color? sidebar, Color? panelShadow}) =>
      FmLook(
        topBar: topBar ?? this.topBar,
        sidebar: sidebar ?? this.sidebar,
        panelShadow: panelShadow ?? this.panelShadow,
      );

  @override
  FmLook lerp(covariant FmLook? other, double t) {
    if (other == null) return this;
    return FmLook(
      topBar: Color.lerp(topBar, other.topBar, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t),
    );
  }
}

/// 横画面の密なテーマを、[palette] の配色で組む。
///
/// [base] は MaterialApp が整えたテーマ(文字の大きさ・太字の設定を含む)。
ThemeData fmLookTheme(ThemeData base, FmPalette palette) {
  final scheme = palette.applyTo(base.colorScheme);
  final body = base.textTheme.bodyMedium?.fontFamily;

  // 文字は一回り小さくして1画面の情報量を保つ。見出しは小さい太字
  // (FM の見出しは小さく、太い)。本文との差が付くよう、見出しは以前より
  // 半段大きい。
  var text = base.textTheme.apply(fontSizeFactor: 0.93);
  TextStyle? head(TextStyle? s, double size) => s?.copyWith(
      fontFamily: body, fontSize: size, fontWeight: FontWeight.bold);
  text = text.copyWith(
    headlineMedium: head(text.headlineMedium, 19),
    headlineSmall: head(text.headlineSmall, 17),
    titleLarge: head(text.titleLarge, 15.5),
    titleMedium: head(text.titleMedium, 14),
    titleSmall: head(text.titleSmall, 13),
  );
  text =
      text.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  const radius = 6.0;
  final shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  final buttonText =
      TextStyle(fontSize: 12.5, fontFamily: body, fontWeight: FontWeight.bold);

  return base.copyWith(
    brightness: palette.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    textTheme: text,
    primaryTextTheme: base.primaryTextTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    iconTheme: base.iconTheme.copyWith(color: scheme.onSurface),
    // 押せない項目の字。既定(38%)では暗い地に沈んで読めなかった。
    disabledColor: scheme.onSurface.withValues(alpha: 0.55),
    extensions: [
      ...base.extensions.values.where((e) => e is! FmLook),
      FmLook(
        topBar: palette.topBar,
        sidebar: palette.sidebar,
        panelShadow: palette.panelShadow,
      ),
    ],
    // 押せる範囲は見た目より広く取る(指で押す目安は44pt)。
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: palette.topBar,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 40,
      titleTextStyle: TextStyle(
        fontFamily: body,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      labelStyle: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: body),
      unselectedLabelStyle: TextStyle(fontSize: 12.5, fontFamily: body),
    ),
    cardTheme: CardThemeData(
      elevation: palette.isLight ? 1 : 0,
      shadowColor: palette.panelShadow,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 8),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),
    dividerTheme:
        DividerThemeData(space: 1, thickness: 1, color: scheme.outlineVariant),
    // 主な操作: 塗り。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        minimumSize: const Size(0, 40),
        textStyle: buttonText,
        shape: shape,
      ),
    ),
    // 次の操作: 主役の色の枠と、ごく薄い下地。灰色の細い枠だけだと、
    // 押せる所に見えなかった。
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6, horizontal: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        textStyle: WidgetStatePropertyAll(buttonText),
        shape: WidgetStatePropertyAll(shape),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.5)
                : scheme.primary),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled)
                ? Colors.transparent
                : scheme.primary.withValues(alpha: 0.08)),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
            color: s.contains(WidgetState.disabled)
                ? scheme.outlineVariant
                : scheme.primary.withValues(alpha: 0.75),
            width: 1.4)),
      ),
    ),
    // 控えめな操作だけ(見送る・閉じる)。
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: scheme.primary,
        textStyle: buttonText,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      labelStyle:
          TextStyle(fontSize: 12, fontFamily: body, color: scheme.onSurface),
      side: BorderSide(color: scheme.outlineVariant),
      shape: shape,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: scheme.surfaceContainer,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      inactiveTrackColor: scheme.outlineVariant,
    ),
  );
}
