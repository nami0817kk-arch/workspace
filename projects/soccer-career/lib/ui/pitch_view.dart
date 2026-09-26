import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/development.dart';
import '../models/pitch.dart';
import 'club_identity.dart';

/// 局面をピッチの絵にする。
///
/// これまで試合画面は最後まで文字だった。「ライン間で前を向いて受けた。
/// 中央は密集、外は空いている」と書いてあっても、自分がどこに居て
/// 相手がどう構えているかは、読んで想像するしかなかった。
///
/// **描くのは判定に効いているものだけ**にしてある。自分の位置（[spot]）と、
/// 相手の戦い方（[style]）が作るブロックの高さ。味方を勝手に何人も置くと、
/// 判定に無いものが画面にあることになる（このゲームで一番やらないこと）。
/// 選んだ手がどうなったか。ピッチの上に、ボールの行方として描く。
///
/// 局面の絵は「どこで」を読まずに分からせたが、**結果は文字だけ**だった。
/// 通ったなら前へ、決まったならゴールまで、止められたなら相手の色で。
/// 判定に無いものは描かない——描くのは成否とゴールかどうか、それだけ。
class PitchOutcome {
  const PitchOutcome({required this.success, required this.goal});

  final bool success;
  final bool goal;
}

class PitchView extends StatelessWidget {
  const PitchView({
    super.key,
    required this.spot,
    required this.club,
    required this.opponent,
    required this.style,
    this.outcome,
    this.aspectRatio = 2.15,
  });

  /// 結果。null なら局面（これから選ぶ）として描く。
  final PitchOutcome? outcome;

  /// 横長さ。結果の絵は小さく置くので、少し詰める。
  final double aspectRatio;

  final PitchSpot spot;

  /// 自分のクラブ。ゴールと自分の印に色が入る。
  final Club club;

  final Club opponent;

