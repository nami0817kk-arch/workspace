/// **近いのか遠いのかが分かる形にする。**
///
/// 参考にした野球のキャリアゲームは、信頼度を「20 / 100」と数字で出し、
/// 「まだ1軍定着ライン(30)に届いていない」と線まで書く。
/// こちらは言葉だけ（「普通」「疑われている」）で、次の段までの距離が
/// どこにも出ていなかった。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/reputation.dart';

void main() {
  group('次の段までの距離', () {
    test('監督の信頼は、次の段と残りを返す', () {
      const low = Relations(manager: 20, teammates: 50);
      expect(low.managerNext?.$1, '疑われている');
      expect(low.managerNext?.$2, 5);

      const mid = Relations(manager: 48, teammates: 50);
      expect(mid.managerNext?.$1, '普通');
      expect(mid.managerNext?.$2, 2);
    });

    test('一番上の段に居れば、次は無い', () {
      const top = Relations(manager: 90, teammates: 90);
      expect(top.managerNext, isNull);
      expect(top.teammatesNext, isNull);
    });

    test('段の名前は、今の呼び名と同じ言葉を使う', () {
      // 「あと5で『疑われている』」と出しておいて、届いたら別の言葉に
      // なっていたら嘘になる。
      const before = Relations(manager: 24, teammates: 50);
      const after = Relations(manager: 25, teammates: 50);
      expect(before.managerNext?.$1, after.managerLabel);
    });

    test('ロッカールームも同じ形', () {
      const r = Relations(manager: 50, teammates: 10);
      expect(r.teammatesNext?.$1, '距離がある');
      expect(r.teammatesNext?.$2, 15);
      const r2 = Relations(manager: 50, teammates: 24);
      const r3 = Relations(manager: 50, teammates: 25);
      expect(r2.teammatesNext?.$1, r3.teammatesLabel);
    });
  });
}
