import 'package:flutter/material.dart';

void main() => runApp(const BasketballCareerApp());

/// 起動確認用の最小画面。画面は別の作業で作る(エンジンは lib/game/)。
class BasketballCareerApp extends StatelessWidget {
  const BasketballCareerApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'バスケ育成',
        home: Scaffold(body: Center(child: Text('バスケ育成'))),
      );
}
