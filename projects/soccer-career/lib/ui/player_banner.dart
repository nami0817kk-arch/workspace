import 'package:flutter/material.dart';

import '../models/career.dart';
import 'club_identity.dart';
import 'player_portrait.dart';

/// 選手証。選手タブの一番上に置く。
///
/// これまで選手タブは**白いカードに文字が並ぶだけ**で、このゲームで唯一
/// 手で描いているもの（`PlayerPortrait`）は 64px の丸で隅に居た。
/// クラブの色を背に敷いて、名前・番号・総合力を大きく出す。
///
/// **判定には一切効かない。** 映しているのは `CareerState` の値だけ。
class PlayerBanner extends StatelessWidget {
  const PlayerBanner({super.key, required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = state.player;
    final identity = ClubIdentity.of(state.club);
    // 背は必ずクラブの色。移籍すれば選手証ごと変わる。
    final onKit = _readableOn(identity.primary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _KitPainter(
          primary: identity.primary,
          secondary: identity.secondary,
          striped: identity.striped,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PlayerPortrait(
                look: player.look,
                club: state.club,
                squadNumber: state.squadNumber,
                size: 84,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (state.squadNumber > 0)
                          Text(
                            '${state.squadNumber}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: onKit.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (state.squadNumber > 0) const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            player.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: onKit,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.captain)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _Pill(label: 'C', on: onKit),
                          ),
                      ],
                    ),
                    if (state.nickname != null)
                      Text(
                        '「${state.nickname}」',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onKit.withValues(alpha: 0.8)),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ClubCrest(club: state.club, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${player.positionLabel} ・ ${state.club.name}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: onKit.withValues(alpha: 0.9)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 総合力。一番よく見る数字なので、一番大きく置く。
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${player.overall}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: onKit,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '総合力',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: onKit.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// その色の上に置いて読める文字色。
  ///
  /// クラブの色は12色あって明るいものも暗いものもある。
  /// 白で固定すると、明るいクラブで文字が飛ぶ。
  static Color _readableOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : const Color(0xFF14140F);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on});

  final String label;
  final Color on;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: on.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: on)),
      );
}

/// 背景。クラブの色で、縦縞のクラブは縞にする。
class _KitPainter extends CustomPainter {
  _KitPainter({
    required this.primary,
    required this.secondary,
    required this.striped,
  });

  final Color primary;
  final Color secondary;
  final bool striped;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 平らな一色だと板に見えるので、わずかに落として奥行きを出す。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(primary, Colors.white, 0.10)!,
            Color.lerp(primary, Colors.black, 0.16)!,
          ],
        ).createShader(rect),
    );
    if (striped) {
      final stripe = Paint()..color = secondary.withValues(alpha: 0.16);
      const width = 14.0;
      for (var x = -size.height; x < size.width; x += width * 2) {
        canvas.drawPath(
          Path()
            ..moveTo(x, size.height)
            ..lineTo(x + size.height, 0)
            ..lineTo(x + size.height + width, 0)
            ..lineTo(x + width, size.height)
            ..close(),
          stripe,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KitPainter old) =>
      old.primary != primary || old.striped != striped;
}
