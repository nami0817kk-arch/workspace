import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../../game/match.dart';
import '../../game/player.dart';
import '../../game/season.dart';
import '../team_colors.dart';

/// 育成画面の上に出す絵。体育館の床・ゴール・選手をコードで描く(画像は使わない)。
/// 選手の大きさは身長に比例し、ユニフォームの色は所属で変わる。
class CourtHeader extends StatelessWidget {
  const CourtHeader(
      {super.key,
      required this.game,
      this.height = 190,
      this.versus = false,
      this.pose = Pose.dribble,
      this.scene,
      this.season,
      this.opponent});
  final Game game;
  final double height;

  /// 選手のポーズ(重点・勝負どころの選択・作戦に合わせて変える)。
  final Pose pose;

  /// 会場の絵を差し替える(大一番の会場など)。null なら段階ごとの会場。
  final String? scene;

  /// 過去の年を描く(成績カード): その年の舞台と年齢で、会場・子ども/大人・ユニフォームの色を決める。
  final ({League league, int age, double heightCm, String team})? season;

  /// ライバルとの対決で、向かい合う相手を描く。
  final bool versus;

  /// 向かい合う相手の名前(相手のユニフォームの色を決める)。null なら黒っぽい色。
  final String? opponent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 下地はコードで描いた体育館。絵が読み込めない間・失敗したときはこれが見える。
            CustomPaint(
              painter: _CourtPainter(
                heightCm: season?.heightCm ?? game.player.heightCm,
                jersey: _colorOf(game, season).jersey,
                slot: game.slot,
                versus: versus,
                number: game.number,
                layer: _Layer.background,
              ),
            ),
            // 段階ごとの会場の絵(Gemini で生成。`assets/art/scene_*.jpg`)。
            Image.asset(
              scene ?? (season == null ? sceneAsset(game) : sceneForLeague(season!.league)),
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              frameBuilder: (context, child, frame, sync) =>
                  (frame == null && !sync) ? const SizedBox.shrink() : child,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            _Sprites(game: game, versus: versus, pose: pose, season: season, opponent: opponent),
            CustomPaint(
              painter: _CourtPainter(
                heightCm: season?.heightCm ?? game.player.heightCm,
                jersey: _colorOf(game, season).jersey,
                slot: game.slot,
                versus: versus,
                number: game.number,
                layer: _Layer.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// いまの段階の会場の絵。大学・実業団・プロは所属、プロは海外、冬の代表招集は代表の会場。
String sceneAsset(Game g) {
  final national = g.nationalPending && g.slot == 3 && g.track == Track.pro;
  return sceneForLeague(national ? League.national : g.league);
}

/// 舞台ごとの会場の絵。
String sceneForLeague(League league) {
  final name = switch (league) {
    League.minibasket => 'minibasket',
    League.juniorHigh => 'junior',
    League.highSchool => 'high',
    League.university => 'university',
    League.corporate => 'corporate',
    League.proDomestic => 'pro',
    League.proAbroad => 'abroad',
    League.national => 'national',
  };
  return 'assets/art/scene_$name.jpg';
}

enum _Layer { background, foreground, fallback }

/// 選手のポーズ(Gemini で作った絵。`tool/make_sprites.py` でマゼンタを抜いて7色にした)。
/// 子どもはダンクの代わりに「思い切りジャンプ」(`kid_jump_*`)。
enum Pose { dribble, shoot, defense, dunk }

/// ポーズの絵のファイル名(色の前まで)。ドリブルは最初の絵(`kid_<色>` / `adult_<色>`)。
String poseFile(Pose p, {required bool kid}) {
  final k = kid ? 'kid' : 'adult';
  return switch (p) {
    Pose.dribble => k,
    Pose.dunk => kid ? 'kid_jump' : 'adult_dunk',
    _ => '${k}_${p.name}',
  };
}

/// ポーズごとの絵の幅÷高さと、背番号を重ねる位置(絵の中の胴の中心、0〜1)。
({double aspect, double nx, double ny}) poseLayout(Pose p, {required bool kid}) => switch ((p, kid)) {
      (Pose.dribble, true) => (aspect: 0.815, nx: 0.58, ny: 0.52),
      (Pose.dribble, false) => (aspect: 0.815, nx: 0.48, ny: 0.40),
      (Pose.shoot, true) => (aspect: 0.433, nx: 0.55, ny: 0.55),
      (Pose.shoot, false) => (aspect: 0.222, nx: 0.50, ny: 0.37),
      (Pose.defense, true) => (aspect: 0.969, nx: 0.50, ny: 0.56),
      (Pose.defense, false) => (aspect: 0.894, nx: 0.50, ny: 0.34),
      (Pose.dunk, true) => (aspect: 0.569, nx: 0.46, ny: 0.54),
      (Pose.dunk, false) => (aspect: 0.381, nx: 0.45, ny: 0.45),
    };

/// 重点の能力に合うポーズ(シュート系→シュート、守り・リバウンド→ディフェンス、ゴール下・体→ダンク)。
Pose poseForFocus(Ability a) => switch (a) {
      Ability.threePoint || Ability.midRange || Ability.freeThrow => Pose.shoot,
      Ability.defense || Ability.rebound => Pose.defense,
      Ability.inside || Ability.physical => Pose.dunk,
      _ => Pose.dribble,
    };

/// 勝負どころのプレーに合うポーズ。
Pose poseForClutch(Clutch c) => switch (c) {
      Clutch.drive || Clutch.drawFoul => Pose.dunk,
      Clutch.threePoint => Pose.shoot,
      Clutch.defend => Pose.defense,
      Clutch.pass => Pose.dribble,
    };

/// 大一番の作戦に合うポーズ。
Pose poseForPlan(BigGamePlan p) => switch (p) {
      BigGamePlan.stopAce => Pose.defense,
      BigGamePlan.attack => Pose.dunk,
      BigGamePlan.team => Pose.dribble,
    };

/// ユニフォームの色(所属チームで決まる。過去の年はその年のチーム)。
TeamColor _colorOf(Game g, ({League league, int age, double heightCm, String team})? season) =>
    season == null ? teamColorOfGame(g) : teamColorOf(season.team, season.league);

/// 選手の絵(Gemini 生成)。12歳までは子ども、それ以降は大人の絵。大きさは身長に比例し、
/// ユニフォームの色は所属チームで変わる(絵は青を色相で替えた12色。`team_colors.dart`)。背番号は絵の上に文字で重ねる。
/// 絵が読み込めないときは、コードで描いた選手に戻る。
class _Sprites extends StatelessWidget {
  const _Sprites(
      {required this.game, required this.versus, this.pose = Pose.dribble, this.season, this.opponent});
  final Game game;
  final bool versus;
  final Pose pose;
  final ({League league, int age, double heightCm, String team})? season;
  final String? opponent;

  @override
  Widget build(BuildContext context) {
    final p = game.player;
    final age = season?.age ?? p.age;
    final kind = age < 13 ? 'kid' : 'adult';
    final ours = _colorOf(game, season);
    final color = ours.sprite;
    final theirs = opponent == null ? 'dark' : opponentColor(opponent!, ours).sprite;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final scale = ((season?.heightCm ?? p.heightCm) / 210).clamp(0.5, 1.05);
      final figH = h * 0.86 * scale;
      final bottom = h * 0.03;
      // 絵が読み込めなかったとき、その選手の枠の中にコードで描いた選手を出す。
      Widget fallback() => CustomPaint(
            painter: _CourtPainter(
              heightCm: 210,
              jersey: ours.jersey,
              slot: game.slot,
              number: game.number,
              layer: _Layer.fallback,
            ),
          );
      Widget sprite(String name, double cx, double hh,
          {bool flip = false, int number = 0, Pose pose = Pose.dribble, bool kid = false}) {
        final lay = poseLayout(pose, kid: kid);
        final ww = hh * lay.aspect;
        // 背番号の位置(胴の中心)。ポーズごとに違う。
        final tx = lay.nx;
        final ty = lay.ny;
        return Positioned(
          left: cx - ww / 2,
          bottom: bottom,
          width: ww,
          height: hh,
          child: Transform.flip(
            flipX: flip,
            child: Stack(children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/art/players/$name.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  frameBuilder: (context, child, frame, sync) =>
                      (frame == null && !sync) ? const SizedBox.shrink() : child,
                  errorBuilder: (_, __, ___) => fallback(),
                ),
              ),
              if (number > 0 && !flip)
                Align(
                  alignment: Alignment(tx * 2 - 1, ty * 2 - 1),
                  child: Text('$number',
                      style: TextStyle(
                          fontFamily: 'NotoSansJP',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: hh * 0.11,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 2)
                          ])),
                ),
            ]),
          ),
        );
      }

