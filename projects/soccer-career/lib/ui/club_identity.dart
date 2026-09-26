import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/club.dart';

/// クラブの見た目。色とエンブレムの形。
///
/// データとしては持たず、クラブのIDから決める。保存しないのに毎回同じに
/// なるので、「あの青いクラブ」という記憶が成立する。名前だけが並ぶ画面は、
/// どこに居るのか分からなくなる。
///
/// 実在のクラブを想起させないよう、形は幾何学的なものだけにしてある。
class ClubIdentity {
  const ClubIdentity({
    required this.primary,
    required this.secondary,
    required this.shape,
    required this.striped,
  });

  final Color primary;
  final Color secondary;
  final CrestShape shape;

  /// 縦縞を入れるか。
  final bool striped;

  /// 落ち着いた色だけを並べてある。彩度を上げすぎると、
  /// 20クラブ並んだ順位表が読めなくなる。
  static const List<Color> palette = [
    Color(0xFF1B4D3E), // 深緑
    Color(0xFF14345C), // 濃紺
    Color(0xFF7A1F2B), // えんじ
    Color(0xFF2E2A4F), // すみれ
    Color(0xFF3F5A2A), // 若草
    Color(0xFF5C3A1E), // 焦茶
    Color(0xFF0E4B54), // 青緑
    Color(0xFF6B2E5F), // 葡萄
    Color(0xFF8A5A15), // 山吹
    Color(0xFF2F4858), // 鉄紺
    Color(0xFF7B2D26), // 煉瓦
    Color(0xFF394F1F), // 苔
  ];

  static const List<Color> accents = [
    Color(0xFFF2F0E6), // 生成り
    Color(0xFFE8C547), // 金
    Color(0xFFD9D9D9), // 銀
    Color(0xFF9BC1BC), // 浅葱
    Color(0xFFE07A5F), // 朱
  ];

  /// クラブのIDから決める。ハッシュではなく符号の和で出すのは、
  /// 実行のたびに変わらないようにするため（ClubStyle と同じ理由）。
  factory ClubIdentity.of(Club club) {
    final seed =
        club.id.codeUnits.fold<int>(0, (a, b) => a + b * 7) +
        club.name.codeUnits.fold<int>(0, (a, b) => a + b);
    return ClubIdentity(
      primary: palette[seed % palette.length],
      secondary: accents[(seed ~/ 3) % accents.length],
      shape: CrestShape.values[(seed ~/ 5) % CrestShape.values.length],
      striped: (seed ~/ 7).isEven,
    );
  }

  /// エンブレムに入れる文字。クラブ名の頭1文字。
  static String initialOf(Club club) =>
      club.name.isEmpty ? '?' : club.name.characters.first;
}

/// エンブレムの形。
enum CrestShape { shield, circle, diamond, banner }

/// クラブのエンブレム。
class ClubCrest extends StatelessWidget {
  const ClubCrest({super.key, required this.club, this.size = 28});

  final Club club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final identity = ClubIdentity.of(club);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrestPainter(identity),
        child: Center(
          child: Text(
            ClubIdentity.initialOf(club),
            style: TextStyle(
              color: identity.secondary,
              fontSize: size * 0.42,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  const _CrestPainter(this.identity);

  final ClubIdentity identity;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(size);
    // **落ち影。** エンブレムが台紙に貼った紙に見えていたので、
    // わずかに浮かせる。光は上から（ピッチの駒と同じ向き）。
    canvas.drawPath(
      path.shift(Offset(0, size.height * 0.045)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.045),
    );
    // 面は、上が明るく下が落ちる。平らな一色だと板に見える。
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.3, 0),
          Offset(size.width * 0.7, size.height),
          [_shade(identity.primary, 1.35), _shade(identity.primary, 0.78)],
        ),
    );

    if (identity.striped) {
      canvas.save();
      canvas.clipPath(path);
      final stripe = Paint()
        ..color = identity.secondary.withValues(alpha: 0.28);
      final width = size.width / 5;
      for (var x = width; x < size.width; x += width * 2) {
        canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), stripe);
      }
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = identity.secondary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06,
    );
    // 縁の面取り。上の内側に光、下の内側に影を薄く乗せる。
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path.shift(Offset(0, -size.height * 0.06)),
      Paint()
        ..color = const Color(0x3DFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07,
    );
    canvas.drawPath(
      path.shift(Offset(0, size.height * 0.06)),
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07,
    );
    canvas.restore();
  }

  /// 色を明るく／暗くする。**新しい色は作らない**——クラブの色から出す。
  static Color _shade(Color base, double factor) => Color.fromARGB(
    (base.a * 255).round(),
    ((base.r * 255) * factor).clamp(0, 255).round(),
    ((base.g * 255) * factor).clamp(0, 255).round(),
    ((base.b * 255) * factor).clamp(0, 255).round(),
  );

  Path _shapePath(Size size) {
    final w = size.width;
    final h = size.height;
    switch (identity.shape) {
      case CrestShape.circle:
        return Path()..addOval(
          Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w / 2 * 0.92),
        );
      case CrestShape.diamond:
        return Path()
          ..moveTo(w / 2, h * 0.04)
          ..lineTo(w * 0.96, h / 2)
          ..lineTo(w / 2, h * 0.96)
          ..lineTo(w * 0.04, h / 2)
          ..close();
      case CrestShape.banner:
        return Path()
          ..moveTo(w * 0.08, h * 0.08)
          ..lineTo(w * 0.92, h * 0.08)
          ..lineTo(w * 0.92, h * 0.78)
          ..lineTo(w / 2, h * 0.94)
          ..lineTo(w * 0.08, h * 0.78)
          ..close();
      case CrestShape.shield:
        return Path()
          ..moveTo(w * 0.1, h * 0.08)
          ..lineTo(w * 0.9, h * 0.08)
          ..lineTo(w * 0.9, h * 0.55)
          ..quadraticBezierTo(w * 0.9, h * 0.9, w / 2, h * 0.96)
          ..quadraticBezierTo(w * 0.1, h * 0.9, w * 0.1, h * 0.55)
          ..close();
    }
  }

  @override
  bool shouldRepaint(_CrestPainter oldDelegate) =>
      oldDelegate.identity.primary != identity.primary ||
      oldDelegate.identity.shape != identity.shape ||
      oldDelegate.identity.striped != identity.striped;
}
