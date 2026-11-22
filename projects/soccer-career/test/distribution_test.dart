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

/// 見出しの下にある最初の囲みを取り出す。
///
/// **位置で数えない。** 以前は「1つ目がプロモーション、2つ目が説明、
/// 3つ目がキーワード」と順番で取っていたので、**英語の掲載を足した瞬間に
/// 全部ずれた**（2026-11-22）。見出しで引けば、間に何を足しても動かない。
///
/// 改行は `\r?\n` で拾う。Windows で書き換えると CRLF になることがあり、
/// `\n` 決め打ちだと塊が1つも見つからないまま通り過ぎる（実際に踏んだ）。
String _block(String heading) {
  final listing = _listing;
  final at = listing.indexOf(heading);
  if (at < 0) fail('STORE_LISTING.md に見出しが無い: $heading');
  final m = RegExp('`' * 3 + r'\r?\n(.*?)' + '`' * 3, dotAll: true)
      .firstMatch(listing.substring(at));
  if (m == null) fail('$heading の下に囲みが無い（改行の種類が変わった？）');
  return m.group(1)!;
}

/// 基本情報の表の1行を取り出す。
String _row(String label) {
  final m = RegExp('\\| ${RegExp.escape(label)} \\| ([^|]+) \\|')
      .firstMatch(_listing);
  if (m == null) fail('STORE_LISTING.md に行が無い: $label');
  return m.group(1)!.trim();
}

/// 貼る文面の置き場。**日本語と英語で同じ検査を掛ける。**
typedef Listing = ({
  String label,
  String name,
  String subtitle,
  String promo,
  String description,
  String keywords,
  /// 空白を1字として数えるか。**英語は数える。**
  bool countsSpaces,
});

final listings = <Listing>[
  (
    label: '日本語',
    name: 'App 名（30字以内・ストア）',
    subtitle: 'サブタイトル（30字以内）',
    promo: '## プロモーションテキスト（170字以内・審査なしで差し替えられる）',
    description: '## 説明（4000字以内）',
    keywords: '## キーワード（App Store キーワードフィールド、100字以内）',
    countsSpaces: false,
  ),
  (
    label: '英語',
    name: 'App 名（英語・30字以内）',
    subtitle: 'サブタイトル（英語・30字以内）',
    promo: '### プロモーションテキスト（英語）',
    description: '### 説明（英語）',
    keywords: '### キーワード（英語）',
    countsSpaces: true,
  ),
];

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
      // （後ろに値段などが続くので、閉じ括弧までは見ない）
      final kind = product.consumable ? '消耗型' : '非消耗型';
      expect(
        RegExp('`${product.id}`（\\*\\*$kind\\*\\*').hasMatch(listing),
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
    for (final l in listings) {
      for (final label in [l.name, l.subtitle]) {
        final value = _row(label);
        expect(value.length, lessThanOrEqualTo(30),
            reason: '${l.label}: $value');
      }
    }

    for (final l in listings) {
      // **英語は空白も1字。** 日本語は空白を入れないので落として数えて
      // いたが、同じ数え方を英語に掛けると 170 を超えた文面が通ってしまう。
      String measure(String text) => l.countsSpaces
          ? text.trim()
          : text.replaceAll(RegExp(r'\s'), '');
      expect(measure(_block(l.promo)).length, lessThanOrEqualTo(170),
          reason: '${l.label} のプロモーションテキスト');
      expect(_block(l.description).length, lessThanOrEqualTo(4000),
          reason: '${l.label} の説明');
      expect(_block(l.keywords).trim().length, lessThanOrEqualTo(100),
          reason: '${l.label} のキーワード');
    }
  });

  test('App Store Connect が弾く記号を、貼る文面に入れていない', () {
    // **実地で弾かれている**（護送ボート、2026-09-28 の提出）。
    // 「このフィールドには1つ以上の無効な文字が含まれています」としか
    // 出ないので、どの字が悪いのか画面からは読めない。通ったのは
    // 見出しが【】・箇条書きが「・」と「-」の形。
    //
    // **markdown の `*` も見張る。** 貼る文面の中では強調にならず、
    // アスタリスクがそのまま App Store の説明に出る。
    const rejected = ['■', '…', '―', '•', '—', '★', '☆', '*'];
    for (final l in listings) {
      for (final (heading, label) in <(String, String)>[
        (l.promo, 'プロモーションテキスト'),
        (l.description, '説明'),
        (l.keywords, 'キーワード'),
      ]) {
        final found = rejected.where(_block(heading).contains).toList();
        expect(found, isEmpty,
            reason: '${l.label} の$label に ${found.join(" ")}');
      }
    }
  });

  test('名前とサブタイトルの語を、キーワードに重ねていない', () {
    // App Store は「名前 + サブタイトル + キーワード」をまとめて索引し、
    // 語の組み合わせは自分で作る。**同じ語を二度書くと、その字数ぶんだけ
    // 当たる語が減る。** 字数は100しかない。
    for (final l in listings) {
      // 英語は大小を揃えてから見る（Football と football は同じ語）。
      final taken = '${_row(l.name)} ${_row(l.subtitle)}'.toLowerCase();
      final dup = _block(l.keywords)
          .trim()
          .split(',')
          .where((word) => taken.contains(word.trim().toLowerCase()))
          .toList();
      expect(dup, isEmpty,
          reason: '${l.label}: 名前かサブタイトルと重複 ${dup.join(", ")}');
    }
  });

  test('アプリアイコンが、App Store の求める形で揃っている', () {
    // 1024 は**透過も角丸も持てない**（Apple が弾く）。ここを間違えると
    // アップロードの当日に気付くことになる。
    final icon = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    );
    expect(icon.existsSync(), isTrue);
    final bytes = icon.readAsBytesSync();
    final head = bytes.sublist(16, 26);
    int be(int at) =>
        (head[at] << 24) |
        (head[at + 1] << 16) |
        (head[at + 2] << 8) |
        head[at + 3];
    expect([be(0), be(4)], [1024, 1024]);
    // IHDR の colour type。4 と 6 がアルファ付き。
    expect(head[9], isNot(4));
    expect(head[9], isNot(6));
  });

  test('掲載する絵が、App Store の寸法で揃っている', () {
    // **1290x2796（6.9インチ）は、もう App Store Connect が
    // 受け付けない**（2026-11-22 に実際に弾かれた）。iPhone の枠は
    // 「中型ディスプレイ」1つで、通るのは 1179x2556 と 1206x2622。
    const sizes = {
      'marketing/screenshots': [1206, 2622],
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
