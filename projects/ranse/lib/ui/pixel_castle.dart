import 'dart:math' as math;

import 'package:flutter/material.dart';

/// タイトルのドット絵: 夕焼けの空・遠い山並み・天守のある城（2026-11-23、ユーザー「ホームにドット絵は欲しい」）。
/// 外の画像は使わず、64×40 のマスの色を規則で決めて描く（作者の権利の心配がなく、どの画面の大きさでもにじまない）。
class PixelCastle extends StatelessWidget {
  const PixelCastle({super.key, this.width = 320});
  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: width,
      height: width * kCastleH / kCastleW,
      child: const CustomPaint(painter: _CastlePainter()),
    ),
  );
}

const kCastleW = 64, kCastleH = 40;

// 色
const _sky = [
  Color(0xFF4B2E5E), // 夜に近い紫
  Color(0xFF7A3F69),
  Color(0xFFB4525F),
  Color(0xFFE07A4A), // 茜
  Color(0xFFF2AE5A), // 山の端の明るい橙
];
const _sun = Color(0xFFFCE08A);
const _farHill = Color(0xFF8A5068);
const _nearHill = Color(0xFF4F3247);
const _ground = Color(0xFF35242D);
const _field = Color(0xFF4A3038);
const _stone = Color(0xFF6E5E5A);
const _stoneDark = Color(0xFF574946);
const _wall = Color(0xFFF1E7D6);
const _wallShade = Color(0xFFD9CBB5);
const _roof = Color(0xFF2C2838);
const _roofEdge = Color(0xFF454057);
const _window = Color(0xFF3A2E2A);
const _gold = Color(0xFFE5B547);
const _bird = Color(0xFF3A2440);

/// マス (x, y) の色。null は描かない（使わない）。
Color castlePixel(int x, int y) {
  // 空: 上から5段。段の境目は市松模様で混ぜる（ドット絵のぼかし）。
  Color sky() {
    const edges = [8, 14, 20, 25];
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      if (y < e - 1) return _sky[i];
      if (y == e - 1) return (x + y).isEven ? _sky[i] : _sky[i + 1];
    }
    return _sky.last;
  }

  var c = sky();

  // 太陽（山に半分沈む）
  final dx = x - 47, dy = y - 25;
  if (dx * dx + dy * dy <= 30) c = _sun;

  // 鳥
  const birds = {(8, 6), (9, 5), (10, 6), (13, 9), (14, 8), (15, 9)};
  if (birds.contains((x, y))) c = _bird;

  // 遠い山並み
  final far = 27 + (3 * math.sin(x / 6.5) + 2 * math.sin(x / 2.7 + 1)).round();
  if (y >= far) c = _farHill;
  // 手前の丘
  final near = 32 + (2 * math.sin(x / 5 + 2)).round();
  if (y >= near) c = _nearHill;
  // 地面と田の畝
  if (y >= 36) c = (y == 37 && x % 4 != 0) ? _field : _ground;

  // ---- 城（x 14〜34 あたり）----
  // 石垣: 下ほど広い台形
  if (y >= 29 && y <= 35) {
    final half = 9 + (y - 29) ~/ 2;
    if ((x - 24).abs() <= half) c = (y + x ~/ 3).isEven ? _stone : _stoneDark;
  }
  // 天守: 3重。各重は 壁(白)＋窓、その上に屋根（両端が反る）。
  void tier(int top, int bottom, int halfWall, int roofY, int halfRoof) {
    if (y >= top && y <= bottom && (x - 24).abs() <= halfWall) {
      c = (x - 24) > halfWall - 2 ? _wallShade : _wall;
      final win = y == top + 1 && (x - 24).abs() < halfWall - 1 && x.isEven;
      if (win) c = _window;
    }
    if (y == roofY && (x - 24).abs() <= halfRoof) c = _roof;
    if (y == roofY + 1 && (x - 24).abs() <= halfRoof - 1) c = _roofEdge;
    // 反り: 屋根の両端を1マス上げる
    if (y == roofY - 1 && (x - 24).abs() == halfRoof) c = _roof;
  }

  tier(25, 28, 7, 23, 10);
  tier(19, 22, 5, 17, 8);
  tier(13, 16, 4, 11, 6);
  // 最上の屋根と鯱
  if (y == 9 && (x - 24).abs() <= 3) c = _roof;
  if (y == 8 && (x - 24).abs() <= 1) c = _roof;
  if (y == 7 && (x == 22 || x == 26)) c = _gold;
  return c;
}

class _CastlePainter extends CustomPainter {
  const _CastlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / kCastleW, ch = size.height / kCastleH;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < kCastleH; y++) {
      for (var x = 0; x < kCastleW; x++) {
        paint.color = castlePixel(x, y);
        // 隣のマスと隙間ができないよう、わずかに重ねて描く。
        canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw + .5, ch + .5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// タイトルの絵（Gemini で作った、夕焼けの城のドット絵。2026-11-23、ユーザー「Gemini に画像頼んで品質上げて」）。
/// 絵が読めなかったときは、コードで描くドット絵（[PixelCastle]）に戻す。
const kTitleArtW = 960, kTitleArtH = 597;

class TitleArt extends StatelessWidget {
  const TitleArt({super.key, this.width = 340});
  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      'assets/images/title_castle.jpg',
      width: width,
      height: width * kTitleArtH / kTitleArtW,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => PixelCastle(width: width),
    ),
  );
}
