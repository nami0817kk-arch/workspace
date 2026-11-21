import 'package:flutter/material.dart';

import '../models/legend.dart';

/// 額の格。
///
/// 引退した選手が並ぶ画面が、白いカードに文字が並ぶだけだった。
/// 20年かけて大陸を獲った選手が、10試合で辞めた選手と同じ見た目で残る。
///
/// 色を決めるのは**カードにすでに書いてあるもの**（獲ったタイトル）だけ。
/// 見た目のためだけの数字は作らない。
///
/// **殿堂の画面から出してある**（2026-11-21）。外に送る1枚
/// （`ui/share_card.dart`）も同じ色分けを使うので、画面の中に置いたままだと
/// 画面と部品が互いを読み合うことになる。
enum HallPlaque {
  gold('金', Color(0xFF8A6B1F)),
  silver('銀', Color(0xFF4C555F)),
  bronze('銅', Color(0xFF5C3F2C));

  const HallPlaque(this.label, this.color);

  final String label;
  final Color color;

  static HallPlaque of(Legend legend) {
    if (legend.continentalTitles > 0) return HallPlaque.gold;
    if (legend.leagueTitles > 0 || legend.cupTitles > 0) {
      return HallPlaque.silver;
    }
    return HallPlaque.bronze;
  }
}
