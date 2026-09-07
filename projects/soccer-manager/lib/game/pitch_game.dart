import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/match_result.dart';
import '../theme/club_palette.dart';

/// ピッチ上でのミニアニメーションと、[events]の分単位での実況出しを行う。
/// [startMinute]〜[endMinute]の区間を[durationSeconds]かけて進行させるため、
/// 前半・後半をそれぞれ独立したインスタンスとして使うこともできる。
///
/// 描画はすべてコードで行う(画像アセットを持たない)。クラブ名は自由入力で、
/// 対戦カードの組み合わせも無数にあるため、絵を用意しておく方式が取れない。
class PitchGame extends FlameGame {
  final List<MatchEvent> events;
  final int startMinute;
  final int endMinute;
  final double durationSeconds;
  final void Function(MatchEvent event) onEvent;
  final VoidCallback onFinished;
  final void Function(int minute)? onMinuteTick;

  /// ユニフォームの色をエンブレムと揃えるためのチームID。
  /// 渡さない場合は既定の青/赤で描く。
  final String? homeTeamId;
  final String? awayTeamId;

  PitchGame({
    required this.events,
    this.startMinute = 1,
    this.endMinute = 90,
    this.durationSeconds = 12,
    required this.onEvent,
    required this.onFinished,
    this.onMinuteTick,
    this.homeTeamId,
    this.awayTeamId,
  });

  late _Ball _ball;
  final List<_PlayerDot> _dots = [];
  double _elapsed = 0;
  int _eventIndex = 0;
  late int _lastMinute;
  bool _finished = false;

  /// ボールの行き先。一定間隔で選び直して、そこへ滑らかに寄せる。
  late Vector2 _ballTarget;
  double _sinceTargetChange = 0;

  /// 描画の見た目を実行のたびに変えないための固定シード。
  /// 試合結果はイベント列で決まっており、ここでの乱数は「どう見えるか」
  /// にしか関わらない。固定しておけば画面の検査も安定する。
  final Random _rng = Random(20260907);

  /// ホームが攻める向き。左から右。
  static const double _homeAttackX = 0.95;
  static const double _awayAttackX = 0.05;

  /// 4-4-2 を正規化座標(0..1)で置いたもの。ホームは左半分から右を攻める。
  static const List<({double x, double y, bool keeper})> formation = [
    (x: 0.05, y: 0.50, keeper: true),
    (x: 0.20, y: 0.18, keeper: false),
    (x: 0.19, y: 0.39, keeper: false),
    (x: 0.19, y: 0.61, keeper: false),
    (x: 0.20, y: 0.82, keeper: false),
    (x: 0.38, y: 0.16, keeper: false),
    (x: 0.36, y: 0.40, keeper: false),
    (x: 0.36, y: 0.60, keeper: false),
    (x: 0.38, y: 0.84, keeper: false),
    (x: 0.55, y: 0.38, keeper: false),
    (x: 0.55, y: 0.62, keeper: false),
  ];

  @override
  Future<void> onLoad() async {
    _lastMinute = startMinute - 1;

    add(_PitchSurface()..size = size);

    final home = homeTeamId == null
        ? const ClubPalette.fromHue(220)
        : ClubPalette.of(homeTeamId!);
    // 色が近いクラブ同士の対戦では、アウェイ側の色相をずらす。
    final away = (awayTeamId == null
            ? const ClubPalette.fromHue(10)
            : ClubPalette.of(awayTeamId!))
        .distinguishedFrom(home);

    for (final slot in formation) {
      _addDot(slot.x, slot.y, home, slot.keeper);
      _addDot(1 - slot.x, slot.y, away, slot.keeper);
    }

    _ballTarget = Vector2(size.x / 2, size.y / 2);
    _ball = _Ball()
      ..position = Vector2(size.x / 2, size.y / 2)
      ..anchor = Anchor.center;
    add(_ball);
  }

