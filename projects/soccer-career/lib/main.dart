import 'package:flutter/material.dart';

import 'state/career_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '選手キャリア',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E3F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: _fontFamily,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E3F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: _fontFamily,
      ),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_controller.hasCareer) {
            return CreatePlayerScreen(controller: _controller);
          }
          if (_controller.state!.retired) {
            return RetiredScreen(controller: _controller);
          }
          return HubScreen(controller: _controller);
        },
      ),
    );
  }
}
