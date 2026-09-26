import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/progress.dart';
import 'ui/menu_screens.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final progress = await Progress.open(await loadLevels());
  runApp(GosoBoatApp(progress: progress));
}

class GosoBoatApp extends StatelessWidget {
  const GosoBoatApp({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '護送ボート',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Palette.river, surface: Palette.sky),
          scaffoldBackgroundColor: Palette.sky,
          fontFamilyFallback: const ['Hiragino Maru Gothic ProN', 'Hiragino Sans', 'Noto Sans JP'],
          useMaterial3: true,
        ),
        home: HomeScreen(progress: progress),
      );
}