  void _addDot(double nx, double ny, ClubPalette palette, bool keeper) {
    final dot = _PlayerDot(
      // キーパーは自チームの補色。固定色にすると、たまたま同じ色の
      // クラブと当たったときに味方と見分けがつかなくなる。
      fill: keeper ? palette.keeperKit : palette.kit,
      outline: keeper ? palette.keeperOutline : palette.kitOutline,
      homePosition: Vector2(nx * size.x, ny * size.y),
      // キーパーはボールに引っ張られない。ゴール前を空けてしまうと
      // 11人が団子になって動く絵になり、布陣が読めなくなる。
      pull: keeper ? 0.03 : 0.16,
      wobblePhase: _rng.nextDouble() * pi * 2,
    )..anchor = Anchor.center;
    dot.position = dot.homePosition.clone();
    _dots.add(dot);
    add(dot);
  }

  /// 次に起きるイベントを出すチームの攻撃方向へ、ボールを寄せる。
  /// 得点の直前にボールが自陣にいると、実況と絵が食い違って見える。
  double _attackBiasX() {
    if (_eventIndex >= events.length) return 0.5;
    final next = events[_eventIndex];
    if (homeTeamId != null && next.teamId == homeTeamId) return _homeAttackX;
    if (awayTeamId != null && next.teamId == awayTeamId) return _awayAttackX;
    return 0.5;
  }

  void _pickBallTarget() {
    final bias = _attackBiasX();
    // 完全に寄せ切らず、中盤も使う。ずっと同じ側にいると試合に見えない。
    final x = (bias * 0.55 + _rng.nextDouble() * 0.45) * size.x;
    final y = (0.12 + _rng.nextDouble() * 0.76) * size.y;
    _ballTarget = Vector2(x.clamp(8.0, size.x - 8), y.clamp(8.0, size.y - 8));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    _elapsed += dt;
    final span = endMinute - startMinute;
    final progressMinute = (startMinute + (_elapsed / durationSeconds * span))
        .clamp(startMinute, endMinute);
    final minuteFloor = progressMinute.floor();
    if (minuteFloor > _lastMinute) {
      _lastMinute = minuteFloor;
      onMinuteTick?.call(_lastMinute);
    }

    _sinceTargetChange += dt;
    if (_sinceTargetChange > 0.9) {
      _sinceTargetChange = 0;
      _pickBallTarget();
    }
    // 目標へ一定割合ずつ寄せる。dt を掛けているので、端末の描画速度が
    // 変わってもボールの速さは変わらない。
    final toTarget = _ballTarget - _ball.position;
    _ball.position += toTarget * (2.6 * dt).clamp(0.0, 1.0);

    for (final dot in _dots) {
      dot.follow(_ball.position, _elapsed, dt);
    }

    while (_eventIndex < events.length &&
        events[_eventIndex].minute <= progressMinute) {
      onEvent(events[_eventIndex]);
      _eventIndex++;
    }

    if (_elapsed >= durationSeconds && !_finished) {
      _finished = true;
      while (_eventIndex < events.length) {
        onEvent(events[_eventIndex]);
        _eventIndex++;
      }
      onMinuteTick?.call(endMinute);
      onFinished();
    }
  }
}