      return Stack(fit: StackFit.expand, children: [
        sprite('${poseFile(pose, kid: kind == 'kid')}_$color', w * (versus ? 0.22 : 0.30), figH,
            number: game.number, pose: pose, kid: kind == 'kid'),
        if (versus)
          sprite('adult_$theirs', w * 0.52, h * 0.86 * 0.98,
              flip: true),
      ]);
    });
  }
}

class _CourtPainter extends CustomPainter {
  _CourtPainter(
      {required this.heightCm,
      required this.jersey,
      required this.slot,
      this.versus = false,
      this.number = 0,
      this.layer = _Layer.background});
  final _Layer layer;
  final double heightCm;
  final Color jersey;
  final int slot;
  final bool versus;
  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (layer == _Layer.foreground) {
      _paintOverlay(canvas, size);
      return;
    }
    if (layer == _Layer.fallback) {
      _paintFigures(canvas, size);
      return;
    }

    // 壁(季節で少し色を変える)と床。
    final wall = [
      const Color(0xFFFFE0B2),
      const Color(0xFFFFCCBC),
      const Color(0xFFFFE082),
      const Color(0xFFB3E5FC),
    ][slot.clamp(0, 3)];
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.55), Paint()..color = wall);
    final floorTop = h * 0.55;
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop, w, h - floorTop),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD9A066), Color(0xFFB9803F)],
        ).createShader(Rect.fromLTWH(0, floorTop, w, h - floorTop)),
    );

    // 床のライン。
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, floorTop + 4), Offset(w, floorTop + 4), line);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.78, floorTop + 4),
          width: w * 0.5,
          height: h * 0.8),
      pi,
      pi,
      false,
      line,
    );

    // ゴール(右)。
    final board = Rect.fromLTWH(w * 0.80, h * 0.10, 6, h * 0.30);
    canvas.drawRect(board, Paint()..color = Colors.white);
    canvas.drawRect(
        board,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke);
    final rim = Offset(w * 0.80 - 20, h * 0.36);
    canvas.drawLine(Offset(w * 0.80, h * 0.36), rim,
        Paint()..color = const Color(0xFFE65100)..strokeWidth = 4);
    final net = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(Offset(rim.dx + i * 4, rim.dy),
          Offset(rim.dx + 3 + i * 3, rim.dy + 16), net);
    }

  }

  /// 選手の絵(`assets/art/players/`)が読み込めないときだけ使う、コードで描いた選手。
  void _paintFigures(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 選手。身長 210cm のとき床から壁近くまで、115cm のとき小さく。
    final scale = (heightCm / 210).clamp(0.5, 1.05);
    final figureH = h * 0.78 * scale;
    final baseY = h * 0.92;
    _figure(canvas, Offset(w * (versus ? 0.22 : 0.30), baseY), figureH,
        number: number);
    if (versus) {
      // 向かい合うライバル(暗い色のユニフォーム、やや大きく)。
      _figure(canvas, Offset(w * 0.52, baseY), h * 0.78 * 0.98,
          color: const Color(0xFF263238), flip: true);
    }
  }

  /// 絵の上に、VS と身長を重ねる。
  void _paintOverlay(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (versus) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'VS',
          style: TextStyle(
              fontFamily: 'NotoSansJP',
              color: Color(0xFFFFEB3B),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black87, blurRadius: 5)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.37 - tp.width / 2, h * 0.28));
    }

    // 身長の目盛り(右下)。
    final tp = TextPainter(
      text: TextSpan(
        text: '${heightCm.toStringAsFixed(1)}cm',
        style: const TextStyle(
            fontFamily: 'NotoSansJP',
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w - tp.width - 10, h - tp.height - 6));
  }

  /// 足元 `foot` を基準に、高さ `fh` の選手を描く(ボールを突いている)。
  void _figure(Canvas canvas, Offset foot, double fh,
      {Color? color, bool flip = false, int number = 0}) {
    if (flip) {
      // 左右を反転して描く(足元を軸に)。
      canvas.save();
      canvas.translate(foot.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    final skin = Paint()..color = const Color(0xFFFFCC99);
    final dark = Paint()..color = const Color(0xFF37474F);
    final shirt = Paint()..color = color ?? jersey;
    final head = fh * 0.13;
    final legH = fh * 0.40;
    final bodyH = fh * 0.33;
    final hip = Offset(foot.dx, foot.dy - legH);
    final neck = Offset(foot.dx, hip.dy - bodyH);

    // 影。
    canvas.drawOval(
        Rect.fromCenter(center: foot, width: fh * 0.45, height: fh * 0.07),
        Paint()..color = Colors.black26);

    // 太い輪郭線(背景の絵と画風をそろえる)。
    final ink = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, fh * 0.03)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 脚。
    final legW = fh * 0.07;
    for (final dx in [-1.0, 1.0]) {
      canvas.drawLine(
          hip + Offset(dx * legW, 0),
          foot + Offset(dx * fh * 0.10, 0),
          Paint()
            ..color = ink.color
            ..strokeWidth = legW + ink.strokeWidth * 1.4
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawLine(hip + Offset(-legW, 0), foot + Offset(-fh * 0.10, 0),
        dark..strokeWidth = legW..strokeCap = StrokeCap.round);
    canvas.drawLine(hip + Offset(legW, 0), foot + Offset(fh * 0.10, 0),
        dark..strokeWidth = legW..strokeCap = StrokeCap.round);

    // 胴(ユニフォーム)。
    final body = Path()
      ..moveTo(neck.dx - fh * 0.12, neck.dy)
      ..lineTo(neck.dx + fh * 0.12, neck.dy)
      ..lineTo(hip.dx + fh * 0.10, hip.dy + fh * 0.04)
      ..lineTo(hip.dx - fh * 0.10, hip.dy + fh * 0.04)
      ..close();
    canvas.drawPath(body, shirt);
    canvas.drawPath(body, ink);
    // 背番号(胴の中央)。
    if (number > 0 && !flip) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            fontFamily: 'NotoSansJP',
            color: Colors.white,
            fontSize: fh * 0.14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(neck.dx - tp.width / 2, neck.dy + bodyH * 0.12));
    }

    // 腕と、ボール。
    final hand = Offset(foot.dx + fh * 0.24, hip.dy + fh * 0.12);
    final armInk = Paint()
      ..color = ink.color
      ..strokeWidth = fh * 0.055 + ink.strokeWidth * 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(neck + Offset(fh * 0.10, fh * 0.03), hand, armInk);
    canvas.drawLine(neck + Offset(-fh * 0.10, fh * 0.03),
        Offset(foot.dx - fh * 0.20, hip.dy), armInk);
    final armPaint = Paint()
      ..color = skin.color
      ..strokeWidth = fh * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        neck + Offset(fh * 0.10, fh * 0.03), hand, armPaint);
    canvas.drawLine(neck + Offset(-fh * 0.10, fh * 0.03),
        Offset(foot.dx - fh * 0.20, hip.dy), armPaint);
    final ball = Offset(hand.dx + fh * 0.03, foot.dy - fh * 0.10);
    canvas.drawCircle(ball, fh * 0.075, Paint()..color = const Color(0xFFE65100));
    canvas.drawCircle(ball, fh * 0.075, ink);
    canvas.drawLine(ball + Offset(-fh * 0.075, 0), ball + Offset(fh * 0.075, 0),
        Paint()..color = Colors.black54..strokeWidth = 1.2);

    // 頭。
    canvas.drawCircle(neck + Offset(0, -head), head, skin);
    canvas.drawCircle(neck + Offset(0, -head), head, ink);
    canvas.drawArc(
      Rect.fromCircle(center: neck + Offset(0, -head), radius: head),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFF3E2723),
    );
    if (flip) canvas.restore();
  }

  @override
  bool shouldRepaint(_CourtPainter old) =>
      old.heightCm != heightCm ||
      old.jersey != jersey ||
      old.slot != slot ||
      old.versus != versus ||
      old.layer != layer ||
      old.number != number;
}
