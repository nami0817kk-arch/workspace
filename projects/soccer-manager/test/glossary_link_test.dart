import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/data/glossary_entries.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/glossary_screen.dart';

/// 画面の数字から用語集を引ける導線の検査。
///
/// 用語集は30項目以上あり、開いてから探すのでは「いま見ている数字が何か」に
/// たどり着けない。数字から直接引けること、引いた語が実在することを見る。
void main() {
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  /// ホームのタイルから引く語。ここを増やしたら、対応する項目も足すこと。
  const linkedTerms = ['総合力', '監督への信頼度', '監督としての評価', '観客動員'];

  test('タイルから引く語は、すべて用語集に実在する', () {
    final terms = glossaryEntries.map((e) => e.term).toSet();
    for (final term in linkedTerms) {
      expect(terms, contains(term), reason: '$term が用語集に無い(引いても空振りする)');
    }
  });

  test('語で絞り込むと、その項目だけが残る', () {
    for (final term in linkedTerms) {
      final hits = GlossaryScreen.filter(glossaryEntries, query: term);
      expect(hits, isNotEmpty, reason: '$term で検索して0件');
      expect(hits.any((e) => e.term == term), isTrue);
    }
  });

  testWidgets('初期の検索語を渡すと、その語で絞られた状態で開く', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: GlossaryScreen(initialQuery: '観客動員'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('観客動員'), findsWidgets);
    // 無関係の項目は出ていない。
    expect(find.text('リリース条項'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
