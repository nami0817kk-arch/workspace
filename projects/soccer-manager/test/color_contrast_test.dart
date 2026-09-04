import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/main.dart';

/// 配色そのもののコントラストを、テーマの実色から計算して確かめる。
///
/// 画面を描画して調べる textContrastGuideline は使わない。あれはノードの
/// 矩形からピクセルの色を推定するため、実フォントを読み込むと文字の縁の
/// アンチエイリアスを拾い、パレットに存在しない色を「文字色」として報告する。
/// 実測では24種類65件の不合格が出たが、いずれもテーマには無い色で、
/// ここで計算し直すと最低でも 7.28 あった。
///
/// ピクセルを見ない代わりに、対になる色(on〇〇 と その背景)を直接突き合わせる。
/// 誤検出も見落としもなく、明暗どちらの配色も一度に確かめられる。
///
/// 基準は WCAG AA の 4.5:1(通常の文字)。アプリの文字は小さいものが多く、
/// 大きい文字向けの緩い基準(3:1)には寄りかからない。
const double _requiredRatio = 4.5;

double _linear(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) {
  final v = ((c.r * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.b * 255).round();
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

void main() {
  for (final brightness in Brightness.values) {
    final label = brightness == Brightness.dark ? 'ダーク' : 'ライト';

    test('$label配色の文字色が背景に対して $_requiredRatio:1 を満たす', () {
      final s = const SoccerManagerApp()
          .buildTheme(brightness, boldText: false)
          .colorScheme;

      // 「この文字色は、この背景の上に置かれる」という対応。Material 3 の
      // 取り決めそのままで、画面側もこの組み合わせで使っている。
      final pairs = <(String, Color, String, Color)>[
        ('onSurface', s.onSurface, 'surface', s.surface),
        ('onSurface', s.onSurface, 'surfaceContainer', s.surfaceContainer),
        ('onSurface', s.onSurface, 'surfaceContainerHigh',
            s.surfaceContainerHigh),
        ('onSurface', s.onSurface, 'surfaceContainerHighest',
            s.surfaceContainerHighest),
        ('onSurfaceVariant', s.onSurfaceVariant, 'surface', s.surface),
        ('onSurfaceVariant', s.onSurfaceVariant, 'surfaceContainer',
            s.surfaceContainer),
        ('onSurfaceVariant', s.onSurfaceVariant, 'surfaceContainerHigh',
            s.surfaceContainerHigh),
        ('onSurfaceVariant', s.onSurfaceVariant, 'surfaceContainerHighest',
            s.surfaceContainerHighest),
        ('onPrimary', s.onPrimary, 'primary', s.primary),
        ('onSecondary', s.onSecondary, 'secondary', s.secondary),
        ('onTertiary', s.onTertiary, 'tertiary', s.tertiary),
        ('onError', s.onError, 'error', s.error),
        ('onPrimaryContainer', s.onPrimaryContainer, 'primaryContainer',
            s.primaryContainer),
        ('onSecondaryContainer', s.onSecondaryContainer, 'secondaryContainer',
            s.secondaryContainer),
        ('onTertiaryContainer', s.onTertiaryContainer, 'tertiaryContainer',
            s.tertiaryContainer),
        ('onErrorContainer', s.onErrorContainer, 'errorContainer',
            s.errorContainer),
        ('onInverseSurface', s.onInverseSurface, 'inverseSurface',
            s.inverseSurface),
      ];

      final failures = <String>[];
      for (final (fgName, fg, bgName, bg) in pairs) {
        final ratio = contrastRatio(fg, bg);
        if (ratio < _requiredRatio) {
          failures.add('$fgName ${_hex(fg)} on $bgName ${_hex(bg)} '
              '= ${ratio.toStringAsFixed(2)}');
        }
      }

      expect(failures, isEmpty,
          reason: '$label配色でコントラストが足りない組み合わせがある:\n'
              '${failures.join('\n')}');
    });
  }

  test('計算式そのものが正しい', () {
    // 白と黒は 21:1、同じ色同士は 1:1。ここが狂うと上の判定が意味を失う。
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21.0, 0.01));
    expect(contrastRatio(const Color(0xFF336699), const Color(0xFF336699)),
        closeTo(1.0, 0.01));
  });
}
