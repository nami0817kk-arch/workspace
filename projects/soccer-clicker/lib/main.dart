import 'package:flutter/material.dart';

import 'game/game_controller.dart';
import 'storage/save_store.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = GameController(store: PrefsSaveStore());
  await controller.start();
  runApp(SoccerClickerApp(controller: controller));
}

class SoccerClickerApp extends StatelessWidget {
  const SoccerClickerApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '育成クリッカー',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F8F5B),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F8F5B),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: GameScreen(controller: controller),
    );
  }
}
