import 'package:flutter/material.dart';

import '../../game/career.dart';
import '../../game/exp.dart';
import '../../game/player.dart';

/// 段階ごとのユニフォーム。実在のチームの配色・意匠は使わない。
class UniformStyle {
  const UniformStyle(this.shirt, this.pants, this.cap, this.trim);
  final Color shirt;
  final Color pants;
  final Color cap;
  final Color trim;
}

UniformStyle uniformOf(Stage s) => switch (s) {
      Stage.youth => const UniformStyle(Color(0xFFFFD54F), Color(0xFF455A64),
          Color(0xFF1E88E5), Color(0xFFFFFFFF)),
      Stage.juniorHigh => const UniformStyle(Color(0xFFF5F5F5),
          Color(0xFF2E7D32), Color(0xFF2E7D32), Color(0xFF1B5E20)),
      Stage.highSchool => const UniformStyle(Color(0xFFFAFAFA),
          Color(0xFFE0E0E0), Color(0xFF1A237E), Color(0xFF1A237E)),
      Stage.pathChoice => const UniformStyle(Color(0xFFECEFF1),
          Color(0xFF37474F), Color(0xFF8E1B2D), Color(0xFF8E1B2D)),
      Stage.pro => const UniformStyle(Color(0xFFFFFFFF), Color(0xFFF0F0F0),
          Color(0xFF0D47A1), Color(0xFFC62828)),
      Stage.retired => const UniformStyle(Color(0xFFCFD8DC), Color(0xFF78909C),
          Color(0xFF546E7A), Color(0xFFFFFFFF)),
    };

/// 表情。やる気から決まる。
enum Mood { sad, flat, happy }

Mood moodOf(Motivation m) => switch (m) {
      Motivation.terrible || Motivation.bad => Mood.sad,
      Motivation.normal => Mood.flat,
      Motivation.good || Motivation.great => Mood.happy,
    };

/// 選手の絵。段階で背格好とユニフォームが変わり、役割で持ち物が変わる。
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.stage,
    required this.role,
    this.mood = Mood.flat,
    this.height = 120,
  });

  final Stage stage;
  final Role role;
  final Mood mood;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '選手',
      child: SizedBox(
        width: height * 100 / 140,
        height: height,
        child: CustomPaint(
            painter: AvatarPainter(stage: stage, role: role, mood: mood)),
      ),
    );
  }
}

class AvatarPainter extends CustomPainter {
  AvatarPainter({required this.stage, required this.role, required this.mood});
  final Stage stage;
  final Role role;
  final Mood mood;

  static const _skin = Color(0xFFF2C9A0);
  static const _hair = Color(0xFF2B2118);
  static const _wood = Color(0xFF9A6B3A);

