import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/achievement.dart';

/// 実績の記章。
///
/// 以前は33件すべてが同じトロフィーのアイコンで、琥珀色の丸に入っていた。
/// 一覧を開くと同じ絵が33個並び、どれを取ったのかも、何の種類なのかも
/// 見分けが付かなかった。種別で色と形と印を変え、未達成は灰色にする。
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final double size;

  const AchievementBadge({
    super.key,
    required this.achievement,
    required this.unlocked,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final art = _BadgeArt.of(achievement.category);
    return Semantics(
      label: unlocked
          ? Tr.pick('${achievement.name}(達成済み)', '${achievement.name} (unlocked)')
          : Tr.pick('${achievement.name}(未達成)', '${achievement.name} (locked)'),
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _BadgePainter(
            art: art,
            unlocked: unlocked,
            seed: achievement.id.hashCode,
          ),
          child: Center(
            // 未達成でも印は出す。鍵に差し替えていた頃は、未達成の
            // ぶんが全部同じ灰色の鍵になって、一覧が読めなかった。
            // 達成したかどうかは色(金銀五色/灰)とギザギザの有無で分かる。
            child: Icon(
              _iconFor(achievement),
              size: size * 0.42,
              color: unlocked
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

/// 実績ごとの印。
///
/// **種別の印だけだと、同じ種別の中で見分けが付かない。** 色を5種類に
/// 分けても、タイトル6件が同じトロフィー、育成9件が同じ人型で並ぶ。
/// 1件ずつ中身に合う印を当てる。知らないIDは種別の印に落とす。
IconData _iconFor(Achievement a) =>
    _iconsById[a.id] ?? _BadgeArt.of(a.category).icon;

const _iconsById = <String, IconData>{
  // タイトル
  'first_title': Icons.emoji_events,
  'back_to_back': Icons.repeat,
  'unbeaten_champion': Icons.shield,
  'cup_winner': Icons.workspace_premium,
  'double': Icons.looks_two,
  'five_titles': Icons.auto_awesome,
  // 通算記録
  'wins_50': Icons.trending_up,
  'wins_100': Icons.show_chart,
  'wins_200': Icons.stacked_line_chart,
  'seasons_5': Icons.event_repeat,
  'seasons_10': Icons.calendar_month,
  'win_rate_60': Icons.percent,
  // クラブ経営
  'promoted': Icons.arrow_upward,
  'bounce_back': Icons.replay,
  'rich_club': Icons.savings,
  'facilities_maxed': Icons.apartment,
  'staff_maxed': Icons.badge,
  'trusted_manager': Icons.handshake,
  'bargain_hunter': Icons.sell,
  'cup_prize_1000': Icons.paid,
  // 選手・育成
  'academy_graduate': Icons.school,
  'academy_backbone': Icons.diversity_3,
  'superstar_player': Icons.star,
  'deep_squad': Icons.people_alt,
  'best_eleven_selection': Icons.verified,
  'hall_of_fame': Icons.museum,
  'legend_collector': Icons.auto_stories,
  'breakthrough_10': Icons.rocket_launch,
  'trait_teacher': Icons.psychology,
  // 監督キャリア
  'veteran_manager': Icons.military_tech,
  'reputation_elite': Icons.public,
  'live_wins_10': Icons.sports,
  'shootout_winner': Icons.sports_soccer,
};

/// 種別ごとの色と印。
class _BadgeArt {
  final Color top;
  final Color bottom;
  final IconData icon;

  const _BadgeArt(this.top, this.bottom, this.icon);

  static _BadgeArt of(AchievementCategory category) => switch (category) {
        // タイトルは金。他と並んだときにいちばん目立つ色を当てる。
        AchievementCategory.title =>
          _BadgeArt(Color(0xFFF2B733), Color(0xFFC77E12), Icons.emoji_events),
        AchievementCategory.record =>
          _BadgeArt(Color(0xFF4E8BD6), Color(0xFF28568F), Icons.timeline),
        AchievementCategory.management =>
          _BadgeArt(Color(0xFF3FA66B), Color(0xFF1E6940), Icons.account_balance),
        AchievementCategory.squad =>
          _BadgeArt(Color(0xFF8A6BD1), Color(0xFF523C8C), Icons.groups),
        AchievementCategory.career =>
          _BadgeArt(Color(0xFFD9694B), Color(0xFF8E3A26), Icons.military_tech),
      };
}

class _BadgePainter extends CustomPainter {
  final _BadgeArt art;
  final bool unlocked;
  final int seed;

  const _BadgePainter({
    required this.art,
    required this.unlocked,
    required this.seed,
  });

  /// 未達成は色を抜く。形だけ残るので、何を目指しているかは分かる。
  static const _lockedTop = Color(0xFFB4B7BD);
  static const _lockedBottom = Color(0xFF80858E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final top = unlocked ? art.top : _lockedTop;
    final bottom = unlocked ? art.bottom : _lockedBottom;

    // 周りのギザギザ。勲章の縁。達成したものだけ付ける。
    if (unlocked) {
      final points = Path();
      const teeth = 16;
      for (var i = 0; i < teeth * 2; i++) {
        final angle = -pi / 2 + i * pi / teeth;
        final r = (i.isEven ? 0.50 : 0.43) * min(w, h);
        final p = Offset(w / 2 + cos(angle) * r, h / 2 + sin(angle) * r);
        i == 0 ? points.moveTo(p.dx, p.dy) : points.lineTo(p.dx, p.dy);
      }
      points.close();
      canvas.drawPath(points, Paint()..color = _shade(bottom, 0.82));
    }

    final disc = Rect.fromCenter(
        center: rect.center, width: w * 0.86, height: h * 0.86);
    canvas.drawOval(
      disc,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(disc),
    );

    // 実績ごとの柄。同じ種別でも並べたときに見分けが付く。
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    final pattern = Paint()..color = Colors.white.withValues(alpha: 0.13);
    switch (seed.abs() % 3) {
      case 0: // 放射
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.translate(rect.center.dx, rect.center.dy);
          canvas.rotate(i * pi / 4 + 0.2);
          canvas.drawRect(
            Rect.fromLTWH(0, -h * 0.03, w * 0.5, h * 0.06),
            pattern,
          );
          canvas.restore();
        }
      case 1: // 斜めの帯
        canvas.save();
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.rotate(-pi / 5);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 0.22),
          pattern,
        );
        canvas.restore();
      default: // 下半分
        canvas.drawRect(
            Rect.fromLTWH(0, rect.center.dy, w, h / 2), pattern);
    }
    // 上に光、下に影。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x3DFFFFFF), Color(0x00FFFFFF), Color(0x2E000000)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
    canvas.restore();

    // 縁は二重。エンブレムと同じ作りにして、見た目の流儀を揃える。
    canvas.drawOval(
      disc,
      Paint()
        ..color = _shade(bottom, 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07,
    );
    canvas.drawOval(
      disc,
      Paint()
        ..color = Colors.white.withValues(alpha: unlocked ? 0.8 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022,
    );
  }

  static Color _shade(Color c, double factor) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(covariant _BadgePainter oldDelegate) =>
      oldDelegate.unlocked != unlocked ||
      oldDelegate.seed != seed ||
      oldDelegate.art.icon != art.icon;
}
