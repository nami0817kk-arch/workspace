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
class PitchView extends StatelessWidget {
  const PitchView({
    super.key,
    required this.spot,
    required this.club,
    required this.opponent,
    required this.style,
  });

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
        aspectRatio: 2.15,
        child: CustomPaint(
          painter: _PitchPainter(
            spot: spot,
            style: style,
            home: ClubIdentity.of(club),
            away: ClubIdentity.of(opponent),
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
  });

  final PitchSpot spot;
  final ClubStyle style;
  final ClubIdentity home;
  final ClubIdentity away;

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
    canvas.restore();
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
    canvas.drawRect(
      Rect.fromLTWH(p.left - w, p.center.dy - h / 2, w, h),
      Paint()..color = home.primary,
    );
    canvas.drawRect(
      Rect.fromLTWH(p.right, p.center.dy - h / 2, w, h),
      Paint()..color = away.primary,
    );
  }

  /// 相手のブロック。後ろに4人、前に3人。
  void _opponents(Canvas canvas, Rect p) {
    final block = _block;
    final fill = Paint()..color = away.primary;
    // 縁は白。相手の色が芝と近い緑のこともあるので、
    // 色に頼らず形で分かるようにしておく。
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xCCFFFFFF);
    void row(double along, int count, double spread) {
      final x = p.left + p.width * along;
      for (var i = 0; i < count; i++) {
        final t = (i + 0.5) / count;
        final y = p.center.dy + (t - 0.5) * p.height * spread;
        // 端は少し下がって構える。並びが直線だと絵が硬い。
        final at = Offset(x + (t - 0.5).abs() * p.width * 0.04, y);
        canvas.drawCircle(at, p.height * 0.05, fill);
        canvas.drawCircle(at, p.height * 0.05, ring);
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
    canvas.drawCircle(at, r * 2.1, Paint()..color = const Color(0x33FFFFFF));
    canvas.drawCircle(at, r + 1.6, Paint()..color = Colors.white);
    canvas.drawCircle(at, r, Paint()..color = home.primary);
    if (home.striped) {
      canvas.drawCircle(at, r * 0.45, Paint()..color = home.secondary);
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.spot != spot ||
      old.style != style ||
      old.home.primary != home.primary ||
      old.away.primary != away.primary;
}
