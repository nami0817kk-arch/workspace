import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/models/news_item.dart';
import 'package:soccer_manager/screens/inbox_screen.dart';

/// 受信箱の絞り込み・分類・件名の検査(2026-11-25 にクラブニュースを受信箱へ
/// 一本化した)。
///
/// 1シーズン回すだけで数十件が積み上がり、ユース・移籍・カップ・理事会が
/// 混ざる。並べるだけでは「あの話はどこだったか」にたどり着けない。
void main() {
  const items = [
    NewsItem(season: 1, context: '移籍', text: '田中がクラブに加入'),
    NewsItem(season: 1, context: 'ユース', text: '佐藤が練習試合で3得点'),
    NewsItem(season: 1, context: 'ユース', text: '鈴木が他クラブに引き抜かれました'),
    NewsItem(season: 2, context: 'カップ戦', text: '準決勝に進出'),
  ];

  test('分類で絞ると、その分類だけが残る', () {
    final hits = InboxScreen.filter(items, category: NewsCategory.people);
    expect(hits.length, 2);
    expect(hits.every((n) => n.context == 'ユース'), isTrue);
  });

  test('本文の言葉で探せる', () {
    expect(InboxScreen.filter(items, query: '引き抜か').length, 1);
    expect(InboxScreen.filter(items, query: '3得点').single.context, 'ユース');
  });

  test('分類と言葉は重ねて効く', () {
    expect(
        InboxScreen.filter(items,
                category: NewsCategory.transfers, query: '田中')
            .length,
        1);
    expect(
        InboxScreen.filter(items, category: NewsCategory.matches, query: '田中'),
        isEmpty);
  });

  test('絞り込みを指定しなければ全件返る', () {
    expect(InboxScreen.filter(items).length, items.length);
  });

  test('文脈の札は日本語でも英語でも5つの分類のどれかに入る', () {
    for (final (ja, en, want) in const [
      ('移籍', 'Transfers', NewsCategory.transfers),
      ('仮契約', 'Pre-contract', NewsCategory.transfers),
      ('スタッフ', 'Staff', NewsCategory.people),
      ('医療', 'Medical', NewsCategory.people),
      ('放映権', 'TV rights', NewsCategory.money),
      ('投資案件', 'Projects', NewsCategory.money),
      ('株主総会', "Shareholders' meeting", NewsCategory.board),
      ('他のオーナー', 'Rival owners', NewsCategory.board),
      ('最後通告', 'Final warning', NewsCategory.board),
      ('第12節', 'Matchday 12', NewsCategory.matches),
      ('カップ戦', 'Cup', NewsCategory.matches),
    ]) {
      expect(NewsCategory.of(ja), want, reason: ja);
      expect(NewsCategory.of(en), want, reason: en);
    }
  });

  test('名前の並びは、件名では人数にまとめる', () {
    expect(InboxScreen.subjectOf('引退: 山田、佐藤、鈴木、高橋'), '引退(4人)');
    expect(InboxScreen.subjectOf('田中がクラブに加入'), '田中がクラブに加入');
  });

  test('日付は保存して読み戻せ、古いお知らせ(日付なし)も読める', () {
    final n = NewsItem(
        season: 2, context: '移籍', text: 'a', date: DateTime(2026, 8, 16));
    final back = NewsItem.fromJson(n.toJson());
    expect(back.date, DateTime(2026, 8, 16));
    final old = NewsItem.fromJson(const {'season': 1, 'context': '移籍', 'text': 'b'});
    expect(old.date, isNull);
  });
}
