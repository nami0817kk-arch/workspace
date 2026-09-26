/// 掲載する文字列と、アプリの中の文字列を突き合わせる。
///
/// **片方だけ直すと、直したことに気付けない。** URL・商品ID・バンドルIDは
/// アプリ・`STORE_LISTING.md`・Xcode の設定の3か所に散っていて、しかも
/// どれも間違えても動く（アプリは起動するし、ビルドも通る）。間違いが表に
/// 出るのは、利用者がリンクを踏んだとき・買おうとしたときになる。
///
/// 長さの上限も見ている。App Store は入力欄で弾くが、**弾かれるのは提出の
/// 当日**で、そこで文面を考え直す羽目になる。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/monetize/purchase_service.dart';
import 'package:soccer_career/ui/screens/support_screen.dart';

String get _listing => File('STORE_LISTING.md').readAsStringSync();

/// 三連バッククォートで囲まれた塊を順に取り出す。
///
/// 改行は `\r?\n` で拾う。Windows で書き換えると CRLF になることがあり、
/// `\n` 決め打ちだと塊が1つも見つからないまま通り過ぎる（実際に踏んだ）。
List<String> get _blocks => RegExp('`' * 3 + r'\r?\n(.*?)' + '`' * 3,
        dotAll: true)
    .allMatches(_listing)
    .map((m) => m.group(1)!)
    .toList();

void main() {
  test('法務ページのURLが、アプリと掲載情報で一致する', () {
    final listing = _listing;
    for (final page in ['privacy', 'terms', 'support']) {
      final url = '${SupportScreen.legalBase}/$page.html';
      expect(
        listing.contains(url),
        isTrue,
        reason: 'STORE_LISTING.md に $url が無い。'
            'アプリ側は SupportScreen.legalBase を見ている。',
      );
    }
  });

  test('掲載情報に、短いほうのドメインを書いていない', () {
    // soccer-career.pages.dev は**他人のサイト**（同じ着想の別アプリが
    // 先に取っている）。Cloudflare が後ろに -49p を足したのはそのため。
    // 「短いほうが正しそう」と直すと、審査で他人のページを見せることになる。
    final wrong = RegExp(r'https://soccer-career\.pages\.dev');
    expect(wrong.hasMatch(_listing), isFalse);
    expect(wrong.hasMatch(SupportScreen.legalBase), isFalse);
  });

  test('商品IDが、アプリと掲載情報で一致する', () {
    final listing = _listing;
    for (final product in Product.values) {
      expect(
        listing.contains('`${product.id}`'),
        isTrue,
        reason: 'STORE_LISTING.md に ${product.id} が無い',
      );
      // 消耗型と非消耗型を取り違えると、復元の挙動が変わる。
      final kind = product.consumable ? '消耗型' : '非消耗型';
      expect(
        RegExp('`${product.id}`（\\*\\*$kind\\*\\*）').hasMatch(listing),
        isTrue,
        reason: '${product.id} は $kind のはず',
      );
    }
  });

  test('バンドルIDが、Xcode の設定と掲載情報で一致する', () {
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);')
        .allMatches(pbxproj)
        .map((m) => m.group(1)!)
        .where((id) => !id.endsWith('.RunnerTests'))
        .toSet();
    expect(ids, {'com.namiki.soccercareer'});
    expect(_listing.contains('`com.namiki.soccercareer`'), isTrue);
  });

  test('掲載する文面が、App Store の文字数に収まっている', () {
    // 名前とサブタイトルは、**検索で当たる語をここに置く**ぶん長くなりやすい。
    // 30字を1字でも超えると App Store Connect の入力欄が受け付けない。
    for (final row in [
      r'\| App 名（30字以内・ストア） \| ([^|]+) \|',
      r'\| サブタイトル（30字以内） \| ([^|]+) \|',
    ]) {
      final value = RegExp(row).firstMatch(_listing)!.group(1)!.trim();
      expect(value.length, lessThanOrEqualTo(30), reason: value);
    }

    final blocks = _blocks;
    expect(blocks.length, greaterThanOrEqualTo(3),
        reason: '囲みが見つからない（改行の種類が変わった？）');
    // 1つ目がプロモーション、2つ目が説明、3つ目がキーワード。
    expect(
      blocks[0].replaceAll(RegExp(r'\s'), '').length,
      lessThanOrEqualTo(170),
      reason: 'プロモーションテキスト',
    );
    expect(blocks[1].length, lessThanOrEqualTo(4000), reason: '説明');
    expect(blocks[2].trim().length, lessThanOrEqualTo(100), reason: 'キーワード');
  });

  test('名前とサブタイトルの語を、キーワードに重ねていない', () {
    // App Store は「名前 + サブタイトル + キーワード」をまとめて索引し、
    // 語の組み合わせは自分で作る。**同じ語を二度書くと、その字数ぶんだけ
    // 当たる語が減る。** 字数は100しかない。
    final listing = _listing;
    final name = RegExp(r'\| App 名（30字以内・ストア） \| ([^|]+) \|')
        .firstMatch(listing)!
        .group(1)!;
    final subtitle = RegExp(r'\| サブタイトル（30字以内） \| ([^|]+) \|')
        .firstMatch(listing)!
        .group(1)!;
    final taken = '$name $subtitle';
    final dup = _blocks[2]
        .trim()
        .split(',')
        .where((word) => taken.contains(word))
        .toList();
    expect(dup, isEmpty, reason: '名前かサブタイトルと重複: ${dup.join(", ")}');
  });

  test('掲載する絵が、App Store の寸法で揃っている', () {
    const sizes = {
      'marketing/screenshots': [1290, 2796],
      'marketing/screenshots_ipad': [2064, 2752],
    };
    sizes.forEach((dir, size) {
      final files = Directory(dir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      expect(files, isNotEmpty, reason: '$dir に絵が1枚も無い');
      for (final file in files) {
        // PNG の IHDR は先頭16バイトのあとに幅・高さが4バイトずつ並ぶ。
        final head = file.readAsBytesSync().sublist(16, 24);
        int be(int at) =>
            (head[at] << 24) |
            (head[at + 1] << 16) |
            (head[at + 2] << 8) |
            head[at + 3];
        expect([be(0), be(4)], size, reason: file.path);
      }
    });
  });
}
