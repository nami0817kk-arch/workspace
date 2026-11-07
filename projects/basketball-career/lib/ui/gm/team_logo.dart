import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/league.dart';

/// ロゴの外の形。
enum LogoShape { circle, shield, hexagon, diamond }

/// チームのロゴの決まり。愛称にちなんだ模様・2つの色・形・3文字の略称。
/// 実在のチームのロゴには似せない(模様は Material のアイコン、形と色の組み合わせで作る)。
class LogoDef {
  const LogoDef(this.abbr, this.icon, this.primary, this.secondary, this.shape);
  final String abbr;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final LogoShape shape;
}

const _navy = Color(0xFF1B2A4A);
const _black = Color(0xFF15171C);
const _gold = Color(0xFFE8B23A);
const _white = Color(0xFFF3F5F8);
const _silver = Color(0xFFB9C2CF);

/// [teamDefs] と同じ順。
const logoDefs = <LogoDef>[
  LogoDef('CHA', Icons.emoji_nature, Color(0xFF0B8A8F), Color(0xFF3B2A6B), LogoShape.hexagon), // スティンガーズ(蜂)
  LogoDef('ATL', Icons.paragliding, Color(0xFFC8102E), _white, LogoShape.diamond), // カイツ(凧)
  LogoDef('BOS', Icons.spa, Color(0xFF00703C), _white, LogoShape.circle), // シャムロックス(葉)
  LogoDef('BKN', Icons.foundation, _navy, _white, LogoShape.shield), // ブリッジズ(橋)
  LogoDef('CHI', Icons.pets, Color(0xFFB3132C), _black, LogoShape.shield), // バイソンズ
  LogoDef('CLE', Icons.shield_moon, Color(0xFF6A1F3A), _gold, LogoShape.shield), // ナイツ
  LogoDef('DET', Icons.settings, Color(0xFF1D5BBF), Color(0xFFC8102E), LogoShape.circle), // モーターズ(歯車)
  LogoDef('IND', Icons.speed, Color(0xFFF2B417), _navy, LogoShape.circle), // スピードスターズ
  LogoDef('MIA', Icons.local_fire_department, Color(0xFFD0202E), _black, LogoShape.diamond), // ブレイズ(炎)
  LogoDef('MIL', Icons.park, Color(0xFF2F7D32), Color(0xFFEEE1C6), LogoShape.shield), // スタッグス(森)
  LogoDef('NYE', Icons.location_city, Color(0xFFF07C1A), Color(0xFF1A4FA0), LogoShape.circle), // エンパイアズ(摩天楼)
  LogoDef('ORL', Icons.auto_awesome, Color(0xFF1C6FD1), _black, LogoShape.hexagon), // スペルズ(魔法)
  LogoDef('PHI', Icons.account_balance, Color(0xFF1E57B7), Color(0xFFC8102E), LogoShape.shield), // ファウンダーズ(議事堂)
  LogoDef('TOR', Icons.egg_alt, Color(0xFF6B2C91), _black, LogoShape.hexagon), // ダイノス(卵)
  LogoDef('WAS', Icons.star, _navy, Color(0xFFC8102E), LogoShape.diamond), // ソーサラーズ(星)
  LogoDef('DAL', Icons.local_police, Color(0xFF2A8FD6), _navy, LogoShape.shield), // アウトローズ(保安官のバッジ)
  LogoDef('DEN', Icons.landscape, Color(0xFFF0B323), _navy, LogoShape.hexagon), // プロスペクターズ(山)
  LogoDef('SFC', Icons.shield, Color(0xFFF5B800), Color(0xFF1A4FA0), LogoShape.circle), // センチネルズ(盾)
  LogoDef('HOU', Icons.public, Color(0xFFCE1141), _silver, LogoShape.circle), // オービッツ(地球と軌道)
  LogoDef('LAS', Icons.sailing, Color(0xFF1D58C4), Color(0xFFC8102E), LogoShape.circle), // スクーナーズ(帆船)
  LogoDef('LAT', Icons.theater_comedy, Color(0xFF5B2A86), _gold, LogoShape.diamond), // ショータイム(仮面)
  LogoDef('MEM', Icons.pets, Color(0xFF5D87C4), _navy, LogoShape.shield), // コディアックス(熊)
  LogoDef('MIN', Icons.nightlight, Color(0xFF1F6F4A), _navy, LogoShape.hexagon), // ハウラーズ(月夜)
  LogoDef('NOH', Icons.flutter_dash, _navy, _gold, LogoShape.circle), // ヘロンズ(鳥)
  LogoDef('OKC', Icons.tornado, Color(0xFF2E8FD8), Color(0xFFEF6C2F), LogoShape.diamond), // トルネードズ
  LogoDef('PHX', Icons.wb_sunny, Color(0xFFEF6C1A), Color(0xFF4B2A7B), LogoShape.circle), // フレアーズ(太陽)
  LogoDef('POR', Icons.explore, Color(0xFFD22B2B), _black, LogoShape.hexagon), // パスファインダーズ(羅針盤)
  LogoDef('SAC', Icons.diamond, Color(0xFF5A2D82), _silver, LogoShape.shield), // クラウンズ(宝石)
  LogoDef('SAN', Icons.adjust, Color(0xFF30343B), _silver, LogoShape.diamond), // ラングラーズ(投げ縄の輪)
  LogoDef('UTA', Icons.music_note, Color(0xFF4F8A2B), Color(0xFF5B2A86), LogoShape.circle), // リズムズ(音符)
];

