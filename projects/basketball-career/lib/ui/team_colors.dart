import 'package:flutter/material.dart';

/// チームの色。`sprite` は選手の絵の色名(`assets/art/players/<絵>_<色名>.png`)、
/// `jersey` はコードで描くときのユニフォームの色、`accent` は画面の差し色(白い字が読める濃さ)。
enum TeamColor {
  blue('blue', Color(0xFF1565C0), Color(0xFF1565C0)),
  yellow('yellow', Color(0xFFF9A825), Color(0xFFB26A00)),
  red('red', Color(0xFFC62828), Color(0xFFC62828)),
  green('green', Color(0xFF2E7D32), Color(0xFF2E7D32)),
  teal('teal', Color(0xFF00838F), Color(0xFF00838F)),
  purple('purple', Color(0xFF6A1B9A), Color(0xFF6A1B9A)),
  orange('orange', Color(0xFFEF6C00), Color(0xFFE65100)),
  pink('pink', Color(0xFFD81B60), Color(0xFFC2185B)),
  sky('sky', Color(0xFF29B6F6), Color(0xFF0277BD)),
  lime('lime', Color(0xFF7CB342), Color(0xFF558B2F)),
  navy('navy', Color(0xFF283593), Color(0xFF283593));

  const TeamColor(this.sprite, this.jersey, this.accent);
  final String sprite;
  final Color jersey;
  final Color accent;
}
