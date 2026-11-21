import 'package:flutter/material.dart';

import '../l10n/lang.dart';
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
  gold(Color(0xFF8A6B1F)),
  silver(Color(0xFF4C555F)),
  bronze(Color(0xFF5C3F2C));

  const HallPlaque(this.color);

  final Color color;

  /// 額に出す字。**`const` では持てない**——enum の引数は定数なので、
  /// そこに入れると起動時の言語で固まり、切り替えても古い言葉が残る。
  String get label => switch (this) {
    HallPlaque.gold => tr('金', 'Gold'),
    HallPlaque.silver => tr('銀', 'Silver'),
    HallPlaque.bronze => tr('銅', 'Bronze'),
  };

  static HallPlaque of(Legend legend) {
    if (legend.continentalTitles > 0) return HallPlaque.gold;
    if (legend.leagueTitles > 0 || legend.cupTitles > 0) {
      return HallPlaque.silver;
    }
    return HallPlaque.bronze;
  }
}
