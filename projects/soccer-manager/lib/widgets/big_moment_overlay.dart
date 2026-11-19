import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/big_moment.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../state/settings_controller.dart';

/// まだ見せていない大事な場面があれば、画面いっぱいの1枚を順に出す。
/// ホームに置く(描いたあとに出すので、作り途中の画面を邪魔しない)。
class BigMomentPresenter extends StatefulWidget {
  const BigMomentPresenter({super.key});

  @override
  State<BigMomentPresenter> createState() => _BigMomentPresenterState();
}

class _BigMomentPresenterState extends State<BigMomentPresenter> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final m = gs.nextMoment;
    if (m != null && !_showing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(gs));
    }
    return const SizedBox.shrink();
  }

  Future<void> _show(GameState gs) async {
    if (_showing || !mounted) return;
    final m = gs.nextMoment;
    if (m == null) return;
    final enabled = context.read<SettingsController>().momentsEnabled;
    _showing = true;
    if (enabled) {
      final kind = BigMomentKind.values
          .where((k) => k.name == m[0])
          .firstOrNull;
      if (kind != null) {
        FeedbackService.success();
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: Tr.pick('閉じる', 'Close'),
          barrierColor: Colors.black87,
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (ctx, _, __) =>
              BigMomentView(kind: kind, tag: m[1], body: m[2]),
        );
      }
    }
    await gs.dismissMoment();
    _showing = false;
    if (mounted && gs.nextMoment != null) _show(gs);
  }
}

/// 画面いっぱいの1枚。タップで閉じる。
class BigMomentView extends StatelessWidget {
  final BigMomentKind kind;
  final String tag;
  final String body;

  const BigMomentView(
      {super.key, required this.kind, required this.tag, required this.body});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final headline = Text(
      kind.headline,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.15,
        shadows: [Shadow(blurRadius: 12, color: Colors.black)],
      ),
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(kind.asset, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xCC000000)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(tag,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFE6B53A),
                            fontSize: 14,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (still)
                      headline
                    else
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, child) => Opacity(
                          opacity: 0.3 + 0.7 * t,
                          child: Transform.translate(
                              offset: Offset(0, 16 * (1 - t)), child: child),
                        ),
                        child: headline,
                      ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, height: 1.5)),
                    ),
                    const SizedBox(height: 16),
                    Text(Tr.pick('タップで閉じる', 'Tap to close'),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
