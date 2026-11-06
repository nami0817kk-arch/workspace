// 遊び方の画面に、主な決まりの説明が載っているか。新しい決まりを足したら、ここに語を足して載せ忘れを止める。
import 'package:basketball_career/ui/howto_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('遊び方に主な決まりの説明がそろっている', () {
    final all = HowToScreen.items.map((e) => '${e.$1}${e.$2}').join('\n');
    const words = [
      '地区予選',
      '県大会',
      '全国大会',
      '決勝',
      'クォーター',
      'スタミナ',
      '予告',
      '守備',
      '連続攻撃',
      'シュート',
      '組み立て',
      '流れ',
      '疲労',
      '延長',
      'パス',
      '部室',
      '部費',
      '仲間',
      '強豪',
      '気持ち',
      '練習',
      '出来事',
      '実績',
      '難しさ',
    ];
    for (final w in words) {
      expect(all, contains(w), reason: '遊び方に「$w」が載っていない');
    }
  });

  test('項目は多すぎず、1つの説明は長すぎない(読まれるように)', () {
    expect(HowToScreen.items.length, inInclusiveRange(6, 12));
    for (final e in HowToScreen.items) {
      expect(e.$1.length, lessThanOrEqualTo(16), reason: e.$1);
      expect(e.$2.length, lessThanOrEqualTo(130), reason: e.$1);
    }
  });
}
