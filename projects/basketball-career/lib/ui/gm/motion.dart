import 'package:flutter/material.dart';

import '../../gm/draft.dart';
import '../../sound/sound.dart';
import 'common.dart';
import 'style.dart';

/// 画面の動き(2026-11-15、ユーザー「ドラフト選手の選択とかのアニメーションを増やしてほしい」「淡々触るだけ」)。
/// どれも決まった時間で止まる(繰り返さない)。テストの pumpAndSettle が終わるように。

/// 数の幅(lo〜hi)を、変わったときになめらかに寄せる。スカウトで幅が狭まるのが見える。
/// 別の選手に替わるときは [key] を替えて、寄せずに切り替える。
class AnimatedRange extends StatelessWidget {
  const AnimatedRange({super.key, required this.lo, required this.hi, required this.builder});
  final int lo, hi;
  final Widget Function(BuildContext context, double lo, double hi) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: lo.toDouble()),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (context, l, _) => TweenAnimationBuilder<double>(
      tween: Tween(end: hi.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, h, _) => builder(context, l, h),
    ),
  );
}

/// 押すと弾んで切り替わる印(☆など)。[on] が変わると古い印が縮み、新しい印が跳ねて出る。
class PopIcon extends StatelessWidget {
  const PopIcon({super.key, required this.on, required this.onIcon, required this.offIcon, required this.size, this.onColor, this.offColor});
  final bool on;
  final IconData onIcon, offIcon;
  final double size;
  final Color? onColor, offColor;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 380),
    switchInCurve: Curves.elasticOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, a) => ScaleTransition(
      scale: a,
      child: RotationTransition(turns: Tween(begin: -0.12, end: 0.0).animate(a), child: child),
    ),
    child: Icon(on ? onIcon : offIcon, key: ValueKey(on), size: size, color: on ? onColor : offColor),
  );
}

/// 中身が替わるたび、右から少し滑り込んで浮かび上がる。[id] が同じなら動かない。
class SlideInSwitcher extends StatelessWidget {
  const SlideInSwitcher({super.key, required this.id, required this.child});
  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
    transitionBuilder: (child, a) {
      final incoming = child.key == ValueKey(id);
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: Offset(incoming ? 0.08 : -0.04, 0), end: Offset.zero).animate(a),
          child: child,
        ),
      );
    },
    child: KeyedSubtree(key: ValueKey(id), child: child),
  );
}

/// 出てくるとき、ふわっと拡大して止まる(評価の札など)。[delay] は全体の時間のうちの待ち(0〜1)。
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = 0, this.ms = 700});
  final Widget child;
  final double delay;
  final int ms;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: ms),
    builder: (context, t, child) {
      final k = delay >= 1 ? 1.0 : ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      final s = Curves.elasticOut.transform(k);
      return Opacity(
        opacity: Curves.easeOut.transform(k),
        child: Transform.scale(scale: 0.3 + 0.7 * s, child: child),
      );
    },
    child: child,
  );
}

/// 数を0から数え上げる。
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style, this.ms = 900});
  final int value;
  final TextStyle style;
  final int ms;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: Duration(milliseconds: ms),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('${v.round()}', style: style),
  );
}

/// 指名の発表(壇上の演出)。チームの紋章が出て、選手の名前が浮かぶ。約1.8秒で閉じる。押せば飛ばせる。
Future<void> showPickIntro(NavigatorState nav, Prospect p) {
  return nav.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _PickIntro(p: p),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _PickIntro extends StatefulWidget {
  const _PickIntro({required this.p});
  final Prospect p;

  @override
  State<_PickIntro> createState() => _PickIntroState();
}

class _PickIntroState extends State<_PickIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    Sfx.play(SoundEffect.cheer);
    _a.addStatusListener((s) {
      if (s == AnimationStatus.completed) _close();
    });
    _a.forward();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    // 上に実績の知らせなどが重なっていても、それではなく自分だけを閉じる
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  /// 全体の時間のうち [from]〜[to] の区間で 0→1。
  double _seg(double from, double to, [Curve curve = Curves.easeOutCubic]) => curve.transform(((_a.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final pl = p.player;
    final team = p.pickedBy ?? 0;
    final color = colorOf(team).jersey;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final band = _seg(0, 0.2);
          final logo = _seg(0.08, 0.45, Curves.elasticOut);
          final no = _seg(0.15, 0.35);
          final name = _seg(0.3, 0.55);
          final sub = _seg(0.45, 0.65);
          final shine = _seg(0.3, 0.8, Curves.easeInOut);
          return Material(
            color: Colors.black.withValues(alpha: 0.72 * band),
            child: Center(
              child: ClipRect(
                child: Align(
                  heightFactor: band,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.6 + 3.2 * shine, -0.4),
                        end: Alignment(-0.6 + 3.2 * shine, 0.4),
                        colors: [GmColors.panel, Color.lerp(GmColors.panel, color, 0.55)!, GmColors.panel],
                      ),
                      border: const Border.symmetric(horizontal: BorderSide(color: GmColors.ball, width: 2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.2 + 0.8 * logo,
                          child: Opacity(
                            opacity: logo.clamp(0.0, 1.0),
                            child: TeamBadge(team: team, size: 72),
                          ),
                        ),
                        const SizedBox(width: 22),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Opacity(
                              opacity: no,
                              child: Transform.translate(
                                offset: Offset(0, -10 * (1 - no)),
                                child: Text(
                                  '${p.pickNo}番目の指名',
                                  style: const TextStyle(color: GmColors.gold, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: name,
                              child: Transform.translate(
                                offset: Offset(40 * (1 - name), 0),
                                child: Text(pl.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                            ),
                            Opacity(
                              opacity: sub,
                              child: Text('${pl.pos.short}・${pl.age}歳・${backgroundOf(p)}', style: const TextStyle(fontSize: 13, color: GmColors.sub)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