/// 芝とライン。1つのコンポーネントでまとめて描く。
/// ライン1本ずつをコンポーネントにすると数十個になり、毎フレームの
/// 走査が無駄に増える。
class _PitchSurface extends PositionComponent {
  static const _turfDark = Color(0xFF20642A);
  static const _turfLight = Color(0xFF2C7C36);
  static const _line = Color(0xCCFFFFFF);

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // 芝刈りの縞。実際のピッチと同じで、これが無いと平らな板に見える。
    const stripes = 8;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w / stripes * i, 0, w / stripes + 1, h),
        Paint()..color = i.isEven ? _turfDark : _turfLight,
      );
    }

    final linePaint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // タッチライン。ピッチの縁は少し内側に取り、外周に余白を残す。
    final margin = min(w, h) * 0.05;
    final field = Rect.fromLTRB(margin, margin, w - margin, h - margin);
    canvas.drawRect(field, linePaint);

    // ハーフウェイライン、センターサークル、キックオフスポット。
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      linePaint,
    );
    final circleR = field.height * 0.17;
    canvas.drawCircle(field.center, circleR, linePaint);
    canvas.drawCircle(field.center, 2.2, Paint()..color = _line);

    for (final left in const [true, false]) {
      final boxW = field.width * 0.16;
      final boxH = field.height * 0.60;
      final goalAreaW = field.width * 0.055;
      final goalAreaH = field.height * 0.28;
      final goalH = field.height * 0.16;

      // ペナルティエリア。
      final x0 = left ? field.left : field.right - boxW;
      canvas.drawRect(
        Rect.fromLTWH(x0, field.center.dy - boxH / 2, boxW, boxH),
        linePaint,
      );
      // ゴールエリア。
      final gx0 = left ? field.left : field.right - goalAreaW;
      canvas.drawRect(
        Rect.fromLTWH(
            gx0, field.center.dy - goalAreaH / 2, goalAreaW, goalAreaH),
        linePaint,
      );
      // ペナルティスポットと、エリアの外へ出る分のアーク。
      final spotX = left
          ? field.left + field.width * 0.105
          : field.right - field.width * 0.105;
      canvas.drawCircle(
          Offset(spotX, field.center.dy), 2.0, Paint()..color = _line);
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(spotX, field.center.dy), radius: circleR),
        left ? -pi / 3 : pi - pi / 3,
        pi * 2 / 3,
        false,
        linePaint,
      );

      // ゴール。タッチラインの外側へ張り出させる。
      final goalDepth = margin * 0.55;
      final goalRect = Rect.fromLTWH(
        left ? field.left - goalDepth : field.right,
        field.center.dy - goalH / 2,
        goalDepth,
        goalH,
      );
      canvas.drawRect(goalRect, Paint()..color = const Color(0x33FFFFFF));
      canvas.drawRect(goalRect, linePaint);
    }

    // コーナーアーク。
    final cornerR = min(w, h) * 0.028;
    void corner(Offset center, double startAngle) => canvas.drawArc(
        Rect.fromCircle(center: center, radius: cornerR),
        startAngle,
        pi / 2,
        false,
        linePaint);
    corner(field.topLeft, 0);
    corner(field.topRight, pi / 2);
    corner(field.bottomRight, pi);
    corner(field.bottomLeft, -pi / 2);
  }
}

/// 選手1人。持ち場を中心に、ボールの方へ少しだけ引かれる。
class _PlayerDot extends PositionComponent {
  final Color fill;
  final Color outline;
  final Vector2 homePosition;
  final double pull;
  final double wobblePhase;

  _PlayerDot({
    required this.fill,
    required this.outline,
    required this.homePosition,
    required this.pull,
    required this.wobblePhase,
  });

  static const double radius = 4.6;

  void follow(Vector2 ball, double elapsed, double dt) {
    // 持ち場とボールの間のどこかへ。全員がボールに集まると布陣が消える。
    final want = homePosition + (ball - homePosition) * pull;
    // 立ち止まらせない程度の揺らぎ。
    want.x += sin(elapsed * 1.7 + wobblePhase) * 2.4;
    want.y += cos(elapsed * 1.3 + wobblePhase) * 2.4;
    position += (want - position) * (3.2 * dt).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
        Offset.zero, radius, Paint()..color = const Color(0x44000000));
    canvas.drawCircle(const Offset(0, -1), radius, Paint()..color = fill);
    canvas.drawCircle(
      const Offset(0, -1),
      radius,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }
}

class _Ball extends PositionComponent {
  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
        const Offset(0, 1.5), 3.4, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(Offset.zero, 3.4, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset.zero,
      3.4,
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }
}