  /// 背丈: 小さい子ほど小さく描く。
  double get _scale => switch (stage) {
        Stage.youth => 0.70,
        Stage.juniorHigh => 0.86,
        _ => 1.0,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final u = uniformOf(stage);
    final k = size.height / 140;
    canvas.save();
    canvas.scale(k);
    // 足元(下端中央)を基準に縮める。
    canvas.translate(50, 140);
    canvas.scale(_scale);
    canvas.translate(-50, -140);

    final fill = Paint()..style = PaintingStyle.fill;
    // 影
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 136), width: 56, height: 8),
        fill..color = const Color(0x33000000));

    // 脚
    fill.color = u.pants;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(36, 78, 12, 44), const Radius.circular(4)),
        fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(52, 78, 12, 44), const Radius.circular(4)),
        fill);
    // ストッキングの線
    fill.color = u.trim;
    canvas.drawRect(const Rect.fromLTWH(36, 104, 12, 5), fill);
    canvas.drawRect(const Rect.fromLTWH(52, 104, 12, 5), fill);
    // 靴
    fill.color = const Color(0xFF263238);
    canvas.drawOval(const Rect.fromLTWH(32, 118, 20, 9), fill);
    canvas.drawOval(const Rect.fromLTWH(50, 118, 20, 9), fill);

    // 腕(後ろ側=左)
    _arm(canvas, const Offset(33, 54), const Offset(22, 76), u);
    // 胴
    fill.color = u.shirt;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(29, 46, 42, 42), const Radius.circular(10)),
        fill);
    fill.color = u.trim;
    canvas.drawRect(const Rect.fromLTWH(29, 80, 42, 4), fill); // ベルト
    canvas.drawRect(const Rect.fromLTWH(48, 46, 4, 34),
        fill..color = u.trim.withValues(alpha: 0.5)); // ボタンの筋

    // 持ち物
    final batter = role != Role.pitcher;
    final pitcher = role != Role.batter;
    if (pitcher) {
      fill.color = const Color(0xFF6D4C2F);
      canvas.drawOval(const Rect.fromLTWH(10, 70, 20, 18), fill); // グラブ
      fill.color = const Color(0xFF8D6E4A);
      canvas.drawOval(const Rect.fromLTWH(13, 73, 14, 12), fill);
    }
    // 腕(手前=右)
    _arm(canvas, const Offset(67, 54), const Offset(80, 70), u);
    if (batter) {
      final bat = Paint()
        ..color = _wood
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(80, 70), const Offset(94, 22), bat);
      canvas.drawLine(
          const Offset(80, 70), const Offset(82, 78), bat..strokeWidth = 3.5);
    }
    if (pitcher && !batter) {
      fill.color = Colors.white;
      canvas.drawCircle(const Offset(83, 68), 5, fill);
      final seam = Paint()
        ..color = const Color(0xFFC62828)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      canvas.drawArc(Rect.fromCircle(center: const Offset(81, 68), radius: 4),
          -1.2, 2.4, false, seam);
    }

    // 頭: 髪(後ろ)→ 顔 → 耳 の順に重ねる。
    fill.color = _hair;
    canvas.drawCircle(const Offset(50, 28), 18.5, fill);
    fill.color = _skin;
    canvas.drawOval(const Rect.fromLTWH(34.5, 17, 31, 33), fill);
    canvas.drawCircle(const Offset(34, 35), 3.4, fill);
    canvas.drawCircle(const Offset(66, 35), 3.4, fill);
    // 帽子
    fill.color = u.cap;
    final dome = Path()
      ..moveTo(32, 30)
      ..arcToPoint(const Offset(68, 30),
          radius: const Radius.circular(18), clockwise: true)
      ..close();
    canvas.drawPath(dome, fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(50, 26, 24, 5), const Radius.circular(3)),
        fill);
    fill.color = u.trim;
    canvas.drawCircle(const Offset(50, 21), 3.2, fill);

    // 顔
    fill.color = const Color(0xFF2B2118);
    canvas.drawCircle(const Offset(44, 36), 1.8, fill);
    canvas.drawCircle(const Offset(57, 36), 1.8, fill);
    final mouth = Paint()
      ..color = const Color(0xFF7A3E2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case Mood.happy:
        canvas.drawArc(
            Rect.fromCenter(
                center: const Offset(50.5, 40.5), width: 11, height: 7),
            0.1,
            2.9,
            false,
            mouth);
      case Mood.flat:
        canvas.drawLine(const Offset(46, 42.5), const Offset(55, 42.5), mouth);
      case Mood.sad:
        canvas.drawArc(
            Rect.fromCenter(
                center: const Offset(50.5, 44), width: 10, height: 6),
            3.4,
            2.6,
            false,
            mouth);
        // 汗
        fill.color = const Color(0xFF81D4FA);
        canvas.drawOval(const Rect.fromLTWH(63, 24, 3.4, 5.4), fill);
    }
    canvas.restore();
  }

  void _arm(Canvas canvas, Offset shoulder, Offset hand, UniformStyle u) {
    final sleeve = Paint()
      ..color = u.shirt
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final mid = Offset.lerp(shoulder, hand, 0.55)!;
    canvas.drawLine(shoulder, mid, sleeve);
    final skin = Paint()
      ..color = _skin
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(mid, hand, skin);
  }

  @override
  bool shouldRepaint(AvatarPainter old) =>
      old.stage != stage || old.role != role || old.mood != mood;
}
