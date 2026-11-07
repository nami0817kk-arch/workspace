// 遊び方の画面に、主な決まりの説明が載っているか。新しい決まりを足したら、ここに語を足して載せ忘れを止める。
import 'package:basketball_career/ui/howto_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('遊び方に主な決まりの説明がそろっている', () {
    final all = HowToScreen.items.map((e) => '${e.$1}${e.$2}').join('\n');
    const words = [
      'GM',
      '10年',
      '82試合',
      'プレーイン',
      'ファイナル',
      'プレーオフ',
      '伸びしろ',
      'OVR',
      'POT',
      '引退',
      '年俸の上限',
      '再契約',
      '最低年俸',
      'ぜいたく税',
      'トレード',
      '指名権',
      '締め切り',
      'ドラフト',
      'スカウト',
      'くじ',
      '自由契約',
      '延長',
      'オーナーの信頼',
      '解任',
      '実績',
      '先発と控え',
      '気持ち',
      '入場料',
      'けが',
      'トレーナー',
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