LogoDef logoOf(int team) => logoDefs[team.clamp(0, logoDefs.length - 1)];

/// チームのロゴ。大きいとき([size] が40以上)は略称の帯も付ける。
class TeamLogo extends StatelessWidget {
  const TeamLogo({super.key, required this.team, this.size = 26});
  final int team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = logoOf(team);
    final big = size >= 40;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(d),
        child: Padding(
          padding: EdgeInsets.all(size * (d.shape == LogoShape.diamond ? 0.24 : 0.17)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(
              child: FittedBox(
                child: Icon(d.icon, color: Colors.white),
              ),
            ),
            if (big)
              FittedBox(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: d.secondary, borderRadius: BorderRadius.circular(3)),
                  child: Text(d.abbr,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 1.15,
                        letterSpacing: 0.5,
                        color: d.secondary.computeLuminance() > 0.45 ? d.primary : Colors.white,
                      )),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.d);
  final LogoDef d;

  Path _shape(Size s, double inset) {
    final r = Rect.fromLTWH(inset, inset, s.width - inset * 2, s.height - inset * 2);
    switch (d.shape) {
      case LogoShape.circle:
        return Path()..addOval(r);
      case LogoShape.diamond:
        return Path()
          ..moveTo(r.center.dx, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.center.dx, r.bottom)
          ..lineTo(r.left, r.center.dy)
          ..close();
      case LogoShape.hexagon:
        final p = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 6 + i * math.pi / 3;
          final pt = Offset(r.center.dx + r.width / 2 * math.cos(a), r.center.dy + r.height / 2 * math.sin(a));
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        return p..close();
      case LogoShape.shield:
        return Path()
          ..moveTo(r.left, r.top + r.height * 0.12)
          ..quadraticBezierTo(r.center.dx, r.top - r.height * 0.04, r.right, r.top + r.height * 0.12)
          ..lineTo(r.right, r.top + r.height * 0.5)
          ..quadraticBezierTo(r.right, r.bottom - r.height * 0.12, r.center.dx, r.bottom)
          ..quadraticBezierTo(r.left, r.bottom - r.height * 0.12, r.left, r.top + r.height * 0.5)
          ..close();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // 外の縁(2つ目の色)、内側(1つ目の色の濃淡)、細い白い線
    final outer = _shape(size, 0);
    canvas.drawPath(outer, Paint()..color = d.secondary);
    // 黒や紺の縁は暗い下地に溶けるので、外に薄い線を引く
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.015)
        ..color = Colors.white.withValues(alpha: 0.28),
    );
    final inner = _shape(size, w * 0.07);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(d.primary, Colors.white, 0.18)!, Color.lerp(d.primary, Colors.black, 0.25)!],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.02)
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.d != d;
}
