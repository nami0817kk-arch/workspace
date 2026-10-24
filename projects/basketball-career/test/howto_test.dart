// 遊び方の画面に、主な機能の説明が載っているか。新しい機能を足したら、ここに語を足して載せ忘れを止める。
import 'package:basketball_career/ui/howto_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('遊び方に主な機能の説明がそろっている', () {
    final all = HowToScreen.items.map((e) => '${e.$1}${e.$2}').join('\n');
    const words = [
      '勝負どころ',
      'タイムアウト',
      'ハーフタイム',
      '持ち味',
      '研究',
      'ファウル',
      '勢い',
      '身長',
      '生活習慣',
      'ビルド',
      '特性',
      '得意技',
      'ドラフト',
      '年俸',
      'スポンサー',
      'フリーエージェント',
      '表彰',
      '殿堂',
      '図鑑',
    ];
    for (final w in words) {
      expect(all, contains(w), reason: '遊び方に「$w」が載っていない');
    }
  });

  test('項目は多すぎず、1つの説明は長すぎない(読まれるように)', () {
    expect(HowToScreen.items.length, inInclusiveRange(7, 14));
    for (final e in HowToScreen.items) {
      expect(e.$1.length, lessThanOrEqualTo(16), reason: e.$1);
      expect(e.$2.length, lessThanOrEqualTo(110), reason: e.$1);
    }
  });
}
