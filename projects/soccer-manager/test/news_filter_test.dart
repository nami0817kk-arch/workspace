import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/models/news_item.dart';
import 'package:soccer_manager/screens/news_screen.dart';

/// クラブニュースの絞り込みの検査。
///
/// 1シーズン回すだけで数十件が積み上がり、ユース・移籍・カップ・理事会が
/// 混ざる。並べるだけでは「あの話はどこだったか」にたどり着けない。
void main() {
  const items = [
    NewsItem(season: 1, context: '移籍', text: '田中がクラブに加入'),
    NewsItem(season: 1, context: 'ユース', text: '佐藤が練習試合で3得点'),
    NewsItem(season: 1, context: 'ユース', text: '鈴木が他クラブに引き抜かれました'),
    NewsItem(season: 2, context: 'カップ', text: '準決勝に進出'),
  ];

  test('種類で絞ると、その種類だけが残る', () {
    final hits = NewsScreen.filter(items, context: 'ユース');
    expect(hits.length, 2);
    expect(hits.every((n) => n.context == 'ユース'), isTrue);
  });

  test('本文の言葉で探せる', () {
    expect(NewsScreen.filter(items, query: '引き抜か').length, 1);
    expect(NewsScreen.filter(items, query: '3得点').single.context, 'ユース');
  });

  test('種類と言葉は重ねて効く', () {
    expect(NewsScreen.filter(items, context: '移籍', query: '田中').length, 1);
    expect(NewsScreen.filter(items, context: 'カップ', query: '田中'), isEmpty);
  });

  test('絞り込みを指定しなければ全件返る', () {
    expect(NewsScreen.filter(items).length, items.length);
  });

  test('種類のボタンは、実際に記録がある種類だけ・多い順', () {
    final contexts = NewsScreen.contextsIn(items);
    expect(contexts.first, 'ユース', reason: '件数の多い種類が先頭に来ていない');
    expect(contexts.toSet(), {'ユース', '移籍', 'カップ'});
    expect(contexts, isNot(contains('表彰')),
        reason: '1件も起きていない種類のボタンが出ている');
  });
}