  /// 相手の戦い方。ブロックの高さと幅がこれで決まる。
  final ClubStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${spot.label}。相手は${style.label}',
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: CustomPaint(
          painter: _PitchPainter(
            spot: spot,
            style: style,
            home: ClubIdentity.of(club),
            away: ClubIdentity.of(opponent),
            outcome: outcome,
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter({
    required this.spot,
    required this.style,
    required this.home,
    required this.away,
    this.outcome,
  });

  final PitchSpot spot;
  final ClubStyle style;
  final ClubIdentity home;
  final ClubIdentity away;
  final PitchOutcome? outcome;

  /// 芝。彩度を落としてあるのは、この上に置く色（クラブ色）を
  /// 読ませるため。緑が主役になると、自分がどこに居るか分からなくなる。
  static const Color _grass = Color(0xFF63846A);
  static const Color _stripe = Color(0xFF6D8F73);
  static const Color _line = Color(0x8CFFFFFF);

  /// 相手のブロック。前の列・後ろの列・横の広がりを、
  /// **戦い方の説明文と同じ形**で置く（自陣ゴール 0.0 〜 相手ゴール 1.0）。
  ///
  /// 1列だけだと「抜けているのか、囲まれているのか」が分からない。
  /// ハイプレス=こちら側まで出てきて厚みが薄い、堅守速攻=自陣に固まる、
  /// 技巧派=高すぎず横に広い、肉弾戦=中央を締めて縦に厚い。
  ({double front, double rear, double spread}) get _block => switch (style) {
    ClubStyle.pressing => (front: 0.32, rear: 0.58, spread: 0.80),
    ClubStyle.defensive => (front: 0.66, rear: 0.88, spread: 0.62),
    ClubStyle.technical => (front: 0.46, rear: 0.74, spread: 0.90),
    ClubStyle.physical => (front: 0.52, rear: 0.78, spread: 0.55),
  };

  @override
  void paint(Canvas canvas, Size size) {
    // 角の丸めはカード側に任せる（Card の clipBehavior）。
    // ここでも丸めると、二重の縁が見える。
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);

    canvas.drawRect(rect, Paint()..color = _grass);
    // 芝目。縞は縦（攻める向きに直交）に入れる。
    final stripe = Paint()..color = _stripe;
    const bands = 7;
    for (var i = 0; i < bands; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * i / bands,
          0,
          size.width / bands,
          size.height,
        ),
        stripe,
      );
    }
    // **照明と、四隅の落ち込み。** 単色の板に丸を置いただけだと、
    // 絵ではなく図表に見える。中央が明るく縁が落ちるだけで、
    // 「上から照らされた平面」として読めるようになる。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.34),
          size.width * 0.72,
          const [Color(0x1AFFFFFF), Color(0x00FFFFFF), Color(0x33000000)],
          const [0.0, 0.55, 1.0],
        ),
    );
    // 上端と下端は、スタンドの影でわずかに沈む。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, rect.top),
          Offset(0, rect.bottom),
          const [Color(0x40000000), Color(0x00000000), Color(0x2E000000)],
          const [0.0, 0.3, 1.0],
        ),
    );

    // 余白を取ってからラインを引く。ピッチの縁とカードの縁が
    // 重なると、絵ではなく枠に見える。
    final inset = Rect.fromLTWH(
      size.width * 0.035,
      size.height * 0.07,
      size.width * 0.93,
      size.height * 0.86,
    );
    _lines(canvas, inset);
    _goals(canvas, inset);
    _opponents(canvas, inset);
    _player(canvas, inset);
    _ball(canvas, inset);
    canvas.restore();
  }

  /// ボール。局面ならこの選手の足元、結果なら行った先まで。
  void _ball(Canvas canvas, Rect p) {
    final from = Offset(
      p.left + p.width * spot.along,
      p.top + p.height * spot.across,
    );
    final r = p.height * 0.032;
    final white = Paint()..color = Colors.white;
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xCC14140F);
    final result = outcome;
    if (result == null) {
      // まだ選んでいない。足元にボール。
      final at = from + Offset(r * 2.2, r * 1.6);
      canvas.drawOval(
        Rect.fromCenter(
          center: at + Offset(r * 0.1, r * 0.55),
          width: r * 1.9,
          height: r * 0.9,
        ),
        Paint()
          ..color = const Color(0x4D000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
      canvas.drawCircle(at, r, white);
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            at + Offset(-r * 0.3, -r * 0.35),
            r * 1.6,
            const [Color(0x00FFFFFF), Color(0x4D000000)],
          ),
      );
      canvas.drawCircle(at, r, dark);
      return;
    }

    // 行き先。決めたならゴール、通ったなら前へ、止められたなら少し先で相手に。
    final goal = Offset(p.right, p.center.dy);
    final Offset to;
    if (result.goal) {
      to = goal;
    } else if (result.success) {
      final dx = (goal.dx - from.dx) * 0.38;
      final dy = (goal.dy - from.dy) * 0.38;
      to = Offset(from.dx + dx, from.dy + dy);
    } else {
      final dx = (goal.dx - from.dx) * 0.22;
      final dy = (goal.dy - from.dy) * 0.22;
      to = Offset(from.dx + dx, from.dy + dy);
    }

    // 軌跡。通ったなら実線、止められたなら途中で切れる破線。
    final path = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = result.success
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.55);
    if (result.success) {
      canvas.drawLine(from, to, path);
    } else {
      const segments = 6;
      for (var i = 0; i < segments; i += 2) {
        final a = Offset.lerp(from, to, i / segments)!;
        final b = Offset.lerp(from, to, (i + 1) / segments)!;
        canvas.drawLine(a, b, path);
      }
    }

    // 行き着いたボール。決まったなら大きく、止められたなら相手の色で。
    if (result.goal) {
      canvas.drawCircle(to, r * 2.6, Paint()..color = const Color(0x55FFFFFF));
      canvas.drawCircle(to, r * 1.4, white);
      canvas.drawCircle(to, r * 1.4, dark);
    } else if (result.success) {
      canvas.drawCircle(to, r, white);
      canvas.drawCircle(to, r, dark);
    } else {
      canvas.drawCircle(to, r * 1.6, Paint()..color = away.primary);
      canvas.drawCircle(
        to,
        r * 1.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xCCFFFFFF),
      );
    }
  }

  void _lines(Canvas canvas, Rect p) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _line;
    canvas.drawRect(p, paint);
    canvas.drawLine(
      Offset(p.center.dx, p.top),
      Offset(p.center.dx, p.bottom),
      paint,
    );
    canvas.drawCircle(p.center, p.width * 0.085, paint);
    canvas.drawCircle(p.center, 1.6, Paint()..color = _line);

    for (final left in [true, false]) {
      // ペナルティエリアとゴールエリア。実寸の比率で置く。
      _boxAt(canvas, p, paint, left, 0.157, 0.593);
      _boxAt(canvas, p, paint, left, 0.052, 0.269);
      final spotX = left ? p.left + p.width * 0.105 : p.right - p.width * 0.105;
      canvas.drawCircle(
        Offset(spotX, p.center.dy),
        1.6,
        Paint()..color = _line,
      );
    }
  }

  void _boxAt(
    Canvas canvas,
    Rect p,
    Paint paint,
    bool left,
    double depth,
    double width,
  ) {
    final w = p.width * depth;
    final h = p.height * width;
    canvas.drawRect(
      Rect.fromLTWH(left ? p.left : p.right - w, p.center.dy - h / 2, w, h),
      paint,
    );
  }

  /// 両端のゴール。左が自分のクラブ、右が相手。
  ///
  /// どちらへ攻めるのかを、矢印や文字ではなく色で示す。
  void _goals(Canvas canvas, Rect p) {
    final h = p.height * 0.22;
    final w = p.width * 0.016;
    // **ゴールは箱として描く。** 短冊1枚だと、ピッチに貼った色のテープに
    // 見える。正面の面と、奥へ伸びる側面を分けて、明るさを変える。
    void goal(Rect mouth, Color color, {required bool toLeft}) {
      final depth = w * 2.2;
      final dx = toLeft ? -depth : depth;
      // 奥の面（暗い）。台形で奥行きを出す。
      final back = Path()
        ..moveTo(mouth.left, mouth.top)
        ..lineTo(mouth.left + dx, mouth.top + mouth.height * 0.1)
        ..lineTo(mouth.left + dx, mouth.bottom - mouth.height * 0.1)
        ..lineTo(mouth.left, mouth.bottom)
        ..close();
      canvas.drawPath(back, Paint()..color = _shade(color, 0.55));
      // 正面のポスト（明るい）。
      canvas.drawRect(mouth, Paint()..color = color);
      canvas.drawRect(
        Rect.fromLTWH(mouth.left, mouth.top, mouth.width, mouth.height * 0.18),
        Paint()..color = _shade(color, 1.45),
      );
    }

    goal(
      Rect.fromLTWH(p.left - w, p.center.dy - h / 2, w, h),
      home.primary,
      toLeft: true,
    );
    goal(
      Rect.fromLTWH(p.right, p.center.dy - h / 2, w, h),
      away.primary,
      toLeft: false,
    );
  }

  /// 色を明るく／暗くする。**新しい色は作らない**——クラブの色から出す。
  static Color _shade(Color base, double factor) => Color.fromARGB(
    (base.a * 255).round(),
    ((base.r * 255) * factor).clamp(0, 255).round(),
    ((base.g * 255) * factor).clamp(0, 255).round(),
    ((base.b * 255) * factor).clamp(0, 255).round(),
  );

  /// ピッチに立つ駒。**平らな丸を球にする。**
  ///
  /// 落ち影で床から浮かせ、上からの光で丸みを出す。
  /// 光の向きは芝の照明（上）と揃える——別々の向きから照らすと、
  /// 同じ絵の中に2つの太陽があることになる。
  void _marker(Canvas canvas, Offset at, double r, Color color) {
    // 床に落ちる影。真下ではなく少し下へ（光は上から）。
    canvas.drawOval(
      Rect.fromCenter(
        center: at + Offset(r * 0.12, r * 0.46),
        width: r * 2.0,
        height: r * 1.05,
      ),
      Paint()
        ..color = const Color(0x4D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    // 縁は白。相手の色が芝と近い緑のこともあるので、
    // 色に頼らず形で分かるようにしておく。
    canvas.drawCircle(at, r + 1.4, Paint()..color = const Color(0xE6FFFFFF));
    canvas.drawCircle(at, r, Paint()..color = color);
    // 上からの光。球の上半分が明るく、下端が落ちる。
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          at + Offset(-r * 0.32, -r * 0.4),
          r * 1.5,
          const [Color(0x73FFFFFF), Color(0x00FFFFFF), Color(0x59000000)],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  /// 相手のブロック。後ろに4人、前に3人。
  void _opponents(Canvas canvas, Rect p) {
    final block = _block;
    void row(double along, int count, double spread) {
      final x = p.left + p.width * along;
      for (var i = 0; i < count; i++) {
        final t = (i + 0.5) / count;
        final y = p.center.dy + (t - 0.5) * p.height * spread;
        // 端は少し下がって構える。並びが直線だと絵が硬い。
        final at = Offset(x + (t - 0.5).abs() * p.width * 0.04, y);
        _marker(canvas, at, p.height * 0.05, away.primary);
      }
    }

    row(block.rear, 4, block.spread);
    row(block.front, 3, block.spread * 0.78);
  }

  /// 自分。局面の場所に置く。
  void _player(Canvas canvas, Rect p) {
    final at = Offset(
      p.left + p.width * spot.along,
      p.top + p.height * spot.across,
    );
    final r = p.height * 0.058;
    // 自分の足元だけ、芝が明るい（スポットライト）。
    canvas.drawCircle(
      at,
      r * 2.3,
      Paint()
        ..shader = ui.Gradient.radial(at, r * 2.3, const [
          Color(0x40FFFFFF),
          Color(0x00FFFFFF),
        ]),
    );
    _marker(canvas, at, r, home.primary);
    if (home.striped) {
      canvas.drawCircle(at, r * 0.45, Paint()..color = home.secondary);
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.spot != spot ||
      old.outcome?.success != outcome?.success ||
      old.outcome?.goal != outcome?.goal ||
      old.style != style ||
      old.home.primary != home.primary ||
      old.away.primary != away.primary;
}
