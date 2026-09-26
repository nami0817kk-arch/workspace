import 'package:flutter/material.dart';

import '../game/formulas.dart';

/// 数字1つを、読まずに分かる重さで置く。
///
/// 画面を全部書き出して見たら、**成績も通算も試合のヘッダーも、
/// 数字がただ並んでいるだけ**で、どれが大事な数字なのか目が止まらなかった。
/// 数字は大きく、名前は小さく、意味があるものには色を付ける。
/// 一度作って全部の画面で同じ部品を使う——画面ごとに書くと大きさがずれる。
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.accent,
    this.small = false,
  });

  final String label;
  final String value;

  /// 数字の色。null なら地の色。
  final Color? accent;

  /// 試合のヘッダーのように、幅が無い場所向け。
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style:
              (small
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.1,
                  ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 評価点の色。基準は判定と同じ線から出す。
///
/// ベンチ外の線（`squadThreshold`）を割ったら赤、途中出場の線
/// （`benchThreshold`）を割ったら注意、7.0 以上なら良い色。
/// **ここに別の線を書かない**——出場機会の判定とずれると、
/// 赤く出ているのに先発する／黒いのにベンチ外、が起きる。
Color? ratingColor(ThemeData theme, double? rating) {
  if (rating == null) return null;
  if (rating < Formulas.squadThreshold) return theme.colorScheme.error;
  if (rating < Formulas.benchThreshold) return theme.colorScheme.tertiary;
  if (rating >= 7.0) return theme.colorScheme.primary;
  return null;
}

/// 目標に対する進み。「8 / 30」と書くより、棒の長さのほうが早い。
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.now,
    required this.target,
    required this.text,
    this.labelWidth = 68,
  });

  final String label;
  final double now;
  final double target;

  /// 棒の右に出す文字（「8 / 30」など）。数字の書き方は呼ぶ側が決める。
  final String text;

  /// 見出しの幅。長い見出し（「同じ場面での勝負」）を切らないため。
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = now >= target;
    final ratio = target <= 0 ? 1.0 : (now / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: GaugeBar(
              value: ratio,
              height: 8,
              color: met
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              text,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: met ? FontWeight.w700 : null,
                color: met ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 溝に沈めた棒。**平らな塗りの帯は紙に引いた線に見える。**
///
/// 溝（背）は内側に影、中身は上が明るく下が落ちる。光の向きは
/// ピッチの駒・似顔・帯と同じ（上から）——1つの絵の中で太陽は1つ。
class GaugeBar extends StatelessWidget {
  const GaugeBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(height);
    // 溝の下地。明るいテーマでは沈み、暗いテーマでは浮く色を選ぶ
    // ——どちらでも「掘ってある」と読めることが要る。
    final track = theme.brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHigh;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            // 溝。内側の上に影を落として窪ませる。
            // **`color` と `gradient` を併記すると色は捨てられる**ので、
            // 下地を混ぜて作る（併記していた頃、ダークで溝が消えていた）。
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(const Color(0x2E000000), track),
                    track,
                    Color.alphaBlend(const Color(0x1FFFFFFF), track),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // 中身。上が明るく、下が落ちる。
            SizedBox(
              width: box.maxWidth * value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.alphaBlend(const Color(0x59FFFFFF), color),
                      color,
                      Color.alphaBlend(const Color(0x40000000), color),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
