import 'package:flutter/material.dart';

import 'state/career_controller.dart';
import 'ui/club_identity.dart';
import 'ui/screens/create_player_screen.dart';
import 'ui/screens/hub_screen.dart';
import 'ui/screens/retired_screen.dart';

void main() {
  runApp(const SoccerCareerApp());
}

/// 同梱している日本語フォント。
///
/// 指定しないと Web 版が不足分を外部から取りに行き、取りきれなかった字が
/// 豆腐（□）で残る。詳しくは assets/fonts/README.md。
const String _fontFamily = 'NotoSansJP';

class SoccerCareerApp extends StatefulWidget {
  const SoccerCareerApp({super.key});

  @override
  State<SoccerCareerApp> createState() => _SoccerCareerAppState();
}

class _SoccerCareerAppState extends State<SoccerCareerApp> {
  final _controller = CareerController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 既定の色。まだクラブが決まっていないときに使う。
  static const Color _defaultSeed = Color(0xFF1B5E3F);

  ThemeData _themeFor(Color seed, Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        ),
        useMaterial3: true,
        fontFamily: _fontFamily,
      );

  @override
  Widget build(BuildContext context) {
    // 色まで含めて作り直したいので、MaterialApp ごと購読する。
    // 中だけを購読すると、移籍しても色が変わらない。
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 所属クラブの色でアプリ全体を染める。移籍すれば色が変わるので、
        // 「どこに居るのか」が画面を開いた瞬間に分かる。
        final club = _controller.state?.club;
        final seed =
            club == null ? _defaultSeed : ClubIdentity.of(club).primary;
        return MaterialApp(
          title: '選手キャリア',
          debugShowCheckedModeBanner: false,
          theme: _themeFor(seed, Brightness.light),
          darkTheme: _themeFor(seed, Brightness.dark),
          home: _screen(),
        );
      },
    );
  }

  Widget _screen() {
    if (_controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_controller.hasCareer) {
      return CreatePlayerScreen(controller: _controller);
    }
    if (_controller.state!.retired) {
      return RetiredScreen(controller: _controller);
    }
    return HubScreen(controller: _controller);
  }
}
