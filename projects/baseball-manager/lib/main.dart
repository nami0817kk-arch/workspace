import 'package:flutter/material.dart';

void main() => runApp(const BaseballManagerApp());

class BaseballManagerApp extends StatelessWidget {
  const BaseballManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('baseball-manager'))),
    );
  }
}
