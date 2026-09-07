import 'package:flutter/material.dart';

import 'state/career_controller.dart';
import 'ui/screens/create_player_screen.dart';
import 'ui/screens/hub_screen.dart';

void main() {
  runApp(const SoccerCareerApp());
}

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
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E3F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
          return HubScreen(controller: _controller);
        },
      ),
    );
  }
}
