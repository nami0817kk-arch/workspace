// 掲載文の下書きが、App Store Connect の制限に収まっていること。
// 文字数の上限と、弾かれる記号(★ ■ … ―― • —)を提出する文面に使っていないこと。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String md() => File('STORE_LISTING.md').readAsStringSync();

  String section(String from, String to) {
    final m = md();
    final i = m.indexOf(from);
    final j = m.indexOf(to, i + 1);
    expect(i, greaterThanOrEqualTo(0), reason: from);
    expect(j, greaterThan(i), reason: to);
    return m.substring(i, j);
  }

  String cell(String label, int col) {
    final m = RegExp('\\| $label[^|]*\\|\\s*([^|]+?)\\s*\\|\\s*([^|]+?)\\s*\\|')
        .firstMatch(md());
    expect(m, isNotNull, reason: label);
    return m!.group(col)!.trim();
  }

  /// 「（17字）」のような括弧書きを除いた本体。
  String body(String s) => s.replaceAll(RegExp(r'（\d+字）'), '').trim();

  test('名前・サブタイトルは30字まで', () {
    for (final col in [1, 2]) {
      expect(body(cell('名前', col)).length, lessThanOrEqualTo(30));
      expect(body(cell('サブタイトル', col)).length, lessThanOrEqualTo(30));
    }
  });

  test('キーワードは100字まで。名前・サブタイトルの語と重ねない', () {
    final ja = cell('キーワード', 1), en = cell('キーワード', 2);
    expect(ja.length, lessThanOrEqualTo(100));
    expect(en.length, lessThanOrEqualTo(100));
    final jaName = body(cell('名前', 1)) + body(cell('サブタイトル', 1));
    for (final k in ja.split(',')) {
      expect(jaName.contains(k), isFalse, reason: '「$k」が名前・サブタイトルと重なる');
    }
  });

  test('プロモーションテキストは170字まで', () {
    final promo = section('## プロモーションテキスト', '## 説明文')
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .join()
        .trim();
    expect(promo.length, lessThanOrEqualTo(170));
    expect(promo, isNotEmpty);
  });

  test('説明文は4000字まで', () {
    final desc = section('## 説明文（日本語）', '## スクリーンショット');
    expect(desc.length, lessThanOrEqualTo(4000));
  });

  test('提出する文面に、弾かれる記号を使っていない', () {
    final submit = section('## プロモーションテキスト', '## スクリーンショット');
    for (final ch in ['★', '■', '…', '―', '•', '—']) {
      expect(submit.contains(ch), isFalse,
          reason: 'U+${ch.codeUnitAt(0).toRadixString(16)}');
    }
    for (final ch in ['★', '■', '―', '•', '—']) {
      expect(cell('名前', 1).contains(ch), isFalse);
      expect(cell('キーワード', 1).contains(ch), isFalse);
    }
  });

  test('実在の名称(商標)を提出する文面に入れていない', () {
    final submit = section('## 名前・サブタイトル・キーワード', '## スクリーンショット');
    final texts =
        submit.split('\n').where((l) => !l.startsWith('- ')).join('\n');
    for (final w in [
      'NPB',
      '日本野球機構',
      'プロ野球',
      '甲子園',
      'メジャーリーグ',
      'MLB',
      'WBC',
      'ワールド・ベースボール',
      '国民栄誉賞',
      '沢村賞'
    ]) {
      expect(texts.contains(w), isFalse, reason: w);
    }
  });

  test('個人の名前・ユーザー名を入れていない', () {
    expect(
        RegExp(r'\bnami\b|0817|なみ', caseSensitive: false).hasMatch(
            md().split('\n').where((l) => !l.contains('入れない')).join('\n')),
        isFalse);
  });
}
